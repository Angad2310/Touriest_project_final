import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Centralized permission handling with in-app rationale dialogs.
///
/// Every module requests permissions through this service — never directly.
/// This ensures consistent rationale UI and graceful denial handling.
class PermissionService {
  /// Request location permission with rationale.
  Future<bool> requestLocation(BuildContext context) async {
    return _requestWithRationale(
      context: context,
      permission: Permission.locationWhenInUse,
      title: 'Location Access Needed',
      message:
          'Tourist Safety needs your location to send your exact position '
          'during emergencies and show your location on the map.',
      icon: Icons.location_on,
    );
  }

  /// Request background location (must be called AFTER foreground location is granted).
  Future<bool> requestBackgroundLocation(BuildContext context) async {
    // First ensure foreground location is granted
    final foreground = await Permission.locationWhenInUse.status;
    if (!foreground.isGranted) {
      if (!context.mounted) return false;
      final granted = await requestLocation(context);
      if (!granted) return false;
    }

    if (!context.mounted) return false;
    return _requestWithRationale(
      context: context,
      permission: Permission.locationAlways,
      title: 'Background Location',
      message:
          'To keep tracking your location when the app is in the background, '
          'Tourist Safety needs "Allow all the time" location access. '
          'This ensures help can find you even if you can\'t open the app.',
      icon: Icons.my_location,
    );
  }

  /// Request microphone permission (Phase 2 — passive audio detection).
  Future<bool> requestMicrophone(BuildContext context) async {
    return _requestWithRationale(
      context: context,
      permission: Permission.microphone,
      title: 'Microphone Access',
      message:
          'Tourist Safety can detect distress sounds (like screams) automatically. '
          'Audio is analyzed entirely on your device and is never sent to any server.',
      icon: Icons.mic,
    );
  }

  /// Request Bluetooth permission (Phase 2 — BLE mesh).
  Future<bool> requestBluetooth(BuildContext context) async {
    return _requestWithRationale(
      context: context,
      permission: Permission.bluetoothScan,
      title: 'Bluetooth Access',
      message:
          'When there\'s no internet, Tourist Safety can relay emergency signals '
          'to nearby users via Bluetooth, creating a safety mesh network.',
      icon: Icons.bluetooth,
    );
  }

  /// Request notification permission (Android 13+).
  Future<bool> requestNotifications(BuildContext context) async {
    return _requestWithRationale(
      context: context,
      permission: Permission.notification,
      title: 'Notification Access',
      message:
          'Tourist Safety needs to send you alerts when a group member '
          'moves too far away or when an emergency is detected.',
      icon: Icons.notifications_active,
    );
  }

  /// Check if a specific permission is currently granted.
  Future<bool> isGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }

  /// Internal: show rationale dialog, then request system permission.
  Future<bool> _requestWithRationale({
    required BuildContext context,
    required Permission permission,
    required String title,
    required String message,
    required IconData icon,
  }) async {
    // Check if already granted
    final currentStatus = await permission.status;
    if (currentStatus.isGranted) return true;

    // If permanently denied, direct to app settings
    if (currentStatus.isPermanentlyDenied) {
      if (!context.mounted) return false;
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(icon, size: 40, color: Theme.of(ctx).colorScheme.primary),
          title: Text(title),
          content: Text(
            '$message\n\nThis permission was previously denied. '
            'Please enable it in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not Now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      if (openSettings == true) {
        await openAppSettings();
      }
      return false;
    }

    // Show rationale dialog first
    if (!context.mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(icon, size: 40, color: Theme.of(ctx).colorScheme.primary),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    if (proceed != true) return false;

    // Actually request the permission
    final result = await permission.request();
    return result.isGranted;
  }
}

/// Riverpod provider for PermissionService.
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});
