import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app.dart';

/// Tourist Safety App — Entry Point
///
/// Minimal bootstrap: wraps the app in [ProviderScope] for Riverpod
/// and delegates everything else to [TouristSafetyApp].
///
/// Nothing heavy is initialized here — all services are lazy-loaded
/// via Riverpod providers when first accessed.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Request notification permission for foreground service (Android 13+)
  FlutterForegroundTask.initCommunicationPort();

  runApp(
    const ProviderScope(
      child: TouristSafetyApp(),
    ),
  );
}
