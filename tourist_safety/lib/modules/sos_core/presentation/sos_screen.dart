import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/distress_payload.dart';
import '../../../core/services/emergency_protocol.dart';
import '../../../core/services/permission_service.dart';
import '../../../theme/app_theme.dart';

/// SOS Trigger Screen — full-screen panic button.
///
/// Design: large red button dominates the screen. Single tap triggers.
/// Haptic feedback on press. Confirmation before cancel.
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isTriggering = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _triggerSos() async {
    if (_isTriggering) return;

    setState(() => _isTriggering = true);

    // Haptic feedback
    HapticFeedback.heavyImpact();

    // Ensure location permission
    final permService = ref.read(permissionServiceProvider);
    final hasLocation = await permService.requestLocation(context);
    if (!hasLocation && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Location unavailable — emergency will be sent without GPS position',
          ),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
    }

    // Trigger the emergency protocol
    final protocol = ref.read(emergencyProtocolProvider);
    final result = await protocol.trigger(type: TriggerType.manual);

    if (mounted) {
      switch (result) {
        case TriggerResult.sentOnline:
        case TriggerResult.queuedOffline:
          context.go('/sos/active');
          break;
        case TriggerResult.alreadyActive:
          context.go('/sos/active');
          break;
        case TriggerResult.failed:
          setState(() => _isTriggering = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to send emergency — please try again'),
              backgroundColor: AppTheme.sosRed,
            ),
          );
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        backgroundColor: AppTheme.sosRed,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),

            // Instructions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Press the button below to send an emergency distress signal with your location.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),

            // SOS Button with pulse animation
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulseController.value * 0.05);
                    final glowOpacity = 0.2 + (_pulseController.value * 0.3);
                    return Transform.scale(
                      scale: _isTriggering ? 0.95 : scale,
                      child: GestureDetector(
                        onTap: _triggerSos,
                        child: Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0xFFEF5350),
                                AppTheme.sosRed,
                                AppTheme.sosRedDark,
                              ],
                              stops: [0.0, 0.5, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppTheme.sosRed.withValues(alpha: glowOpacity),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: _isTriggering
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.warning_rounded,
                                      color: Colors.white,
                                      size: 56,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'SOS',
                                      style: theme.textTheme.headlineLarge
                                          ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 6,
                                        fontSize: 40,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Footer note
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_off,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Works offline — your alert will be queued',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
