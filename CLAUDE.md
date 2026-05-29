# CLAUDE.md — AR Object Scanner

This file provides guidance for AI assistants working in this codebase.

## Project Overview

**AR Object Scanner** is a full-stack AI application that transforms physical objects into interactive digital twins via smartphone scanning. It combines computer vision (YOLOv8), neural radiance fields (NeRF/3D Gaussian Splatting), and LLMs (Claude) to deliver engineering-grade diagnostics, repair guides, simulations, and a multilingual AI phone call assistant.

Core user flow: scan object → AI pipeline → 3D digital twin → diagnostics / repair guide / simulation / marketplace.

Secondary flow: incoming phone call → FCM push to mobile → user decision (answer / AI / decline) → Claude-powered multilingual conversation → transcript + action extraction.

---

## Repository Structure

```
sandbox/
├── backend/                          # FastAPI Python backend
│   ├── main.py                       # App entrypoint, router registration, startup
│   ├── config/settings.py            # All env-driven config (pydantic Settings, 51 keys)
│   ├── api/
│   │   ├── routes/                   # One file per feature domain
│   │   │   ├── scan.py               # POST /v1/scan — image upload + AI pipeline
│   │   │   ├── twin.py               # GET/POST /v1/twin — 3D model management
│   │   │   ├── assistant.py          # POST /v1/assistant — Claude chat + voice Q&A
│   │   │   ├── repair.py             # GET /v1/repair — repair guides
│   │   │   ├── diagnostics.py        # GET /v1/diagnostics — health scoring
│   │   │   ├── simulation.py         # POST /v1/simulation — physics engines
│   │   │   ├── collaboration.py      # WebSocket /v1/collaboration
│   │   │   ├── marketplace.py        # GET /v1/marketplace — parts + technicians
│   │   │   ├── gamification.py       # GET/POST /v1/gamification — XP + ranks
│   │   │   ├── calls.py              # POST/WS /v1/calls — Twilio AI call assistant
│   │   │   └── calendar_integration.py # GET/POST /v1/calendar — Google + Outlook
│   │   ├── middleware/auth.py         # JWT + Firebase auth, dev-mode bypass
│   │   └── schemas/
│   │       ├── scan_schemas.py        # Scan request/response models
│   │       ├── call_schemas.py        # CallRecord, CallStatus, CallDecision enums
│   │       └── calendar_schemas.py    # Calendar event models
│   ├── services/
│   │   ├── ai/                        # AI service wrappers (mock-capable)
│   │   │   ├── object_recognizer.py   # YOLOv8 + Google Vision + product KB
│   │   │   ├── digital_twin_generator.py
│   │   │   ├── measurement_estimator.py
│   │   │   ├── damage_detector.py
│   │   │   └── material_analyzer.py
│   │   ├── database/
│   │   │   ├── db.py                  # Async pools (PostgreSQL asyncpg + MongoDB motor)
│   │   │   └── scan_repository.py     # Data access layer
│   │   ├── cache/redis_cache.py       # Redis wrapper, call state TTL=2h
│   │   ├── storage/
│   │   │   ├── s3_service.py          # AWS S3 images/models
│   │   │   └── encrypted_call_storage.py # AES-256-GCM encrypted recordings
│   │   ├── telephony/
│   │   │   └── twilio_service.py      # TwiML generation, call state, history
│   │   ├── conversation/
│   │   │   ├── call_assistant.py      # Claude multilingual call driver (478 LOC)
│   │   │   └── context_manager.py
│   │   ├── speech/
│   │   │   ├── tts_service.py         # Google Cloud TTS
│   │   │   ├── stt_service.py         # Speech recognition
│   │   │   └── language_detector.py   # BCP-47 detection with fallback
│   │   ├── notifications/
│   │   │   └── fcm_service.py         # Firebase Cloud Messaging
│   │   ├── personalization/
│   │   │   └── user_profile_service.py
│   │   └── calendar/
│   │       ├── google_calendar_service.py
│   │       └── outlook_calendar_service.py
│   ├── tests/test_scan_api.py         # pytest integration tests (125 LOC)
│   ├── requirements.txt               # 71 dependencies
│   ├── Dockerfile
│   └── .env.example                   # Reference for all 68 env vars
├── ai_modules/                        # Standalone AI/ML modules (no backend imports)
│   ├── object_recognition/yolo_detector.py   # YOLOv8-seg, 80 COCO + 30 engineering classes
│   ├── reconstruction_3d/nerf_pipeline.py    # Instant-NGP / Gaussian Splatting
│   ├── measurement/depth_estimator.py        # Depth Anything V2
│   ├── simulation/physics_engine.py          # PyBullet + custom solvers
│   └── voice/__init__.py
├── flutter_app/                       # Flutter 3 mobile frontend
│   ├── lib/
│   │   ├── main.dart                  # App entry, Riverpod ProviderScope, go_router
│   │   ├── core/
│   │   │   ├── routing/app_router.dart
│   │   │   ├── theme/app_theme.dart
│   │   │   ├── constants/             # route_names.dart, api_constants.dart
│   │   │   └── services/              # api_service.dart, ar_service.dart, ai_service.dart,
│   │   │                              #   storage_service.dart, audio_service.dart
│   │   ├── features/
│   │   │   ├── scanner/               # Camera + capture pipeline
│   │   │   ├── digital_twin/          # 3D interactive viewer
│   │   │   ├── exploded_view/         # Part disassembly animation
│   │   │   ├── xray_mode/             # Internal structure visualization
│   │   │   ├── measurements/          # AR ruler & dimension overlays
│   │   │   ├── repair_guide/          # Step-by-step wizard
│   │   │   ├── diagnostics/           # Health scores + failure prediction
│   │   │   ├── marketplace/           # Parts search + nearby technicians
│   │   │   ├── ai_assistant/          # LLM chat + voice
│   │   │   ├── collaboration/         # Real-time multi-user AR sessions
│   │   │   ├── calls/                 # Incoming call UI (screens + controller + model)
│   │   │   └── gamification/          # XP, badges, leaderboard
│   │   ├── services/
│   │   │   ├── calendar_service.dart  # Google + Outlook OAuth2
│   │   │   └── notification_service.dart # FCM listener
│   │   └── shared/
│   │       ├── models/scanned_object.dart
│   │       └── widgets/               # glass_card, main_shell, holographic_button
│   ├── pubspec.yaml                   # 80 Dart dependencies
│   ├── android/                       # ARCore bridge, signing config
│   └── ios/Runner/                    # ARKit config
├── house_3d/index.html                # Standalone Three.js 3D house visualization demo
├── docker-compose.yml                 # 8-service local dev stack
├── .github/workflows/
│   └── build-apk.yml                  # CI: Flutter analyze + debug/release APK build
└── README.md
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend framework | FastAPI 0.111 (Python 3.12), async/await throughout |
| Object detection | YOLOv8-seg (ultralytics) |
| 3D reconstruction | Instant-NGP (NeRF) / 3D Gaussian Splatting |
| Depth estimation | Depth Anything V2 |
| LLM assistant | Claude (`claude-sonnet-4-6`) via Anthropic SDK |
| Speech-to-text | OpenAI Whisper + Google Cloud Speech |
| Text-to-speech | Google Cloud TTS |
| Telephony | Twilio (webhooks, TwiML, recordings) |
| Material analysis | Custom CNN |
| Primary DB | PostgreSQL 16 (asyncpg) — scan metadata, users |
| Document DB | MongoDB 7 (motor) — full object/twin documents, transcripts |
| Cache / queue | Redis 7 (LRU 256MB, TTL-based call state) + Celery workers |
| File storage | AWS S3 (images, 3D models, AES-256-GCM encrypted call recordings) |
| Auth | Firebase Auth + JWT (7-day expiry) |
| Push notifications | Firebase Cloud Messaging (FCM) |
| Calendar | Google Calendar + Microsoft Outlook OAuth2 |
| Mobile | Flutter 3, Riverpod, go_router, ARCore/ARKit, model_viewer_plus |
| 3D demo | Three.js (self-contained `house_3d/index.html`) |
| Monitoring | Prometheus + Grafana (optional Docker profile) |
| CI | GitHub Actions (Flutter APK build on push) |

---

## Development Setup

### Prerequisites
- Docker + Docker Compose
- Python 3.12 (for running backend locally without Docker)
- Flutter 3 SDK (for mobile development)
- GPU recommended for NeRF/Gaussian Splatting processing

### Start the full stack

```bash
docker compose up -d
```

Docker Compose services:
- `api` — FastAPI on http://localhost:8000 (hot-reload volumes)
- `worker` — Celery worker for async AI tasks (concurrency=2)
- `postgres` — PostgreSQL 16 on port 5432
- `mongo` — MongoDB 7 on port 27017
- `redis` — Redis 7 on port 6379 (LRU cache, 256MB max)
- `nerf_service` — GPU-enabled 3D reconstruction (`--profile gpu`)
- `prometheus` + `grafana` — Metrics & dashboards (`--profile monitoring`)

### API docs
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

### Environment variables

Copy `.env.example` to `.env` and fill in values. Key variable groups:

```
# Core
DATABASE_URL=postgresql+asyncpg://...
MONGODB_URL=mongodb://...
REDIS_URL=redis://localhost:6379
JWT_SECRET_KEY=...
DEV_MODE=true              # Bypasses auth + uses mock AI responses

# AI / LLM
ANTHROPIC_API_KEY=...      # Claude chat + call assistant
OPENAI_API_KEY=...         # Whisper STT

# Object detection / vision
GOOGLE_VISION_API_KEY=...

# Cloud storage
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
S3_BUCKET_NAME=...

# Call assistant
TWILIO_ACCOUNT_SID=...
TWILIO_AUTH_TOKEN=...
TWILIO_PHONE_NUMBER=...
GOOGLE_CLOUD_SPEECH_CREDENTIALS=...   # JSON path or inline
GOOGLE_CLOUD_TTS_CREDENTIALS=...
CALL_ENCRYPTION_KEY=...    # AES-256-GCM base64

# Auth + notifications
FIREBASE_PROJECT_ID=...
FCM_SERVER_KEY=...

# Calendar integrations
GOOGLE_CALENDAR_CLIENT_ID=...
GOOGLE_CALENDAR_CLIENT_SECRET=...
MICROSOFT_CLIENT_ID=...
MICROSOFT_CLIENT_SECRET=...
```

Full list of all 68 environment variables is in `backend/.env.example`.

### Running tests

```bash
cd backend
pytest tests/ -v
```

The test suite uses `httpx.AsyncClient` against the FastAPI app directly (no live services needed when `DEV_MODE=true`).

Test coverage in `backend/tests/test_scan_api.py`:
- `test_health_check` — /health endpoint
- `test_analyze_object` — image upload + AI pipeline response
- `test_analyze_invalid_format` — 400 on non-image
- `test_scan_history_empty` — paginated GET /history
- `test_get_scan_not_found` — 404 handling
- `test_chat_with_assistant` — async Claude chat
- `test_gamification_stats` — leaderboard endpoint
- `test_list_simulation_types` — physics sim types
- `test_marketplace_search` — parts search

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

**Mock-first AI services**: When `DEV_MODE=true`, all AI services return representative hardcoded responses. Real model inference only runs in production. Do not remove this pattern — it keeps dev fast without GPU hardware, and the call assistant uses it too.

**Knowledge base**: `main.py` contains `OBJECT_KNOWLEDGE_BASE` — a dict keyed by object category with full product specs, component breakdowns, and technical parameters. When adding new object types, add entries here first, then update the recognizer's category mappings.

**Route structure**: Each route file owns one domain. Routes call `services/` directly — no business logic in route handlers. Keep handlers thin.

**Auth middleware**: `api/middleware/auth.py` validates JWT tokens and Firebase auth. Set `DEV_MODE=true` to bypass auth during local development. Twilio webhook routes are intentionally auth-exempt — they are validated via Twilio signature instead. Never disable production auth code paths.

**Pydantic schemas**: All request bodies and responses use typed Pydantic models in `api/schemas/`. Add new schemas there, not inline in route files.

**Background tasks**: Long-running AI tasks (NeRF reconstruction) are dispatched to Celery. Use FastAPI `BackgroundTasks` only for lightweight fire-and-forget operations.

**Database access**: Go through `services/database/scan_repository.py` for all scan/object DB operations. Do not write raw SQL or MongoDB queries in route handlers.

**Call state**: The telephony system stores active call state in Redis (2h TTL) — not in the database. This includes call_sid, user_id, status, conversation history, and language code. The database (PostgreSQL/MongoDB) receives the permanent record only after a call completes.

### AI Modules (`ai_modules/`)

These are standalone implementations meant to be importable as library modules, separate from the FastAPI app. They do not import from `backend/`. Keep them decoupled.

- `yolo_detector.py` — `YOLOObjectDetector.detect(image)` / `detect_from_bytes(bytes)` → list of Detection (bbox, class, confidence, mask)
- `nerf_pipeline.py` — `NeRFPipeline.reconstruct_from_single_image()` / `reconstruct_from_video()` / `generate_exploded_model()`. Backends: `instant_ngp`, `gaussian_splatting`, `nerfacto`.
- `depth_estimator.py` — `DepthEstimator.estimate(image)` → normalized depth; `estimate_metric(image, ref_px, ref_cm)` → metric depth; `compute_object_dimensions(depth_map, mask)` → dict
- `physics_engine.py` — PyBullet + custom FEA solvers for five simulation types

### Call Assistant (`backend/api/routes/calls.py` + `services/conversation/call_assistant.py`)

The telephony system is the most complex subsystem (1034 LOC in routes, 478 LOC in assistant). Key design decisions:

- **Webhook flow**: Twilio calls back our `/v1/calls/webhook/*` endpoints. These routes bypass JWT auth — they are validated by `twilio_service.py` using Twilio's signature header.
- **Decision polling**: After an incoming call arrives, Twilio polls `/webhook/poll/{call_id}` until the mobile app POSTs a decision to `/{call_id}/decision`. The 30s decision timeout is configurable via `CALL_DECISION_TIMEOUT` in settings.
- **Conversation loop**: The `/webhook/gather/{call_id}` endpoint is called after each user utterance. It STTs the audio, sends to Claude (150 token limit per turn for low latency), TTS the response, and returns a new `<Gather>` TwiML.
- **Language switching**: `language_detector.py` detects the BCP-47 language code each turn. If it changes, `tts_service.py` and `stt_service.py` switch language mid-call.
- **Recordings**: Twilio uploads the recording; `/webhook/recording/{call_id}` downloads it, encrypts with AES-256-GCM, and stores in S3. The key is derived from `CALL_ENCRYPTION_KEY` in settings.
- **Action extraction**: After a call ends, `call_assistant.generate_call_summary()` uses Claude to extract structured actions (meetings, appointments, tasks) as JSON.

### Flutter App

State management uses **Riverpod** exclusively. Do not introduce `setState`, `Provider`, or `BLoC` patterns — the codebase uses `StateNotifierProvider` and `FutureProvider`.

Feature code lives under `lib/features/<feature_name>/`. Each feature has its own screen, controller/provider, and model files. Shared widgets go in `lib/shared/`.

Navigation uses `go_router` with named routes defined in `lib/core/constants/route_names.dart`.

The `calls` feature (`lib/features/calls/`) handles:
- FCM push notification for incoming calls (`notification_service.dart`)
- `IncomingCallScreen` — caller info + three decision buttons
- `CallHistoryScreen` / `CallDetailScreen` — browsing past calls + transcripts
- `CallsController` (Riverpod StateNotifier) — manages call state, history, summaries

### 3D Visualization (`house_3d/`)

`index.html` is a self-contained Three.js demo. It has no build step — open directly in a browser. Do not add npm/webpack tooling.

---

## API Route Summary

| Method | Path | Description |
|---|---|---|
| POST | `/v1/scan/analyze` | Upload image, run full AI pipeline, return analysis |
| GET | `/v1/scan/history` | Paginated user scan history |
| GET | `/v1/scan/{object_id}` | Retrieve specific scan |
| DELETE | `/v1/scan/{object_id}` | Remove scan |
| POST | `/v1/twin/generate` | Trigger 3D twin generation (quality: low/medium/high/ultra) |
| GET | `/v1/twin/{object_id}/model` | Retrieve GLB model URL |
| GET | `/v1/twin/{object_id}/components` | List identified parts |
| GET | `/v1/twin/{object_id}/exploded` | Exploded view offsets |
| GET | `/v1/twin/{object_id}/assembly` | Disassembly steps with tools + duration |
| GET | `/v1/twin/{object_id}/xray` | Internal layers (circuit, power, thermal, storage) |
| POST | `/v1/assistant/chat` | Text Q&A with Claude (full object context injected) |
| POST | `/v1/assistant/voice` | Audio query → Whisper transcription → chat |
| GET | `/v1/repair/{scan_id}` | Get repair guide for scanned object |
| GET | `/v1/diagnostics/{scan_id}` | Health score and failure predictions |
| POST | `/v1/simulation/run` | Run physics simulation |
| GET | `/v1/marketplace/parts` | Search compatible parts |
| GET | `/v1/marketplace/technicians` | Find nearby repair technicians |
| WS | `/v1/collaboration/session` | Real-time multi-user AR session |
| GET | `/v1/gamification/profile` | User XP, rank, achievements |
| POST | `/v1/gamification/action` | Record action, award XP |
| POST | `/v1/calls/webhook/incoming` | Twilio: incoming call arrives (no auth) |
| POST | `/v1/calls/webhook/poll/{call_id}` | Twilio: poll for user decision (no auth) |
| POST | `/v1/calls/webhook/gather/{call_id}` | Twilio: STT → Claude → TTS loop (no auth) |
| POST | `/v1/calls/webhook/status/{call_id}` | Twilio: call status change (no auth) |
| POST | `/v1/calls/webhook/recording/{call_id}` | Twilio: recording available (no auth) |
| POST | `/v1/calls/{call_id}/decision` | Mobile app: submit call handling decision |
| GET | `/v1/calls/history` | Paginated call records for user |
| GET | `/v1/calls/{call_id}` | Full call record + transcript |
| GET | `/v1/calls/{call_id}/summary` | AI-generated summary + extracted actions |
| POST | `/v1/calls/query` | Natural-language query over call history |
| DELETE | `/v1/calls/{call_id}` | Erase call + recording |
| GET | `/v1/calendar/...` | Google + Outlook calendar integration |

---

## CI / CD

GitHub Actions workflow (`.github/workflows/build-apk.yml`) builds Flutter APKs on pushes to `claude/ar-object-scanner-3UXyJ` or `main`:
1. Sets up Java 17 + Flutter 3.24.5
2. Runs `flutter analyze`
3. Builds debug APK
4. Builds release APK (split per ABI, `continue-on-error`)
5. Uploads artifacts (30-day retention)

There is no automated backend CI yet — add tests to `backend/tests/` and wire them into a workflow when needed.

---

## Gamification System

XP awards are defined in the route handler (`gamification.py`). Rank thresholds: 15 levels from Rookie (0 XP) through Legend (50,000 XP). When adding new user actions, add an entry to the XP table in `gamification.py` and document it in the API schema.

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

## 3D Reconstruction Quality Tiers

| Quality | Method | Time | Polygons | Use Case |
|---|---|---|---|---|
| `low` (fast) | Procedural template mesh | < 5s | ~1K | Live preview |
| `medium` (standard) | Photogrammetry multi-view | ~30s | ~8K | Quick share |
| `high` | NeRF (Instant-NGP) | 2–10 min | ~48K | Detailed inspection |
| `ultra` | 3D Gaussian Splatting | 10–30 min | ~148K | Export / CAD |

CAD export formats: STL, OBJ, STEP, IGES, 3MF. Blueprint exports: SVG, DXF, PDF.

---

## Important Notes for AI Assistants

- **Never add synchronous blocking I/O** in FastAPI route handlers or service methods.
- **Do not hardcode credentials**. All secrets come from environment variables via `config/settings.py`.
- **Preserve mock mode**. The `DEV_MODE` pattern is intentional throughout — don't inline real model calls without the guard. This applies to the call assistant as well.
- **Keep `ai_modules/` decoupled** from `backend/`. They share no imports.
- **The knowledge base in `main.py`** is the source of truth for object specifications. Extend it, don't bypass it.
- **Flutter state is Riverpod-only** — do not introduce other state management patterns.
- **`house_3d/index.html` has no build step** — keep it as a single self-contained file.
- **Twilio webhook routes are intentionally auth-exempt** — they use Twilio signature validation instead. Do not add JWT middleware to `/v1/calls/webhook/*` routes.
- **Call state lives in Redis, not the DB** — the database only gets the final record post-call. Don't query the DB for in-progress call state.
- **`calls.py` is 1034 LOC** — the largest file in the codebase. When editing, be precise about which webhook handler you're modifying to avoid unintended cross-contamination.
