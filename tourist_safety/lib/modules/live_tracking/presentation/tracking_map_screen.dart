import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/location_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../theme/app_theme.dart';

/// Live tracking map screen.
///
/// Shows the user's current position on an OpenStreetMap tile layer.
/// Follows the user's location in real-time.
class TrackingMapScreen extends ConsumerStatefulWidget {
  const TrackingMapScreen({super.key});

  @override
  ConsumerState<TrackingMapScreen> createState() => _TrackingMapScreenState();
}

class _TrackingMapScreenState extends ConsumerState<TrackingMapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<AppPosition>? _locationSubscription;
  AppPosition? _currentPosition;
  final List<LatLng> _trackPoints = [];
  bool _isTracking = false;
  bool _followUser = true;
  bool _locationDenied = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final permService = ref.read(permissionServiceProvider);
    final hasLocation = await permService.requestLocation(context);

    if (!hasLocation) {
      if (mounted) {
        setState(() => _locationDenied = true);
      }
      return;
    }

    final locationService = ref.read(locationServiceProvider);

    // Get initial position
    final pos = await locationService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _currentPosition = pos;
        _trackPoints.add(LatLng(pos.latitude, pos.longitude));
      });
    }

    // Start streaming
    locationService.startStreaming(LocationMode.normal);
    _locationSubscription = locationService.positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _trackPoints.add(LatLng(pos.latitude, pos.longitude));
          _isTracking = true;
        });

        if (_followUser) {
          _mapController.move(
            LatLng(pos.latitude, pos.longitude),
            _mapController.camera.zoom,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Default center (New Delhi) until GPS fix arrives
    final center = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(28.6139, 77.2090);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Map'),
        actions: [
          // Follow user toggle
          IconButton(
            icon: Icon(
              _followUser ? Icons.gps_fixed : Icons.gps_not_fixed,
              color: _followUser ? Colors.white : Colors.white54,
            ),
            onPressed: () {
              setState(() => _followUser = !_followUser);
              if (_followUser && _currentPosition != null) {
                _mapController.move(
                  LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude),
                  _mapController.camera.zoom,
                );
              }
            },
            tooltip: _followUser ? 'Following you' : 'Free look',
          ),
        ],
      ),
      body: _locationDenied
          ? _LocationDeniedView(theme: theme)
          : Stack(
              children: [
                // ─── Map ────────────────────────────────────
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 15.0,
                    onPositionChanged: (pos, hasGesture) {
                      if (hasGesture) {
                        setState(() => _followUser = false);
                      }
                    },
                  ),
                  children: [
                    // OSM tile layer (free, no API key)
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.touristsafety.tourist_safety',
                    ),

                    // Track polyline
                    if (_trackPoints.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _trackPoints,
                            strokeWidth: 4,
                            color: AppTheme.primaryColor.withValues(alpha: 0.8),
                          ),
                        ],
                      ),

                    // User marker
                    if (_currentPosition != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // ─── Status overlay ─────────────────────────
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _isTracking
                                ? AppTheme.safeGreen
                                : AppTheme.warningAmber,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isTracking
                                    ? 'Tracking Active'
                                    : 'Acquiring GPS...',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_currentPosition != null)
                                Text(
                                  '${_currentPosition!.latitude.toStringAsFixed(5)}, '
                                  '${_currentPosition!.longitude.toStringAsFixed(5)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_currentPosition?.accuracy != null)
                          Chip(
                            label: Text(
                              '±${_currentPosition!.accuracy!.toStringAsFixed(0)}m',
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor:
                                AppTheme.primaryColor.withValues(alpha: 0.1),
                            side: BorderSide.none,
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Shown when location permission is denied.
class _LocationDeniedView extends StatelessWidget {
  final ThemeData theme;
  const _LocationDeniedView({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Location Access Required',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The map needs location permission to show your position. '
              'Please enable it in your device settings.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
