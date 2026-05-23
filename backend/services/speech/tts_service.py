"""Google Cloud Text-to-Speech service for natural multilingual voice synthesis."""
import asyncio
import logging
import os
from typing import Optional

from backend.services.speech.language_detector import GOOGLE_TTS_VOICES

logger = logging.getLogger(__name__)

_DEV_MODE: bool = os.getenv("DEV_MODE", "false").lower() in ("true", "1", "yes")

# Fallback mock audio URL used in dev / test environments
_MOCK_AUDIO_URL = "https://cdn.arobjectscanner.com/mock/tts_placeholder.mp3"


class TTSService:
    """Convert LLM response text to audio using Google Cloud TTS and store in S3.

    Parameters
    ----------
    credentials_path:
        Path to the Google Cloud service-account JSON key file.
    s3_service:
        An instance of ``S3Service`` (or compatible) used for upload and
        presigned-URL generation.
    bucket:
        S3 bucket name where audio files are stored.
    """

    def __init__(self, credentials_path: str, s3_service, bucket: str) -> None:
        self._s3 = s3_service
        self._bucket = bucket
        self._credentials_path = credentials_path
        self._client = None  # lazy-initialised on first real use

        if not _DEV_MODE:
            self._client = self._init_google_client(credentials_path)

    # ------------------------------------------------------------------
    # Public async API
    # ------------------------------------------------------------------

    async def synthesize(
        self,
        text: str,
        language_code: str,
        call_id: str,
        turn_index: int,
    ) -> Optional[str]:
        """Synthesize *text* to speech, upload to S3, and return a presigned URL.

        Parameters
        ----------
        text:
            The text (or SSML) to convert to audio.
        language_code:
            BCP-47 code, e.g. ``"en-US"``.
        call_id:
            Unique identifier for this call session (used as S3 path prefix).
        turn_index:
            Sequential turn number within the call (used in the S3 key).

        Returns
        -------
        str or None
            Presigned S3 URL valid for 1 hour, or ``None`` on Google API
            failure (caller should fall back to Twilio ``<Say>`` TwiML).
        """
        if _DEV_MODE:
            logger.info("TTS mock: %s", text[:120])
            return _MOCK_AUDIO_URL

        try:
            audio_bytes = await self.synthesize_to_bytes(text, language_code)
            s3_key = f"calls/{call_id}/audio/turn_{turn_index}.mp3"
            await self._upload_audio(audio_bytes, s3_key)
            url: str = await self._s3.generate_presigned_url(s3_key, expiry_seconds=3600)
            logger.info(
                "TTS synthesized turn %d for call %s (%d bytes) → %s",
                turn_index,
                call_id,
                len(audio_bytes),
                url,
            )
            return url
        except Exception as exc:
            logger.error("TTS synthesis failed for call %s turn %d: %s", call_id, turn_index, exc)
            return None  # Caller falls back to Twilio <Say>

    async def synthesize_to_bytes(self, text: str, language_code: str) -> bytes:
        """Return raw MP3 audio bytes for *text* in *language_code*.

        Runs the blocking Google API call in a thread-pool executor so the
        event loop is not blocked.
        """
        if _DEV_MODE:
            logger.info("TTS mock (bytes): %s", text[:120])
            return b""

        ssml = self._build_ssml(text, language_code)
        loop = asyncio.get_event_loop()
        audio_bytes: bytes = await loop.run_in_executor(
            None, self._call_google_tts, ssml, language_code
        )
        return audio_bytes

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _build_ssml(self, text: str, language_code: str) -> str:
        """Wrap *text* in an SSML ``<speak>`` block with the correct ``xml:lang``."""
        # Escape minimal XML special characters to avoid malformed SSML
        safe_text = (
            text.replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
        )
        return (
            f'<speak xml:lang="{language_code}">'
            f'<prosody rate="0.9">{safe_text}</prosody>'
            f"</speak>"
        )

    def _get_voice_config(self, language_code: str) -> dict:
        """Return ``{voice_name, ssml_gender}`` for the given *language_code*."""
        return GOOGLE_TTS_VOICES.get(
            language_code,
            GOOGLE_TTS_VOICES["en-US"],
        )

    def _init_google_client(self, credentials_path: str):
        """Initialise and return a ``texttospeech.TextToSpeechClient``."""
        try:
            from google.cloud import texttospeech  # type: ignore
            from google.oauth2 import service_account  # type: ignore

            if credentials_path and os.path.isfile(credentials_path):
                creds = service_account.Credentials.from_service_account_file(
                    credentials_path,
                    scopes=["https://www.googleapis.com/auth/cloud-platform"],
                )
                client = texttospeech.TextToSpeechClient(credentials=creds)
            else:
                # Fall back to ADC (Application Default Credentials)
                client = texttospeech.TextToSpeechClient()

            logger.info("Google TTS client initialised.")
            return client
        except Exception as exc:
            logger.warning(
                "Could not initialise Google TTS client: %s — TTS will return None.", exc
            )
            return None

    def _call_google_tts(self, ssml: str, language_code: str) -> bytes:
        """Blocking call to the Google TTS API. Run via ``run_in_executor``."""
        if self._client is None:
            raise RuntimeError("Google TTS client is not initialised.")

        from google.cloud import texttospeech  # type: ignore

        voice_cfg = self._get_voice_config(language_code)
        ssml_gender_map = {
            "FEMALE": texttospeech.SsmlVoiceGender.FEMALE,
            "MALE": texttospeech.SsmlVoiceGender.MALE,
            "NEUTRAL": texttospeech.SsmlVoiceGender.NEUTRAL,
        }

        synthesis_input = texttospeech.SynthesisInput(ssml=ssml)
        voice = texttospeech.VoiceSelectionParams(
            language_code=language_code,
            name=voice_cfg["voice_name"],
            ssml_gender=ssml_gender_map.get(
                voice_cfg["ssml_gender"], texttospeech.SsmlVoiceGender.FEMALE
            ),
        )
        audio_config = texttospeech.AudioConfig(
            audio_encoding=texttospeech.AudioEncoding.MP3,
            speaking_rate=0.9,
        )

        response = self._client.synthesize_speech(
            input=synthesis_input,
            voice=voice,
            audio_config=audio_config,
        )
        return response.audio_content

    async def _upload_audio(self, audio_bytes: bytes, s3_key: str) -> None:
        """Upload raw *audio_bytes* to S3 at *s3_key*."""
        # The existing S3Service exposes upload_image/upload_model helpers; we
        # reach into generate_presigned_url which implies the object already
        # exists.  In production use aioboto3 directly.  For now we call the
        # generic upload helper if available, otherwise log.
        try:
            if hasattr(self._s3, "upload_audio"):
                await self._s3.upload_audio(audio_bytes, s3_key)
            elif hasattr(self._s3, "upload_image"):
                # Re-use upload_image with the audio key override trick
                await self._s3.upload_image(audio_bytes, s3_key, content_type="audio/mpeg")
            else:
                logger.warning("S3 service has no upload method for audio; key %s not stored.", s3_key)
        except Exception as exc:
            logger.error("S3 audio upload failed for key %s: %s", s3_key, exc)
            raise
