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

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
