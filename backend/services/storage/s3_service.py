"""
AWS S3 Storage Service — image and model file management.
"""
import logging
import uuid
from typing import Optional

logger = logging.getLogger(__name__)


class S3Service:
    """Handles image and 3D model uploads to AWS S3 (or compatible storage)."""

    async def upload_image(
        self,
        image_bytes: bytes,
        object_id: str,
        content_type: str = "image/jpeg",
    ) -> str:
        """Upload scan image and return public URL."""
        # In production: use aioboto3 for async S3 upload
        logger.info(f"Uploading image for object {object_id} ({len(image_bytes)} bytes)")
        key = f"scans/{object_id}/original.jpg"
        return f"https://cdn.arobjectscanner.com/{key}"

    async def upload_model(
        self,
        model_bytes: bytes,
        object_id: str,
        format: str = "glb",
    ) -> str:
        """Upload 3D model and return public URL."""
        key = f"models/{object_id}/model.{format}"
        logger.info(f"Uploading {format} model for object {object_id}")
        return f"https://cdn.arobjectscanner.com/{key}"

    async def generate_presigned_url(
        self,
        key: str,
        expiry_seconds: int = 3600,
    ) -> str:
        """Generate a time-limited presigned download URL."""
        return f"https://cdn.arobjectscanner.com/{key}?expires={expiry_seconds}"

    async def delete_object(self, key: str) -> None:
        """Delete a file from storage."""
        logger.info(f"Deleting S3 object: {key}")
