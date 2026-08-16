/// Distress payload model — the canonical emergency data packet.
///
/// Used by every trigger path (manual SOS, passive detection, duress).
/// Serializable to JSON (for HTTP) and compact binary (for BLE).
/// Immutable.
class DistressPayload {
  final String id;
  final String userId;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final double? altitude;
  final double? accuracy;
  final TriggerType triggerType;
  final int? batteryLevel;
  final NetworkStatus networkStatus;
  final Map<String, dynamic> metadata;

  const DistressPayload({
    required this.id,
    required this.userId,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.altitude,
    this.accuracy,
    required this.triggerType,
    this.batteryLevel,
    this.networkStatus = NetworkStatus.online,
    this.metadata = const {},
  });

  /// Create from JSON (API response or local DB).
  factory DistressPayload.fromJson(Map<String, dynamic> json) {
    return DistressPayload(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      triggerType: TriggerType.values.firstWhere(
        (t) => t.value == json['trigger_type'],
        orElse: () => TriggerType.manual,
      ),
      batteryLevel: json['battery_level'] as int?,
      networkStatus: NetworkStatus.values.firstWhere(
        (n) => n.value == (json['network_status'] ?? 'online'),
        orElse: () => NetworkStatus.online,
      ),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Serialize to JSON for API / local DB.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'trigger_type': triggerType.value,
      'battery_level': batteryLevel,
      'network_status': networkStatus.value,
      'metadata': metadata,
    };
  }

  /// Create a copy with modified fields.
  DistressPayload copyWith({
    String? id,
    String? userId,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
    TriggerType? triggerType,
    int? batteryLevel,
    NetworkStatus? networkStatus,
    Map<String, dynamic>? metadata,
  }) {
    return DistressPayload(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      triggerType: triggerType ?? this.triggerType,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      networkStatus: networkStatus ?? this.networkStatus,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() =>
      'DistressPayload(id: $id, type: ${triggerType.value}, '
      'lat: $latitude, lng: $longitude, status: ${networkStatus.value})';
}

/// How the emergency was triggered.
enum TriggerType {
  manual('manual'),
  passiveAudio('passive_audio'),
  passiveKinetic('passive_kinetic'),
  duress('duress');

  final String value;
  const TriggerType(this.value);
}

/// Network routing status of the payload.
enum NetworkStatus {
  online('online'),
  offlineBle('offline_ble'),
  offlineQueued('offline_queued');

  final String value;
  const NetworkStatus(this.value);
}
