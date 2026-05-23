"""Google Cloud Speech-to-Text for recording transcription and language-aware processing."""
import asyncio
import logging
import os
from typing import Optional

logger = logging.getLogger(__name__)

_DEV_MODE: bool = os.getenv("DEV_MODE", "false").lower() in ("true", "1", "yes")

# All BCP-47 codes the service supports (used for alternative language hints)
_SUPPORTED_LANGUAGE_CODES: list[str] = ["te-IN", "hi-IN", "en-US", "ar-XA", "kn-IN"]

# Placeholder transcript returned in mock / dev mode
_MOCK_TRANSCRIPT = "Hello, I am calling about a meeting tomorrow at 3 PM."
_MOCK_LANGUAGE = "en-US"
_MOCK_CONFIDENCE = 0.95


class STTService:
    """Transcribe phone-call audio using the Google Cloud Speech-to-Text API.

    Parameters
    ----------
    credentials_path:
        Path to the Google Cloud service-account JSON key file.
    """

    def __init__(self, credentials_path: str) -> None:
        self._credentials_path = credentials_path
        self._client = None  # lazy-initialised on first real use

        if not _DEV_MODE:
            self._client = self._init_google_client(credentials_path)

    # ------------------------------------------------------------------
    # Public async API
    # ------------------------------------------------------------------

    async def transcribe_audio_url(
        self,
        audio_url: str,
        hint_language: str = "en-US",
    ) -> tuple[str, str, float]:
        """Download audio from *audio_url* and transcribe it.

        Returns
        -------
        tuple[str, str, float]
            ``(transcript, detected_language_code, confidence)``
        """
        if _DEV_MODE:
            logger.info("STT mock (url): %s", audio_url)
            return (_MOCK_TRANSCRIPT, _MOCK_LANGUAGE, _MOCK_CONFIDENCE)

        try:
            audio_bytes = await self._download_audio(audio_url)
            return await self.transcribe_audio_bytes(audio_bytes, hint_language)
        except Exception as exc:
            logger.error("transcribe_audio_url failed for %s: %s", audio_url, exc)
            return ("", hint_language, 0.0)

    async def transcribe_audio_bytes(
        self,
        audio_bytes: bytes,
        hint_language: str = "en-US",
    ) -> tuple[str, str, float]:
        """Transcribe raw *audio_bytes*.

        Returns
        -------
        tuple[str, str, float]
            ``(transcript, detected_language_code, confidence)``
        """
        if _DEV_MODE:
            logger.info("STT mock (bytes): %d bytes", len(audio_bytes))
            return (_MOCK_TRANSCRIPT, _MOCK_LANGUAGE, _MOCK_CONFIDENCE)

        if self._client is None:
            logger.warning("Google STT client not initialised; returning empty transcript.")
            return ("", hint_language, 0.0)

        try:
            config = self._build_recognition_config(hint_language)
            loop = asyncio.get_event_loop()
            result: tuple[str, str, float] = await loop.run_in_executor(
                None,
                self._call_google_stt,
                audio_bytes,
                config,
            )
            return result
        except Exception as exc:
            logger.error("transcribe_audio_bytes failed: %s", exc)
            return ("", hint_language, 0.0)

    async def transcribe_call_recording(
        self,
        recording_url: str,
    ) -> tuple[str, str]:
        """Download a full call recording and return a readable transcript.

        Returns
        -------
        tuple[str, str]
            ``(formatted_transcript, dominant_language)``

        The *formatted_transcript* uses the form::

            Caller: <text>
            Assistant: <text>
            ...
        """
        if _DEV_MODE:
            logger.info("STT mock (recording): %s", recording_url)
            return (
                "Caller: Hello, I am calling about a meeting tomorrow at 3 PM.\n"
                "Assistant: Of course, I will pass that information along.",
                "en-US",
            )

        try:
            transcript, language, _conf = await self.transcribe_audio_url(
                recording_url, hint_language="en-US"
            )
            # For a complete recording we don't have turn demarcation; label all
            # as "Caller" and let downstream processing split if needed.
            formatted = f"Caller: {transcript}" if transcript else ""
            return (formatted, language)
        except Exception as exc:
            logger.error("transcribe_call_recording failed for %s: %s", recording_url, exc)
            return ("", "en-US")

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _build_recognition_config(self, hint_language: str) -> dict:
        """Build and return a RecognitionConfig-compatible dict.

        The *hint_language* is used as the primary language; all other supported
        codes are passed as ``alternative_language_codes`` so Google can
        auto-detect language switches.
        """
        alternatives = [
            code for code in _SUPPORTED_LANGUAGE_CODES if code != hint_language
        ]
        return {
            "language_code": hint_language,
            "alternative_language_codes": alternatives,
            "model": "phone_call",
            "use_enhanced": True,
            "enable_automatic_punctuation": True,
            "enable_word_confidence": False,
        }

    def _init_google_client(self, credentials_path: str):
        """Initialise and return a ``speech.SpeechClient``."""
        try:
            from google.cloud import speech  # type: ignore
            from google.oauth2 import service_account  # type: ignore

            if credentials_path and os.path.isfile(credentials_path):
                creds = service_account.Credentials.from_service_account_file(
                    credentials_path,
                    scopes=["https://www.googleapis.com/auth/cloud-platform"],
                )
                client = speech.SpeechClient(credentials=creds)
            else:
                client = speech.SpeechClient()

            logger.info("Google STT client initialised.")
            return client
        except Exception as exc:
            logger.warning(
                "Could not initialise Google STT client: %s — STT will return empty strings.", exc
            )
            return None

    def _call_google_stt(
        self,
        audio_bytes: bytes,
        config_dict: dict,
    ) -> tuple[str, str, float]:
        """Blocking synchronous call to the Google STT API.

        Must be run via ``asyncio.run_in_executor``.
        """
        from google.cloud import speech  # type: ignore

        audio = speech.RecognitionAudio(content=audio_bytes)
        config = speech.RecognitionConfig(**config_dict)
        response = self._client.recognize(config=config, audio=audio)

        if not response.results:
            return ("", config_dict["language_code"], 0.0)

        # Pick result with the highest confidence across all alternatives
        best_transcript = ""
        best_confidence = 0.0
        best_language = config_dict["language_code"]

        for result in response.results:
            for alt in result.alternatives:
                conf = getattr(alt, "confidence", 0.0) or 0.0
                if conf >= best_confidence:
                    best_confidence = conf
                    best_transcript = alt.transcript
                    # language_code is on the result level in multi-language mode
                    best_language = getattr(result, "language_code", best_language) or best_language

        return (best_transcript, best_language, round(best_confidence, 4))

    @staticmethod
    async def _download_audio(url: str) -> bytes:
        """Async HTTP download of audio from *url*."""
        try:
            import httpx  # type: ignore

            async with httpx.AsyncClient(timeout=30.0) as client:
                resp = await client.get(url)
                resp.raise_for_status()
                return resp.content
        except Exception as exc:
            logger.error("Failed to download audio from %s: %s", url, exc)
            raise
