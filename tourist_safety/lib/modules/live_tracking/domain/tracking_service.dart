import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/services/location_service.dart';
import '../../../core/services/network_service.dart';
import '../../../core/services/background_tracking_service.dart';

/// Tracking service — bridges LocationService → NetworkService (WebSocket).
///
/// Responsibilities:
/// 1. Subscribe to the location stream
/// 2. Send each position update via WebSocket to the backend
/// 3. Batch-buffer location points for offline resilience
/// 4. Coordinate with BackgroundTrackingService to keep GPS alive
class TrackingService {
  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));
  final LocationService _locationService;
  final NetworkService _networkService;
  final BackgroundTrackingService _backgroundService;

  StreamSubscription<AppPosition>? _positionSubscription;
  final List<Map<String, dynamic>> _localBuffer = [];
  bool _isTracking = false;
  String? _userId;

  TrackingService({
    required this._locationService,
    required this._networkService,
    required this._backgroundService,
  });

  bool get isTracking => _isTracking;

  /// Start live tracking for a given user in the specified mode.
  Future<void> startTracking({
    required String userId,
    LocationMode mode = LocationMode.normal,
    bool background = false,
  }) async {
    if (_isTracking) {
      _log.w('Tracking already active');
      return;
    }

    _userId = userId;
    _isTracking = true;

    // 1. Open WebSocket connection
    _networkService.openTrackingWebSocket(userId);

    // 2. Start GPS stream at the appropriate accuracy
    _locationService.startStreaming(mode);

    // 3. Subscribe to position updates and forward to backend
    _positionSubscription =
        _locationService.positionStream.listen(_onPosition);

    // 4. Start background foreground service if needed
    if (background) {
      await (mode == LocationMode.emergency
          ? _backgroundService.startEmergencyTracking()
          : _backgroundService.startNormalTracking());
    }

    _log.i('Tracking started — user: $userId, mode: ${mode.name}');
  }

  /// Stop tracking and close connections.
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    _positionSubscription?.cancel();
    _positionSubscription = null;
    _locationService.stopStreaming();
    _networkService.closeTrackingWebSocket();
    await _backgroundService.stopTracking();

    // Flush any buffered points
    await _flushBuffer();

    _isTracking = false;
    _userId = null;
    _log.i('Tracking stopped');
  }

  /// Upgrade to emergency-mode tracking (higher frequency + emergency notification).
  Future<void> upgradeToEmergency() async {
    if (!_isTracking) return;

    // Restart stream at emergency frequency
    _locationService.startStreaming(LocationMode.emergency);
    await _backgroundService.startEmergencyTracking();
    _log.i('Tracking upgraded to emergency mode');
  }

  // ─── Internal ─────────────────────────────────────────────

  void _onPosition(AppPosition position) {
    final locationData = {
      'user_id': _userId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'altitude': position.altitude,
      'accuracy': position.accuracy,
      'speed': position.speed,
      'heading': position.heading,
      'timestamp': position.timestamp.toIso8601String(),
    };

    // Try to send via WebSocket
    if (_networkService.isOnline) {
      _networkService.sendLocationUpdate(locationData);
    } else {
      // Buffer for batch upload when back online
      _localBuffer.add(locationData);
      if (_localBuffer.length > 200) {
        _localBuffer.removeAt(0); // Drop oldest if buffer overflows
      }
    }
  }

  Future<void> _flushBuffer() async {
    if (_localBuffer.isEmpty || !_networkService.isOnline) return;
    final flushed = await _networkService.batchUploadLocations(
      List.from(_localBuffer),
    );
    if (flushed) {
      _log.i('Flushed ${_localBuffer.length} buffered location points');
      _localBuffer.clear();
    }
  }

  void dispose() {
    _positionSubscription?.cancel();
    _networkService.closeTrackingWebSocket();
  }
}

/// Riverpod provider for TrackingService.
final trackingServiceProvider = Provider<TrackingService>((ref) {
  final service = TrackingService(
    locationService: ref.watch(locationServiceProvider),
    networkService: ref.watch(networkServiceProvider),
    backgroundService: ref.watch(backgroundTrackingServiceProvider),
  );
  ref.onDispose(() => service.dispose());
  return service;
});
