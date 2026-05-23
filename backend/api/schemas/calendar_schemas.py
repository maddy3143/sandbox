"""Pydantic v2 schemas for calendar integration."""
from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Enumerations
# ---------------------------------------------------------------------------


class CalendarProvider(str, Enum):
    GOOGLE = "google"
    OUTLOOK = "outlook"
    DEVICE = "device"


# ---------------------------------------------------------------------------
# Core domain models
# ---------------------------------------------------------------------------


class CalendarEvent(BaseModel):
    """A calendar event that can be created from an extracted call action."""

    title: str
    description: Optional[str] = None
    start_datetime: datetime
    end_datetime: datetime
    location: Optional[str] = None
    attendees: Optional[List[str]] = None  # List of e-mail addresses
    calendar_id: Optional[str] = None  # Provider-specific calendar/mailbox ID
    provider: Optional[CalendarProvider] = None


class UserCalendarSettings(BaseModel):
    """Per-user calendar configuration stored in MongoDB."""

    user_id: str
    preferred_provider: Optional[CalendarProvider] = None
    google_connected: bool = False
    outlook_connected: bool = False
    device_calendar_enabled: bool = False
    # AES-256 encrypted OAuth token blobs (base-64 encoded ciphertext)
    google_token_encrypted: Optional[str] = None
    outlook_token_encrypted: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


# ---------------------------------------------------------------------------
# Request models
# ---------------------------------------------------------------------------


class CalendarAuthRequest(BaseModel):
    """OAuth authorization-code exchange request."""

    provider: CalendarProvider
    auth_code: str
    redirect_uri: str


class CreateEventRequest(BaseModel):
    """Request to create a calendar event, optionally linked to a call."""

    title: str
    description: Optional[str] = None
    start_datetime: str  # ISO 8601 string so callers don't need to know timezone
    end_datetime: Optional[str] = None
    location: Optional[str] = None
    attendees: Optional[List[str]] = None
    provider: Optional[CalendarProvider] = CalendarProvider.GOOGLE
    source_call_id: Optional[str] = None  # Traceability back to the originating call


# ---------------------------------------------------------------------------
# Response models
# ---------------------------------------------------------------------------


class CalendarAuthResponse(BaseModel):
    """Response returned after a successful OAuth token exchange."""

    provider: CalendarProvider
    access_token: str
    refresh_token: Optional[str] = None
    expires_at: datetime
    calendar_id: str


class CreateEventResponse(BaseModel):
    """Response returned after a calendar event is successfully created."""

    event_id: str
    provider: CalendarProvider
    event_url: Optional[str] = None  # Deep link to the event in the provider's UI
    calendar_id: str


class CalendarListResponse(BaseModel):
    """Paginated list of calendar events returned to clients."""

    events: List[CalendarEvent]
    provider: CalendarProvider
    total: int
