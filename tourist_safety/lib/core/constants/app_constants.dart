/// App-wide constants.
abstract class AppConstants {
  /// Backend API base URL (local development)
  static const String apiBaseUrl = 'http://localhost:8000/api/v1';

  /// WebSocket URL for location tracking
  static const String wsBaseUrl = 'ws://localhost:8000/api/v1';

  /// Location update intervals
  static const int emergencyLocationIntervalMs = 5000;   // 5 seconds during SOS
  static const int normalLocationIntervalMs = 30000;     // 30 seconds normal tracking
  static const int passiveLocationIntervalMs = 300000;   // 5 minutes for buddy geofence

  /// BLE Mesh
  static const int bleMaxHopCount = 5;
  static const String bleServiceUuid = '12345678-1234-1234-1234-123456789abc';

  /// Buddy Geofence
  static const double defaultSafeDistanceMeters = 500.0;

  /// Encryption
  static const int encryptionKeyLength = 32; // AES-256

  /// Payload limits
  static const int maxAudioSnippetDurationSeconds = 10;
  static const int maxQueuedPayloads = 100;
}
