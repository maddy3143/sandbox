# CLAUDE.md — AR Object Scanner

This file provides guidance for AI assistants working in this codebase.

## Project Overview

**AR Object Scanner** is a full-stack AI application that transforms physical objects into interactive digital twins via smartphone scanning. It combines computer vision (YOLOv8), neural radiance fields (NeRF/3D Gaussian Splatting), and LLMs (Claude) to deliver engineering-grade diagnostics, repair guides, and simulations.

Core user flow: scan object → AI pipeline → 3D digital twin → diagnostics / repair guide / simulation / marketplace.

---

## Repository Structure

```
sandbox/
├── backend/                   # FastAPI Python backend
│   ├── main.py                # App entrypoint, router registration, startup
│   ├── config/settings.py     # All env-driven configuration (pydantic Settings)
│   ├── api/
│   │   ├── routes/            # One file per feature domain
│   │   │   ├── scan.py        # POST /v1/scan — main image upload + AI pipeline
│   │   │   ├── twin.py        # GET/POST /v1/twin — 3D model management
│   │   │   ├── repair.py      # GET /v1/repair — repair guides
│   │   │   ├── diagnostics.py # GET /v1/diagnostics — health scoring
│   │   │   ├── simulation.py  # POST /v1/simulation — physics engines
│   │   │   ├── collaboration.py # WebSocket /v1/collaboration
│   │   │   ├── marketplace.py # GET /v1/marketplace — parts + technicians
│   │   │   └── gamification.py # GET/POST /v1/gamification — XP + ranks
│   │   ├── middleware/auth.py # JWT + Firebase auth, dev-mode bypass
│   │   └── schemas/           # Pydantic request/response models
│   ├── services/
│   │   ├── ai/                # AI service wrappers (mock-capable)
│   │   │   ├── damage_detector.py
│   │   │   ├── digital_twin_generator.py
│   │   │   ├── measurement_estimator.py
│   │   │   ├── object_recognizer.py
│   │   │   └── material_analyzer.py
│   │   ├── database/
│   │   │   ├── db.py          # Async connection pools (PostgreSQL + MongoDB)
│   │   │   └── scan_repository.py # Data access layer
│   │   ├── cache/redis_cache.py   # Redis wrapper
│   │   └── storage/s3_service.py  # AWS S3 operations
│   ├── tests/test_scan_api.py # pytest integration tests
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .env.example           # Reference for all required env vars
├── ai_modules/                # Standalone AI/ML module implementations
│   ├── object_recognition/yolo_detector.py   # YOLOv8 wrapper
│   ├── reconstruction_3d/nerf_pipeline.py    # NeRF / Gaussian Splatting pipeline
│   ├── measurement/depth_estimator.py        # Depth Anything V2
│   └── simulation/physics_engine.py          # Gear, airflow, stress, piston engines
├── flutter_app/               # Flutter 3 mobile frontend
│   ├── lib/main.dart          # App entry, Riverpod providers, routing
│   ├── pubspec.yaml           # Dart dependencies
│   └── android/               # Android-specific configs + ARCore bridge
├── house_3d/index.html        # Standalone Three.js 3D house visualization demo
├── docker-compose.yml         # Full local dev stack
├── .github/workflows/
│   └── build-apk.yml          # CI: Android APK build via GitHub Actions
└── README.md
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend framework | FastAPI (Python 3.12), async/await throughout |
| Object detection | YOLOv8 (ultralytics) |
| 3D reconstruction | Instant-NGP (NeRF) / 3D Gaussian Splatting |
| Depth estimation | Depth Anything V2 |
| LLM assistant | Claude (`claude-sonnet-4-6`) via Anthropic SDK |
| Speech-to-text | OpenAI Whisper |
| Material analysis | Custom CNN |
| Primary DB | PostgreSQL (asyncpg) — scan metadata, users |
| Document DB | MongoDB (motor) — full object/twin documents |
| Cache / queue | Redis (aioredis) + Celery workers |
| File storage | AWS S3 |
| Auth | Firebase + JWT |
| Mobile | Flutter 3, Riverpod, ARCore/ARKit, model_viewer_plus |
| Monitoring | Prometheus + Grafana |
| CI | GitHub Actions |

---

## Development Setup

### Prerequisites
- Docker + Docker Compose
- Python 3.12 (for running backend locally without Docker)
- Flutter 3 SDK (for mobile development)
- GPU recommended for NeRF processing

### Start the full stack

```bash
docker compose up -d
```

Services started:
- `backend` — FastAPI on http://localhost:8000
- `postgres` — PostgreSQL on port 5432
- `mongodb` — MongoDB on port 27017
- `redis` — Redis on port 6379
- `celery_worker` — Background AI task processor
- `prometheus` / `grafana` — Monitoring

### API docs
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

### Environment variables

Copy `.env.example` to `.env` and fill in values. Key variables:

```
DATABASE_URL=postgresql+asyncpg://...
MONGODB_URL=mongodb://...
REDIS_URL=redis://localhost:6379
AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / S3_BUCKET_NAME
ANTHROPIC_API_KEY          # Claude LLM
FIREBASE_PROJECT_ID
JWT_SECRET_KEY
DEV_MODE=true              # Bypasses auth + uses mock AI responses
```

### Running tests

```bash
cd backend
pytest tests/ -v
```

The test suite uses `httpx.AsyncClient` against the FastAPI app directly (no live services needed in dev mode).

### Flutter development

```bash
cd flutter_app
flutter pub get
flutter run
```

---

## Key Conventions

### Backend

**Async-first**: All I/O — database queries, HTTP calls, file uploads — must use `async/await`. Never use synchronous blocking calls in route handlers.

**Mock-first AI services**: In `DEV_MODE=true`, all AI services return representative hardcoded responses. Real model inference only runs in production. This keeps dev fast without GPU hardware. Do not remove this pattern.

**Knowledge base**: `main.py` contains `OBJECT_KNOWLEDGE_BASE` — a dict keyed by object category with full product specs, component breakdowns, and technical parameters. When adding new object types, add entries here first, then update the recognizer's category mappings.

**Route structure**: Each route file owns one domain. Routes call `services/` directly — no business logic in route handlers. Keep handlers thin.

**Auth middleware**: `api/middleware/auth.py` validates JWT tokens. Set `DEV_MODE=true` to bypass auth during local development. Never disable auth in production code paths.

**Pydantic schemas**: All request bodies and responses use typed Pydantic models in `api/schemas/`. Add new schemas there, not inline in route files.

**Background tasks**: Long-running AI tasks (NeRF reconstruction) are dispatched to Celery. Use `BackgroundTasks` only for lightweight fire-and-forget operations.

**Database access**: Go through `services/database/scan_repository.py` for all DB operations. Do not write raw SQL or MongoDB queries in route handlers.

### AI Modules (`ai_modules/`)

These are standalone implementations meant to be importable as library modules, separate from the FastAPI app. They do not import from `backend/`. Keep them decoupled.

### Flutter App

State management uses **Riverpod** exclusively. Do not introduce `setState`, `Provider`, or `BLoC` patterns — the codebase uses `StateNotifierProvider` and `FutureProvider`.

Feature code lives under `lib/features/<feature_name>/`. Each feature has its own screen, controller, and model files. Shared widgets go in `lib/shared/`.

### 3D Visualization (`house_3d/`)

`index.html` is a self-contained Three.js demo. It has no build step — open directly in a browser. Do not add npm/webpack tooling.

---

## API Route Summary

| Method | Path | Description |
|---|---|---|
| POST | `/v1/scan` | Upload image, run full AI pipeline, return analysis |
| GET | `/v1/twin/{scan_id}` | Retrieve 3D twin model data |
| POST | `/v1/twin/exploded-view` | Generate exploded component view |
| GET | `/v1/repair/{scan_id}` | Get repair guide for scanned object |
| GET | `/v1/diagnostics/{scan_id}` | Health score and failure predictions |
| POST | `/v1/simulation/run` | Run physics simulation (gear/airflow/stress/piston/thermal) |
| GET | `/v1/marketplace/parts` | Search compatible parts |
| GET | `/v1/marketplace/technicians` | Find nearby repair technicians |
| WS | `/v1/collaboration/session` | Real-time multi-user AR session |
| GET | `/v1/gamification/profile` | User XP, rank, achievements |
| POST | `/v1/gamification/action` | Record action, award XP |

---

## CI / CD

GitHub Actions workflow (`.github/workflows/build-apk.yml`) builds an Android APK on every push. The workflow:
1. Sets up Flutter
2. Runs `flutter pub get`
3. Builds release APK
4. Uploads as a workflow artifact

There is no automated backend CI yet — add tests to `backend/tests/` and wire them into a workflow if needed.

---

## Gamification System

XP awards are defined in the route handler. Rank thresholds: 15 levels from Rookie (0 XP) through Legend (50,000 XP). When adding new user actions, add an entry to the XP table in `gamification.py` and document it in the API schema.

---

## Simulation Types

The physics engine (`ai_modules/simulation/physics_engine.py`) supports:
- `gear_rotation` — torque, angular velocity, gear ratios
- `airflow` — pressure, velocity, flow rate
- `piston_cycle` — stroke analysis, compression ratio
- `stress_analysis` — yield strength, safety factor
- `thermal_analysis` — heat transfer, temperature gradients

Add new simulation types by subclassing the base engine and registering the type string in the router.

---

## Important Notes for AI Assistants

- **Never add synchronous blocking I/O** in FastAPI route handlers or service methods.
- **Do not hardcode credentials**. All secrets come from environment variables via `config/settings.py`.
- **Preserve mock mode**. The `DEV_MODE` pattern is intentional — don't inline real model calls without the guard.
- **Keep `ai_modules/` decoupled** from `backend/`. They share no imports.
- **The knowledge base in `main.py`** is the source of truth for object specifications. Extend it, don't bypass it.
- **Flutter state is Riverpod-only** — do not introduce other state management patterns.
- **`house_3d/index.html` has no build step** — keep it as a single self-contained file.
