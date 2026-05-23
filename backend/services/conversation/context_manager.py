"""Per-call conversation context manager backed by Redis."""
import json
import logging
import os
import time
from typing import Any, Optional

logger = logging.getLogger(__name__)

# TTL constants (seconds)
_CALL_TTL: int = 4 * 60 * 60       # 4 hours
_PROFILE_TTL: int = 30 * 24 * 60 * 60  # 30 days

_DEV_MODE: bool = os.getenv("DEV_MODE", "false").lower() in ("true", "1", "yes")


class ConversationContextManager:
    """Store and retrieve per-call conversation state in Redis.

    Parameters
    ----------
    redis_client:
        An ``aioredis`` client (or compatible async Redis client).  In dev
        mode with the in-memory redis stub the same key/value semantics apply.
    """

    def __init__(self, redis_client) -> None:
        self._redis = redis_client

    # ------------------------------------------------------------------
    # Call lifecycle
    # ------------------------------------------------------------------

    async def initialize_context(
        self,
        call_id: str,
        caller_number: str,
        user_id: str,
    ) -> None:
        """Create initial context and empty history entries for *call_id*.

        Keys created
        ------------
        ``call_context:{call_id}``
            JSON-encoded dict holding call metadata.  TTL 4 hours.
        ``call_history:{call_id}``
            JSON-encoded list of conversation turns.  TTL 4 hours.
        """
        context: dict[str, Any] = {
            "call_id": call_id,
            "caller_number": caller_number,
            "user_id": user_id,
            "turn_count": 0,
            "start_time": time.time(),
            "detected_language": "en-US",
            "extracted_actions": [],
        }
        history: list = []

        await self._set_json(f"call_context:{call_id}", context, ttl=_CALL_TTL)
        await self._set_json(f"call_history:{call_id}", history, ttl=_CALL_TTL)
        logger.info("Initialized context for call %s (caller=%s)", call_id, caller_number)

    async def add_turn(
        self,
        call_id: str,
        role: str,
        text: str,
        language: str,
    ) -> int:
        """Append a conversation turn and return the new turn index (0-based).

        Parameters
        ----------
        role:
            ``"user"`` or ``"assistant"``.
        text:
            Transcribed or synthesized text for this turn.
        language:
            BCP-47 language code active for this turn.
        """
        history = await self.get_history(call_id)
        turn_index = len(history)
        turn: dict[str, Any] = {
            "turn_index": turn_index,
            "role": role,
            "text": text,
            "language": language,
            "timestamp": time.time(),
        }
        history.append(turn)
        await self._set_json(f"call_history:{call_id}", history, ttl=_CALL_TTL)

        # Increment turn_count in context
        ctx = await self.get_context(call_id)
        if ctx:
            ctx["turn_count"] = len(history)
            await self._set_json(f"call_context:{call_id}", ctx, ttl=_CALL_TTL)

        logger.debug(
            "Added turn %d (role=%s, lang=%s) for call %s",
            turn_index,
            role,
            language,
            call_id,
        )
        return turn_index

    async def get_history(self, call_id: str) -> list[dict]:
        """Return the list of conversation turns for *call_id*.

        Returns an empty list if no history is found.
        """
        raw = await self._get_json(f"call_history:{call_id}")
        if raw is None:
            return []
        if isinstance(raw, list):
            return raw
        logger.warning("Unexpected history type for call %s: %s", call_id, type(raw))
        return []

    async def update_language(self, call_id: str, language: str) -> None:
        """Update the detected language stored in the call context."""
        ctx = await self.get_context(call_id)
        if ctx is None:
            logger.warning("update_language: no context found for call %s", call_id)
            return
        ctx["detected_language"] = language
        await self._set_json(f"call_context:{call_id}", ctx, ttl=_CALL_TTL)
        logger.debug("Language updated to %s for call %s", language, call_id)

    async def get_context(self, call_id: str) -> Optional[dict]:
        """Return the full context dict for *call_id*, or ``None`` if missing."""
        return await self._get_json(f"call_context:{call_id}")

    async def set_extracted_actions(self, call_id: str, actions: list) -> None:
        """Persist a list of extracted action dicts onto the call context."""
        ctx = await self.get_context(call_id)
        if ctx is None:
            logger.warning("set_extracted_actions: no context found for call %s", call_id)
            return
        ctx["extracted_actions"] = actions
        await self._set_json(f"call_context:{call_id}", ctx, ttl=_CALL_TTL)

    async def get_extracted_actions(self, call_id: str) -> list:
        """Return previously stored action items, or an empty list."""
        ctx = await self.get_context(call_id)
        if ctx is None:
            return []
        return ctx.get("extracted_actions", [])

    async def finalize(self, call_id: str) -> dict:
        """Collect and return the full context + history, then delete the keys.

        This should be called once after the call ends so that downstream
        post-processing (summaries, calendar entries) can consume the data.

        Returns
        -------
        dict
            ``{"context": {...}, "history": [...]}``
        """
        context = await self.get_context(call_id) or {}
        history = await self.get_history(call_id)

        # Clean up Redis keys
        for key in (f"call_context:{call_id}", f"call_history:{call_id}"):
            try:
                await self._delete(key)
            except Exception as exc:
                logger.warning("Failed to delete key %s: %s", key, exc)

        logger.info(
            "Finalized call %s — %d turns, %d actions",
            call_id,
            len(history),
            len(context.get("extracted_actions", [])),
        )
        return {"context": context, "history": history}

    # ------------------------------------------------------------------
    # User profile (long-lived preferences)
    # ------------------------------------------------------------------

    async def get_user_profile(self, user_id: str) -> dict:
        """Return the learned preference profile for *user_id*.

        Returns an empty dict if no profile has been stored yet.
        """
        profile = await self._get_json(f"user_profile:{user_id}")
        return profile if isinstance(profile, dict) else {}

    async def update_user_profile(self, user_id: str, updates: dict) -> None:
        """Merge *updates* into the stored user profile (TTL 30 days)."""
        profile = await self.get_user_profile(user_id)
        profile.update(updates)
        await self._set_json(f"user_profile:{user_id}", profile, ttl=_PROFILE_TTL)
        logger.debug("User profile updated for user %s", user_id)

    # ------------------------------------------------------------------
    # Private Redis helpers
    # ------------------------------------------------------------------

    async def _set_json(self, key: str, value: Any, ttl: int = _CALL_TTL) -> None:
        """Serialize *value* to JSON and store it in Redis with *ttl* seconds."""
        try:
            serialized = json.dumps(value, default=str)
            # aioredis >= 2.x: set(key, value, ex=ttl)
            # Fallback for in-memory stub that only takes (key, value)
            try:
                await self._redis.set(key, serialized, ex=ttl)
            except TypeError:
                await self._redis.set(key, serialized)
        except Exception as exc:
            logger.error("Redis SET failed for key %s: %s", key, exc)
            raise

    async def _get_json(self, key: str) -> Optional[Any]:
        """Retrieve and deserialize a JSON value from Redis.

        Returns ``None`` if the key does not exist or deserialization fails.
        """
        try:
            raw = await self._redis.get(key)
            if raw is None:
                return None
            # aioredis may return bytes or str depending on version/decode_responses
            if isinstance(raw, bytes):
                raw = raw.decode("utf-8")
            return json.loads(raw)
        except Exception as exc:
            logger.error("Redis GET/decode failed for key %s: %s", key, exc)
            return None

    async def _delete(self, key: str) -> None:
        """Delete a single key from Redis."""
        try:
            await self._redis.delete(key)
        except Exception as exc:
            logger.error("Redis DELETE failed for key %s: %s", key, exc)
            raise
