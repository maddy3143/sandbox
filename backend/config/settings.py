from pydantic_settings import BaseSettings
from typing import List
import os


class Settings(BaseSettings):
    # App
    APP_NAME: str = "AR Object Scanner API"
    DEBUG: bool = False
    SECRET_KEY: str = os.getenv("SECRET_KEY", "dev-secret-change-in-production")

    # Database
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "postgresql+asyncpg://postgres:postgres@localhost:5432/ar_scanner",
    )
    MONGODB_URL: str = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
    MONGODB_DB: str = "ar_scanner"

    # Redis
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379")
    CACHE_TTL: int = 3600  # 1 hour

    # Firebase
    FIREBASE_PROJECT_ID: str = os.getenv("FIREBASE_PROJECT_ID", "")
    FIREBASE_CREDENTIALS_PATH: str = os.getenv("FIREBASE_CREDENTIALS_PATH", "")

    # AWS S3
    AWS_ACCESS_KEY_ID: str = os.getenv("AWS_ACCESS_KEY_ID", "")
    AWS_SECRET_ACCESS_KEY: str = os.getenv("AWS_SECRET_ACCESS_KEY", "")
    AWS_BUCKET_NAME: str = os.getenv("AWS_BUCKET_NAME", "ar-scanner-models")
    AWS_REGION: str = os.getenv("AWS_REGION", "us-east-1")

    # AI/ML Services
    OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "")
    ANTHROPIC_API_KEY: str = os.getenv("ANTHROPIC_API_KEY", "")
    GOOGLE_VISION_API_KEY: str = os.getenv("GOOGLE_VISION_API_KEY", "")

    # NeRF / 3D Reconstruction
    NERF_SERVICE_URL: str = os.getenv("NERF_SERVICE_URL", "http://nerf-service:8001")
    GAUSSIAN_SPLATTING_URL: str = os.getenv(
        "GAUSSIAN_SPLATTING_URL", "http://gaussian-service:8002"
    )

    # JWT
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    # CORS
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost:3000",
        "https://app.arobjectscanner.com",
    ]

    # Rate Limiting
    RATE_LIMIT_PER_MINUTE: int = 60
    RATE_LIMIT_SCAN_PER_HOUR: int = 100

    # Model paths
    YOLO_MODEL_PATH: str = "models/yolov8_objects.pt"
    MATERIAL_MODEL_PATH: str = "models/material_classifier.pt"
    DAMAGE_MODEL_PATH: str = "models/damage_detector.pt"
    DEPTH_MODEL_PATH: str = "models/depth_estimator.pt"

    # ── Call Assistant ────────────────────────────────────────────────────────
    # Twilio
    TWILIO_ACCOUNT_SID: str = os.getenv("TWILIO_ACCOUNT_SID", "")
    TWILIO_AUTH_TOKEN: str = os.getenv("TWILIO_AUTH_TOKEN", "")
    TWILIO_PHONE_NUMBER: str = os.getenv("TWILIO_PHONE_NUMBER", "")

    # Google Cloud (Speech + TTS)
    GOOGLE_APPLICATION_CREDENTIALS: str = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "")
    GOOGLE_STT_CREDENTIALS_PATH: str = os.getenv("GOOGLE_STT_CREDENTIALS_PATH", "")
    GOOGLE_TTS_CREDENTIALS_PATH: str = os.getenv("GOOGLE_TTS_CREDENTIALS_PATH", "")

    # FCM / Firebase Cloud Messaging
    FCM_CREDENTIALS_PATH: str = os.getenv("FCM_CREDENTIALS_PATH", "")

    # Call encryption (AES-256, must be exactly 32 bytes when base64-decoded)
    CALL_ENCRYPTION_KEY: str = os.getenv("CALL_ENCRYPTION_KEY", "")

    # Google Calendar OAuth
    GOOGLE_CALENDAR_CLIENT_ID: str = os.getenv("GOOGLE_CALENDAR_CLIENT_ID", "")
    GOOGLE_CALENDAR_CLIENT_SECRET: str = os.getenv("GOOGLE_CALENDAR_CLIENT_SECRET", "")
    GOOGLE_CALENDAR_REDIRECT_URI: str = os.getenv(
        "GOOGLE_CALENDAR_REDIRECT_URI", "http://localhost:8000/v1/calendar/auth/google/callback"
    )

    # Microsoft Graph / Outlook Calendar OAuth
    OUTLOOK_CLIENT_ID: str = os.getenv("OUTLOOK_CLIENT_ID", "")
    OUTLOOK_CLIENT_SECRET: str = os.getenv("OUTLOOK_CLIENT_SECRET", "")
    OUTLOOK_TENANT_ID: str = os.getenv("OUTLOOK_TENANT_ID", "common")
    OUTLOOK_REDIRECT_URI: str = os.getenv(
        "OUTLOOK_REDIRECT_URI", "http://localhost:8000/v1/calendar/auth/outlook/callback"
    )

    # Call assistant settings
    CALL_DECISION_TIMEOUT_SECONDS: int = int(os.getenv("CALL_DECISION_TIMEOUT_SECONDS", "30"))
    CALL_MAX_DURATION_SECONDS: int = int(os.getenv("CALL_MAX_DURATION_SECONDS", "600"))
    CALL_RECORDINGS_S3_PREFIX: str = "calls"

    # Dev mode (bypasses auth and uses mock AI responses)
    DEV_MODE: bool = os.getenv("DEV_MODE", "false").lower() == "true"

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
