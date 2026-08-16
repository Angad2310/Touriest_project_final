import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// Manages the Android foreground service that keeps GPS streaming
/// alive when the app is backgrounded.
///
/// Android kills background apps aggressively. Without a foreground service
/// (which shows a persistent notification), GPS stops within ~60 seconds.
/// This service keeps it alive for the duration of an active emergency.
///
/// iOS: Uses `significantLocationChange` background mode — no foreground
/// service needed, but lower accuracy (system-approved behaviour).
class BackgroundTrackingService {
  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Initialize the foreground task config — call once at app start.
  void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'tourist_safety_tracking',
        channelName: 'Tourist Safety — Location Tracking',
        channelDescription:
            'Keeps your location active during an emergency so help can find you.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWifiLock: true,
      ),
    );
    _log.i('BackgroundTrackingService initialized');
  }

  /// Start the foreground service with emergency-mode notification.
  Future<void> startEmergencyTracking() async {
    if (_isRunning) {
      // Update the notification text to emergency
      await FlutterForegroundTask.updateService(
        notificationTitle: '🚨 Emergency Alert Active',
        notificationText: 'Your location is being shared with emergency services.',
        callback: backgroundTaskCallback,
      );
      return;
    }

    await FlutterForegroundTask.startService(
      notificationTitle: '🚨 Emergency Alert Active',
      notificationText: 'Your location is being shared with emergency services.',
      callback: backgroundTaskCallback,
    );
    _isRunning = true;
    _log.i('Emergency tracking foreground service started');
  }

  /// Start normal-mode tracking notification.
  Future<void> startNormalTracking() async {
    if (_isRunning) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Tourist Safety — Tracking',
        notificationText: 'Your location is being monitored for safety.',
        callback: backgroundTaskCallback,
      );
      return;
    }

    await FlutterForegroundTask.startService(
      notificationTitle: 'Tourist Safety — Tracking',
      notificationText: 'Your location is being monitored for safety.',
      callback: backgroundTaskCallback,
    );
    _isRunning = true;
    _log.i('Normal tracking foreground service started');
  }

  /// Stop the foreground service.
  Future<void> stopTracking() async {
    if (!_isRunning) return;
    await FlutterForegroundTask.stopService();
    _isRunning = false;
    _log.i('Background tracking service stopped');
  }
}

/// Top-level callback — required to be a top-level function.
/// This is the entry point for the background isolate.
@pragma('vm:entry-point')
void backgroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(TrackingTaskHandler());
}

/// Background isolate task handler.
/// Runs every 5 seconds (as configured in ForegroundTaskOptions).
class TrackingTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Background isolate is ready — actual GPS comes from main isolate
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Heartbeat — keeps the service alive and updates timestamp in notification
    FlutterForegroundTask.updateService(
      notificationTitle: '🚨 Emergency Alert Active',
      notificationText:
          'Location active · ${_fmt(timestamp)}',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

/// Riverpod provider.
final backgroundTrackingServiceProvider =
    Provider<BackgroundTrackingService>((ref) {
  return BackgroundTrackingService();
});
