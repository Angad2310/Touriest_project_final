import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logger/logger.dart';

import '../constants/app_constants.dart';

/// HTTP + WebSocket communication with the backend.
///
/// All network calls go through this service. Modules never use
/// Dio or WebSocket directly.
class NetworkService {
  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));
  final Dio _dio;
  final Connectivity _connectivity = Connectivity();
  WebSocketChannel? _wsChannel;
  bool _isOnline = true;

  NetworkService()
      : _dio = Dio(BaseOptions(
          baseUrl: AppConstants.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        )) {
    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      _log.i('Connectivity changed: ${_isOnline ? "online" : "offline"}');
    });
  }

  /// Whether the device currently has internet access.
  bool get isOnline => _isOnline;

  /// Set the auth token for all subsequent requests.
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear auth token (logout).
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  // ─── Auth API ──────────────────────────────────────────────

  /// Register a new user.
  Future<Map<String, dynamic>?> register(
      String email, String password, String name) async {
    try {
      final response = await _dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'name': name,
      });
      return response.data;
    } on DioException catch (e) {
      _log.e('Register failed', error: e.message);
      return null;
    }
  }

  /// Login and get JWT tokens.
  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      return response.data;
    } on DioException catch (e) {
      _log.e('Login failed', error: e.message);
      return null;
    }
  }

  // ─── SOS API ───────────────────────────────────────────────

  /// Send a distress payload to the backend.
  /// Returns true if sent successfully, false if failed (will be queued).
  Future<bool> sendDistressPayload(Map<String, dynamic> payload) async {
    if (!_isOnline) return false;

    try {
      final response = await _dio.post('/sos/trigger', data: {
        'payload_id': payload['id'],
        'trigger_type': payload['trigger_type'],
        'latitude': payload['latitude'],
        'longitude': payload['longitude'],
        'altitude': payload['altitude'],
        'accuracy': payload['accuracy'],
        'battery_level': payload['battery_level'],
        'metadata': payload['metadata'] ?? {},
      });
      return response.statusCode == 201;
    } on DioException catch (e) {
      _log.e('Failed to send distress payload', error: e.message);
      return false;
    }
  }

  /// Resolve an active SOS incident.
  Future<bool> resolveIncident(String incidentId) async {
    try {
      final response = await _dio.post('/sos/$incidentId/resolve');
      return response.statusCode == 200;
    } on DioException catch (e) {
      _log.e('Failed to resolve incident', error: e.message);
      return false;
    }
  }

  // ─── Location Tracking WebSocket ──────────────────────────

  /// Open a WebSocket for live location streaming.
  WebSocketChannel? openTrackingWebSocket(String userId) {
    if (!_isOnline) return null;

    try {
      final uri = Uri.parse('${AppConstants.wsBaseUrl}/tracking/ws/$userId');
      _wsChannel = WebSocketChannel.connect(uri);
      _log.i('WebSocket connected for user $userId');
      return _wsChannel;
    } catch (e) {
      _log.e('WebSocket connection failed', error: e);
      return null;
    }
  }

  /// Send a location update through the WebSocket.
  void sendLocationUpdate(Map<String, dynamic> locationData) {
    _wsChannel?.sink.add(jsonEncode(locationData));
  }

  /// Close the tracking WebSocket.
  void closeTrackingWebSocket() {
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  // ─── Batch Location Upload ────────────────────────────────

  /// Batch upload queued location logs.
  Future<bool> batchUploadLocations(
      List<Map<String, dynamic>> locations) async {
    if (!_isOnline || locations.isEmpty) return false;

    try {
      final response = await _dio.post('/tracking/batch', data: locations);
      return response.statusCode == 200;
    } on DioException catch (e) {
      _log.e('Batch upload failed', error: e.message);
      return false;
    }
  }

  /// Clean up resources.
  void dispose() {
    closeTrackingWebSocket();
    _dio.close();
  }
}

/// Riverpod provider for NetworkService.
final networkServiceProvider = Provider<NetworkService>((ref) {
  final service = NetworkService();
  ref.onDispose(() => service.dispose());
  return service;
});
