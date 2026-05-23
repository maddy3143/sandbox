"""
Async Twilio service — TwiML generation, call state management, and
Redis-backed conversation history.

All Twilio SDK calls (which are synchronous) are dispatched via a
ThreadPoolExecutor so they never block the event loop.
"""
from __future__ import annotations

import asyncio
import json
import logging
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from functools import partial
from typing import Optional
from xml.sax.saxutils import escape as xml_escape

from config.settings import settings
from services.cache import redis_cache

logger = logging.getLogger(__name__)

# Thread pool for Twilio's blocking REST client calls
_executor = ThreadPoolExecutor(max_workers=4, thread_name_prefix="twilio-")

# Redis TTL for call state — 2 hours, covers longest calls + post-processing
_CALL_TTL = 7200

# ---------------------------------------------------------------------------
# Language → voice mappings
# ---------------------------------------------------------------------------
# Each entry is (twilio_language_code, google_tts_voice_name).
# Telugu (te-IN) has no Twilio-supported TTS voice; we fall back to an Indian
# English Neural2 voice which is the closest audibly acceptable proxy.
_LANGUAGE_VOICE_MAP: dict[str, tuple[str, str]] = {
    "te-IN": ("en-IN", "en-IN-Neural2-C"),
    "hi-IN": ("hi-IN", "hi-IN-Neural2-A"),
    "en-US": ("en-US", "en-US-Neural2-F"),
    "ar-XA": ("ar",    "ar-XA-Neural2-A"),
    "kn-IN": ("kn-IN", "kn-IN-Standard-A"),
}

_DEFAULT_TWILIO_LANG = "en-US"
_DEFAULT_VOICE_NAME = "en-US-Neural2-F"


# ---------------------------------------------------------------------------
# Private base-URL helper
# ---------------------------------------------------------------------------

def _base_url() -> str:
    """Return the publicly reachable backend base URL (no trailing slash)."""
    return getattr(settings, "BACKEND_BASE_URL", "https://api.arobjectscanner.com")


# ---------------------------------------------------------------------------
# TwiML element builders (pure string helpers — no I/O)
# ---------------------------------------------------------------------------

def _say_tag(
    text: str,
    language: str = "en-US",
    voice: str = "Polly.Joanna",
) -> str:
    """Return a ``<Say>`` TwiML element with XML-escaped text."""
    return (
        f'<Say language="{xml_escape(language)}" voice="{xml_escape(voice)}">'
        f"{xml_escape(text)}"
        f"</Say>"
    )


def _play_tag(url: str) -> str:
    """Return a ``<Play>`` TwiML element."""
    return f"<Play>{xml_escape(url)}</Play>"


def _pause_tag(seconds: int = 1) -> str:
    return f'<Pause length="{seconds}"/>'


def _gather_tag(
    action: str,
    language: str,
    timeout: int = 8,
    speech_timeout: int = 3,
    inner: str = "",
) -> str:
    """Return a ``<Gather>`` element that collects speech input."""
    return (
        f'<Gather input="speech" action="{xml_escape(action)}" method="POST" '
        f'language="{xml_escape(language)}" timeout="{timeout}" '
        f'speechTimeout="{speech_timeout}" enhanced="true">'
        f"{inner}"
        f"</Gather>"
    )


def _redirect_tag(url: str) -> str:
    return f'<Redirect method="POST">{xml_escape(url)}</Redirect>'


def _hangup_tag() -> str:
    return "<Hangup/>"


def _wrap_twiml(*elements: str) -> str:
    """Wrap TwiML verb elements in a ``<Response>`` root with XML declaration."""
    body = "".join(elements)
    return f'<?xml version="1.0" encoding="UTF-8"?><Response>{body}</Response>'


# ---------------------------------------------------------------------------
# Service class
# ---------------------------------------------------------------------------


class TwilioService:
    """
    Encapsulates all Twilio interactions for the AI voice call assistant.

    Blocking Twilio REST calls are dispatched to a thread-pool executor so
    the FastAPI event loop is never blocked.

    Parameters
    ----------
    account_sid:
        Twilio Account SID (``AC…``).
    auth_token:
        Twilio Auth Token.
    phone_number:
        The Twilio phone number used to originate/handle calls (E.164 format).
    """

    def __init__(
        self,
        account_sid: str,
        auth_token: str,
        phone_number: str,
    ) -> None:
        self._account_sid = account_sid
        self._auth_token = auth_token
        self._phone_number = phone_number
        self._client: Optional[object] = None  # lazy-initialised on first real use

    # ------------------------------------------------------------------
    # Twilio REST client — lazy, thread-safe initialisation
    # ------------------------------------------------------------------

    def _get_client(self):
        """Return (or create) the Twilio REST client."""
        if self._client is None:
            from twilio.rest import Client  # type: ignore[import]
            self._client = Client(self._account_sid, self._auth_token)
        return self._client

    async def _run_in_executor(self, func, *args, **kwargs):
        """Dispatch a synchronous callable to the thread pool executor."""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            _executor,
            partial(func, *args, **kwargs),
        )

    # ------------------------------------------------------------------
    # TwiML generators
    # ------------------------------------------------------------------

    async def generate_hold_twiml(self, call_id: str) -> str:
        """
        Return TwiML that plays a brief hold message then polls the backend
        every ~5 s until the user makes a call-handling decision.

        The ``<Redirect>`` at the end causes Twilio to POST to the poll
        endpoint, which either loops or branches based on the stored decision.
        """
        poll_url = f"{_base_url()}/v1/calls/webhook/poll/{call_id}"
        twiml = _wrap_twiml(
            _say_tag(
                "Hello! Please hold for just a moment while we connect you.",
                language="en-US",
                voice="Polly.Joanna",
            ),
            _pause_tag(4),
            _redirect_tag(poll_url),
        )
        logger.debug("Generated hold TwiML for call_id=%s", call_id)
        return twiml

    async def generate_ai_answer_twiml(
        self,
        call_id: str,
        language: str,
        first_turn: bool = True,
    ) -> str:
        """
        Return TwiML that starts an AI-driven conversation.

        On the first turn we play a greeting inside the ``<Gather>`` so the
        speech capture begins immediately after the greeting ends.  Recording
        is enabled via a ``<Record>`` verb placed *before* the gather loop so
        Twilio captures the full call audio in parallel.

        Parameters
        ----------
        call_id:
            Unique call identifier used to build webhook callback URLs.
        language:
            BCP-47 language code for Twilio's speech recognition.
        first_turn:
            When ``True`` a greeting message is injected into the gather.
        """
        twilio_lang, _ = _language_to_voice_parts(language)
        gather_url = f"{_base_url()}/v1/calls/webhook/gather/{call_id}"
        recording_callback = f"{_base_url()}/v1/calls/webhook/recording/{call_id}"

        # <Record> runs asynchronously while the gather loop handles the
        # conversation; recordingStatusCallback fires when the recording is
        # ready (after the call ends).
        record_tag = (
            f'<Record action="{xml_escape(recording_callback)}" '
            f'recordingStatusCallback="{xml_escape(recording_callback)}" '
            f'maxLength="3600" playBeep="false" trim="trim-silence"/>'
        )

        greeting = (
            _say_tag(
                "Hello, I'm an AI assistant. How can I help you today?",
                language=twilio_lang,
                voice="Polly.Joanna" if language == "en-US" else "woman",
            )
            if first_turn
            else ""
        )

        gather = _gather_tag(
            action=gather_url,
            language=twilio_lang,
            timeout=8,
            speech_timeout=3,
            inner=greeting,
        )

        # Fallback path when the gather times out with no speech
        fallback_say = _say_tag(
            "I didn't catch that. Could you please repeat?",
            language=twilio_lang,
        )
        redirect = _redirect_tag(gather_url)

        twiml = _wrap_twiml(record_tag, gather, fallback_say, redirect)
        logger.debug(
            "Generated AI answer TwiML for call_id=%s first_turn=%s", call_id, first_turn
        )
        return twiml

    async def generate_decline_twiml(self) -> str:
        """Return TwiML that politely declines the call and hangs up."""
        twiml = _wrap_twiml(
            _say_tag(
                "I'm sorry, the person you're calling is unavailable right now. "
                "Please try again later or leave a message after the tone.",
                language="en-US",
                voice="Polly.Joanna",
            ),
            _pause_tag(1),
            _hangup_tag(),
        )
        logger.debug("Generated decline TwiML")
        return twiml

    async def generate_gather_twiml(
        self,
        call_id: str,
        prompt_audio_url: str,
        language: str,
    ) -> str:
        """
        Play a pre-synthesised TTS audio clip inside a ``<Gather>`` so Twilio
        begins listening for the caller's response immediately after the clip
        finishes.

        Parameters
        ----------
        call_id:
            Unique call identifier.
        prompt_audio_url:
            Publicly accessible URL (e.g. S3 presigned) to an MP3/WAV file
            containing the AI assistant's response.
        language:
            BCP-47 language code for Twilio's ASR.
        """
        twilio_lang, _ = _language_to_voice_parts(language)
        gather_url = f"{_base_url()}/v1/calls/webhook/gather/{call_id}"

        # Play the audio clip *inside* the <Gather> so speech recognition is
        # active while (and after) the clip plays.
        inner_play = _play_tag(prompt_audio_url)
        gather = _gather_tag(
            action=gather_url,
            language=twilio_lang,
            timeout=8,
            speech_timeout=3,
            inner=inner_play,
        )

        # Fallback when the caller doesn't respond after the audio finishes
        fallback_say = _say_tag(
            "Sorry, I couldn't hear you. Please say that again.",
            language=twilio_lang,
        )
        redirect = _redirect_tag(gather_url)

        twiml = _wrap_twiml(gather, fallback_say, redirect)
        logger.debug("Generated gather TwiML for call_id=%s lang=%s", call_id, language)
        return twiml

    # ------------------------------------------------------------------
    # Redis state management
    # ------------------------------------------------------------------

    async def update_call_state(self, call_id: str, state: dict) -> None:
        """Persist an arbitrary call-state dict to Redis (merges with existing)."""
        key = f"call:{call_id}:state"
        existing = await self.get_call_state(call_id)
        existing.update(state)
        await redis_cache.set(key, json.dumps(existing), ttl=_CALL_TTL)
        logger.debug(
            "Updated call state call_id=%s keys=%s", call_id, list(state.keys())
        )

    async def get_call_state(self, call_id: str) -> dict:
        """Read call state dict from Redis; returns ``{}`` if not found."""
        key = f"call:{call_id}:state"
        raw = await redis_cache.get(key)
        if raw is None:
            return {}
        try:
            data = json.loads(raw) if isinstance(raw, (str, bytes)) else raw
            return data if isinstance(data, dict) else {}
        except (json.JSONDecodeError, TypeError):
            logger.warning("Could not decode call state for call_id=%s", call_id)
            return {}

    async def set_call_decision(self, call_id: str, decision: str) -> None:
        """Persist the user's call-handling decision to a dedicated Redis key."""
        key = f"call:{call_id}:decision"
        await redis_cache.set(key, decision, ttl=_CALL_TTL)
        logger.info(
            "Call decision stored call_id=%s decision=%s", call_id, decision
        )

    async def get_call_decision(self, call_id: str) -> Optional[str]:
        """Return the stored call-handling decision string, or ``None``."""
        key = f"call:{call_id}:decision"
        value = await redis_cache.get(key)
        if value is None:
            return None
        return value.decode() if isinstance(value, bytes) else str(value)

    async def store_conversation_turn(
        self,
        call_id: str,
        role: str,
        text: str,
        language: str,
    ) -> None:
        """
        Append a single conversation turn to the Redis-backed history list.

        Parameters
        ----------
        call_id:
            Unique call identifier.
        role:
            Either ``"caller"`` or ``"assistant"``.
        text:
            Transcribed or generated text for this turn.
        language:
            BCP-47 language code of the text.
        """
        key = f"call:{call_id}:history"
        turn = {
            "role": role,
            "text": text,
            "language": language,
            "timestamp": _utc_now_iso(),
        }
        history = await self._load_history(call_id)
        history.append(turn)
        await redis_cache.set(key, json.dumps(history), ttl=_CALL_TTL)
        logger.debug(
            "Stored conversation turn call_id=%s role=%s chars=%d",
            call_id,
            role,
            len(text),
        )

    async def get_conversation_history(self, call_id: str) -> list:
        """Return the full ordered conversation history for a call."""
        return await self._load_history(call_id)

    async def _load_history(self, call_id: str) -> list:
        """Internal helper: read and deserialize the history list from Redis."""
        key = f"call:{call_id}:history"
        raw = await redis_cache.get(key)
        if raw is None:
            return []
        try:
            data = json.loads(raw) if isinstance(raw, (str, bytes)) else raw
            return data if isinstance(data, list) else []
        except (json.JSONDecodeError, TypeError):
            logger.warning("Could not decode history for call_id=%s", call_id)
            return []

    async def delete_call_state(self, call_id: str) -> None:
        """Remove all Redis keys associated with a call (cleanup / GDPR erasure)."""
        for suffix in ("state", "decision", "language", "history"):
            await redis_cache.delete(f"call:{call_id}:{suffix}")
        logger.info("Deleted all Redis state for call_id=%s", call_id)

    # ------------------------------------------------------------------
    # Twilio REST actions
    # ------------------------------------------------------------------

    async def end_call(self, call_sid: str) -> None:
        """
        Terminate an in-progress call via the Twilio REST API.

        The synchronous SDK call is dispatched to the thread pool so the
        event loop is never blocked.
        """
        if settings.DEV_MODE:
            logger.info("[DEV_MODE] Simulated end_call for call_sid=%s", call_sid)
            return

        def _do_end() -> None:
            client = self._get_client()
            client.calls(call_sid).update(status="completed")

        try:
            await self._run_in_executor(_do_end)
            logger.info("Ended call call_sid=%s", call_sid)
        except Exception:
            logger.exception("Failed to end call call_sid=%s", call_sid)

    # ------------------------------------------------------------------
    # Static helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _language_to_twilio_code(language: str) -> str:
        """
        Map an internal BCP-47 language code to the Twilio speech-recognition
        language code.  Falls back to ``"en-US"`` for unrecognised codes.

        Parameters
        ----------
        language:
            One of ``"te-IN"``, ``"hi-IN"``, ``"en-US"``, ``"ar-XA"``,
            ``"kn-IN"`` (or any other BCP-47 code).

        Returns
        -------
        str
            Twilio-compatible language code.
        """
        twilio_lang, _ = _language_to_voice_parts(language)
        return twilio_lang


# ---------------------------------------------------------------------------
# Module-level helpers
# ---------------------------------------------------------------------------


def _language_to_voice_parts(language: str) -> tuple[str, str]:
    """
    Map an internal language code to ``(twilio_language_code, google_tts_voice_name)``.

    Falls back to US English for unknown codes.
    """
    return _LANGUAGE_VOICE_MAP.get(language, (_DEFAULT_TWILIO_LANG, _DEFAULT_VOICE_NAME))


def _utc_now_iso() -> str:
    """Return the current UTC time as an ISO-8601 string."""
    return datetime.now(timezone.utc).isoformat()
