"""AI call assistant powered by Claude. Handles multilingual conversations and action extraction."""
import json
import logging
import os
from typing import Any, Optional

try:
    import anthropic  # type: ignore
except ImportError:  # pragma: no cover
    anthropic = None  # type: ignore

from backend.services.conversation.context_manager import ConversationContextManager
from backend.services.speech.language_detector import (
    LANGUAGE_DISPLAY_NAMES,
    LanguageDetector,
)

logger = logging.getLogger(__name__)

_DEV_MODE: bool = os.getenv("DEV_MODE", "false").lower() in ("true", "1", "yes")

_MODEL = "claude-sonnet-4-6"
_MAX_TOKENS_RESPONSE = 150        # Short — this is a phone call
_MAX_TOKENS_EXTRACTION = 1024     # Enough for structured JSON output
_MAX_TOKENS_SUMMARY = 512

# ---------------------------------------------------------------------------
# System prompt template
# ---------------------------------------------------------------------------

_SYSTEM_PROMPT_TEMPLATE = """\
You are an intelligent AI voice assistant answering a phone call on behalf of {user_name}.
You are speaking with {caller_name_or_number}.

Your role:
- Answer naturally and helpfully as if you are the owner's personal assistant
- Be polite, professional, and concise (this is a phone call, keep responses short)
- Speak in {language_name} language
- Listen carefully for the purpose of the call: meetings, appointments, deliveries, invitations, work matters
- When the caller mentions something actionable (meeting, appointment, etc), note it
- After the call ends, you will extract action items

Important: Keep responses to 2-3 sentences max. Do not be verbose. Be warm but efficient.
If the caller asks to speak with the owner directly, say they're unavailable and you'll pass the message.\
"""

# Prompt used to extract structured action items from the conversation history
_ACTION_EXTRACTION_PROMPT = """\
Based on the following phone conversation, extract any action items, meetings, appointments, \
tasks, or commitments mentioned. Return ONLY a JSON array (no markdown, no explanation) where \
each element has these fields:
  - action_type: string (e.g. "meeting", "appointment", "delivery", "task", "invitation", "other")
  - title: string (short descriptive title)
  - description: string (full detail from the conversation)
  - datetime_str: string in ISO 8601 format if a date/time was mentioned, otherwise null
  - location: string if a location was mentioned, otherwise null

If there are no action items, return an empty array: []

Conversation:
{conversation_text}\
"""

# Prompt used to generate a post-call summary
_SUMMARY_PROMPT = """\
Summarize the following phone conversation. Respond with valid JSON only (no markdown fences) \
using this exact structure:
{
  "summary": "<2-3 sentence summary>",
  "key_points": ["<point 1>", "<point 2>", "<point 3>"],
  "extracted_actions": [
    {
      "action_type": "<type>",
      "title": "<title>",
      "description": "<description>",
      "datetime_str": "<ISO 8601 or null>",
      "location": "<location or null>"
    }
  ]
}

Conversation:
{conversation_text}\
"""


class CallAssistant:
    """AI voice assistant that drives a multilingual phone conversation via Claude.

    Parameters
    ----------
    context_manager:
        A :class:`ConversationContextManager` instance for reading/writing
        per-call state.
    language_detector:
        A :class:`LanguageDetector` for detecting language switches mid-call.
    """

    def __init__(
        self,
        context_manager: ConversationContextManager,
        language_detector: LanguageDetector,
    ) -> None:
        self._ctx = context_manager
        self._lang = language_detector

        # Anthropic client — safe to instantiate even without a key in dev mode
        api_key = os.getenv("ANTHROPIC_API_KEY", "")
        self._anthropic = None
        if not _DEV_MODE:
            if anthropic is None:
                logger.warning(
                    "anthropic package is not installed — AI responses will be unavailable."
                )
            else:
                try:
                    self._anthropic = anthropic.AsyncAnthropic(api_key=api_key)
                    logger.info("Anthropic async client initialised (model=%s)", _MODEL)
                except Exception as exc:
                    logger.warning("Could not initialise Anthropic client: %s", exc)

    # ------------------------------------------------------------------
    # Public async API
    # ------------------------------------------------------------------

    async def generate_response(
        self,
        call_id: str,
        caller_text: str,
        current_language: str,
    ) -> tuple[str, str]:
        """Generate an AI response to *caller_text* and persist both turns.

        Parameters
        ----------
        call_id:
            Unique identifier for the active call session.
        caller_text:
            The transcribed speech from the caller for this turn.
        current_language:
            The BCP-47 language code most recently detected/used.

        Returns
        -------
        tuple[str, str]
            ``(response_text, language_to_use)`` where *language_to_use* is
            the language the assistant's reply is spoken in (may differ from
            *current_language* if a switch is detected).
        """
        if _DEV_MODE:
            logger.info("CallAssistant mock generate_response for call %s", call_id)
            mock_reply = "I understand. I'll pass that message along."
            await self._ctx.add_turn(call_id, "user", caller_text, current_language)
            await self._ctx.add_turn(call_id, "assistant", mock_reply, "en-US")
            return (mock_reply, "en-US")

        # Detect language switch
        detected_language = self._lang.detect(caller_text)
        if detected_language != current_language:
            logger.info(
                "Language switch detected for call %s: %s → %s",
                call_id,
                current_language,
                detected_language,
            )
            await self._ctx.update_language(call_id, detected_language)
            language_to_use = detected_language
        else:
            language_to_use = current_language

        # Record the caller's turn before calling Claude
        await self._ctx.add_turn(call_id, "user", caller_text, language_to_use)

        # Build Claude messages from stored history
        ctx = await self._ctx.get_context(call_id) or {}
        history = await self._ctx.get_history(call_id)

        system_prompt = self._build_system_prompt(ctx, language_to_use)
        messages = self._history_to_messages(history)

        try:
            reply = await self._call_claude(
                system_prompt=system_prompt,
                messages=messages,
                max_tokens=_MAX_TOKENS_RESPONSE,
            )
        except Exception as exc:
            logger.error("Claude response generation failed for call %s: %s", call_id, exc)
            reply = "I'm sorry, I'm having a brief technical difficulty. Could you please repeat that?"

        # Record the assistant's turn
        await self._ctx.add_turn(call_id, "assistant", reply, language_to_use)
        return (reply, language_to_use)

    async def generate_greeting(
        self,
        call_id: str,
        caller_number: str,
    ) -> tuple[str, str]:
        """Generate an opening greeting when the AI answers the call.

        Returns
        -------
        tuple[str, str]
            ``(greeting_text, language_code)`` — defaults to English until
            the caller's language is known.
        """
        if _DEV_MODE:
            logger.info("CallAssistant mock generate_greeting for call %s", call_id)
            greeting = "Hello! I'm an AI assistant. How can I help?"
            await self._ctx.add_turn(call_id, "assistant", greeting, "en-US")
            return (greeting, "en-US")

        ctx = await self._ctx.get_context(call_id) or {}
        user_name = ctx.get("user_name", "the owner")
        greeting = (
            f"Hello! This is {user_name}'s AI assistant. "
            "How may I help you today?"
        )

        system_prompt = self._build_system_prompt(ctx, "en-US")
        try:
            greeting = await self._call_claude(
                system_prompt=system_prompt,
                messages=[
                    {
                        "role": "user",
                        "content": (
                            f"[System: The phone just connected. The caller's number is "
                            f"{caller_number}. Generate a warm, concise opening greeting.]"
                        ),
                    }
                ],
                max_tokens=_MAX_TOKENS_RESPONSE,
            )
        except Exception as exc:
            logger.error("Greeting generation failed for call %s: %s", call_id, exc)
            # Keep the hardcoded greeting as fallback

        await self._ctx.add_turn(call_id, "assistant", greeting, "en-US")
        logger.info("Greeting generated for call %s", call_id)
        return (greeting, "en-US")

    async def generate_farewell(self, call_id: str) -> str:
        """Generate a polite goodbye in the call's detected language.

        Returns
        -------
        str
            Farewell text in the conversation's active language.
        """
        if _DEV_MODE:
            logger.info("CallAssistant mock generate_farewell for call %s", call_id)
            return "Thank you for calling. Goodbye!"

        ctx = await self._ctx.get_context(call_id) or {}
        language = ctx.get("detected_language", "en-US")
        language_name = self._lang.get_display_name(language)

        system_prompt = self._build_system_prompt(ctx, language)
        try:
            farewell = await self._call_claude(
                system_prompt=system_prompt,
                messages=[
                    {
                        "role": "user",
                        "content": (
                            f"[System: The call is ending. Generate a warm, brief farewell "
                            f"in {language_name}.]"
                        ),
                    }
                ],
                max_tokens=60,
            )
        except Exception as exc:
            logger.error("Farewell generation failed for call %s: %s", call_id, exc)
            farewell = "Thank you for calling. Goodbye!"

        await self._ctx.add_turn(call_id, "assistant", farewell, language)
        return farewell

    async def extract_actions(self, call_id: str) -> list[dict]:
        """Extract action items from the completed conversation.

        Prompts Claude with the full conversation history and parses the
        returned JSON array into a Python list.

        Returns
        -------
        list[dict]
            Each dict has keys: ``action_type``, ``title``, ``description``,
            ``datetime_str``, ``location``.
        """
        if _DEV_MODE:
            logger.info("CallAssistant mock extract_actions for call %s", call_id)
            return [
                {
                    "action_type": "meeting",
                    "title": "Mock meeting",
                    "description": "Caller requested a meeting",
                    "datetime_str": None,
                    "location": None,
                }
            ]

        history = await self._ctx.get_history(call_id)
        conversation_text = self._format_history_as_text(history)

        prompt = _ACTION_EXTRACTION_PROMPT.format(conversation_text=conversation_text)
        try:
            raw = await self._call_claude(
                system_prompt="You are an expert at extracting structured action items from conversations. Always respond with valid JSON only.",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=_MAX_TOKENS_EXTRACTION,
            )
            actions = self._parse_json_list(raw)
        except Exception as exc:
            logger.error("Action extraction failed for call %s: %s", call_id, exc)
            actions = []

        await self._ctx.set_extracted_actions(call_id, actions)
        logger.info("Extracted %d action(s) for call %s", len(actions), call_id)
        return actions

    async def generate_call_summary(
        self,
        call_id: str,
        history: list[dict],
    ) -> dict:
        """Produce a structured summary of the completed call.

        Parameters
        ----------
        call_id:
            Used for logging context.
        history:
            List of turn dicts (as returned by
            :meth:`ConversationContextManager.get_history`).

        Returns
        -------
        dict
            ``{"summary": str, "key_points": list[str], "extracted_actions": list[dict]}``
        """
        if _DEV_MODE:
            logger.info("CallAssistant mock generate_call_summary for call %s", call_id)
            return {
                "summary": "Mock call summary",
                "key_points": ["Point 1", "Point 2"],
                "extracted_actions": [],
            }

        conversation_text = self._format_history_as_text(history)
        prompt = _SUMMARY_PROMPT.format(conversation_text=conversation_text)

        try:
            raw = await self._call_claude(
                system_prompt="You are an expert at summarizing phone conversations. Always respond with valid JSON only.",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=_MAX_TOKENS_SUMMARY,
            )
            summary_dict = self._parse_json_dict(raw)
        except Exception as exc:
            logger.error("Summary generation failed for call %s: %s", call_id, exc)
            summary_dict = {
                "summary": "Call summary unavailable.",
                "key_points": [],
                "extracted_actions": [],
            }

        return summary_dict

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _build_system_prompt(self, ctx: dict, language_code: str) -> str:
        """Render the system prompt template with per-call context values."""
        user_name = ctx.get("user_name", "the owner")
        caller_number = ctx.get("caller_number", "an unknown caller")
        caller_name = ctx.get("caller_name") or caller_number
        language_name = self._lang.get_display_name(language_code)
        return _SYSTEM_PROMPT_TEMPLATE.format(
            user_name=user_name,
            caller_name_or_number=caller_name,
            language_name=language_name,
        )

    def _history_to_messages(self, history: list[dict]) -> list[dict[str, str]]:
        """Convert stored history turns into the Anthropic messages format.

        Consecutive messages with the same role are merged to satisfy the
        API requirement that roles alternate.
        """
        messages: list[dict[str, str]] = []
        for turn in history:
            role = "user" if turn.get("role") == "user" else "assistant"
            content = turn.get("text", "")
            if messages and messages[-1]["role"] == role:
                # Merge to avoid consecutive same-role messages
                messages[-1]["content"] += f"\n{content}"
            else:
                messages.append({"role": role, "content": content})
        return messages

    @staticmethod
    def _format_history_as_text(history: list[dict]) -> str:
        """Render conversation history as a plain-text transcript."""
        lines: list[str] = []
        for turn in history:
            role_label = "Caller" if turn.get("role") == "user" else "Assistant"
            lines.append(f"{role_label}: {turn.get('text', '')}")
        return "\n".join(lines)

    async def _call_claude(
        self,
        system_prompt: str,
        messages: list[dict],
        max_tokens: int,
    ) -> str:
        """Send a messages request to Claude and return the text reply.

        Raises on API error so callers can apply their own fallback logic.
        """
        if self._anthropic is None:
            raise RuntimeError("Anthropic client is not initialised.")

        if not messages:
            raise ValueError("messages list must not be empty.")

        response = await self._anthropic.messages.create(
            model=_MODEL,
            system=system_prompt,
            messages=messages,
            max_tokens=max_tokens,
        )
        # Extract the first text content block
        for block in response.content:
            if hasattr(block, "text"):
                return block.text.strip()
        return ""

    @staticmethod
    def _parse_json_list(raw: str) -> list:
        """Parse a JSON array from *raw*, returning ``[]`` on any error."""
        try:
            # Strip markdown code fences if Claude wrapped the output
            cleaned = raw.strip()
            if cleaned.startswith("```"):
                lines = cleaned.splitlines()
                # Drop first and last fence lines
                cleaned = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])
            result = json.loads(cleaned)
            if isinstance(result, list):
                return result
            logger.warning("Expected JSON array, got %s", type(result))
            return []
        except (json.JSONDecodeError, ValueError) as exc:
            logger.warning("JSON list parse failed: %s — raw: %s", exc, raw[:200])
            return []

    @staticmethod
    def _parse_json_dict(raw: str) -> dict:
        """Parse a JSON object from *raw*, returning a default dict on any error."""
        try:
            cleaned = raw.strip()
            if cleaned.startswith("```"):
                lines = cleaned.splitlines()
                cleaned = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])
            result = json.loads(cleaned)
            if isinstance(result, dict):
                return result
            logger.warning("Expected JSON object, got %s", type(result))
            return {}
        except (json.JSONDecodeError, ValueError) as exc:
            logger.warning("JSON dict parse failed: %s — raw: %s", exc, raw[:200])
            return {}
