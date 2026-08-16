# 🏗️ Tourist Safety — Architecture Guide

## Overview

The Tourist Safety app follows a **modular architecture** where each feature is an isolated module with clearly defined interfaces. Modules communicate only through the shared `core/` layer — never by reaching into each other's internals.

```
┌──────────────────────────────────────────────────────┐
│                    Mobile App (Flutter)                │
│  ┌─────────────────────────────────────────────────┐  │
│  │              Presentation Layer                  │  │
│  │  (Screens, Widgets, Navigation — GoRouter)       │  │
│  └──────────────────┬──────────────────────────────┘  │
│                     │                                  │
│  ┌──────────────────▼──────────────────────────────┐  │
│  │           Module Layer (Feature Modules)         │  │
│  │  ┌─────────┐ ┌──────────┐ ┌─────────────────┐  │  │
│  │  │SOS Core │ │ Live     │ │ BLE Mesh        │  │  │
│  │  │         │ │ Tracking │ │ (Phase 2)       │  │  │
│  │  └────┬────┘ └────┬─────┘ └────┬────────────┘  │  │
│  │  ┌────┴────┐ ┌────┴─────┐ ┌────┴────────────┐  │  │
│  │  │Duress UI│ │Passive   │ │Threat Intel     │  │  │
│  │  │(Ph. 2)  │ │Detection │ │(Phase 2)        │  │  │
│  │  └────┬────┘ │(Phase 2) │ └────┬────────────┘  │  │
│  │       │      └────┬─────┘ ┌────┴────────────┐  │  │
│  │       │           │       │Safe Nav / Buddy  │  │  │
│  │       │           │       │(Phase 2)         │  │  │
│  │       │           │       └─────────────────┘   │  │
│  └───────┴───────────┴─────────────────────────────┘  │
│                     │                                  │
│  ┌──────────────────▼──────────────────────────────┐  │
│  │             Core Layer (Shared)                  │  │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────────┐  │  │
│  │  │ Location  │ │ Encryption│ │ Local Queue   │  │  │
│  │  │ Service   │ │ Service   │ │ Service       │  │  │
│  │  └───────────┘ └───────────┘ └───────────────┘  │  │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────────┐  │  │
│  │  │ Network   │ │ Auth      │ │ Permissions   │  │  │
│  │  │ Service   │ │ Service   │ │ Service       │  │  │
│  │  └───────────┘ └───────────┘ └───────────────┘  │  │
│  └─────────────────────────────────────────────────┘  │
└──────────────────────┬───────────────────────────────┘
                       │ HTTPS / WebSocket
┌──────────────────────▼───────────────────────────────┐
│              Backend (FastAPI + PostgreSQL)            │
│  ┌───────────┐ ┌────────────┐ ┌───────────────────┐  │
│  │ SOS API   │ │ Tracking   │ │ Threat Scraper    │  │
│  │           │ │ WebSocket  │ │ (NLP Pipeline)    │  │
│  └───────────┘ └────────────┘ └───────────────────┘  │
│  ┌───────────┐ ┌────────────┐ ┌───────────────────┐  │
│  │ Auth API  │ │ Dashboard  │ │ Notification      │  │
│  │ (JWT)     │ │ API        │ │ Service           │  │
│  └───────────┘ └────────────┘ └───────────────────┘  │
└──────────────────────┬───────────────────────────────┘
                       │
┌──────────────────────▼───────────────────────────────┐
│            Admin Dashboard (React + Vite)              │
│  Live map • Alert panel • Incident history • Dispatch  │
└──────────────────────────────────────────────────────┘
```

---

## Module Structure

Every feature module follows this internal structure:

```
modules/<module_name>/
├── presentation/          # UI screens and widgets
│   ├── <module>_screen.dart
│   └── widgets/
├── domain/                # Business logic and state
│   ├── <module>_service.dart
│   └── <module>_state.dart
├── data/                  # Data access (API calls, local DB)
│   └── <module>_repository.dart
└── tests/                 # Module-specific tests
    └── <module>_service_test.dart
```

### Rules for modules:
1. **A module may only depend on `core/`** — never on another module directly.
2. **Cross-module communication** goes through core services (e.g., `SosService` is in `core/` so both `sos_core` and `passive_detection` can trigger it).
3. **Each module checks its feature flag** before activating any UI or background work.
4. **Each module handles its own permission requests** via the shared `PermissionService` in core.

---

## Core Services (Shared Layer)

| Service | File | Purpose |
|---------|------|---------|
| `LocationService` | `core/services/location_service.dart` | GPS streaming, one-shot location, background tracking |
| `EncryptionService` | `core/services/encryption_service.dart` | AES-256-GCM payload encryption |
| `NetworkService` | `core/services/network_service.dart` | HTTP client + WebSocket for backend communication |
| `LocalQueueService` | `core/services/local_queue_service.dart` | Drift DB queue for offline payload storage |
| `AuthService` | `core/services/auth_service.dart` | JWT auth, user session management |
| `PermissionService` | `core/services/permission_service.dart` | Runtime permission requests with rationale UI |
| `EmergencyProtocol` | `core/services/emergency_protocol.dart` | Orchestrates: trigger → encrypt → route (online/offline) |

---

## Data Flow: Emergency Protocol

```
Manual SOS tap ──┐
Passive audio ───┤
Passive kinetic ─┤──► EmergencyProtocol.trigger()
Duress PIN ──────┘        │
                          ▼
                  Build DistressPayload
                  (location, timestamp, type, battery)
                          │
                          ▼
                  EncryptionService.encrypt()
                          │
                          ▼
                  Check connectivity
                    ┌─────┴─────┐
                 Online      Offline
                    │           │
                    ▼           ▼
              NetworkService  ┌─► LocalQueueService.enqueue()
              .sendPayload()  │   (persisted to Drift DB)
                    │         │
                    │         └─► BleMeshService.broadcast()
                    │             (if BLE module enabled)
                    ▼
              Backend receives
              Dashboard updates
```

---

## State Management

**Riverpod 2.x** is used exclusively across all modules. Do NOT mix Bloc, Provider, or setState.

Patterns:
- `@riverpod` annotation for auto-generated providers
- `AsyncNotifier` for async state (API calls, sensor streams)
- `StreamNotifier` for real-time data (location, BLE)
- `ref.watch()` in widgets, `ref.read()` in callbacks
- State classes use `freezed` for immutability

---

## Backend Architecture

- **FastAPI** (Python 3.10+) with async SQLAlchemy
- **PostgreSQL** for persistent storage
- **Redis** for WebSocket pub/sub and rate limiting
- **Alembic** for database migrations
- All endpoints under `/api/v1/` prefix
- JWT authentication on all protected routes
- WebSocket for real-time location streaming

---

## Feature Flags

All Phase 2 features are behind compile-time flags in `core/constants/feature_flags.dart`. This ensures:
- Phase 1 can always ship independently
- A broken Phase 2 module can be disabled without touching other code
- Team members working on different modules don't interfere with each other

---

## Testing Strategy

| Level | What | Tool |
|-------|------|------|
| Unit | Service logic, payload encoding, encryption | `flutter test` |
| Widget | UI components render correctly | `flutter test` (with `WidgetTester`) |
| Integration | Full SOS flow end-to-end | `flutter test integration_test/` |
| Backend | API endpoints, DB operations | `pytest` |
| Manual | Permissions, background execution, BLE | Real Android device |

---

## Performance Targets

| Metric | Target |
|--------|--------|
| Cold start | < 3 seconds on mid-range Android |
| APK size (per ABI) | < 50 MB |
| API response time | < 500ms for dashboard queries |
| Location update interval | 5s during SOS, 30s during normal tracking |
| ML inference | Off UI thread, < 200ms per frame |
