"""FCM push notification service for incoming call alerts."""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone
from typing import Optional

logger = logging.getLogger(__name__)

# TTL for device token in Redis: 30 days in seconds
_TOKEN_TTL_SECONDS = 30 * 24 * 60 * 60

# Maximum seconds a call notification is relevant before discarding
_CALL_NOTIFICATION_TTL_SECONDS = 30


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class FCMService:
    """
    Sends Firebase Cloud Messaging push notifications for call events.

    Device tokens are stored in Redis under two complementary keys:
      - ``fcm_token:{user_id}``    — the most-recently registered token (string)
      - ``fcm_tokens:{user_id}``   — a set of all active tokens (multi-device)

    In DEV_MODE (``settings.DEV_MODE is True``) no real FCM messages are sent;
    notification payloads are logged instead and ``True`` is returned.
    """

    def __init__(self, credentials_path: str, redis_client) -> None:
        """
        Parameters
        ----------
        credentials_path:
            Filesystem path to the Firebase service-account JSON file.
            Sourced from ``settings.FIREBASE_CREDENTIALS_PATH``.
        redis_client:
            An aioredis-compatible async client (or the project's
            ``services/cache/redis_cache`` module).
        """
        self._redis = redis_client
        self._firebase_app = None
        self._messaging = None
        self._dev_mode = False

        # Attempt to import and initialise firebase_admin at construction time.
        # If credentials are missing or the library is absent we fall back to
        # dev-mode mock behaviour so the module stays importable.
        try:
            import firebase_admin
            from firebase_admin import credentials as fb_credentials, messaging as fb_messaging

            if credentials_path and not firebase_admin._apps:
                cred = fb_credentials.Certificate(credentials_path)
                self._firebase_app = firebase_admin.initialize_app(cred)
            elif firebase_admin._apps:
                # Already initialised by another component
                self._firebase_app = firebase_admin.get_app()

            self._messaging = fb_messaging
            logger.info("FCMService: Firebase Admin SDK initialised.")
        except ImportError:
            logger.warning(
                "FCMService: firebase-admin is not installed — running in mock mode. "
                "Install it with: pip install firebase-admin"
            )
            self._dev_mode = True
        except Exception as exc:
            logger.warning(
                "FCMService: Could not initialise Firebase app (%s) — "
                "running in mock mode.",
                exc,
            )
            self._dev_mode = True

        if not credentials_path:
            logger.warning(
                "FCMService: No credentials_path supplied — running in mock mode."
            )
            self._dev_mode = True

    # ─── Device token management ─────────────────────────────────────────────

    async def register_device_token(
        self,
        user_id: str,
        device_token: str,
        platform: str = "android",
    ) -> None:
        """
        Register (or refresh) a device push token for a user.

        Stores:
          - ``fcm_token:{user_id}``   — latest token string (for quick single-device send)
          - ``fcm_tokens:{user_id}``  — set of all tokens (for multi-device fanout)

        Both keys expire after 30 days to self-clean stale tokens.
        """
        primary_key = f"fcm_token:{user_id}"
        set_key = f"fcm_tokens:{user_id}"

        try:
            if hasattr(self._redis, "set"):
                # aioredis-style async client
                await self._redis.set(primary_key, device_token, ex=_TOKEN_TTL_SECONDS)
                await self._redis.sadd(set_key, device_token)
                await self._redis.expire(set_key, _TOKEN_TTL_SECONDS)
            else:
                # Fallback: project redis_cache module interface
                from services.cache import redis_cache
                await redis_cache.set(primary_key, device_token, ttl=_TOKEN_TTL_SECONDS)

            logger.info(
                "FCMService: Registered device token for user_id=%s platform=%s",
                user_id,
                platform,
            )
        except Exception:
            logger.exception(
                "FCMService: Failed to register device token for user_id=%s", user_id
            )

    async def get_device_tokens(self, user_id: str) -> list[str]:
        """
        Return all registered device tokens for *user_id*.

        Prefers the set key (multi-device); falls back to the primary string
        key for backward compatibility.
        """
        set_key = f"fcm_tokens:{user_id}"
        primary_key = f"fcm_token:{user_id}"

        try:
            if hasattr(self._redis, "smembers"):
                members = await self._redis.smembers(set_key)
                if members:
                    # aioredis returns bytes or str depending on decode_responses
                    return [
                        m.decode() if isinstance(m, bytes) else m for m in members
                    ]
                # Fallback to primary key
                token = await self._redis.get(primary_key)
                if token:
                    return [token.decode() if isinstance(token, bytes) else token]
            else:
                from services.cache import redis_cache
                token = await redis_cache.get(primary_key)
                if token:
                    return [token]
        except Exception:
            logger.exception(
                "FCMService: Failed to retrieve tokens for user_id=%s", user_id
            )

        return []

    # ─── Notification senders ────────────────────────────────────────────────

    async def send_incoming_call_notification(
        self,
        user_id: str,
        call_id: str,
        from_number: str,
        caller_name: Optional[str] = None,
    ) -> bool:
        """
        Send a high-priority FCM notification alerting the user of an incoming call.

        The notification carries a data payload (for app-side handling) and a
        visible notification (for lock-screen / notification-shade display).

        Returns True if at least one device received the message.
        """
        display_name = caller_name or from_number
        data_payload = {
            "type": "incoming_call",
            "call_id": call_id,
            "from_number": from_number,
            "caller_name": display_name,
            "timestamp": _utc_now_iso(),
        }

        if self._dev_mode:
            logger.info(
                "[DEV_MODE] FCM incoming_call notification → user_id=%s call_id=%s "
                "from=%s payload=%s",
                user_id,
                call_id,
                display_name,
                data_payload,
            )
            return True

        tokens = await self.get_device_tokens(user_id)
        if not tokens:
            logger.warning(
                "FCMService: No device tokens for user_id=%s — cannot send incoming-call notification",
                user_id,
            )
            return False

        success_count = 0
        for token in tokens:
            try:
                message = self._messaging.Message(
                    data=data_payload,
                    notification=self._messaging.Notification(
                        title="📞 Incoming Call",
                        body=f"Call from {display_name}",
                    ),
                    android=self._messaging.AndroidConfig(
                        priority="high",
                        ttl=_CALL_NOTIFICATION_TTL_SECONDS,
                        notification=self._messaging.AndroidNotification(
                            sound="default",
                            priority="max",
                        ),
                    ),
                    apns=self._messaging.APNSConfig(
                        headers={
                            "apns-priority": "10",
                            "apns-expiration": str(
                                int(datetime.now(timezone.utc).timestamp())
                                + _CALL_NOTIFICATION_TTL_SECONDS
                            ),
                        },
                        payload=self._messaging.APNSPayload(
                            aps=self._messaging.Aps(sound="default", badge=1)
                        ),
                    ),
                    token=token,
                )
                # firebase_admin.messaging.send() is synchronous — run in executor
                loop = asyncio.get_event_loop()
                await loop.run_in_executor(None, self._messaging.send, message)
                success_count += 1
                logger.info(
                    "FCMService: Sent incoming_call notification to token=...%s for user_id=%s",
                    token[-8:],
                    user_id,
                )
            except Exception as exc:
                logger.warning(
                    "FCMService: Failed to send to token=...%s for user_id=%s: %s",
                    token[-8:],
                    user_id,
                    exc,
                )

        return success_count > 0

    async def send_call_ended_notification(
        self,
        user_id: str,
        call_id: str,
        duration: int,
        summary: str,
    ) -> None:
        """
        Notify the user that a call has ended and its summary is ready.

        Parameters
        ----------
        duration:
            Call duration in seconds.
        summary:
            Short one-sentence summary of the call.
        """
        data_payload = {
            "type": "call_ended",
            "call_id": call_id,
            "duration_seconds": str(duration),
            "timestamp": _utc_now_iso(),
        }
        body = f"{summary[:120]}…" if len(summary) > 120 else summary

        if self._dev_mode:
            logger.info(
                "[DEV_MODE] FCM call_ended notification → user_id=%s call_id=%s "
                "duration=%ds summary='%s'",
                user_id,
                call_id,
                duration,
                summary,
            )
            return

        tokens = await self.get_device_tokens(user_id)
        if not tokens:
            logger.warning(
                "FCMService: No tokens for user_id=%s — skipping call_ended notification",
                user_id,
            )
            return

        for token in tokens:
            try:
                message = self._messaging.Message(
                    data=data_payload,
                    notification=self._messaging.Notification(
                        title="Call summary ready",
                        body=body,
                    ),
                    android=self._messaging.AndroidConfig(priority="normal"),
                    token=token,
                )
                loop = asyncio.get_event_loop()
                await loop.run_in_executor(None, self._messaging.send, message)
            except Exception as exc:
                logger.warning(
                    "FCMService: call_ended notification failed for user_id=%s token=...%s: %s",
                    user_id,
                    token[-8:],
                    exc,
                )

    async def send_action_confirmation_notification(
        self,
        user_id: str,
        call_id: str,
        action: dict,
    ) -> None:
        """
        Notify the user that an action item was detected in a call.

        The notification prompts the user to confirm adding it to their calendar.
        The *action* dict is JSON-serialised and included in the FCM data payload.

        Parameters
        ----------
        action:
            A dict describing the detected action, e.g.::

                {
                    "type": "meeting",
                    "title": "Follow-up with John",
                    "datetime": "2026-05-24T10:00:00Z",
                    "description": "...",
                }
        """
        import json as _json

        action_title = action.get("title", "Action item")
        data_payload = {
            "type": "action_detected",
            "call_id": call_id,
            "action": _json.dumps(action),
            "timestamp": _utc_now_iso(),
        }

        if self._dev_mode:
            logger.info(
                "[DEV_MODE] FCM action_detected notification → user_id=%s call_id=%s "
                "action_title='%s'",
                user_id,
                call_id,
                action_title,
            )
            return

        tokens = await self.get_device_tokens(user_id)
        if not tokens:
            logger.warning(
                "FCMService: No tokens for user_id=%s — skipping action_detected notification",
                user_id,
            )
            return

        for token in tokens:
            try:
                message = self._messaging.Message(
                    data=data_payload,
                    notification=self._messaging.Notification(
                        title=f"Action detected: {action_title}",
                        body="Add to calendar?",
                    ),
                    android=self._messaging.AndroidConfig(priority="normal"),
                    token=token,
                )
                loop = asyncio.get_event_loop()
                await loop.run_in_executor(None, self._messaging.send, message)
                logger.info(
                    "FCMService: Sent action_detected notification to user_id=%s action='%s'",
                    user_id,
                    action_title,
                )
            except Exception as exc:
                logger.warning(
                    "FCMService: action_detected notification failed for user_id=%s: %s",
                    user_id,
                    exc,
                )
