"""Language detector — identifies which of the 5 supported languages a text string is in."""
import logging
from typing import Optional

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Language metadata tables
# ---------------------------------------------------------------------------

# Maps our BCP-47 language codes → human-readable display names
LANGUAGE_DISPLAY_NAMES: dict[str, str] = {
    "te-IN": "Telugu",
    "hi-IN": "Hindi",
    "en-US": "English",
    "ar-XA": "Arabic",
    "kn-IN": "Kannada",
}

# Maps langdetect ISO 639-1 codes → our BCP-47 language codes
_LANGDETECT_TO_OURS: dict[str, str] = {
    "te": "te-IN",
    "hi": "hi-IN",
    "en": "en-US",
    "ar": "ar-XA",
    "kn": "kn-IN",
}

# Maps Twilio's language hint codes → Google Cloud BCP-47 codes
TWILIO_TO_GOOGLE_CODES: dict[str, str] = {
    "te-IN": "te-IN",
    "hi-IN": "hi-IN",
    "en-US": "en-US",
    "ar": "ar-XA",
    "ar-XA": "ar-XA",
    "kn-IN": "kn-IN",
    "en": "en-US",
}

# Maps our language codes → best available Google TTS voice name + SSML gender
GOOGLE_TTS_VOICES: dict[str, dict[str, str]] = {
    "te-IN": {
        "voice_name": "te-IN-Standard-A",
        "ssml_gender": "FEMALE",
    },
    "hi-IN": {
        "voice_name": "hi-IN-Neural2-A",
        "ssml_gender": "FEMALE",
    },
    "en-US": {
        "voice_name": "en-US-Neural2-F",
        "ssml_gender": "FEMALE",
    },
    "ar-XA": {
        "voice_name": "ar-XA-Neural2-A",
        "ssml_gender": "FEMALE",
    },
    "kn-IN": {
        "voice_name": "kn-IN-Standard-A",
        "ssml_gender": "FEMALE",
    },
}

_DEFAULT_LANGUAGE = "en-US"
_SUPPORTED_CODES = set(LANGUAGE_DISPLAY_NAMES.keys())


class LanguageDetector:
    """Identify which of the 5 supported languages a text snippet is written in."""

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def detect(self, text: str) -> str:
        """Return our BCP-47 language code for *text*.

        Falls back to ``"en-US"`` when detection fails or the identified
        language is not in the supported set.
        """
        if not text or not text.strip():
            return _DEFAULT_LANGUAGE

        try:
            from langdetect import detect as _detect, LangDetectException  # type: ignore

            raw_code: str = _detect(text)
            return _LANGDETECT_TO_OURS.get(raw_code, _DEFAULT_LANGUAGE)
        except Exception as exc:  # catches LangDetectException and ImportError alike
            logger.debug("Language detection failed: %s — defaulting to en-US", exc)
            return _DEFAULT_LANGUAGE

    def detect_with_confidence(self, text: str) -> tuple[str, float]:
        """Return ``(language_code, confidence)`` where confidence is in ``[0, 1]``.

        Uses langdetect's probability list to pick the best candidate.
        Falls back to ``("en-US", 0.0)`` on any failure.
        """
        if not text or not text.strip():
            return (_DEFAULT_LANGUAGE, 0.0)

        try:
            from langdetect import detect_langs as _detect_langs, LangDetectException  # type: ignore

            lang_probs = _detect_langs(text)  # list of Language objects with .lang / .prob
            for lang_prob in lang_probs:
                mapped = _LANGDETECT_TO_OURS.get(lang_prob.lang)
                if mapped:
                    return (mapped, round(float(lang_prob.prob), 4))

            # Top result exists but maps to an unsupported language — still return it
            # with its confidence so callers can inspect.
            top = lang_probs[0]
            return (_DEFAULT_LANGUAGE, round(float(top.prob), 4))

        except Exception as exc:
            logger.debug("detect_with_confidence failed: %s", exc)
            return (_DEFAULT_LANGUAGE, 0.0)

    def detect_language_switch(self, previous: str, current_text: str) -> bool:
        """Return ``True`` if *current_text* appears to be in a different language
        than *previous* (one of our BCP-47 codes).
        """
        detected = self.detect(current_text)
        return detected != previous

    def get_display_name(self, language_code: str) -> str:
        """Return the human-readable name for a BCP-47 *language_code*.

        Returns ``"English"`` for unknown codes.
        """
        return LANGUAGE_DISPLAY_NAMES.get(language_code, "English")

    def is_supported(self, language_code: str) -> bool:
        """Return ``True`` if *language_code* is in the supported set."""
        return language_code in _SUPPORTED_CODES
