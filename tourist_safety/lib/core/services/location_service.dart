import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';

/// Wraps the Geolocator plugin to provide a unified location API.
///
/// Consumed by: SOS Core, Live Tracking, Buddy Geofence, Safe Navigation.
/// Modules should never call Geolocator directly — always go through this.
class LocationService {
  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<AppPosition> _positionController =
      StreamController<AppPosition>.broadcast();

  /// Stream of position updates. Modules subscribe to this.
  Stream<AppPosition> get positionStream => _positionController.stream;

  /// Get a one-shot current position.
  Future<AppPosition?> getCurrentPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _log.w('Location permission not granted');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return AppPosition.fromGeolocator(position);
    } catch (e) {
      _log.e('Failed to get current position', error: e);
      return null;
    }
  }

  /// Start streaming position updates at the given mode's frequency.
  void startStreaming(LocationMode mode) {
    stopStreaming(); // Cancel any existing stream

    final settings = _settingsForMode(mode);
    _log.i('Starting location stream: ${mode.name}');

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) {
        _positionController.add(AppPosition.fromGeolocator(position));
      },
      onError: (error) {
        _log.e('Location stream error', error: error);
      },
    );
  }

  /// Stop streaming position updates.
  void stopStreaming() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Check if location services are enabled and permission is granted.
  Future<LocationStatus> checkStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationStatus.serviceDisabled;

    final permission = await Geolocator.checkPermission();
    switch (permission) {
      case LocationPermission.denied:
        return LocationStatus.denied;
      case LocationPermission.deniedForever:
        return LocationStatus.permanentlyDenied;
      case LocationPermission.whileInUse:
        return LocationStatus.grantedForeground;
      case LocationPermission.always:
        return LocationStatus.grantedBackground;
      default:
        return LocationStatus.denied;
    }
  }

  LocationSettings _settingsForMode(LocationMode mode) {
    switch (mode) {
      case LocationMode.emergency:
        return const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,     // Update every 5 meters
        );
      case LocationMode.normal:
        return const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,    // Update every 20 meters
        );
      case LocationMode.passive:
        return const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 100,   // Update every 100 meters (battery efficient)
        );
    }
  }

  /// Clean up resources.
  void dispose() {
    stopStreaming();
    _positionController.close();
  }
}

/// App-internal position model (decoupled from Geolocator).
class AppPosition {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final DateTime timestamp;

  const AppPosition({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.speed,
    this.heading,
    required this.timestamp,
  });

  factory AppPosition.fromGeolocator(Position p) {
    return AppPosition(
      latitude: p.latitude,
      longitude: p.longitude,
      altitude: p.altitude != 0.0 ? p.altitude : null,
      accuracy: p.accuracy != 0.0 ? p.accuracy : null,
      speed: p.speed != 0.0 ? p.speed : null,
      heading: p.heading != 0.0 ? p.heading : null,
      timestamp: p.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'altitude': altitude,
    'accuracy': accuracy,
    'speed': speed,
    'heading': heading,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Location permission / service status.
enum LocationStatus {
  serviceDisabled,
  denied,
  permanentlyDenied,
  grantedForeground,
  grantedBackground,
}

/// Location update frequency modes.
enum LocationMode {
  /// High accuracy, ~5-second interval (during active SOS)
  emergency,
  /// Medium accuracy, ~30-second interval (normal tracking)
  normal,
  /// Low accuracy, significant-change only (buddy geofence, battery-efficient)
  passive,
}

/// Riverpod provider for LocationService.
final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(() => service.dispose());
  return service;
});
