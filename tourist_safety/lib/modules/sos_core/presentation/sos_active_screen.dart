import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/emergency_protocol.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/local_queue_service.dart';
import '../../../theme/app_theme.dart';

/// SOS Active Screen — shown after emergency is triggered.
///
/// Displays:
/// - Confirmation that the alert was sent (or queued)
/// - Live location coordinates being streamed
/// - Queue status if offline
/// - Cancel button with confirmation dialog
class SosActiveScreen extends ConsumerStatefulWidget {
  const SosActiveScreen({super.key});

  @override
  ConsumerState<SosActiveScreen> createState() => _SosActiveScreenState();
}

class _SosActiveScreenState extends ConsumerState<SosActiveScreen> {
  StreamSubscription<EmergencyState>? _stateSubscription;
  StreamSubscription<AppPosition>? _locationSubscription;
  AppPosition? _lastPosition;
  int _secondsElapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Listen to emergency state changes
    final protocol = ref.read(emergencyProtocolProvider);
    _stateSubscription = protocol.stateStream.listen((state) {
      if (state == EmergencyState.idle && mounted) {
        context.go('/');
      }
    });

    // Listen to location updates
    final locationService = ref.read(locationServiceProvider);
    _locationSubscription = locationService.positionStream.listen((pos) {
      if (mounted) {
        setState(() => _lastPosition = pos);
      }
    });

    // Elapsed time counter
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _locationSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cancelSos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Emergency?'),
        content: const Text(
          'Are you sure you want to cancel this emergency alert? '
          'Only do this if you are safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Alert Active'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.safeGreen,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('I\'m Safe — Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final protocol = ref.read(emergencyProtocolProvider);
      await protocol.cancel();
      if (mounted) {
        context.go('/');
      }
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final protocol = ref.read(emergencyProtocolProvider);
    final payload = protocol.activePayload;
    final queueService = ref.read(localQueueServiceProvider);

    return Scaffold(
      backgroundColor: AppTheme.sosRedDark,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),

            // ─── Alert Active Header ────────────────────
            const Icon(
              Icons.cell_tower,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'EMERGENCY ACTIVE',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDuration(_secondsElapsed),
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w300,
                fontFamily: 'monospace',
              ),
            ),

            const SizedBox(height: 32),

            // ─── Status Cards ───────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Alert status
                    _StatusCard(
                      icon: payload?.networkStatus.value == 'online'
                          ? Icons.cloud_done
                          : Icons.cloud_off,
                      title: payload?.networkStatus.value == 'online'
                          ? 'Alert Sent'
                          : 'Alert Queued (Offline)',
                      subtitle: payload?.networkStatus.value == 'online'
                          ? 'Your emergency signal has been received'
                          : 'Will be sent when connectivity returns',
                      color: payload?.networkStatus.value == 'online'
                          ? AppTheme.safeGreen
                          : AppTheme.warningAmber,
                    ),

                    const SizedBox(height: 12),

                    // Location
                    _StatusCard(
                      icon: _lastPosition != null
                          ? Icons.location_on
                          : Icons.location_off,
                      title: _lastPosition != null
                          ? 'Location Streaming'
                          : 'Awaiting GPS Fix',
                      subtitle: _lastPosition != null
                          ? '${_lastPosition!.latitude.toStringAsFixed(6)}, '
                              '${_lastPosition!.longitude.toStringAsFixed(6)}'
                          : 'Getting your position...',
                      color: _lastPosition != null
                          ? AppTheme.safeGreen
                          : AppTheme.warningAmber,
                    ),

                    const SizedBox(height: 12),

                    // Trigger type
                    _StatusCard(
                      icon: Icons.info_outline,
                      title: 'Trigger Type',
                      subtitle: payload?.triggerType.value.toUpperCase() ??
                          'MANUAL',
                      color: Colors.blue,
                    ),

                    if (queueService.queueLength > 0) ...[
                      const SizedBox(height: 12),
                      _StatusCard(
                        icon: Icons.queue,
                        title: 'Offline Queue',
                        subtitle:
                            '${queueService.queueLength} payload(s) waiting for connectivity',
                        color: AppTheme.warningAmber,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ─── Cancel Button ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _cancelSos,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.close),
                  label: const Text(
                    'I\'m Safe — Cancel Alert',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single status info card on the SOS Active screen.
class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
