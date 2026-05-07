"""
AR Object Scanner — FastAPI Backend
Entry point. All routes registered via routers.
"""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from api.routes import (
    scan_router,
    twin_router,
    assistant_router,
    repair_router,
    diagnostics_router,
    marketplace_router,
    collaboration_router,
    gamification_router,
    simulation_router,
)
from config.settings import settings
from services.database.db import init_db
from services.cache.redis_cache import init_cache
import logging

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting AR Object Scanner API...")
    await init_db()
    await init_cache()
    logger.info("Services initialized successfully.")
    yield
    logger.info("Shutting down AR Object Scanner API...")


app = FastAPI(
    title="AR Object Scanner API",
    description="AI-powered AR application backend for real-world object intelligence",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)

# Routers
app.include_router(scan_router, prefix="/v1/scan", tags=["Scanner"])
app.include_router(twin_router, prefix="/v1/twin", tags=["Digital Twin"])
app.include_router(assistant_router, prefix="/v1/assistant", tags=["AI Assistant"])
app.include_router(repair_router, prefix="/v1/repair", tags=["Repair Guide"])
app.include_router(diagnostics_router, prefix="/v1/diagnostics", tags=["Diagnostics"])
app.include_router(marketplace_router, prefix="/v1/marketplace", tags=["Marketplace"])
app.include_router(collaboration_router, prefix="/v1/collaboration", tags=["Collaboration"])
app.include_router(gamification_router, prefix="/v1/gamification", tags=["Gamification"])
app.include_router(simulation_router, prefix="/v1/simulation", tags=["Simulation"])


@app.get("/health")
async def health_check():
    return {"status": "healthy", "version": "1.0.0"}
