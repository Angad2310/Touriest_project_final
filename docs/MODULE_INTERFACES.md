# Module Interface Contracts

This document defines the public API of each module and core service. Modules may **only** communicate through these interfaces — never by importing another module's internal files.

---

## Core Services

### LocationService

```dart
/// Provides GPS location data to all modules.
/// Located: core/services/location_service.dart
abstract class LocationService {
  /// Stream of position updates. Frequency depends on [mode].
  Stream<AppPosition> positionStream({LocationMode mode = LocationMode.normal});

  /// One-shot current position.
  Future<AppPosition> getCurrentPosition();

  /// Start background location tracking (foreground service on Android).
  Future<void> startBackgroundTracking();

  /// Stop background location tracking.
  Future<void> stopBackgroundTracking();

  /// Check if location permission is granted.
  Future<bool> hasPermission();

  /// Request location permission with in-app rationale.
  Future<PermissionResult> requestPermission();
}

enum LocationMode {
  /// High accuracy, 5-second interval (during active SOS)
  emergency,

  /// Medium accuracy, 30-second interval (normal tracking)
  normal,

  /// Low accuracy, significant-change only (buddy geofence)
  passive,
}
```

---

### EmergencyProtocol

```dart
/// Central emergency orchestrator. ALL trigger paths go through this.
/// Located: core/services/emergency_protocol.dart
abstract class EmergencyProtocol {
  /// Trigger an emergency. Builds payload, encrypts, and routes.
  Future<TriggerResult> trigger({
    required TriggerType type,
    Map<String, dynamic>? metadata,
  });

  /// Cancel an active emergency (normal PIN disarm).
  Future<void> cancel();

  /// Current emergency state.
  Stream<EmergencyState> get stateStream;
}

enum TriggerType { manual, passiveAudio, passiveKinetic, duress }

enum EmergencyState { idle, triggering, active, resolved, error }
```

---

### EncryptionService

```dart
/// AES-256-GCM encryption for all payloads.
/// Located: core/services/encryption_service.dart
abstract class EncryptionService {
  /// Encrypt a DistressPayload to bytes.
  Future<Uint8List> encryptPayload(DistressPayload payload);

  /// Decrypt bytes back to a DistressPayload.
  Future<DistressPayload> decryptPayload(Uint8List encrypted);
}
```

---

### NetworkService

```dart
/// HTTP + WebSocket communication with the backend.
/// Located: core/services/network_service.dart
abstract class NetworkService {
  /// Send an encrypted distress payload to the backend.
  Future<SendResult> sendPayload(Uint8List encryptedPayload);

  /// Open a WebSocket for live location streaming.
  Future<WebSocketChannel> openTrackingStream(String userId);

  /// Check current connectivity status.
  Stream<ConnectivityStatus> get connectivityStream;

  /// Whether the device currently has internet access.
  bool get isOnline;
}

enum ConnectivityStatus { online, offline }
enum SendResult { success, queued, failed }
```

---

### LocalQueueService

```dart
/// Offline queue for distress payloads. Persists to local DB.
/// Located: core/services/local_queue_service.dart
abstract class LocalQueueService {
  /// Queue a payload for later delivery.
  Future<void> enqueue(Uint8List encryptedPayload, String payloadId);

  /// Flush all queued payloads when connectivity returns.
  Future<int> flushQueue();

  /// Number of payloads currently queued.
  Future<int> get queueLength;

  /// Stream that emits when queue changes.
  Stream<int> get queueLengthStream;
}
```

---

### AuthService

```dart
/// User authentication and session management.
/// Located: core/services/auth_service.dart
abstract class AuthService {
  /// Register a new user.
  Future<AuthResult> register(String email, String password, String name);

  /// Log in and receive JWT tokens.
  Future<AuthResult> login(String email, String password);

  /// Log out and clear session.
  Future<void> logout();

  /// Current authenticated user, or null.
  User? get currentUser;

  /// Stream of auth state changes.
  Stream<User?> get authStateStream;

  /// Current JWT access token.
  String? get accessToken;
}
```

---

## Module Interfaces

### SOS Core Module

```dart
/// Manual SOS trigger and active SOS management.
/// Located: modules/sos_core/domain/sos_service.dart
///
/// Dependencies: EmergencyProtocol, LocationService
/// Depended on by: UI only (SOS screen)
abstract class SosService {
  /// Trigger a manual SOS.
  Future<TriggerResult> triggerManualSos();

  /// Cancel the active SOS (normal disarm).
  Future<void> cancelSos();

  /// Current SOS state.
  Stream<SosState> get stateStream;
}
```

---

### Live Tracking Module

```dart
/// GPS tracking stream management.
/// Located: modules/live_tracking/domain/tracking_service.dart
///
/// Dependencies: LocationService, NetworkService
/// Depended on by: UI only (map screen)
abstract class TrackingService {
  /// Start streaming location to the backend.
  Future<void> startTracking();

  /// Stop streaming.
  Future<void> stopTracking();

  /// Whether currently tracking.
  bool get isTracking;

  /// Stream of current positions (for local map display).
  Stream<AppPosition> get positionStream;
}
```

---

### BLE Mesh Module (Phase 2)

```dart
/// Bluetooth Low Energy mesh relay for offline payload delivery.
/// Located: modules/ble_mesh/domain/ble_mesh_service.dart
///
/// Dependencies: LocalQueueService, NetworkService
/// Depended on by: EmergencyProtocol (as offline fallback)
abstract class BleMeshService {
  /// Start BLE advertising + scanning.
  Future<void> startMesh();

  /// Stop BLE mesh.
  Future<void> stopMesh();

  /// Broadcast an encrypted payload to nearby peers.
  Future<void> broadcastPayload(Uint8List encryptedPayload, String payloadId);

  /// Stream of received payloads from peers (for relay).
  Stream<ReceivedPayload> get incomingPayloads;

  /// Number of peers currently visible.
  Stream<int> get peerCount;
}
```

---

### Duress UI Module (Phase 2)

```dart
/// Anti-coercion decoy PIN and fake screen.
/// Located: modules/duress_ui/domain/duress_service.dart
///
/// Dependencies: EmergencyProtocol, AuthService
/// Depended on by: PIN entry screen
abstract class DuressService {
  /// Set up the duress PIN (separate from normal PIN).
  Future<void> setDuressPin(String pin);

  /// Verify a PIN. Returns whether it's normal, duress, or invalid.
  Future<PinResult> verifyPin(String pin);

  /// Whether a duress PIN has been configured.
  Future<bool> get isDuressConfigured;
}

enum PinResult { normalPin, duressPin, invalid }
```

---

### Passive Detection Module (Phase 2)

```dart
/// Edge AI threat detection from microphone and IMU sensors.
/// Located: modules/passive_detection/domain/detection_service.dart
///
/// Dependencies: EmergencyProtocol, PermissionService
/// Depended on by: Background service only
abstract class PassiveDetectionService {
  /// Start passive monitoring (audio + kinetic).
  Future<void> startMonitoring();

  /// Stop passive monitoring.
  Future<void> stopMonitoring();

  /// Whether monitoring is currently active.
  bool get isMonitoring;

  /// Stream of detection events (for UI display / logging).
  Stream<DetectionEvent> get detectionStream;

  /// Adjust sensitivity thresholds.
  Future<void> setThresholds({double? audioConfidence, double? kineticConfidence});
}
```

---

### Threat Intelligence Module (Phase 2)

```dart
/// Red Zone data from the backend threat scraping service.
/// Located: modules/threat_intel/domain/threat_service.dart
///
/// Dependencies: NetworkService, LocalQueueService (for caching)
/// Depended on by: Map display, Safe Navigation module
abstract class ThreatService {
  /// Fetch red zones near a location.
  Future<List<RedZone>> getRedZones(double lat, double lng, double radiusKm);

  /// Stream of red zone updates (auto-refreshed).
  Stream<List<RedZone>> get redZoneStream;

  /// Force a refresh from the backend.
  Future<void> refreshRedZones();
}
```

---

### Safe Navigation Module (Phase 2)

```dart
/// Risk-weighted routing that avoids red zones.
/// Located: modules/safe_navigation/domain/navigation_service.dart
///
/// Dependencies: ThreatService, LocationService
/// Depended on by: UI only (navigation screen)
abstract class SafeNavigationService {
  /// Calculate a safe route avoiding red zones.
  Future<SafeRoute> calculateRoute(LatLng origin, LatLng destination);

  /// Stream of navigation instructions.
  Stream<NavigationInstruction> get instructionStream;

  /// Start turn-by-turn navigation.
  Future<void> startNavigation(SafeRoute route);

  /// Stop navigation.
  Future<void> stopNavigation();
}
```

---

### Buddy Geofence Module (Phase 2)

```dart
/// Travel group tracking with drift alerts.
/// Located: modules/buddy_geofence/domain/buddy_service.dart
///
/// Dependencies: LocationService, NetworkService
/// Depended on by: UI only (buddy map screen)
abstract class BuddyService {
  /// Create a new travel group. Returns an invite code.
  Future<String> createGroup(String groupName);

  /// Join an existing group via invite code.
  Future<void> joinGroup(String inviteCode);

  /// Leave the current group.
  Future<void> leaveGroup();

  /// Stream of group member positions.
  Stream<List<BuddyPosition>> get memberPositions;

  /// Stream of drift alerts.
  Stream<DriftAlert> get driftAlerts;

  /// Set the safe distance threshold (default 500m, configurable).
  Future<void> setSafeDistance(double meters);
}
```

---

## Dependency Rules Summary

| Module | May depend on | Must NOT depend on |
|--------|--------------|-------------------|
| `sos_core` | `core/*` | Any other module |
| `live_tracking` | `core/*` | Any other module |
| `ble_mesh` | `core/*` | Any other module |
| `duress_ui` | `core/*` | Any other module |
| `passive_detection` | `core/*` | Any other module |
| `threat_intel` | `core/*` | Any other module |
| `safe_navigation` | `core/*`, `threat_intel` (read-only via ThreatService) | Other modules |
| `buddy_geofence` | `core/*` | Any other module |

> **Exception:** `safe_navigation` depends on `threat_intel` for Red Zone data. This is permitted because it goes through the published `ThreatService` interface — it never imports `threat_intel` internals.
