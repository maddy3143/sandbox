FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# System deps for OpenCV, Open3D, etc.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libgomp1 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

# ── Production stage ──────────────────────────────────────────────────────────
FROM base AS production

COPY . .

RUN addgroup --system appgroup && adduser --system --group appuser
USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", \
     "--workers", "4", "--proxy-headers", "--forwarded-allow-ips", "*"]

# ── Development stage ─────────────────────────────────────────────────────────
FROM base AS development

COPY requirements.txt .
RUN pip install watchfiles pytest pytest-asyncio

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
