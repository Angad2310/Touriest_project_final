import 'package:go_router/go_router.dart';

import '../modules/sos_core/presentation/sos_screen.dart';
import '../modules/sos_core/presentation/sos_active_screen.dart';
import '../modules/live_tracking/presentation/tracking_map_screen.dart';
import 'home_screen.dart';

/// App-level route configuration using GoRouter.
///
/// All routes are defined here — modules do not define their own routes.
/// This keeps navigation centralized and avoids circular dependencies.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/sos',
      name: 'sos',
      builder: (context, state) => const SosScreen(),
    ),
    GoRoute(
      path: '/sos/active',
      name: 'sos-active',
      builder: (context, state) => const SosActiveScreen(),
    ),
    GoRoute(
      path: '/map',
      name: 'map',
      builder: (context, state) => const TrackingMapScreen(),
    ),
    // Phase 2 routes (added when modules are built and flags enabled)
    // GoRoute(path: '/buddy', ...),
    // GoRoute(path: '/settings', ...),
  ],
);
