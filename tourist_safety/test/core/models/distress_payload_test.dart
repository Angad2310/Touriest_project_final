import 'package:flutter_test/flutter_test.dart';
import 'package:tourist_safety/core/models/distress_payload.dart';

void main() {
  group('DistressPayload', () {
    test('creates a valid payload with all fields', () {
      final payload = DistressPayload(
        id: 'test-123',
        userId: 'user-456',
        timestamp: DateTime(2026, 8, 15, 3, 0, 0),
        latitude: 28.6139,
        longitude: 77.2090,
        altitude: 216.0,
        accuracy: 5.0,
        triggerType: TriggerType.manual,
        batteryLevel: 75,
        networkStatus: NetworkStatus.online,
        metadata: {'source': 'test'},
      );

      expect(payload.id, 'test-123');
      expect(payload.userId, 'user-456');
      expect(payload.latitude, 28.6139);
      expect(payload.longitude, 77.2090);
      expect(payload.triggerType, TriggerType.manual);
      expect(payload.batteryLevel, 75);
      expect(payload.networkStatus, NetworkStatus.online);
    });

    test('creates a valid payload without optional fields (GPS denied)', () {
      final payload = DistressPayload(
        id: 'test-no-gps',
        userId: 'user-789',
        timestamp: DateTime.now(),
        triggerType: TriggerType.manual,
      );

      expect(payload.latitude, isNull);
      expect(payload.longitude, isNull);
      expect(payload.altitude, isNull);
      expect(payload.accuracy, isNull);
      expect(payload.batteryLevel, isNull);
      expect(payload.networkStatus, NetworkStatus.online);
    });

    test('serializes to JSON correctly', () {
      final timestamp = DateTime(2026, 8, 15, 3, 0, 0);
      final payload = DistressPayload(
        id: 'json-test',
        userId: 'user-json',
        timestamp: timestamp,
        latitude: 28.6139,
        longitude: 77.2090,
        triggerType: TriggerType.passiveAudio,
        batteryLevel: 50,
        networkStatus: NetworkStatus.offlineQueued,
      );

      final json = payload.toJson();

      expect(json['id'], 'json-test');
      expect(json['user_id'], 'user-json');
      expect(json['trigger_type'], 'passive_audio');
      expect(json['battery_level'], 50);
      expect(json['network_status'], 'offline_queued');
      expect(json['latitude'], 28.6139);
      expect(json['timestamp'], timestamp.toIso8601String());
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'id': 'from-json',
        'user_id': 'user-from-json',
        'timestamp': '2026-08-15T03:00:00.000',
        'latitude': 28.6139,
        'longitude': 77.2090,
        'trigger_type': 'duress',
        'battery_level': 30,
        'network_status': 'offline_ble',
        'metadata': {'key': 'value'},
      };

      final payload = DistressPayload.fromJson(json);

      expect(payload.id, 'from-json');
      expect(payload.triggerType, TriggerType.duress);
      expect(payload.networkStatus, NetworkStatus.offlineBle);
      expect(payload.metadata['key'], 'value');
      expect(payload.batteryLevel, 30);
    });

    test('roundtrip JSON serialization preserves data', () {
      final original = DistressPayload(
        id: 'roundtrip',
        userId: 'user-rt',
        timestamp: DateTime(2026, 8, 15),
        latitude: 28.6139,
        longitude: 77.2090,
        altitude: 200.0,
        accuracy: 3.5,
        triggerType: TriggerType.passiveKinetic,
        batteryLevel: 88,
        networkStatus: NetworkStatus.online,
        metadata: {'sensor': 'accelerometer'},
      );

      final json = original.toJson();
      final restored = DistressPayload.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.triggerType, original.triggerType);
      expect(restored.batteryLevel, original.batteryLevel);
      expect(restored.networkStatus, original.networkStatus);
      expect(restored.metadata['sensor'], 'accelerometer');
    });

    test('copyWith creates modified copy', () {
      final original = DistressPayload(
        id: 'copy-test',
        userId: 'user-copy',
        timestamp: DateTime.now(),
        triggerType: TriggerType.manual,
        networkStatus: NetworkStatus.online,
      );

      final modified = original.copyWith(
        networkStatus: NetworkStatus.offlineQueued,
        batteryLevel: 42,
      );

      expect(modified.id, original.id); // unchanged
      expect(modified.triggerType, TriggerType.manual); // unchanged
      expect(modified.networkStatus, NetworkStatus.offlineQueued); // changed
      expect(modified.batteryLevel, 42); // changed
    });

    test('all TriggerType values have correct string representation', () {
      expect(TriggerType.manual.value, 'manual');
      expect(TriggerType.passiveAudio.value, 'passive_audio');
      expect(TriggerType.passiveKinetic.value, 'passive_kinetic');
      expect(TriggerType.duress.value, 'duress');
    });

    test('all NetworkStatus values have correct string representation', () {
      expect(NetworkStatus.online.value, 'online');
      expect(NetworkStatus.offlineBle.value, 'offline_ble');
      expect(NetworkStatus.offlineQueued.value, 'offline_queued');
    });
  });
}
