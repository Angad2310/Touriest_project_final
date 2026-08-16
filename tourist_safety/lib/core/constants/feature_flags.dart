/// Tourist Safety App — Feature Flags
///
/// All Phase 2 features are disabled by default.
/// Toggle these flags during development to enable/disable modules.
///
/// IMPORTANT: Phase 2 flags should remain `false` until the Phase 1
/// baseline is fully tested and stable. Each module's UI entry point
/// and background service checks its flag before activating.
abstract class FeatureFlags {
  // ─── Phase 2 Modules ──────────────────────────────────────
  /// Offline BLE mesh relay for distress payloads
  static const bool bleRelay = false;

  /// Anti-coercion decoy PIN + fake weather screen
  static const bool duressPin = false;

  /// Edge AI passive threat detection (mic + accelerometer)
  static const bool passiveDetection = false;

  /// Red Zone overlays from backend NLP threat scraping
  static const bool threatIntel = false;

  /// Risk-weighted navigation avoiding Red Zones
  static const bool safeNavigation = false;

  /// Travel group tracking with drift alerts
  static const bool buddyGeofence = false;

  // ─── Debug Flags ──────────────────────────────────────────
  /// Show debug overlay with sensor data on-screen
  static const bool debugOverlay = false;

  /// Use mock location data instead of real GPS
  static const bool mockLocation = false;

  /// Use mock backend (in-memory) instead of real API
  static const bool mockBackend = false;
}
