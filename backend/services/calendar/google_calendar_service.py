"""Google Calendar API integration for creating events from call action items."""
from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

logger = logging.getLogger(__name__)

# OAuth2 scopes required for full calendar read/write access
SCOPES = ["https://www.googleapis.com/auth/calendar"]

# MongoDB collection for storing OAuth tokens
_TOKEN_COLLECTION = "calendar_tokens"


class GoogleCalendarService:
    """
    Manages Google Calendar OAuth2 tokens per user and creates / lists events
    by calling the Google Calendar REST API via the official Python client.

    All Google API calls (which are synchronous) are wrapped in
    ``asyncio.run_in_executor`` so they do not block the event loop.

    Token storage uses the injected MongoDB (motor) client; tokens are
    upserted per ``(user_id, provider="google")`` document.

    In DEV_MODE (no credentials configured) every method returns mock data and
    logs the intended operation.
    """

    def __init__(
        self,
        client_id: str,
        client_secret: str,
        redirect_uri: str,
        db_client,
    ) -> None:
        """
        Parameters
        ----------
        client_id / client_secret:
            Google OAuth2 application credentials.
        redirect_uri:
            The URI Google redirects to after user consent.
        db_client:
            A motor AsyncIOMotorClient (or compatible) instance.
        """
        self._client_id = client_id
        self._client_secret = client_secret
        self._redirect_uri = redirect_uri
        self._db = db_client
        self._dev_mode = not (client_id and client_secret)

        if self._dev_mode:
            logger.warning(
                "GoogleCalendarService: client_id / client_secret not configured — "
                "running in mock mode."
            )
        else:
            logger.info("GoogleCalendarService initialised.")

    # ─── Internal helpers ────────────────────────────────────────────────────

    def _token_collection(self):
        """Return the motor collection, or None if no DB client is set."""
        if self._db is None:
            return None
        from config.settings import settings
        return self._db[settings.MONGODB_DB][_TOKEN_COLLECTION]

    def _build_flow(self):
        """Construct a google_auth_oauthlib InstalledAppFlow."""
        from google_auth_oauthlib.flow import Flow

        client_config = {
            "web": {
                "client_id": self._client_id,
                "client_secret": self._client_secret,
                "redirect_uris": [self._redirect_uri],
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
            }
        }
        flow = Flow.from_client_config(client_config, scopes=SCOPES)
        flow.redirect_uri = self._redirect_uri
        return flow

    # ─── OAuth2 flow ─────────────────────────────────────────────────────────

    def get_auth_url(self, user_id: str) -> str:
        """
        Generate the Google OAuth2 consent URL.

        The *user_id* is encoded in the ``state`` parameter so it can be
        recovered in the redirect callback.

        Returns the URL string the frontend should redirect the user to.
        """
        if self._dev_mode:
            mock_url = (
                "https://accounts.google.com/o/oauth2/auth"
                f"?client_id=MOCK&state={user_id}&scope=calendar&response_type=code"
            )
            logger.info(
                "[DEV_MODE] GoogleCalendarService.get_auth_url user_id=%s → %s",
                user_id,
                mock_url,
            )
            return mock_url

        try:
            flow = self._build_flow()
            auth_url, _ = flow.authorization_url(
                access_type="offline",
                include_granted_scopes="true",
                state=user_id,
                prompt="consent",
            )
            return auth_url
        except Exception:
            logger.exception(
                "GoogleCalendarService: Failed to generate auth URL for user_id=%s",
                user_id,
            )
            raise

    async def exchange_code(self, user_id: str, code: str) -> dict:
        """
        Exchange an OAuth2 authorisation code for access + refresh tokens.

        Tokens are persisted in MongoDB keyed by ``(user_id, provider="google")``.

        Returns a dict with token metadata (without exposing raw secrets to callers).
        """
        if self._dev_mode:
            mock_token = {
                "user_id": user_id,
                "provider": "google",
                "token": "mock_access_token",
                "refresh_token": "mock_refresh_token",
                "expiry": "2099-01-01T00:00:00Z",
            }
            logger.info(
                "[DEV_MODE] GoogleCalendarService.exchange_code user_id=%s", user_id
            )
            return mock_token

        try:
            flow = self._build_flow()
            loop = asyncio.get_event_loop()
            # fetch_token is synchronous
            await loop.run_in_executor(None, flow.fetch_token, None, None, code)
            creds = flow.credentials

            token_doc = {
                "user_id": user_id,
                "provider": "google",
                "token": creds.token,
                "refresh_token": creds.refresh_token,
                "token_uri": creds.token_uri,
                "client_id": creds.client_id,
                "client_secret": creds.client_secret,
                "scopes": list(creds.scopes) if creds.scopes else SCOPES,
                "expiry": creds.expiry.isoformat() if creds.expiry else None,
            }

            collection = self._token_collection()
            if collection is not None:
                await collection.update_one(
                    {"user_id": user_id, "provider": "google"},
                    {"$set": token_doc},
                    upsert=True,
                )

            logger.info(
                "GoogleCalendarService: Token exchanged and stored for user_id=%s",
                user_id,
            )
            return {k: v for k, v in token_doc.items() if k != "client_secret"}
        except Exception:
            logger.exception(
                "GoogleCalendarService: Code exchange failed for user_id=%s", user_id
            )
            raise

    async def get_credentials(self, user_id: str) -> Optional[Any]:
        """
        Load OAuth2 credentials from MongoDB for *user_id* and refresh if expired.

        Returns a ``google.oauth2.credentials.Credentials`` object, or None if
        no tokens are stored.
        """
        if self._dev_mode:
            logger.info(
                "[DEV_MODE] GoogleCalendarService.get_credentials user_id=%s → mock creds",
                user_id,
            )
            return None

        collection = self._token_collection()
        if collection is None:
            return None

        try:
            doc = await collection.find_one({"user_id": user_id, "provider": "google"})
        except Exception:
            logger.exception(
                "GoogleCalendarService: DB error loading credentials for user_id=%s",
                user_id,
            )
            return None

        if not doc:
            return None

        try:
            from google.oauth2.credentials import Credentials
            from google.auth.transport.requests import Request

            expiry = None
            if doc.get("expiry"):
                try:
                    expiry = datetime.fromisoformat(doc["expiry"])
                except ValueError:
                    pass

            creds = Credentials(
                token=doc.get("token"),
                refresh_token=doc.get("refresh_token"),
                token_uri=doc.get("token_uri", "https://oauth2.googleapis.com/token"),
                client_id=doc.get("client_id", self._client_id),
                client_secret=doc.get("client_secret", self._client_secret),
                scopes=doc.get("scopes", SCOPES),
            )
            if expiry:
                creds.expiry = expiry

            if creds.expired and creds.refresh_token:
                loop = asyncio.get_event_loop()
                await loop.run_in_executor(None, creds.refresh, Request())

                # Persist refreshed token
                collection = self._token_collection()
                if collection is not None:
                    await collection.update_one(
                        {"user_id": user_id, "provider": "google"},
                        {
                            "$set": {
                                "token": creds.token,
                                "expiry": creds.expiry.isoformat() if creds.expiry else None,
                            }
                        },
                    )

            return creds
        except Exception:
            logger.exception(
                "GoogleCalendarService: Failed to build/refresh credentials for user_id=%s",
                user_id,
            )
            return None

    # ─── Calendar operations ─────────────────────────────────────────────────

    async def create_event(
        self,
        user_id: str,
        title: str,
        description: str,
        start_datetime: datetime,
        end_datetime: Optional[datetime] = None,
        location: Optional[str] = None,
        attendees: Optional[list] = None,
    ) -> dict:
        """
        Create a Google Calendar event on the user's primary calendar.

        Returns a dict::

            {"event_id": str, "event_url": str, "calendar_id": "primary"}
        """
        if end_datetime is None:
            end_datetime = start_datetime + timedelta(hours=1)

        if self._dev_mode:
            mock_event_id = f"mock_event_{user_id}_{start_datetime.strftime('%Y%m%dT%H%M%S')}"
            logger.info(
                "[DEV_MODE] GoogleCalendarService.create_event user_id=%s title='%s' "
                "start=%s end=%s",
                user_id,
                title,
                start_datetime.isoformat(),
                end_datetime.isoformat(),
            )
            return {
                "event_id": mock_event_id,
                "event_url": f"https://calendar.google.com/calendar/event?eid={mock_event_id}",
                "calendar_id": "primary",
            }

        creds = await self.get_credentials(user_id)
        if creds is None:
            raise ValueError(
                f"No Google Calendar credentials for user_id={user_id}. "
                "User must complete OAuth2 flow first."
            )

        # Format datetimes; use UTC if tz-naive
        def _fmt(dt: datetime) -> str:
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt.isoformat()

        event_body: dict = {
            "summary": title,
            "description": description,
            "start": {"dateTime": _fmt(start_datetime), "timeZone": "UTC"},
            "end": {"dateTime": _fmt(end_datetime), "timeZone": "UTC"},
        }
        if location:
            event_body["location"] = location
        if attendees:
            event_body["attendees"] = [
                {"email": a} if isinstance(a, str) else a for a in attendees
            ]

        try:
            from googleapiclient.discovery import build

            loop = asyncio.get_event_loop()

            def _insert():
                service = build("calendar", "v3", credentials=creds)
                return (
                    service.events()
                    .insert(calendarId="primary", body=event_body)
                    .execute()
                )

            created = await loop.run_in_executor(None, _insert)
            logger.info(
                "GoogleCalendarService: Created event id=%s for user_id=%s",
                created.get("id"),
                user_id,
            )
            return {
                "event_id": created.get("id", ""),
                "event_url": created.get("htmlLink", ""),
                "calendar_id": "primary",
            }
        except Exception:
            logger.exception(
                "GoogleCalendarService: Failed to create event for user_id=%s", user_id
            )
            raise

    async def list_upcoming_events(self, user_id: str, days: int = 7) -> list:
        """
        Return upcoming calendar events for *user_id* in the next *days* days.

        Each element is the raw Google Calendar event resource dict.
        """
        if self._dev_mode:
            logger.info(
                "[DEV_MODE] GoogleCalendarService.list_upcoming_events user_id=%s days=%d",
                user_id,
                days,
            )
            return [
                {
                    "id": "mock_event_1",
                    "summary": "Team standup",
                    "start": {"dateTime": datetime.now(timezone.utc).isoformat()},
                    "end": {"dateTime": (datetime.now(timezone.utc) + timedelta(minutes=30)).isoformat()},
                    "htmlLink": "https://calendar.google.com/calendar/event?eid=mock_event_1",
                }
            ]

        creds = await self.get_credentials(user_id)
        if creds is None:
            logger.warning(
                "GoogleCalendarService: No credentials for user_id=%s", user_id
            )
            return []

        now = datetime.now(timezone.utc)
        time_min = now.isoformat()
        time_max = (now + timedelta(days=days)).isoformat()

        try:
            from googleapiclient.discovery import build

            loop = asyncio.get_event_loop()

            def _list():
                service = build("calendar", "v3", credentials=creds)
                result = (
                    service.events()
                    .list(
                        calendarId="primary",
                        timeMin=time_min,
                        timeMax=time_max,
                        singleEvents=True,
                        orderBy="startTime",
                        maxResults=50,
                    )
                    .execute()
                )
                return result.get("items", [])

            events = await loop.run_in_executor(None, _list)
            logger.info(
                "GoogleCalendarService: Listed %d events for user_id=%s",
                len(events),
                user_id,
            )
            return events
        except Exception:
            logger.exception(
                "GoogleCalendarService: Failed to list events for user_id=%s", user_id
            )
            return []

    async def check_free_busy(
        self, user_id: str, start: datetime, end: datetime
    ) -> bool:
        """
        Return True if the user has no calendar events between *start* and *end*.

        Uses the Google Calendar FreeBusy API.
        """
        if self._dev_mode:
            logger.info(
                "[DEV_MODE] GoogleCalendarService.check_free_busy user_id=%s "
                "start=%s end=%s → True (mock)",
                user_id,
                start.isoformat(),
                end.isoformat(),
            )
            return True

        creds = await self.get_credentials(user_id)
        if creds is None:
            return True  # Assume free if no creds

        def _fmt(dt: datetime) -> str:
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt.isoformat()

        try:
            from googleapiclient.discovery import build

            loop = asyncio.get_event_loop()

            def _query():
                service = build("calendar", "v3", credentials=creds)
                body = {
                    "timeMin": _fmt(start),
                    "timeMax": _fmt(end),
                    "items": [{"id": "primary"}],
                }
                return service.freebusy().query(body=body).execute()

            result = await loop.run_in_executor(None, _query)
            busy_slots = result.get("calendars", {}).get("primary", {}).get("busy", [])
            is_free = len(busy_slots) == 0
            logger.info(
                "GoogleCalendarService: check_free_busy user_id=%s → is_free=%s",
                user_id,
                is_free,
            )
            return is_free
        except Exception:
            logger.exception(
                "GoogleCalendarService: FreeBusy query failed for user_id=%s", user_id
            )
            return True  # Default to free on error

    async def revoke_access(self, user_id: str) -> None:
        """
        Revoke Google OAuth2 tokens for *user_id* and remove them from MongoDB.

        After this call the user must re-authorise to use calendar features.
        """
        if self._dev_mode:
            logger.info(
                "[DEV_MODE] GoogleCalendarService.revoke_access user_id=%s", user_id
            )
            return

        creds = await self.get_credentials(user_id)

        if creds and creds.token:
            try:
                import httpx

                async with httpx.AsyncClient(timeout=10.0) as client:
                    await client.post(
                        "https://oauth2.googleapis.com/revoke",
                        params={"token": creds.token},
                    )
                logger.info(
                    "GoogleCalendarService: Revoked token with Google for user_id=%s",
                    user_id,
                )
            except Exception:
                logger.warning(
                    "GoogleCalendarService: Could not revoke token with Google for user_id=%s "
                    "(token may already be expired)",
                    user_id,
                )

        collection = self._token_collection()
        if collection is not None:
            try:
                await collection.delete_one({"user_id": user_id, "provider": "google"})
                logger.info(
                    "GoogleCalendarService: Deleted token record for user_id=%s", user_id
                )
            except Exception:
                logger.exception(
                    "GoogleCalendarService: Failed to delete token record for user_id=%s",
                    user_id,
                )
