"""Calendar integration routes — Google Calendar and Outlook OAuth + event management."""
import logging
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query
from fastapi.responses import RedirectResponse

from api.middleware.auth import get_current_user
from api.schemas.calendar_schemas import (
    CalendarAuthRequest,
    CalendarAuthResponse,
    CalendarListResponse,
    CalendarProvider,
    CreateEventRequest,
    CreateEventResponse,
    UserCalendarSettings,
)
from api.schemas.call_schemas import CalendarConfirmRequest
from config.settings import settings

logger = logging.getLogger(__name__)

router = APIRouter()


def _get_google_service():
    from services.calendar.google_calendar_service import GoogleCalendarService
    from services.database.db import get_mongo_client

    db = get_mongo_client()
    return GoogleCalendarService(
        client_id=settings.GOOGLE_CALENDAR_CLIENT_ID,
        client_secret=settings.GOOGLE_CALENDAR_CLIENT_SECRET,
        redirect_uri=settings.GOOGLE_CALENDAR_REDIRECT_URI,
        db_client=db,
    )


def _get_outlook_service():
    from services.calendar.outlook_calendar_service import OutlookCalendarService
    from services.database.db import get_mongo_client

    db = get_mongo_client()
    return OutlookCalendarService(
        client_id=settings.OUTLOOK_CLIENT_ID,
        client_secret=settings.OUTLOOK_CLIENT_SECRET,
        tenant_id=settings.OUTLOOK_TENANT_ID,
        redirect_uri=settings.OUTLOOK_REDIRECT_URI,
        db_client=db,
    )


# ── Google OAuth ──────────────────────────────────────────────────────────────

@router.get("/auth/google")
async def google_auth_start(
    current_user: dict = Depends(get_current_user),
):
    """Return Google OAuth URL for the client to redirect to."""
    svc = _get_google_service()
    url = svc.get_auth_url(user_id=current_user["user_id"])
    return {"auth_url": url, "provider": "google"}


@router.get("/auth/google/callback")
async def google_auth_callback(
    code: str = Query(...),
    state: str = Query(...),  # user_id
):
    """Handle Google OAuth callback. Exchange code for tokens."""
    if settings.DEV_MODE:
        logger.info("DEV_MODE: mock Google Calendar auth for user %s", state)
        return {"provider": "google", "connected": True, "user_id": state}

    svc = _get_google_service()
    try:
        token_info = await svc.exchange_code(user_id=state, code=code)
        return CalendarAuthResponse(
            provider=CalendarProvider.GOOGLE,
            access_token=token_info.get("access_token", ""),
            refresh_token=token_info.get("refresh_token", ""),
            expires_at=token_info.get("expires_at", ""),
            calendar_id="primary",
        )
    except Exception as e:
        logger.error("Google Calendar auth error: %s", e)
        raise HTTPException(status_code=400, detail=f"Google Calendar auth failed: {e}")


# ── Outlook OAuth ─────────────────────────────────────────────────────────────

@router.get("/auth/outlook")
async def outlook_auth_start(
    current_user: dict = Depends(get_current_user),
):
    """Return Outlook OAuth URL."""
    svc = _get_outlook_service()
    url = svc.get_auth_url(user_id=current_user["user_id"])
    return {"auth_url": url, "provider": "outlook"}


@router.get("/auth/outlook/callback")
async def outlook_auth_callback(
    code: str = Query(...),
    state: str = Query(...),
):
    """Handle Outlook OAuth callback."""
    if settings.DEV_MODE:
        return {"provider": "outlook", "connected": True, "user_id": state}

    svc = _get_outlook_service()
    try:
        token_info = await svc.exchange_code(user_id=state, code=code)
        return CalendarAuthResponse(
            provider=CalendarProvider.OUTLOOK,
            access_token=token_info.get("access_token", ""),
            refresh_token=token_info.get("refresh_token", ""),
            expires_at=token_info.get("expires_at", ""),
            calendar_id="primary",
        )
    except Exception as e:
        logger.error("Outlook auth error: %s", e)
        raise HTTPException(status_code=400, detail=f"Outlook auth failed: {e}")


# ── Event Management ──────────────────────────────────────────────────────────

@router.post("/events", response_model=CreateEventResponse)
async def create_calendar_event(
    req: CreateEventRequest,
    current_user: dict = Depends(get_current_user),
):
    """Manually create a calendar event."""
    user_id = current_user["user_id"]

    if settings.DEV_MODE:
        return CreateEventResponse(
            event_id="mock_event_id",
            provider=req.provider or CalendarProvider.GOOGLE,
            event_url="https://calendar.google.com/mock",
            calendar_id="primary",
        )

    provider = req.provider or CalendarProvider.GOOGLE
    try:
        if provider == CalendarProvider.GOOGLE:
            svc = _get_google_service()
        elif provider == CalendarProvider.OUTLOOK:
            svc = _get_outlook_service()
        else:
            raise HTTPException(status_code=400, detail="Device calendar must be managed from the app")

        start_dt = datetime.fromisoformat(req.start_datetime)
        end_dt = datetime.fromisoformat(req.end_datetime) if req.end_datetime else None
        result = await svc.create_event(
            user_id=user_id,
            title=req.title,
            description=req.description or "",
            start_datetime=start_dt,
            end_datetime=end_dt,
            location=req.location,
            attendees=req.attendees,
        )
        return CreateEventResponse(
            event_id=result["event_id"],
            provider=provider,
            event_url=result["event_url"],
            calendar_id=result["calendar_id"],
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Create event error: %s", e)
        raise HTTPException(status_code=500, detail=f"Failed to create event: {e}")


@router.get("/events", response_model=CalendarListResponse)
async def list_calendar_events(
    provider: CalendarProvider = Query(CalendarProvider.GOOGLE),
    days: int = Query(default=7, ge=1, le=90),
    current_user: dict = Depends(get_current_user),
):
    """List upcoming calendar events."""
    user_id = current_user["user_id"]

    if settings.DEV_MODE:
        return CalendarListResponse(events=[], provider=provider, total=0)

    try:
        if provider == CalendarProvider.GOOGLE:
            svc = _get_google_service()
        elif provider == CalendarProvider.OUTLOOK:
            svc = _get_outlook_service()
        else:
            return CalendarListResponse(events=[], provider=provider, total=0)

        events = await svc.list_upcoming_events(user_id=user_id, days=days)
        return CalendarListResponse(events=events, provider=provider, total=len(events))
    except Exception as e:
        logger.error("List events error: %s", e)
        raise HTTPException(status_code=500, detail=f"Failed to list events: {e}")


@router.post("/confirm-action")
async def confirm_call_action(
    req: CalendarConfirmRequest,
    current_user: dict = Depends(get_current_user),
):
    """Confirm (or dismiss) a calendar action extracted from a call."""
    user_id = current_user["user_id"]

    if settings.DEV_MODE:
        return {
            "status": "confirmed" if req.confirmed else "dismissed",
            "call_id": req.call_id,
            "action_index": req.action_index,
        }

    if not req.confirmed:
        return {"status": "dismissed", "call_id": req.call_id, "action_index": req.action_index}

    # Load the call record and find the action
    try:
        from services.storage.encrypted_call_storage import EncryptedCallStorage
        from services.storage.s3_service import S3Service
        from services.database.db import get_mongo_client

        db = get_mongo_client()
        s3 = S3Service(
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
            bucket_name=settings.AWS_BUCKET_NAME,
            region=settings.AWS_REGION,
        )
        storage = EncryptedCallStorage(s3_service=s3, encryption_key=settings.CALL_ENCRYPTION_KEY)
        metadata = await storage.get_call_metadata(req.call_id)
        if not metadata or metadata.get("user_id") != user_id:
            raise HTTPException(status_code=404, detail="Call not found")

        actions = metadata.get("extracted_actions", [])
        if req.action_index >= len(actions):
            raise HTTPException(status_code=400, detail="Invalid action index")

        action = actions[req.action_index]
        calendar_type = req.calendar_type or "google"

        # Create the calendar event
        if calendar_type == "google":
            svc = _get_google_service()
        else:
            svc = _get_outlook_service()

        start_dt = None
        if action.get("datetime_str"):
            try:
                start_dt = datetime.fromisoformat(action["datetime_str"])
            except ValueError:
                start_dt = None

        if start_dt is None:
            return {
                "status": "needs_datetime",
                "message": "Could not determine event time. Please set it manually.",
            }

        result = await svc.create_event(
            user_id=user_id,
            title=action.get("title", "Call Action"),
            description=action.get("description", ""),
            start_datetime=start_dt,
            location=action.get("location"),
            attendees=action.get("attendees"),
        )

        # Mark action as confirmed in MongoDB
        actions[req.action_index]["confirmed"] = True
        actions[req.action_index]["calendar_event_id"] = result["event_id"]
        await db["call_records"].update_one(
            {"call_id": req.call_id},
            {"$set": {"extracted_actions": actions}},
        )

        return {
            "status": "confirmed",
            "event_id": result["event_id"],
            "event_url": result["event_url"],
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error("confirm_call_action error: %s", e)
        raise HTTPException(status_code=500, detail=f"Failed to create calendar event: {e}")


@router.get("/settings", response_model=UserCalendarSettings)
async def get_calendar_settings(
    current_user: dict = Depends(get_current_user),
):
    """Get user's calendar configuration and connection status."""
    user_id = current_user["user_id"]
    return UserCalendarSettings(
        user_id=user_id,
        preferred_provider=CalendarProvider.GOOGLE,
        google_connected=bool(settings.GOOGLE_CALENDAR_CLIENT_ID),
        outlook_connected=bool(settings.OUTLOOK_CLIENT_ID),
        device_calendar_enabled=True,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )


@router.delete("/disconnect/{provider}")
async def disconnect_calendar(
    provider: CalendarProvider,
    current_user: dict = Depends(get_current_user),
):
    """Revoke calendar access for a provider."""
    user_id = current_user["user_id"]

    if settings.DEV_MODE:
        return {"status": "disconnected", "provider": provider}

    try:
        if provider == CalendarProvider.GOOGLE:
            svc = _get_google_service()
        elif provider == CalendarProvider.OUTLOOK:
            svc = _get_outlook_service()
        else:
            return {"status": "disconnected", "provider": provider}

        await svc.revoke_access(user_id=user_id)
        return {"status": "disconnected", "provider": provider}
    except Exception as e:
        logger.error("Disconnect calendar error: %s", e)
        raise HTTPException(status_code=500, detail=f"Failed to disconnect: {e}")
