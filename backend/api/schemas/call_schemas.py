"""Pydantic v2 schemas for the AI voice call assistant."""
from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Enumerations
# ---------------------------------------------------------------------------


class CallStatus(str, Enum):
    INCOMING = "incoming"
    PENDING_DECISION = "pending_decision"  # waiting for user to decide
    USER_ANSWERING = "user_answering"
    AI_ANSWERING = "ai_answering"
    IN_PROGRESS = "in_progress"  # AI conversation active
    COMPLETED = "completed"
    MISSED = "missed"
    DECLINED = "declined"


class CallDecision(str, Enum):
    ANSWER_MYSELF = "answer_myself"
    LET_AI_ANSWER = "let_ai_answer"
    DECLINE = "decline"


class SupportedLanguage(str, Enum):
    TELUGU = "te-IN"
    HINDI = "hi-IN"
    ENGLISH = "en-US"
    ARABIC = "ar-XA"
    KANNADA = "kn-IN"


class ActionType(str, Enum):
    MEETING = "meeting"
    APPOINTMENT = "appointment"
    REMINDER = "reminder"
    TRAVEL = "travel"
    FOLLOW_UP = "follow_up"
    DELIVERY = "delivery"
    INVITATION = "invitation"
    WORK = "work"
    PERSONAL = "personal"


# ---------------------------------------------------------------------------
# Core domain models
# ---------------------------------------------------------------------------


class ExtractedAction(BaseModel):
    """A structured action item extracted from a call transcript."""

    action_type: ActionType
    title: str
    description: str
    datetime_str: Optional[str] = None
    location: Optional[str] = None
    attendees: Optional[List[str]] = None
    confirmed: bool = False
    calendar_event_id: Optional[str] = None


class ConversationTurn(BaseModel):
    """One turn in a call transcript — either caller speech or AI response."""

    role: str  # "caller" or "assistant"
    text: str
    language: str  # BCP-47 code, e.g. "en-US"
    timestamp: datetime
    audio_url: Optional[str] = None  # Presigned S3 URL to the TTS audio clip


class CallRecord(BaseModel):
    """Full call document stored in MongoDB and returned to clients."""

    call_id: str
    call_sid: str  # Twilio Call SID (CA…)
    from_number: str
    to_number: str
    caller_name: Optional[str] = None
    status: CallStatus
    decision: Optional[CallDecision] = None
    language_detected: Optional[str] = None  # BCP-47 code
    started_at: datetime
    ended_at: Optional[datetime] = None
    duration_seconds: Optional[int] = None
    recording_s3_key: Optional[str] = None
    recording_encrypted: bool = False
    transcript: Optional[str] = None  # Plain-text full transcript
    transcript_turns: List[ConversationTurn] = []
    summary: Optional[str] = None
    extracted_actions: List[ExtractedAction] = []
    user_id: str = ""
    device_token: Optional[str] = None  # FCM registration token for push notification


# ---------------------------------------------------------------------------
# Request models
# ---------------------------------------------------------------------------


class UserDecisionRequest(BaseModel):
    """Sent by the mobile app when the user decides how to handle an incoming call."""

    call_id: str
    decision: CallDecision


class CallQueryRequest(BaseModel):
    """Natural-language query over the user's call history."""

    query: str
    date_filter: Optional[str] = None  # "today" | "yesterday" | "this_week" | "this_month"
    limit: int = Field(default=10, ge=1, le=50)


class CalendarConfirmRequest(BaseModel):
    """Confirm (or reject) a specific extracted action for calendar creation."""

    call_id: str
    action_index: int  # index into CallRecord.extracted_actions
    confirmed: bool
    calendar_type: Optional[str] = "google"  # "google" | "outlook" | "device"


# ---------------------------------------------------------------------------
# Response models
# ---------------------------------------------------------------------------


class CallListResponse(BaseModel):
    calls: List[CallRecord]
    total: int
    has_more: bool


class CallSummaryResponse(BaseModel):
    call_id: str
    summary: str
    key_points: List[str]
    extracted_actions: List[ExtractedAction]
    duration_seconds: Optional[int] = None
    caller_name: Optional[str] = None
    language: Optional[str] = None


class CallQueryResponse(BaseModel):
    answer: str
    relevant_calls: List[CallRecord]
    action_items: List[ExtractedAction]


# ---------------------------------------------------------------------------
# Push notification payload
# ---------------------------------------------------------------------------


class IncomingCallNotification(BaseModel):
    """FCM data payload sent to the mobile app when a call arrives."""

    call_id: str
    from_number: str
    caller_name: Optional[str] = None
    timestamp: str  # ISO-8601 UTC string
