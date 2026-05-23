"""User profile service — learns communication preferences and call patterns over time."""
import json
import logging
from datetime import datetime, timezone
from typing import Optional

logger = logging.getLogger(__name__)

# Redis TTLs
_PROFILE_TTL = 60 * 60 * 24 * 365   # 1 year
_CONTACT_TTL = 60 * 60 * 24 * 365   # 1 year
_SCHEDULE_TTL = 60 * 60 * 24 * 365  # 1 year


class UserProfileService:
    def __init__(self, redis_client, mongodb_client) -> None:
        self.redis = redis_client
        self.db = mongodb_client

    # ── Profile ───────────────────────────────────────────────────────────────

    async def get_profile(self, user_id: str) -> dict:
        try:
            raw = await self.redis.get(f"profile:{user_id}:prefs")
            if raw:
                data = raw if isinstance(raw, str) else raw.decode()
                return json.loads(data)
        except Exception as e:
            logger.warning("Redis get_profile error: %s", e)
        return {
            "user_id": user_id,
            "preferred_language": "en-US",
            "preferred_calendar": "google",
            "timezone": "UTC",
            "call_count": 0,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }

    async def update_profile(self, user_id: str, updates: dict) -> None:
        profile = await self.get_profile(user_id)
        profile.update(updates)
        try:
            await self.redis.set(
                f"profile:{user_id}:prefs",
                json.dumps(profile),
                ex=_PROFILE_TTL,
            )
        except Exception as e:
            logger.warning("Redis update_profile error: %s", e)

    # ── Contacts ──────────────────────────────────────────────────────────────

    async def record_caller(
        self,
        user_id: str,
        phone_number: str,
        call_summary: str,
        inferred_name: Optional[str] = None,
    ) -> None:
        contact = await self.get_caller_info(user_id, phone_number) or {}
        contact["phone_number"] = phone_number
        contact["call_count"] = contact.get("call_count", 0) + 1
        contact["last_call_at"] = datetime.now(timezone.utc).isoformat()
        if inferred_name and not contact.get("name"):
            contact["name"] = inferred_name
        topics: list = contact.get("topics", [])
        if call_summary:
            # Keep up to 10 recent topics
            topics = (topics + [call_summary[:200]])[-10:]
        contact["topics"] = topics

        key = f"profile:{user_id}:contacts"
        try:
            raw = await self.redis.get(key)
            contacts: dict = {}
            if raw:
                contacts = json.loads(raw if isinstance(raw, str) else raw.decode())
            contacts[phone_number] = contact
            await self.redis.set(key, json.dumps(contacts), ex=_CONTACT_TTL)
        except Exception as e:
            logger.warning("Redis record_caller error: %s", e)

    async def get_caller_info(self, user_id: str, phone_number: str) -> Optional[dict]:
        key = f"profile:{user_id}:contacts"
        try:
            raw = await self.redis.get(key)
            if raw:
                contacts = json.loads(raw if isinstance(raw, str) else raw.decode())
                return contacts.get(phone_number)
        except Exception as e:
            logger.warning("Redis get_caller_info error: %s", e)
        return None

    # ── Learning ──────────────────────────────────────────────────────────────

    async def learn_from_call(
        self,
        user_id: str,
        call_id: str,
        conversation_history: list,
        actions: list,
    ) -> None:
        """Extract patterns from a completed call to refine the user's profile."""
        if not conversation_history:
            return

        # Detect dominant language from caller turns
        caller_languages = [
            t.get("language", "en-US")
            for t in conversation_history
            if t.get("role") == "caller" and t.get("language")
        ]
        if caller_languages:
            from collections import Counter
            dominant = Counter(caller_languages).most_common(1)[0][0]
            profile = await self.get_profile(user_id)
            # Weighted update: don't overwrite after a single call
            call_count = profile.get("call_count", 0) + 1
            await self.update_profile(user_id, {
                "call_count": call_count,
                "last_call_at": datetime.now(timezone.utc).isoformat(),
                "recent_language": dominant,
            })

        # Track action type frequencies
        if actions:
            profile = await self.get_profile(user_id)
            action_counts: dict = profile.get("action_type_counts", {})
            for action in actions:
                atype = action.get("action_type", "unknown")
                action_counts[atype] = action_counts.get(atype, 0) + 1
            await self.update_profile(user_id, {"action_type_counts": action_counts})

    async def get_preferred_language(self, user_id: str, caller_number: str) -> Optional[str]:
        """Return the language most used with this specific caller, or the user's global preference."""
        caller = await self.get_caller_info(user_id, caller_number)
        if caller and caller.get("preferred_language"):
            return caller["preferred_language"]
        profile = await self.get_profile(user_id)
        return profile.get("preferred_language")

    # ── Scheduling preferences ────────────────────────────────────────────────

    async def get_scheduling_preferences(self, user_id: str) -> dict:
        key = f"profile:{user_id}:schedule_prefs"
        try:
            raw = await self.redis.get(key)
            if raw:
                return json.loads(raw if isinstance(raw, str) else raw.decode())
        except Exception as e:
            logger.warning("Redis get_scheduling_preferences error: %s", e)
        return {
            "preferred_meeting_start_hour": 9,
            "preferred_meeting_end_hour": 18,
            "meeting_buffer_minutes": 15,
            "preferred_calendar": "google",
            "timezone": "UTC",
            "auto_add_to_calendar": False,
        }

    async def set_scheduling_preferences(self, user_id: str, prefs: dict) -> None:
        current = await self.get_scheduling_preferences(user_id)
        current.update(prefs)
        try:
            await self.redis.set(
                f"profile:{user_id}:schedule_prefs",
                json.dumps(current),
                ex=_SCHEDULE_TTL,
            )
        except Exception as e:
            logger.warning("Redis set_scheduling_preferences error: %s", e)
