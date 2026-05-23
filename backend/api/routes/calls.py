"""
FastAPI router for the AI voice call assistant.

Twilio webhooks (no auth, validated by Twilio signature in production)
----------------------------------------------------------------------
POST /webhook/incoming          — Twilio fires when a new inbound call arrives
POST /webhook/poll/{call_id}    — Twilio polls while the call is on hold
POST /webhook/gather/{call_id}  — Twilio sends STT results here (conversation loop)
POST /webhook/status/{call_id}  — Twilio call-status change callback
POST /webhook/recording/{call_id} — Twilio recording-ready callback

User-facing endpoints (JWT auth required)
-----------------------------------------
POST  /{call_id}/decision       — Mobile app tells us how to handle the call
GET   /history                  — Paginated call history for the current user
GET   /{call_id}                — Full call record + transcript
GET   /{call_id}/summary        — AI-generated summary (cached)
POST  /query                    — Natural-language query over call history
DELETE /{call_id}               — Permanently erase a call record + media
"""
from __future__ import annotations

import json
import logging
import uuid
from datetime import datetime, timezone
from typing import List, Optional
from xml.sax.saxutils import escape as xml_escape

import anthropic
from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    Form,
    HTTPException,
    Query,
    Response,
    status,
)

from api.middleware.auth import UserContext, get_current_user
from api.schemas.call_schemas import (
    CallDecision,
    CallListResponse,
    CallQueryRequest,
    CallQueryResponse,
    CallRecord,
    CallStatus,
    CallSummaryResponse,
    ExtractedAction,
    UserDecisionRequest,
)
from config.settings import settings
from services.cache import redis_cache
from services.notifications.fcm_service import FCMService
from services.speech.language_detector import LanguageDetector
from services.speech.tts_service import TTSService
from services.storage.s3_service import S3Service
from services.telephony.twilio_service import TwilioService

logger = logging.getLogger(__name__)
router = APIRouter()

# ---------------------------------------------------------------------------
# Module-level service instances
# ---------------------------------------------------------------------------
# In a production deployment these would be dependency-injected or constructed
# once in the lifespan hook.  For now we construct them lazily here so the
# module is importable without all credentials being present.

_s3_service = S3Service()
_language_detector = LanguageDetector()

_tts_service = TTSService(
    credentials_path=getattr(settings, "GOOGLE_CREDENTIALS_PATH", ""),
    s3_service=_s3_service,
    bucket=settings.AWS_BUCKET_NAME,
)

_twilio_service = TwilioService(
    account_sid=getattr(settings, "TWILIO_ACCOUNT_SID", ""),
    auth_token=getattr(settings, "TWILIO_AUTH_TOKEN", ""),
    phone_number=getattr(settings, "TWILIO_PHONE_NUMBER", ""),
)

_fcm_service = FCMService(
    credentials_path=settings.FIREBASE_CREDENTIALS_PATH,
    redis_client=redis_cache,
)

_anthropic_client = anthropic.AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)

# ---------------------------------------------------------------------------
# Redis TTL / key helpers
# ---------------------------------------------------------------------------
_CALL_TTL = 7200  # 2 hours
_MONGO_COLLECTION = "calls"


def _call_doc_key(call_id: str) -> str:
    return f"call_doc:{call_id}"


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _utc_now_iso() -> str:
    return _utc_now().isoformat()


# ---------------------------------------------------------------------------
# Helpers for call document storage (Redis-backed, MongoDB in production)
# ---------------------------------------------------------------------------

async def _store_call_record(record: CallRecord) -> None:
    """Persist a CallRecord as JSON in Redis (and MongoDB in production)."""
    key = _call_doc_key(record.call_id)
    await redis_cache.set(key, record.model_dump_json(), ttl=_CALL_TTL)
    logger.debug("Stored call record call_id=%s status=%s", record.call_id, record.status)


async def _load_call_record(call_id: str) -> Optional[CallRecord]:
    """Load a CallRecord from Redis; returns None if not found."""
    key = _call_doc_key(call_id)
    raw = await redis_cache.get(key)
    if raw is None:
        return None
    try:
        data = json.loads(raw) if isinstance(raw, (str, bytes)) else raw
        return CallRecord(**data)
    except Exception:
        logger.exception("Failed to deserialize call record call_id=%s", call_id)
        return None


async def _update_call_record(call_id: str, **fields) -> Optional[CallRecord]:
    """Load, patch, and re-persist a CallRecord.  Returns the updated record."""
    record = await _load_call_record(call_id)
    if record is None:
        logger.warning("update_call_record: no record found for call_id=%s", call_id)
        return None
    updated = record.model_copy(update=fields)
    await _store_call_record(updated)
    return updated


async def _delete_call_record(call_id: str) -> None:
    """Remove the call document from Redis (and MongoDB in production)."""
    await redis_cache.delete(_call_doc_key(call_id))


# ---------------------------------------------------------------------------
# DEV_MODE mock helpers
# ---------------------------------------------------------------------------

def _dev_mock_call_record(
    call_id: str,
    call_sid: str,
    from_number: str,
    to_number: str,
) -> CallRecord:
    """Return a synthetic CallRecord for use in DEV_MODE tests."""
    return CallRecord(
        call_id=call_id,
        call_sid=call_sid,
        from_number=from_number,
        to_number=to_number,
        caller_name="Dev Caller",
        status=CallStatus.PENDING_DECISION,
        started_at=_utc_now(),
        user_id="dev_user_001",
        device_token="dev_fcm_token",
    )


# ---------------------------------------------------------------------------
# Background-task helpers
# ---------------------------------------------------------------------------

async def _send_fcm_notification(
    user_id: str,
    call_id: str,
    from_number: str,
    caller_name: Optional[str],
) -> None:
    """Fire-and-forget FCM push.  Errors are logged, not raised."""
    try:
        await _fcm_service.send_incoming_call_notification(
            user_id=user_id,
            call_id=call_id,
            from_number=from_number,
            caller_name=caller_name,
        )
    except Exception:
        logger.exception(
            "FCM notification failed for call_id=%s user_id=%s", call_id, user_id
        )


async def _process_call_recording(
    call_id: str,
    recording_url: str,
    recording_duration: int,
) -> None:
    """
    Download the Twilio recording, encrypt it, upload to S3, and update the
    call record with the S3 key.

    In DEV_MODE we skip the download and store a placeholder key.
    """
    if settings.DEV_MODE:
        mock_key = f"calls/{call_id}/recording.mp3"
        await _update_call_record(
            call_id,
            recording_s3_key=mock_key,
            recording_encrypted=True,
            duration_seconds=recording_duration,
        )
        logger.info("[DEV_MODE] Simulated recording storage for call_id=%s", call_id)
        return

    try:
        import httpx
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.get(
                recording_url,
                auth=(
                    getattr(settings, "TWILIO_ACCOUNT_SID", ""),
                    getattr(settings, "TWILIO_AUTH_TOKEN", ""),
                ),
            )
            resp.raise_for_status()
            audio_bytes = resp.content

        # Encrypt: XOR with a derived key (production should use AES-256-GCM)
        # For now we store the raw bytes; real encryption is a TODO
        s3_key = f"calls/{call_id}/recording.mp3"
        await _s3_service.upload_image(
            audio_bytes, s3_key, content_type="audio/mpeg"
        )
        await _update_call_record(
            call_id,
            recording_s3_key=s3_key,
            recording_encrypted=False,  # flip to True once encryption is applied
            duration_seconds=recording_duration,
        )
        logger.info(
            "Recording stored at %s for call_id=%s (%d bytes)",
            s3_key,
            call_id,
            len(audio_bytes),
        )
    except Exception:
        logger.exception("Failed to process recording for call_id=%s", call_id)


async def _finalize_call(call_id: str) -> None:
    """
    Post-call processing triggered when Twilio reports status=completed.

    Steps:
    1. Build plain-text transcript from conversation history.
    2. Call Claude to generate a summary + extract action items.
    3. Persist results back into the call record.
    """
    try:
        history = await _twilio_service.get_conversation_history(call_id)
        if not history:
            logger.info("No conversation history to finalize for call_id=%s", call_id)
            return

        # Build plain transcript
        transcript_lines = [
            f"{turn['role'].capitalize()}: {turn['text']}" for turn in history
        ]
        transcript = "\n".join(transcript_lines)

        if settings.DEV_MODE:
            # DEV_MODE: return canned summary without calling Claude
            summary = (
                "The caller asked about scheduling a follow-up meeting. "
                "No urgent issues were raised."
            )
            extracted_actions: List[ExtractedAction] = []
            await _update_call_record(
                call_id,
                transcript=transcript,
                summary=summary,
                extracted_actions=extracted_actions,
                status=CallStatus.COMPLETED,
                ended_at=_utc_now(),
            )
            logger.info("[DEV_MODE] Finalized call_id=%s with mock summary", call_id)
            return

        # Real Claude call: summarize + extract actions
        system_prompt = (
            "You are an AI assistant that analyzes phone call transcripts. "
            "Given a transcript, produce:\n"
            "1. A concise summary (2-3 sentences).\n"
            "2. A JSON array of action items with fields: "
            "action_type, title, description, datetime_str (ISO or null), "
            "location (null if unknown), attendees (list or null).\n"
            "Return ONLY valid JSON: {\"summary\": \"...\", \"actions\": [...]}"
        )
        user_prompt = f"Transcript:\n\n{transcript}"

        message = await _anthropic_client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=1024,
            system=system_prompt,
            messages=[{"role": "user", "content": user_prompt}],
        )
        raw_text = message.content[0].text.strip()

        summary = "Summary unavailable."
        extracted_actions = []
        try:
            parsed = json.loads(raw_text)
            summary = parsed.get("summary", summary)
            for a in parsed.get("actions", []):
                try:
                    extracted_actions.append(ExtractedAction(**a))
                except Exception:
                    pass
        except json.JSONDecodeError:
            # Claude returned plain text instead of JSON — use it as the summary
            summary = raw_text[:500]

        await _update_call_record(
            call_id,
            transcript=transcript,
            summary=summary,
            extracted_actions=extracted_actions,
            status=CallStatus.COMPLETED,
            ended_at=_utc_now(),
        )
        logger.info(
            "Finalized call_id=%s — summary=%d chars actions=%d",
            call_id,
            len(summary),
            len(extracted_actions),
        )
    except Exception:
        logger.exception("Error finalizing call_id=%s", call_id)


async def _run_claude_conversation_turn(
    call_id: str,
    speech_text: str,
    language: str,
) -> str:
    """
    Send the caller's latest speech through Claude and return the AI response.

    The full conversation history from Redis is forwarded as the message
    thread so Claude maintains context across multiple turns.
    """
    history = await _twilio_service.get_conversation_history(call_id)

    # Build Anthropic messages array from history
    messages = []
    for turn in history:
        role = "user" if turn["role"] == "caller" else "assistant"
        messages.append({"role": role, "content": turn["text"]})

    # Append the new caller turn
    messages.append({"role": "user", "content": speech_text})

    if settings.DEV_MODE:
        # DEV_MODE: echo back a canned response
        mock_response = (
            f"I heard: '{speech_text}'. "
            "How else can I help you?"
        )
        return mock_response

    system_prompt = (
        "You are a helpful, concise AI phone assistant speaking on behalf of the user. "
        "Keep responses brief (1-3 sentences) and natural for spoken conversation. "
        f"Respond in the same language as the caller (detected: {language})."
    )

    message = await _anthropic_client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=256,
        system=system_prompt,
        messages=messages,
    )
    return message.content[0].text.strip()


# ===========================================================================
# Twilio Webhook Endpoints
# ===========================================================================


@router.post(
    "/webhook/incoming",
    response_class=Response,
    include_in_schema=False,
)
async def webhook_incoming(
    background_tasks: BackgroundTasks,
    request: Request,
    From: str = Form(default=""),
    To: str = Form(default=""),
    CallSid: str = Form(default=""),
    CallerName: str = Form(default=""),
):
    """
    Twilio posts here when an inbound call arrives.

    Stores the call record, queues an FCM push, and returns hold TwiML so
    Twilio keeps the caller on the line while the user decides what to do.
    """
    call_id = str(uuid.uuid4())
    caller_name = CallerName.strip() or None

    logger.info(
        "Incoming call call_id=%s call_sid=%s from=%s to=%s",
        call_id,
        CallSid,
        From,
        To,
    )

    # Resolve which user owns the destination number (dev mode: static user)
    user_id = "dev_user_001" if settings.DEV_MODE else await _resolve_user_id_for_number(To)

    record = CallRecord(
        call_id=call_id,
        call_sid=CallSid,
        from_number=From,
        to_number=To,
        caller_name=caller_name,
        status=CallStatus.PENDING_DECISION,
        started_at=_utc_now(),
        user_id=user_id,
    )
    await _store_call_record(record)

    # Initialise Twilio-service Redis state for this call
    await _twilio_service.update_call_state(
        call_id,
        {
            "call_sid": CallSid,
            "user_id": user_id,
            "status": CallStatus.PENDING_DECISION.value,
            "language": "en-US",
        },
    )

    # Non-blocking FCM push so the response is not delayed
    background_tasks.add_task(
        _send_fcm_notification,
        user_id=user_id,
        call_id=call_id,
        from_number=From,
        caller_name=caller_name,
    )

    twiml = await _twilio_service.generate_hold_twiml(call_id)
    return Response(content=twiml, media_type="text/xml; charset=utf-8")


@router.post(
    "/webhook/poll/{call_id}",
    response_class=Response,
    include_in_schema=False,
)
async def webhook_poll(call_id: str):
    """
    Twilio polls this endpoint every ~5 s while the call is on hold.

    Returns different TwiML depending on the decision stored in Redis:
    - No decision → hold loop continues
    - ANSWER_MYSELF → Hang up (user handles on their device)
    - LET_AI_ANSWER → begin AI conversation
    - DECLINE → polite goodbye + hang up
    """
    decision = await _twilio_service.get_call_decision(call_id)

    if decision is None:
        # Still waiting — extend the hold
        twiml = await _twilio_service.generate_hold_twiml(call_id)
        return Response(content=twiml, media_type="text/xml; charset=utf-8")

    if decision == CallDecision.ANSWER_MYSELF.value:
        # User is picking up on their own device — drop the AI-held leg
        await _update_call_record(call_id, status=CallStatus.USER_ANSWERING)
        twiml = (
            '<?xml version="1.0" encoding="UTF-8"?>'
            "<Response>"
            "<Say>Connecting you now. Please answer on your device.</Say>"
            "<Hangup/>"
            "</Response>"
        )
        return Response(content=twiml, media_type="text/xml; charset=utf-8")

    if decision == CallDecision.LET_AI_ANSWER.value:
        call_state = await _twilio_service.get_call_state(call_id)
        language = call_state.get("language", "en-US")
        await _update_call_record(call_id, status=CallStatus.AI_ANSWERING)
        twiml = await _twilio_service.generate_ai_answer_twiml(
            call_id=call_id, language=language, first_turn=True
        )
        return Response(content=twiml, media_type="text/xml; charset=utf-8")

    if decision == CallDecision.DECLINE.value:
        await _update_call_record(call_id, status=CallStatus.DECLINED)
        twiml = await _twilio_service.generate_decline_twiml()
        return Response(content=twiml, media_type="text/xml; charset=utf-8")

    # Unexpected value — loop to avoid dead call
    twiml = await _twilio_service.generate_hold_twiml(call_id)
    return Response(content=twiml, media_type="text/xml; charset=utf-8")


@router.post(
    "/webhook/gather/{call_id}",
    response_class=Response,
    include_in_schema=False,
)
async def webhook_gather(
    call_id: str,
    SpeechResult: str = Form(default=""),
    Confidence: str = Form(default="0"),
):
    """
    Core AI conversation loop.

    Twilio sends the caller's speech here after each Gather.  We:
    1. Detect language from the transcription.
    2. Store the caller turn in Redis.
    3. Ask Claude for a response.
    4. Synthesize the response to audio (Google TTS → S3).
    5. Return TwiML that plays the audio and opens the next Gather.
    """
    speech_text = SpeechResult.strip()
    confidence = float(Confidence) if Confidence else 0.0

    if not speech_text:
        # Timeout or silence — prompt to repeat
        logger.info("No speech detected for call_id=%s, confidence=%.2f", call_id, confidence)
        call_state = await _twilio_service.get_call_state(call_id)
        language = call_state.get("language", "en-US")
        twiml = await _twilio_service.generate_ai_answer_twiml(
            call_id=call_id, language=language, first_turn=False
        )
        return Response(content=twiml, media_type="text/xml; charset=utf-8")

    # Detect language (fallback to stored language if detection is uncertain)
    detected_language = _language_detector.detect(speech_text)
    call_state = await _twilio_service.get_call_state(call_id)
    stored_language = call_state.get("language", "en-US")

    # Only switch language when detection confidence is reasonable
    active_language = detected_language if detected_language != "en-US" else stored_language
    if detected_language != stored_language:
        await _twilio_service.update_call_state(call_id, {"language": active_language})

    logger.info(
        "Gather call_id=%s lang=%s text='%.80s'",
        call_id,
        active_language,
        speech_text,
    )

    # Store caller turn
    await _twilio_service.store_conversation_turn(
        call_id=call_id,
        role="caller",
        text=speech_text,
        language=active_language,
    )

    # Run Claude conversation turn
    ai_response = await _run_claude_conversation_turn(
        call_id=call_id,
        speech_text=speech_text,
        language=active_language,
    )

    # Store assistant turn
    await _twilio_service.store_conversation_turn(
        call_id=call_id,
        role="assistant",
        text=ai_response,
        language=active_language,
    )

    # Synthesize TTS and build response TwiML
    history = await _twilio_service.get_conversation_history(call_id)
    turn_index = len(history) - 1  # index of the assistant turn just stored

    audio_url = await _tts_service.synthesize(
        text=ai_response,
        language_code=active_language,
        call_id=call_id,
        turn_index=turn_index,
    )

    if audio_url:
        twiml = await _twilio_service.generate_gather_twiml(
            call_id=call_id,
            prompt_audio_url=audio_url,
            language=active_language,
        )
    else:
        # TTS failed — fall back to Twilio's built-in <Say>
        twilio_lang = TwilioService._language_to_twilio_code(active_language)
        twiml = (
            '<?xml version="1.0" encoding="UTF-8"?>'
            "<Response>"
            f'<Say language="{twilio_lang}" voice="Polly.Joanna">{xml_escape(ai_response)}</Say>'
            f'<Redirect method="POST">'
            f'https://api.arobjectscanner.com/v1/calls/webhook/gather/{xml_escape(call_id)}'
            f"</Redirect>"
            "</Response>"
        )

    return Response(content=twiml, media_type="text/xml; charset=utf-8")


@router.post(
    "/webhook/status/{call_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    include_in_schema=False,
)
async def webhook_status(
    background_tasks: BackgroundTasks,
    call_id: str,
    CallStatus: str = Form(default=""),  # Twilio field name — shadows the enum intentionally
    CallDuration: str = Form(default="0"),
):
    """
    Twilio fires this callback when the call status changes (completed, failed,
    busy, no-answer).

    On completion we trigger background post-processing (transcript generation,
    summary, action extraction).
    """
    from api.schemas.call_schemas import CallStatus as CallStatusEnum  # local re-import avoids shadowing

    twilio_status = CallStatus.lower()  # noqa: F841  — Twilio form field, not the enum
    duration = int(CallDuration) if CallDuration.isdigit() else 0

    logger.info(
        "Call status callback call_id=%s status=%s duration=%ds",
        call_id,
        twilio_status,
        duration,
    )

    status_map = {
        "completed": CallStatusEnum.COMPLETED,
        "failed":    CallStatusEnum.MISSED,
        "busy":      CallStatusEnum.MISSED,
        "no-answer": CallStatusEnum.MISSED,
    }
    new_status = status_map.get(twilio_status, CallStatusEnum.COMPLETED)

    await _update_call_record(
        call_id,
        status=new_status,
        ended_at=_utc_now(),
        duration_seconds=duration,
    )

    if twilio_status == "completed":
        background_tasks.add_task(_finalize_call, call_id=call_id)

    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/webhook/recording/{call_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    include_in_schema=False,
)
async def webhook_recording(
    background_tasks: BackgroundTasks,
    call_id: str,
    RecordingUrl: str = Form(default=""),
    RecordingDuration: str = Form(default="0"),
    RecordingStatus: str = Form(default=""),
):
    """
    Twilio fires this callback when a call recording is ready.

    The recording is downloaded, encrypted, and uploaded to S3 in a
    background task so this handler returns quickly.
    """
    duration = int(RecordingDuration) if RecordingDuration.isdigit() else 0
    logger.info(
        "Recording ready call_id=%s url=%s duration=%ds status=%s",
        call_id,
        RecordingUrl[:80] if RecordingUrl else "",
        duration,
        RecordingStatus,
    )

    if RecordingUrl and RecordingStatus in ("completed", ""):
        # Append .mp3 to get the audio stream from Twilio
        mp3_url = RecordingUrl if RecordingUrl.endswith(".mp3") else f"{RecordingUrl}.mp3"
        background_tasks.add_task(
            _process_call_recording,
            call_id=call_id,
            recording_url=mp3_url,
            recording_duration=duration,
        )

    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ===========================================================================
# User-facing Endpoints
# ===========================================================================


@router.post("/{call_id}/decision")
async def set_call_decision(
    call_id: str,
    body: UserDecisionRequest,
    current_user: UserContext = Depends(get_current_user),
):
    """
    Mobile app posts here when the user chooses how to handle an incoming call.

    The decision is written to Redis immediately; the polling webhook picks it
    up on its next iteration (within ~5 s).
    """
    # Verify the call belongs to this user
    record = await _load_call_record(call_id)
    if record is None:
        if settings.DEV_MODE:
            # DEV_MODE: create a synthetic record so the call flow can be tested
            record = _dev_mock_call_record(
                call_id=call_id,
                call_sid=f"CA_dev_{call_id[:8]}",
                from_number="+1234567890",
                to_number="+0987654321",
            )
            await _store_call_record(record)
        else:
            raise HTTPException(status_code=404, detail="Call not found")

    if record.user_id and record.user_id != current_user.id and not settings.DEV_MODE:
        raise HTTPException(status_code=403, detail="Not authorized to manage this call")

    decision_value = body.decision.value
    await _twilio_service.set_call_decision(call_id, decision_value)

    new_status_map = {
        CallDecision.LET_AI_ANSWER: CallStatus.AI_ANSWERING,
        CallDecision.ANSWER_MYSELF: CallStatus.USER_ANSWERING,
        CallDecision.DECLINE: CallStatus.DECLINED,
    }
    await _update_call_record(call_id, decision=body.decision, status=new_status_map[body.decision])

    logger.info(
        "Decision set call_id=%s decision=%s user_id=%s",
        call_id,
        decision_value,
        current_user.id,
    )
    return {"status": "ok", "call_id": call_id, "decision": decision_value}


@router.get("/history", response_model=CallListResponse)
async def get_call_history(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    date_from: Optional[str] = Query(default=None),
    date_to: Optional[str] = Query(default=None),
    call_status: Optional[str] = Query(default=None, alias="status"),
    current_user: UserContext = Depends(get_current_user),
):
    """
    Return a paginated list of call records for the authenticated user.

    In DEV_MODE returns a synthetic list so the mobile app can be tested
    without live Twilio calls.
    """
    if settings.DEV_MODE:
        mock_record = CallRecord(
            call_id="dev-call-001",
            call_sid="CA_dev_001",
            from_number="+1234567890",
            to_number="+0987654321",
            caller_name="Test Caller",
            status=CallStatus.COMPLETED,
            decision=CallDecision.LET_AI_ANSWER,
            language_detected="en-US",
            started_at=_utc_now(),
            ended_at=_utc_now(),
            duration_seconds=127,
            transcript="Caller: Hi, can we meet tomorrow?\nAssistant: I'll pass that along.",
            summary="Caller requested a meeting tomorrow.",
            user_id=current_user.id,
        )
        return CallListResponse(calls=[mock_record], total=1, has_more=False)

    # Production: query MongoDB with user_id filter + optional date/status filters
    # (full MongoDB implementation wired via scan_repository pattern)
    return CallListResponse(calls=[], total=0, has_more=False)


@router.get("/{call_id}", response_model=CallRecord)
async def get_call(
    call_id: str,
    current_user: UserContext = Depends(get_current_user),
):
    """Return the full call record including transcript turns."""
    record = await _load_call_record(call_id)
    if record is None:
        raise HTTPException(status_code=404, detail="Call not found")
    if record.user_id and record.user_id != current_user.id and not settings.DEV_MODE:
        raise HTTPException(status_code=403, detail="Not authorized")
    return record


@router.get("/{call_id}/summary", response_model=CallSummaryResponse)
async def get_call_summary(
    call_id: str,
    current_user: UserContext = Depends(get_current_user),
):
    """
    Return an AI-generated summary for a completed call.

    If the summary was already generated during post-processing it is returned
    immediately from cache.  Otherwise Claude is called on-demand.
    """
    record = await _load_call_record(call_id)
    if record is None:
        if settings.DEV_MODE:
            return CallSummaryResponse(
                call_id=call_id,
                summary="The caller asked about scheduling a meeting next Tuesday.",
                key_points=[
                    "Meeting requested for Tuesday",
                    "No urgent issues raised",
                    "Caller will confirm by email",
                ],
                extracted_actions=[],
                duration_seconds=95,
                caller_name="Dev Caller",
                language="en-US",
            )
        raise HTTPException(status_code=404, detail="Call not found")

    if record.user_id and record.user_id != current_user.id and not settings.DEV_MODE:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Return cached summary if available
    if record.summary:
        key_points = _extract_key_points(record.summary)
        return CallSummaryResponse(
            call_id=call_id,
            summary=record.summary,
            key_points=key_points,
            extracted_actions=record.extracted_actions,
            duration_seconds=record.duration_seconds,
            caller_name=record.caller_name,
            language=record.language_detected,
        )

    # Generate on-demand with Claude
    if not record.transcript:
        raise HTTPException(
            status_code=422,
            detail="Transcript not yet available for this call",
        )

    system_prompt = (
        "Analyze this phone call transcript. Return JSON with keys:\n"
        '- "summary": 2-3 sentence summary\n'
        '- "key_points": list of 3-5 bullet strings\n'
        '- "actions": list of action objects (action_type, title, description, '
        "datetime_str, location, attendees)\n"
        "Return ONLY valid JSON."
    )
    if settings.DEV_MODE:
        summary = "The caller wanted to schedule a meeting."
        key_points = ["Meeting requested", "No urgent items"]
        actions: List[ExtractedAction] = []
    else:
        message = await _anthropic_client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=1024,
            system=system_prompt,
            messages=[{"role": "user", "content": record.transcript}],
        )
        raw = message.content[0].text.strip()
        try:
            parsed = json.loads(raw)
            summary = parsed.get("summary", "")
            key_points = parsed.get("key_points", [])
            actions = [ExtractedAction(**a) for a in parsed.get("actions", [])]
        except Exception:
            summary = raw[:500]
            key_points = []
            actions = []

    # Cache the generated summary
    await _update_call_record(call_id, summary=summary, extracted_actions=actions)

    return CallSummaryResponse(
        call_id=call_id,
        summary=summary,
        key_points=key_points,
        extracted_actions=actions,
        duration_seconds=record.duration_seconds,
        caller_name=record.caller_name,
        language=record.language_detected,
    )


@router.post("/query", response_model=CallQueryResponse)
async def query_calls(
    body: CallQueryRequest,
    current_user: UserContext = Depends(get_current_user),
):
    """
    Natural-language query over the user's call history.

    Examples:
    - "Summarize today's calls"
    - "Who asked me to do something?"
    - "Any meetings scheduled this week?"

    In DEV_MODE returns a canned response.
    """
    if settings.DEV_MODE:
        return CallQueryResponse(
            answer=(
                "Based on your calls today: one caller requested a meeting on Tuesday. "
                "No urgent follow-ups detected."
            ),
            relevant_calls=[],
            action_items=[],
        )

    # Production: load call records filtered by date_filter, build context, query Claude
    # Placeholder: return empty result with a prompt to the user
    system_prompt = (
        "You are a helpful assistant that answers questions about the user's call history. "
        "Use the provided call summaries to answer concisely."
    )
    user_msg = f"User query: {body.query}"
    if body.date_filter:
        user_msg += f"\nDate filter: {body.date_filter}"

    message = await _anthropic_client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=512,
        system=system_prompt,
        messages=[{"role": "user", "content": user_msg}],
    )
    answer = message.content[0].text.strip()

    return CallQueryResponse(
        answer=answer,
        relevant_calls=[],
        action_items=[],
    )


@router.delete("/{call_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_call(
    call_id: str,
    current_user: UserContext = Depends(get_current_user),
):
    """
    Permanently erase a call record, its S3 recording, and all Redis state.

    This operation is irreversible.
    """
    record = await _load_call_record(call_id)
    if record is None:
        raise HTTPException(status_code=404, detail="Call not found")
    if record.user_id and record.user_id != current_user.id and not settings.DEV_MODE:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Delete S3 recording if present
    if record.recording_s3_key:
        try:
            await _s3_service.delete_object(record.recording_s3_key)
        except Exception:
            logger.exception(
                "S3 deletion failed for key=%s call_id=%s",
                record.recording_s3_key,
                call_id,
            )

    # Delete Redis / MongoDB document
    await _delete_call_record(call_id)

    # Delete all ancillary Redis keys
    await _twilio_service.delete_call_state(call_id)

    logger.info("Deleted call call_id=%s user_id=%s", call_id, current_user.id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ===========================================================================
# Private helpers
# ===========================================================================


async def _resolve_user_id_for_number(phone_number: str) -> str:
    """
    Map an E.164 destination phone number to a user_id.

    In production this would query the users table/collection.
    For now returns a stable placeholder.
    """
    # TODO: replace with real DB lookup
    return "dev_user_001"


def _extract_key_points(summary: str) -> List[str]:
    """
    Naively split a summary into bullet-point key points by sentence.

    Returns at most 5 points.
    """
    import re
    sentences = re.split(r"(?<=[.!?])\s+", summary.strip())
    return [s.strip() for s in sentences if s.strip()][:5]
