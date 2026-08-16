import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../core/constants/feature_flags.dart';

/// Home screen — the main hub of the app.
///
/// Shows the SOS button prominently, with navigation to
/// tracking map and other features below.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shield,
                      color: AppTheme.primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tourist Safety',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Your safety companion',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () {
                      // TODO: Navigate to settings
                    },
                  ),
                ],
              ),
            ),

            // ─── Status Card ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: AppTheme.safeGreen.withValues(alpha: isDark ? 0.2 : 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppTheme.safeGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status: Safe',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.safeGreen,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'All systems operational',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ─── SOS Button (center stage) ──────────────────
            Expanded(
              flex: 3,
              child: Center(
                child: GestureDetector(
                  onTap: () => context.push('/sos'),
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          AppTheme.sosRed,
                          AppTheme.sosRedDark,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.sosRed.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'SOS',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap for emergency',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ─── Quick Actions Grid ─────────────────────────
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.0,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _QuickActionCard(
                      icon: Icons.map_outlined,
                      label: 'Live Map',
                      color: AppTheme.primaryColor,
                      onTap: () => context.push('/map'),
                    ),
                    _QuickActionCard(
                      icon: Icons.location_on_outlined,
                      label: 'Track Me',
                      color: Colors.blue.shade600,
                      onTap: () => context.push('/map'),
                    ),
                    _QuickActionCard(
                      icon: Icons.group_outlined,
                      label: 'Buddy',
                      color: Colors.purple.shade600,
                      enabled: FeatureFlags.buddyGeofence,
                      onTap: () {
                        // TODO: Navigate to buddy screen
                      },
                    ),
                    _QuickActionCard(
                      icon: Icons.navigate_next_outlined,
                      label: 'Safe Route',
                      color: AppTheme.safeGreen,
                      enabled: FeatureFlags.safeNavigation,
                      onTap: () {
                        // TODO: Navigate to safe navigation
                      },
                    ),
                    _QuickActionCard(
                      icon: Icons.warning_amber_outlined,
                      label: 'Red Zones',
                      color: AppTheme.dangerZoneRed,
                      enabled: FeatureFlags.threatIntel,
                      onTap: () {
                        // TODO: Navigate to threat intel map
                      },
                    ),
                    _QuickActionCard(
                      icon: Icons.phone_outlined,
                      label: 'Contacts',
                      color: Colors.orange.shade700,
                      onTap: () {
                        // TODO: Navigate to emergency contacts
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// A single quick-action tile in the home screen grid.
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = enabled ? color : Colors.grey;

    return Material(
      borderRadius: BorderRadius.circular(16),
      color: effectiveColor.withValues(alpha: 
        theme.brightness == Brightness.dark ? 0.15 : 0.08,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: effectiveColor, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: effectiveColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (!enabled) ...[
              const SizedBox(height: 2),
              Text(
                'Coming soon',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.grey,
                  fontSize: 9,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
