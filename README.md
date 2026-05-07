# AR Object Scanner — AI-Powered Digital Twin Platform

> **Point your camera at any real-world object → instantly unlock its complete digital intelligence.**

---

## Overview

AR Object Scanner is a full-stack AI application that transforms any physical object into an interactive **Digital Twin** in seconds. Using a combination of computer vision, neural radiance fields, and large language models, the app delivers engineering-grade insights about any object you scan — from a laptop motherboard to a car engine.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Flutter Mobile App                          │
│  Scanner │ Digital Twin │ X-Ray │ Repair │ AI Chat │ Marketplace    │
└────────────────────────────┬────────────────────────────────────────┘
                             │  HTTPS / WebSocket
┌────────────────────────────▼────────────────────────────────────────┐
│                      FastAPI Backend (Python)                        │
│  /scan  /twin  /assistant  /repair  /diagnostics  /simulation       │
└──────┬───────────┬──────────────┬──────────────┬────────────────────┘
       │           │              │              │
  PostgreSQL   MongoDB        Redis         Celery Workers
  (metadata)  (objects)      (cache)       (AI tasks)
       │                                        │
       └────────────────────────────────────────┤
                                                │
                              ┌─────────────────▼──────────────────┐
                              │         AI / ML Services            │
                              │  YOLOv8 │ NeRF │ Claude │ Whisper  │
                              │  Depth Anything V2 │ Material CNN  │
                              └────────────────────────────────────┘
```

---

## Feature Map

| Feature | Technology |
|---|---|
| Object Recognition | YOLOv8-seg + Google Vision API |
| 3D Digital Twin | NeRF (Instant-NGP) / Gaussian Splatting |
| Exploded View | Procedural mesh segmentation |
| Measurements | Depth Anything V2 + reference calibration |
| X-Ray / Internal Structure | Component segmentation + depth compositing |
| AI Assistant | Claude (claude-sonnet-4-6) with full object context |
| Voice Interface | Whisper ASR + Flutter TTS |
| Repair Guides | LLM-generated step-by-step procedures |
| Damage Detection | Fine-tuned YOLOv8 defect model |
| Physics Simulation | PyBullet / custom Navier-Stokes solver |
| AR Overlays | ARCore (Android) + ARKit (iOS) native bridge |
| Parts Marketplace | Multi-vendor compatibility search |
| Real-time Collaboration | WebSocket sessions with AR sync |
| Gamification | XP, levels, achievements, leaderboard |

---

## Project Structure

```
ar-object-scanner/
├── flutter_app/                  # Flutter mobile frontend
│   ├── lib/
│   │   ├── core/                 # Theme, routing, services, constants
│   │   ├── features/             # One folder per app feature
│   │   │   ├── scanner/          # Camera + AI scan pipeline
│   │   │   ├── digital_twin/     # 3D interactive model viewer
│   │   │   ├── exploded_view/    # Part disassembly animation
│   │   │   ├── measurements/     # AR ruler & dimension display
│   │   │   ├── xray_mode/        # Internal structure visualisation
│   │   │   ├── ai_assistant/     # LLM chat + voice interface
│   │   │   ├── repair_guide/     # Step-by-step repair wizard
│   │   │   ├── diagnostics/      # Health score + failure prediction
│   │   │   ├── marketplace/      # Parts search + technician finder
│   │   │   ├── collaboration/    # Real-time AR sessions
│   │   │   └── gamification/     # XP, badges, leaderboard
│   │   └── shared/               # Reusable widgets and models
│   ├── android/                  # ARCore native bridge (Kotlin)
│   └── ios/                      # ARKit native bridge (Swift)
│
├── backend/                      # FastAPI Python backend
│   ├── api/
│   │   ├── routes/               # One file per feature domain
│   │   ├── schemas/              # Pydantic request/response models
│   │   └── middleware/           # Auth, rate limiting, logging
│   ├── services/
│   │   ├── ai/                   # Object recognition, material analysis,
│   │   │                         # damage detection, twin generation
│   │   ├── database/             # PostgreSQL + MongoDB repositories
│   │   ├── storage/              # AWS S3 image/model storage
│   │   └── cache/                # Redis caching layer
│   ├── config/                   # Settings, environment management
│   ├── tests/                    # pytest integration tests
│   ├── requirements.txt
│   └── Dockerfile
│
├── ai_modules/                   # Standalone ML pipeline modules
│   ├── object_recognition/       # YOLOv8 detector + class mappings
│   ├── reconstruction_3d/        # NeRF + Gaussian Splatting pipeline
│   ├── measurement/              # Depth Anything V2 estimator
│   ├── simulation/               # Physics engine (gears, airflow, FEA)
│   └── diagnostics/              # Damage detector
│
├── docs/                         # Architecture diagrams + API docs
├── docker-compose.yml            # Full stack local development
└── README.md
```

---

## Quick Start

### Prerequisites
- Flutter 3.22+ / Dart 3.4+
- Python 3.12+
- Docker & Docker Compose
- Android Studio (for ARCore) / Xcode 15+ (for ARKit)

### 1. Clone and configure

```bash
git clone https://github.com/maddy3143/sandbox.git
cd sandbox
cp backend/.env.example backend/.env
# Edit backend/.env with your API keys
```

### 2. Start backend services

```bash
docker compose up -d
# API available at http://localhost:8000
# Swagger docs at http://localhost:8000/docs
```

### 3. Run Flutter app

```bash
cd flutter_app
flutter pub get
flutter run
```

### 4. Run tests

```bash
# Backend
cd backend && pytest tests/ -v

# Flutter
cd flutter_app && flutter test
```

---

## API Reference

Base URL: `http://localhost:8000/v1`

| Endpoint | Method | Description |
|---|---|---|
| `/scan/analyze` | POST | Upload image → full AI analysis |
| `/scan/history` | GET | Paginated scan history |
| `/twin/generate` | POST | Start 3D twin generation |
| `/twin/{id}/exploded` | GET | Exploded view configuration |
| `/twin/{id}/xray` | GET | Internal layer data |
| `/assistant/chat` | POST | AI chat with object context |
| `/assistant/voice` | POST | Voice query (audio upload) |
| `/repair/{id}/guide` | GET | Step-by-step repair guide |
| `/diagnostics/damage` | POST | Damage detection from image |
| `/diagnostics/{id}/predict` | GET | Failure prediction |
| `/marketplace/search` | GET | Compatible parts search |
| `/collaboration/session` | POST | Create AR session |
| `/simulation/run` | POST | Run physics simulation |
| `/gamification/stats` | GET | User XP and achievements |

Full interactive docs: `http://localhost:8000/docs`

---

## Technology Stack

| Layer | Technology |
|---|---|
| Mobile Frontend | Flutter 3 + Riverpod + go_router |
| AR (Android) | ARCore + Sceneform (Kotlin) |
| AR (iOS) | ARKit + RealityKit (Swift) |
| 3D Rendering | ModelViewer Plus + custom GL shaders |
| Backend | FastAPI + Uvicorn |
| AI Recognition | YOLOv8 (Ultralytics) + Google Vision |
| AI Assistant | Anthropic Claude (claude-sonnet-4-6) |
| Speech | OpenAI Whisper (STT) + Flutter TTS |
| 3D Reconstruction | Instant-NGP / 3D Gaussian Splatting |
| Depth Estimation | Depth Anything V2 |
| Physics | PyBullet + custom Navier-Stokes |
| Primary DB | PostgreSQL (asyncpg) |
| Document DB | MongoDB (motor) |
| Cache / Queue | Redis + Celery |
| Storage | AWS S3 |
| Auth | Firebase Auth + JWT |
| Monitoring | Prometheus + Grafana |
| Container | Docker + Docker Compose |

---

## Potential Industries

- **Engineering Education** — Interactive 3D learning for students
- **Automobile Service** — Remote diagnostics and repair guidance
- **Industrial Maintenance** — Factory floor AR assistance
- **Manufacturing** — Assembly training and quality control
- **Consumer Electronics** — DIY repair and upgrade guide
- **Aerospace Training** — Component-level inspection training
- **Medical Equipment** — Maintenance and calibration support
- **E-commerce** — AR product visualisation before purchase

---

## Roadmap

- [ ] Spatial computing support (Apple Vision Pro, Meta Quest)
- [ ] AI predictive maintenance with IoT sensor integration
- [ ] Full-scale holographic projection mode
- [ ] CAD export (STEP, IGES) from scanned models
- [ ] Enterprise multi-site collaboration hub
- [ ] Offline-first mode with on-device LLM (Gemma 2)
- [ ] Manufacturing process simulation
- [ ] Patent and technical database integration
