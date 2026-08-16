import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../models/distress_payload.dart';
import 'location_service.dart';
import 'network_service.dart';
import 'local_queue_service.dart';

/// Central emergency orchestrator.
///
/// ALL trigger paths (manual SOS, passive detection, duress) flow through
/// this single service. It builds the payload, routes it (online → HTTP,
/// offline → local queue + future BLE), and manages the emergency lifecycle.
///
/// Dependencies: LocationService, NetworkService, LocalQueueService
/// Depended on by: SosService, PassiveDetectionService, DuressService
class EmergencyProtocol {
  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));
  final LocationService _locationService;
  final NetworkService _networkService;
  final LocalQueueService _queueService;
  final _uuid = const Uuid();

  final StreamController<EmergencyState> _stateController =
      StreamController<EmergencyState>.broadcast();

  EmergencyState _currentState = EmergencyState.idle;
  DistressPayload? _activePayload;

  EmergencyProtocol({
    required this._locationService,
    required this._networkService,
    required this._queueService,
  });

  /// Current emergency state.
  EmergencyState get currentState => _currentState;

  /// Stream of state changes.
  Stream<EmergencyState> get stateStream => _stateController.stream;

  /// The active distress payload (null if no emergency).
  DistressPayload? get activePayload => _activePayload;

  /// Trigger an emergency.
  ///
  /// 1. Gets current location (if available)
  /// 2. Builds a DistressPayload
  /// 3. Routes it: online → backend API, offline → local queue
  /// 4. If SOS is active, starts emergency-mode location streaming
  Future<TriggerResult> trigger({
    required TriggerType type,
    String userId = 'anonymous', // TODO: Get from AuthService
    Map<String, dynamic>? metadata,
  }) async {
    if (_currentState == EmergencyState.active) {
      _log.w('Emergency already active — ignoring duplicate trigger');
      return TriggerResult.alreadyActive;
    }

    _setState(EmergencyState.triggering);
    _log.i('🚨 EMERGENCY TRIGGERED: ${type.value}');

    try {
      // 1. Get current location (best effort — SOS works without it)
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        _log.w('Location unavailable — proceeding without GPS');
      }

      // 2. Build the distress payload
      _activePayload = DistressPayload(
        id: _uuid.v4(),
        userId: userId,
        timestamp: DateTime.now(),
        latitude: position?.latitude,
        longitude: position?.longitude,
        altitude: position?.altitude,
        accuracy: position?.accuracy,
        triggerType: type,
        batteryLevel: null, // TODO: Get from battery plugin
        networkStatus: _networkService.isOnline
            ? NetworkStatus.online
            : NetworkStatus.offlineQueued,
        metadata: metadata ?? {},
      );

      // 3. Route the payload
      bool sent = false;
      if (_networkService.isOnline) {
        sent = await _networkService.sendDistressPayload(
          _activePayload!.toJson(),
        );
      }

      if (!sent) {
        // Queue for later delivery (and future BLE relay)
        await _queueService.enqueue(
          _activePayload!.toJson(),
          _activePayload!.id,
        );
        _log.i('Payload queued offline: ${_activePayload!.id}');
      } else {
        _log.i('Payload sent to backend: ${_activePayload!.id}');
      }

      // 4. Start emergency-mode location streaming
      _locationService.startStreaming(LocationMode.emergency);

      _setState(EmergencyState.active);

      return sent
          ? TriggerResult.sentOnline
          : TriggerResult.queuedOffline;

    } catch (e) {
      _log.e('Emergency trigger failed', error: e);
      _setState(EmergencyState.error);
      return TriggerResult.failed;
    }
  }

  /// Cancel the active emergency (normal PIN disarm).
  Future<void> cancel() async {
    if (_currentState != EmergencyState.active) return;

    _log.i('Emergency cancelled by user');
    _locationService.stopStreaming();
    _activePayload = null;
    _setState(EmergencyState.resolved);

    // Brief delay then reset to idle
    await Future.delayed(const Duration(seconds: 2));
    _setState(EmergencyState.idle);
  }

  /// Flush queued payloads when connectivity returns.
  Future<int> flushQueue() async {
    if (!_networkService.isOnline) return 0;

    final queued = _queueService.getAll();
    int flushed = 0;

    for (final item in queued) {
      final sent = await _networkService.sendDistressPayload(item.payload);
      if (sent) {
        _queueService.remove(item.id);
        flushed++;
      }
    }

    if (flushed > 0) {
      _log.i('Flushed $flushed queued payloads');
    }
    return flushed;
  }

  void _setState(EmergencyState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void dispose() {
    _stateController.close();
  }
}

/// Emergency lifecycle states.
enum EmergencyState {
  idle,
  triggering,
  active,
  resolved,
  error,
}

/// Result of a trigger attempt.
enum TriggerResult {
  sentOnline,
  queuedOffline,
  alreadyActive,
  failed,
}

/// Riverpod provider for EmergencyProtocol.
final emergencyProtocolProvider = Provider<EmergencyProtocol>((ref) {
  final protocol = EmergencyProtocol(
    locationService: ref.watch(locationServiceProvider),
    networkService: ref.watch(networkServiceProvider),
    queueService: ref.watch(localQueueServiceProvider),
  );
  ref.onDispose(() => protocol.dispose());
  return protocol;
});
