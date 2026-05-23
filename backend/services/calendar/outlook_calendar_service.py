"""Microsoft Outlook Calendar integration via Microsoft Graph API."""
from __future__ import annotations

import json
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

import httpx

logger = logging.getLogger(__name__)

# Microsoft Graph base URL
_GRAPH_BASE = "https://graph.microsoft.com/v1.0"

# Microsoft OAuth2 / MSAL authority template
_AUTHORITY_TEMPLATE = "https://login.microsoftonline.com/{tenant_id}"

# OAuth2 scopes for Outlook Calendar read/write
_SCOPES = ["https://graph.microsoft.com/Calendars.ReadWrite", "offline_access"]

# MongoDB collection for storing OAuth tokens
_TOKEN_COLLECTION = "calendar_tokens"


class OutlookCalendarService:
    """
    Manages Microsoft Outlook Calendar OAuth2 tokens per user via MSAL and
    makes async calls to the Microsoft Graph API using ``httpx``.

    Token storage uses the injected MongoDB (motor) client; tokens are upserted
    per ``(user_id, provider="outlook")`` document.

    In DEV_MODE (no credentials configured) every method returns mock data and
    logs the intended operation.
    """

    def __init__(
        self,
        client_id: str,
        client_secret: str,
        tenant_id: str,
        redirect_uri: str,
        db_client,
    ) -> None:
        """
        Parameters
        ----------
        client_id / client_secret:
            Azure AD application (client) credentials.
        tenant_id:
            Azure AD tenant ID; use ``"common"`` for multi-tenant apps.
        redirect_uri:
            The URI Microsoft redirects to after user consent.
        db_client:
            A motor AsyncIOMotorClient (or compatible) instance.
        """
        self._client_id = client_id
        self._client_secret = client_secret
        self._tenant_id = tenant_id
        self._redirect_uri = redirect_uri
        self._db = db_client
        self._dev_mode = not (client_id and client_secret and tenant_id)

        if self._dev_mode:
            logger.warning(
                "OutlookCalendarService: credentials not fully configured — "
                "running in mock mode."
            )
        else:
            logger.info("OutlookCalendarService initialised.")

        # MSAL ConfidentialClientApplication — initialised lazily
        self._msal_app = None

    # ─── Internal helpers ────────────────────────────────────────────────────

    def _token_collection(self):
        if self._db is None:
            return None
        from config.settings import settings
        return self._db[settings.MONGODB_DB][_TOKEN_COLLECTION]

    def _get_msal_app(self):
        """Lazy-initialise the MSAL ConfidentialClientApplication."""
        if self._msal_app is not None:
            return self._msal_app
        try:
            import msal

            authority = _AUTHORITY_TEMPLATE.format(tenant_id=self._tenant_id)
            self._msal_app = msal.ConfidentialClientApplication(
                client_id=self._client_id,
                client_credential=self._client_secret,
                authority=authority,
            )
            return self._msal_app
        except ImportError:
            logger.error(
                "OutlookCalendarService: msal is not installed. "
                "Install with: pip install msal"
            )
            raise
        except Exception:
            logger.exception("OutlookCalendarService: Failed to init MSAL app")
            raise

    # ─── OAuth2 flow ─────────────────────────────────────────────────────────

    def get_auth_url(self, user_id: str) -> str:
        """
        Generate the Microsoft OAuth2 consent URL.

        *user_id* is encoded in the ``state`` parameter so it can be recovered
        in the redirect callback.

        Returns the URL string the frontend should redirect the user to.
        """
        if self._dev_mode:
            mock_url = (
                "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
                f"?client_id=MOCK&state={user_id}&scope=Calendars.ReadWrite"
                f"&response_type=code&redirect_uri={self._redirect_uri or 'http://localhost'}"
            )
            logger.info(
                "[DEV_MODE] OutlookCalendarService.get_auth_url user_id=%s → %s",
                user_id,
                mock_url,
            )
            return mock_url

        try:
            app = self._get_msal_app()
            result = app.get_authorization_request_url(
                scopes=_SCOPES,
                state=user_id,
                redirect_uri=self._redirect_uri,
            )
            return result
        except Exception:
            logger.exception(
                "OutlookCalendarService: Failed to generate auth URL for user_id=%s",
                user_id,
            )
            raise

    async def exchange_code(self, user_id: str, code: str) -> dict:
        """
        Exchange an OAuth2 authorisation code for access + refresh tokens.

        Tokens are persisted in MongoDB keyed by ``(user_id, provider="outlook")``.
        Returns a sanitised dict with token metadata.
        """
        if self._dev_mode:
            mock_token = {
                "user_id": user_id,
                "provider": "outlook",
                "access_token": "mock_access_token",
                "refresh_token": "mock_refresh_token",
                "expires_in": 3600,
            }
            logger.info(
                "[DEV_MODE] OutlookCalendarService.exchange_code user_id=%s", user_id
            )
            return mock_token

        try:
            import asyncio

            app = self._get_msal_app()
            loop = asyncio.get_event_loop()

            # MSAL acquire_token_by_authorization_code is synchronous
            result = await loop.run_in_executor(
                None,
                lambda: app.acquire_token_by_authorization_code(
                    code=code,
                    scopes=_SCOPES,
                    redirect_uri=self._redirect_uri,
                ),
            )

            if "error" in result:
                raise RuntimeError(
                    f"MSAL token exchange error: {result.get('error')} — "
                    f"{result.get('error_description')}"
                )

            token_doc = {
                "user_id": user_id,
                "provider": "outlook",
                "access_token": result.get("access_token"),
                "refresh_token": result.get("refresh_token"),
                "expires_in": result.get("expires_in", 3600),
                "token_type": result.get("token_type", "Bearer"),
                "scope": result.get("scope", ""),
                "id_token": result.get("id_token", ""),
            }

            collection = self._token_collection()
            if collection is not None:
                await collection.update_one(
                    {"user_id": user_id, "provider": "outlook"},
                    {"$set": token_doc},
                    upsert=True,
                )

            logger.info(
                "OutlookCalendarService: Token exchanged and stored for user_id=%s",
                user_id,
            )
            return {k: v for k, v in token_doc.items() if k not in ("access_token",)}
        except Exception:
            logger.exception(
                "OutlookCalendarService: Code exchange failed for user_id=%s", user_id
            )
            raise

    async def get_access_token(self, user_id: str) -> Optional[str]:
        """
        Return a valid Microsoft Graph access token for *user_id*.

        Loads the stored token document from MongoDB.  If the token appears
        expired, attempts a silent refresh via MSAL using the stored refresh
        token.  Returns None if no token is available or refresh fails.
        """
        if self._dev_mode:
            logger.info(
                "[DEV_MODE] OutlookCalendarService.get_access_token user_id=%s → mock token",
                user_id,
            )
            return "mock_access_token"

        collection = self._token_collection()
        if collection is None:
            return None

        try:
            doc = await collection.find_one({"user_id": user_id, "provider": "outlook"})
        except Exception:
            logger.exception(
                "OutlookCalendarService: DB error loading token for user_id=%s", user_id
            )
            return None

        if not doc:
            return None

        # Attempt silent token acquisition / refresh via MSAL
        try:
            import asyncio

            app = self._get_msal_app()
            accounts = app.get_accounts()

            loop = asyncio.get_event_loop()
            refresh_token = doc.get("refresh_token")

            if refresh_token:
                # Use acquire_token_by_refresh_token to get a fresh access token
                result = await loop.run_in_executor(
                    None,
                    lambda: app.acquire_token_by_refresh_token(
                        refresh_token=refresh_token,
                        scopes=_SCOPES,
                    ),
                )
                if result and "access_token" in result:
                    # Persist the refreshed tokens
                    await collection.update_one(
                        {"user_id": user_id, "provider": "outlook"},
                        {
                            "$set": {
                                "access_token": result["access_token"],
                                "refresh_token": result.get(
                                    "refresh_token", refresh_token
                                ),
                                "expires_in": result.get("expires_in", 3600),
                            }
                        },
                    )
                    logger.info(
                        "OutlookCalendarService: Refreshed access token for user_id=%s",
                        user_id,
                    )
                    return result["access_token"]
                else:
                    logger.warning(
                        "OutlookCalendarService: MSAL refresh failed for user_id=%s: %s",
                        user_id,
                        result.get("error_description", "unknown"),
                    )
                    return None

            # No refresh token — return stored access token as-is (may be expired)
            logger.warning(
                "OutlookCalendarService: No refresh token for user_id=%s — "
                "returning stored access token (may be expired).",
                user_id,
            )
            return doc.get("access_token")

        except Exception:
            logger.exception(
                "OutlookCalendarService: Failed to get/refresh token for user_id=%s",
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
        Create an Outlook calendar event via Microsoft Graph.

        Returns::

            {"event_id": str, "event_url": str, "calendar_id": "primary"}
        """
        if end_datetime is None:
            end_datetime = start_datetime + timedelta(hours=1)

        def _fmt(dt: datetime) -> str:
            """Format datetime for Graph API (no offset suffix — use timeZone field)."""
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            # Graph API expects ISO 8601 without timezone offset in dateTime field;
            # the timeZone field carries the zone.
            return dt.strftime("%Y-%m-%dT%H:%M:%S")

        if self._dev_mode:
            mock_id = f"mock_outlook_event_{user_id}_{start_datetime.strftime('%Y%m%dT%H%M%S')}"
            logger.info(
                "[DEV_MODE] OutlookCalendarService.create_event user_id=%s title='%s' "
                "start=%s end=%s",
                user_id,
                title,
                start_datetime.isoformat(),
                end_datetime.isoformat(),
            )
            return {
                "event_id": mock_id,
                "event_url": (
                    f"https://outlook.live.com/calendar/deeplink/compose?path=/calendar/item&itemId={mock_id}"
                ),
                "calendar_id": "primary",
            }

        access_token = await self.get_access_token(user_id)
        if not access_token:
            raise ValueError(
                f"No Outlook access token for user_id={user_id}. "
                "User must complete OAuth2 flow first."
            )

        # Build Microsoft Graph event payload
        event_body: dict = {
            "subject": title,
            "body": {
                "contentType": "HTML",
                "content": description,
            },
            "start": {
                "dateTime": _fmt(start_datetime),
                "timeZone": "UTC",
            },
            "end": {
                "dateTime": _fmt(end_datetime),
                "timeZone": "UTC",
            },
        }
        if location:
            event_body["location"] = {"displayName": location}
        if attendees:
            event_body["attendees"] = [
                {
                    "emailAddress": {
                        "address": a if isinstance(a, str) else a.get("email", a),
                        "name": a if isinstance(a, str) else a.get("name", ""),
                    },
                    "type": "required",
                }
                for a in attendees
            ]

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{_GRAPH_BASE}/me/events",
                    headers={
                        "Authorization": f"Bearer {access_token}",
                        "Content-Type": "application/json",
                    },
                    json=event_body,
                )
                response.raise_for_status()
                created = response.json()

            event_id = created.get("id", "")
            event_url = created.get("webLink", "")
            logger.info(
                "OutlookCalendarService: Created event id=%s for user_id=%s",
                event_id,
                user_id,
            )
            return {
                "event_id": event_id,
                "event_url": event_url,
                "calendar_id": "primary",
            }
        except httpx.HTTPStatusError as exc:
            logger.error(
                "OutlookCalendarService: HTTP %d creating event for user_id=%s: %s",
                exc.response.status_code,
                user_id,
                exc.response.text,
            )
            raise
        except Exception:
            logger.exception(
                "OutlookCalendarService: Failed to create event for user_id=%s", user_id
            )
            raise

    async def list_upcoming_events(self, user_id: str, days: int = 7) -> list:
        """
        Return upcoming Outlook calendar events for the next *days* days.

        Each element is the raw Microsoft Graph event resource dict.
        """
        if self._dev_mode:
            logger.info(
                "[DEV_MODE] OutlookCalendarService.list_upcoming_events user_id=%s days=%d",
                user_id,
                days,
            )
            return [
                {
                    "id": "mock_outlook_event_1",
                    "subject": "Weekly sync",
                    "start": {"dateTime": datetime.now(timezone.utc).isoformat(), "timeZone": "UTC"},
                    "end": {
                        "dateTime": (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat(),
                        "timeZone": "UTC",
                    },
                    "webLink": "https://outlook.live.com/calendar/0/deeplink/compose",
                }
            ]

        access_token = await self.get_access_token(user_id)
        if not access_token:
            logger.warning(
                "OutlookCalendarService: No token for user_id=%s", user_id
            )
            return []

        now = datetime.now(timezone.utc)
        start_dt = now.strftime("%Y-%m-%dT%H:%M:%SZ")
        end_dt = (now + timedelta(days=days)).strftime("%Y-%m-%dT%H:%M:%SZ")

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{_GRAPH_BASE}/me/calendarView",
                    headers={"Authorization": f"Bearer {access_token}"},
                    params={
                        "startDateTime": start_dt,
                        "endDateTime": end_dt,
                        "$orderby": "start/dateTime",
                        "$top": "50",
                        "$select": "id,subject,start,end,location,webLink,organizer",
                    },
                )
                response.raise_for_status()
                data = response.json()
                events = data.get("value", [])
                logger.info(
                    "OutlookCalendarService: Listed %d events for user_id=%s",
                    len(events),
                    user_id,
                )
                return events
        except httpx.HTTPStatusError as exc:
            logger.error(
                "OutlookCalendarService: HTTP %d listing events for user_id=%s: %s",
                exc.response.status_code,
                user_id,
                exc.response.text,
            )
            return []
        except Exception:
            logger.exception(
                "OutlookCalendarService: Failed to list events for user_id=%s", user_id
            )
            return []

    async def revoke_access(self, user_id: str) -> None:
        """
        Remove Outlook OAuth tokens for *user_id* from MongoDB.

        Note: Microsoft does not provide a direct token-revocation endpoint
        for refresh tokens via a simple HTTP call in all configurations.
        The token is removed locally; it will expire on Microsoft's side
        within its normal lifetime.
        """
        if self._dev_mode:
            logger.info(
                "[DEV_MODE] OutlookCalendarService.revoke_access user_id=%s", user_id
            )
            return

        collection = self._token_collection()
        if collection is None:
            return

        try:
            await collection.delete_one({"user_id": user_id, "provider": "outlook"})
            logger.info(
                "OutlookCalendarService: Deleted token record for user_id=%s", user_id
            )
        except Exception:
            logger.exception(
                "OutlookCalendarService: Failed to delete token record for user_id=%s",
                user_id,
            )
