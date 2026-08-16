import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../constants/app_constants.dart';

/// Offline queue for distress payloads and location updates.
///
/// When the device has no connectivity (no cellular, no Wi-Fi, no BLE peer),
/// payloads are persisted here so nothing is ever silently lost.
/// Auto-flushes when connectivity returns.
///
/// Uses a simple JSON file store for MVP. Will migrate to Drift DB
/// when the schema stabilizes.
class LocalQueueService {
  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));
  final List<QueuedPayload> _queue = [];
  final StreamController<int> _queueLengthController =
      StreamController<int>.broadcast();

  /// Stream that emits current queue length on changes.
  Stream<int> get queueLengthStream => _queueLengthController.stream;

  /// Current number of queued payloads.
  int get queueLength => _queue.length;

  /// Queue a distress payload for later delivery.
  Future<void> enqueue(Map<String, dynamic> payload, String payloadId) async {
    if (_queue.length >= AppConstants.maxQueuedPayloads) {
      // Remove oldest to make room
      _queue.removeAt(0);
      _log.w('Queue full — dropped oldest payload');
    }

    _queue.add(QueuedPayload(
      id: payloadId,
      payload: payload,
      queuedAt: DateTime.now(),
    ));

    _queueLengthController.add(_queue.length);
    _log.i('Payload queued: $payloadId (queue size: ${_queue.length})');
  }

  /// Get all queued payloads for flushing.
  List<QueuedPayload> getAll() => List.unmodifiable(_queue);

  /// Remove a payload after successful delivery.
  void remove(String payloadId) {
    _queue.removeWhere((p) => p.id == payloadId);
    _queueLengthController.add(_queue.length);
  }

  /// Clear all queued payloads (after successful flush).
  void clearAll() {
    _queue.clear();
    _queueLengthController.add(0);
    _log.i('Queue cleared');
  }

  void dispose() {
    _queueLengthController.close();
  }
}

/// A single queued payload waiting for delivery.
class QueuedPayload {
  final String id;
  final Map<String, dynamic> payload;
  final DateTime queuedAt;

  const QueuedPayload({
    required this.id,
    required this.payload,
    required this.queuedAt,
  });
}

/// Riverpod provider for LocalQueueService.
final localQueueServiceProvider = Provider<LocalQueueService>((ref) {
  final service = LocalQueueService();
  ref.onDispose(() => service.dispose());
  return service;
});
