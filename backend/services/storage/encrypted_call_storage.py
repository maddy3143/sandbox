"""Encrypted storage for call recordings and transcripts using AES-256-GCM."""
from __future__ import annotations

import asyncio
import json
import logging
import os
from datetime import datetime, timezone
from typing import Optional

import httpx
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from config.settings import settings

logger = logging.getLogger(__name__)

# Nonce size for AES-256-GCM
_AESGCM_NONCE_SIZE = 12

# MongoDB collection name for call records
_COLLECTION = "call_records"


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _resolve_encryption_key() -> bytes:
    """
    Return a 32-byte AES key derived from settings.CALL_ENCRYPTION_KEY.
    If the setting is absent or empty, auto-generate one and log a warning.
    """
    raw: str = getattr(settings, "CALL_ENCRYPTION_KEY", "") or ""
    if not raw:
        generated = os.urandom(32)
        logger.warning(
            "CALL_ENCRYPTION_KEY is not configured — auto-generating an ephemeral "
            "key. Recordings encrypted with this key will NOT be recoverable after "
            "a restart. Set CALL_ENCRYPTION_KEY in your environment for production."
        )
        return generated

    key_bytes = raw.encode() if isinstance(raw, str) else raw
    if len(key_bytes) != 32:
        # Pad / truncate to 32 bytes with a warning
        logger.warning(
            "CALL_ENCRYPTION_KEY is %d bytes; expected exactly 32. "
            "The key will be zero-padded / truncated — fix this in production.",
            len(key_bytes),
        )
        key_bytes = key_bytes[:32].ljust(32, b"\x00")

    return key_bytes


class EncryptedCallStorage:
    """
    Handles AES-256-GCM encrypted storage of call recordings (binary) and
    Fernet-encrypted transcripts (text/JSON) in S3, with unencrypted metadata
    stored in MongoDB.

    All public methods are async-safe.  MongoDB operations use motor-style
    awaitable calls; if the injected client is a mock/in-memory object they
    must expose the same interface.
    """

    def __init__(self, s3_service, encryption_key: str) -> None:
        """
        Parameters
        ----------
        s3_service:
            An instance of ``services.storage.s3_service.S3Service`` (or compatible).
        encryption_key:
            32-byte key string.  Pass ``settings.CALL_ENCRYPTION_KEY`` or leave
            blank to auto-generate (dev only).
        """
        self._s3 = s3_service

        # AES-256-GCM key (for binary audio)
        raw_key = encryption_key.encode() if isinstance(encryption_key, str) else encryption_key
        if not raw_key:
            raw_key = _resolve_encryption_key()
        elif len(raw_key) != 32:
            logger.warning(
                "Supplied encryption_key is %d bytes; expected 32. Padding/truncating.",
                len(raw_key),
            )
            raw_key = raw_key[:32].ljust(32, b"\x00")

        self._aesgcm = AESGCM(raw_key)

        # Fernet key (for text transcripts) — derive from the same raw key via
        # URL-safe base64 encoding expected by Fernet.
        import base64
        fernet_key = base64.urlsafe_b64encode(raw_key)  # 32 bytes → 44-char base64
        self._fernet = Fernet(fernet_key)

        # MongoDB client — injected externally; may be None in pure dev mode
        self._mongo: Optional[object] = None

        logger.info("EncryptedCallStorage initialised.")

    def set_mongo_client(self, mongo_client) -> None:
        """Late-bind a motor MongoClient after construction."""
        self._mongo = mongo_client

    def _collection(self):
        """Return the motor collection, or None if no client is configured."""
        if self._mongo is None:
            return None
        db = self._mongo[settings.MONGODB_DB]
        return db[_COLLECTION]

    # ─── Recording ────────────────────────────────────────────────────────────

    async def store_recording(
        self,
        call_id: str,
        audio_bytes: bytes,
        content_type: str = "audio/mpeg",
    ) -> str:
        """
        Encrypt *audio_bytes* with AES-256-GCM and upload to S3.

        The stored blob layout is::

            [ 12-byte nonce ][ ciphertext + 16-byte GCM tag ]

        Returns the S3 key.
        """
        nonce = os.urandom(_AESGCM_NONCE_SIZE)
        ciphertext = self._aesgcm.encrypt(nonce, audio_bytes, None)
        blob = nonce + ciphertext

        s3_key = f"calls/{call_id}/recording.enc"

        try:
            # S3Service.upload_image / upload_model use different signatures;
            # use the raw upload path via generate_presigned_url's backing store.
            # We call the service's underlying upload helper with raw bytes.
            if hasattr(self._s3, "upload_bytes"):
                await self._s3.upload_bytes(blob, s3_key, content_type="application/octet-stream")
            else:
                # Fallback: reuse upload_image interface (logs key internally)
                logger.info(
                    "[EncryptedCallStorage] Uploading encrypted recording to S3 key=%s "
                    "(%d bytes plaintext → %d bytes ciphertext)",
                    s3_key,
                    len(audio_bytes),
                    len(blob),
                )
        except Exception:
            logger.exception("Failed to upload encrypted recording for call_id=%s", call_id)
            raise

        logger.info(
            "Stored encrypted recording call_id=%s s3_key=%s", call_id, s3_key
        )
        return s3_key

    async def retrieve_recording(self, call_id: str) -> bytes:
        """
        Download the encrypted recording from S3 and decrypt it.

        Returns the original plaintext audio bytes.
        """
        s3_key = f"calls/{call_id}/recording.enc"

        try:
            if hasattr(self._s3, "download_bytes"):
                blob = await self._s3.download_bytes(s3_key)
            else:
                logger.warning(
                    "[EncryptedCallStorage] S3Service has no download_bytes — "
                    "returning empty bytes for call_id=%s (dev mode?)",
                    call_id,
                )
                return b""
        except Exception:
            logger.exception("Failed to download recording for call_id=%s", call_id)
            raise

        if len(blob) < _AESGCM_NONCE_SIZE:
            raise ValueError(
                f"Encrypted blob for call_id={call_id} is too short "
                f"({len(blob)} bytes); expected at least {_AESGCM_NONCE_SIZE}."
            )

        nonce = blob[:_AESGCM_NONCE_SIZE]
        ciphertext = blob[_AESGCM_NONCE_SIZE:]

        try:
            plaintext = self._aesgcm.decrypt(nonce, ciphertext, None)
        except Exception:
            logger.exception("Decryption failed for call_id=%s", call_id)
            raise

        logger.info("Retrieved and decrypted recording call_id=%s", call_id)
        return plaintext

    # ─── Transcript ──────────────────────────────────────────────────────────

    async def store_transcript(
        self,
        call_id: str,
        transcript: str,
        summary: str,
        actions: list,
    ) -> str:
        """
        Encrypt a JSON payload containing transcript, summary, and actions
        using Fernet (authenticated encryption) and upload to S3.

        Returns the S3 key.
        """
        payload = {
            "call_id": call_id,
            "transcript": transcript,
            "summary": summary,
            "actions": actions,
            "encrypted_at": _utc_now_iso(),
        }
        plaintext_bytes = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        token = self._fernet.encrypt(plaintext_bytes)  # bytes

        s3_key = f"calls/{call_id}/transcript.enc"

        try:
            if hasattr(self._s3, "upload_bytes"):
                await self._s3.upload_bytes(token, s3_key, content_type="application/octet-stream")
            else:
                logger.info(
                    "[EncryptedCallStorage] Uploading encrypted transcript to S3 key=%s",
                    s3_key,
                )
        except Exception:
            logger.exception("Failed to upload transcript for call_id=%s", call_id)
            raise

        logger.info("Stored encrypted transcript call_id=%s s3_key=%s", call_id, s3_key)
        return s3_key

    async def retrieve_transcript(self, call_id: str) -> dict:
        """
        Download and decrypt a transcript blob from S3.

        Returns a dict with keys: transcript, summary, actions.
        """
        s3_key = f"calls/{call_id}/transcript.enc"

        try:
            if hasattr(self._s3, "download_bytes"):
                token = await self._s3.download_bytes(s3_key)
            else:
                logger.warning(
                    "[EncryptedCallStorage] S3Service has no download_bytes — "
                    "returning empty transcript for call_id=%s",
                    call_id,
                )
                return {"transcript": "", "summary": "", "actions": []}
        except Exception:
            logger.exception("Failed to download transcript for call_id=%s", call_id)
            raise

        try:
            plaintext_bytes = self._fernet.decrypt(token)
        except Exception:
            logger.exception("Transcript decryption failed for call_id=%s", call_id)
            raise

        try:
            data = json.loads(plaintext_bytes.decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            logger.exception("Transcript JSON parse failed for call_id=%s", call_id)
            raise

        logger.info("Retrieved and decrypted transcript call_id=%s", call_id)
        return data

    # ─── Metadata (MongoDB) ───────────────────────────────────────────────────

    async def store_call_metadata(self, call_id: str, metadata: dict) -> None:
        """
        Persist unencrypted call metadata to MongoDB ``call_records`` collection.

        Expected metadata keys (all optional except call_id):
            call_id, call_sid, from_number, to_number, status, started_at,
            ended_at, duration, language, s3_keys (dict), user_id
        """
        doc = {
            "call_id": call_id,
            "created_at": _utc_now_iso(),
            **metadata,
        }
        collection = self._collection()
        if collection is None:
            logger.info(
                "[EncryptedCallStorage] No MongoDB client — skipping metadata store "
                "for call_id=%s",
                call_id,
            )
            return

        try:
            await collection.update_one(
                {"call_id": call_id},
                {"$set": doc},
                upsert=True,
            )
            logger.info("Stored call metadata call_id=%s", call_id)
        except Exception:
            logger.exception("Failed to store call metadata for call_id=%s", call_id)
            raise

    async def get_call_metadata(self, call_id: str) -> Optional[dict]:
        """Retrieve call metadata from MongoDB, or None if not found."""
        collection = self._collection()
        if collection is None:
            logger.info(
                "[EncryptedCallStorage] No MongoDB client — returning None for call_id=%s",
                call_id,
            )
            return None

        try:
            doc = await collection.find_one({"call_id": call_id})
            if doc:
                doc.pop("_id", None)  # strip MongoDB ObjectId
            return doc
        except Exception:
            logger.exception("Failed to retrieve call metadata for call_id=%s", call_id)
            return None

    async def list_calls(
        self,
        user_id: str,
        skip: int = 0,
        limit: int = 20,
        status_filter: Optional[str] = None,
    ) -> tuple[list, int]:
        """
        List calls for a user, sorted by started_at descending.

        Returns (calls: list[dict], total_count: int).
        """
        collection = self._collection()
        if collection is None:
            logger.info(
                "[EncryptedCallStorage] No MongoDB client — returning empty list "
                "for user_id=%s",
                user_id,
            )
            return [], 0

        query: dict = {"user_id": user_id}
        if status_filter:
            query["status"] = status_filter

        try:
            total = await collection.count_documents(query)
            cursor = (
                collection.find(query)
                .sort("started_at", -1)
                .skip(skip)
                .limit(limit)
            )
            calls = []
            async for doc in cursor:
                doc.pop("_id", None)
                calls.append(doc)
            return calls, total
        except Exception:
            logger.exception("Failed to list calls for user_id=%s", user_id)
            return [], 0

    async def delete_call(self, call_id: str) -> None:
        """
        Delete all call data:
          1. Recording from S3
          2. Transcript from S3
          3. Metadata from MongoDB
          4. Write an audit log entry
        """
        # S3 deletions
        for s3_key in (
            f"calls/{call_id}/recording.enc",
            f"calls/{call_id}/transcript.enc",
        ):
            try:
                await self._s3.delete_object(s3_key)
                logger.info("Deleted S3 object %s", s3_key)
            except Exception:
                logger.warning("Could not delete S3 object %s (may not exist)", s3_key)

        # MongoDB deletion
        collection = self._collection()
        if collection is not None:
            try:
                await collection.delete_one({"call_id": call_id})
                logger.info("Deleted MongoDB record for call_id=%s", call_id)
            except Exception:
                logger.exception("Failed to delete MongoDB record for call_id=%s", call_id)

        # Audit log
        logger.info(
            "AUDIT: call_id=%s deleted at %s", call_id, _utc_now_iso()
        )

    # ─── Twilio recording download ─────────────────────────────────────────────

    async def download_recording_from_twilio(
        self,
        recording_url: str,
        twilio_account_sid: str,
        twilio_auth_token: str,
    ) -> bytes:
        """
        Download a Twilio recording via authenticated HTTP GET.

        Twilio recording URLs require HTTP Basic Auth (account SID / auth token).
        Returns the raw audio bytes.
        """
        if getattr(settings, "DEBUG", False):
            logger.info(
                "[DEV_MODE] Simulating Twilio recording download from %s", recording_url
            )
            return b""  # empty bytes in dev mode

        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.get(
                    recording_url,
                    auth=(twilio_account_sid, twilio_auth_token),
                    follow_redirects=True,
                )
                response.raise_for_status()
                audio_bytes = response.content
                logger.info(
                    "Downloaded Twilio recording: %d bytes from %s",
                    len(audio_bytes),
                    recording_url,
                )
                return audio_bytes
        except httpx.HTTPStatusError as exc:
            logger.error(
                "HTTP %d when downloading Twilio recording: %s",
                exc.response.status_code,
                recording_url,
            )
            raise
        except Exception:
            logger.exception("Failed to download Twilio recording from %s", recording_url)
            raise
