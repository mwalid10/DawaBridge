import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_extensions.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_gradient_button.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_hero_background.dart';

/// Shown when the app is signed in but can't reach the server and has no
/// cached answer from a previous run about what this account may do.
///
/// This is the screen that used to not exist. A cold start with no network
/// left `SessionController` stuck in `unknown`, and the router's rule for
/// `unknown` is "hold on the splash" — so the app simply sat on the logo
/// indefinitely with no message, no retry and no way to reach sign-in.
///
/// Retries automatically the moment the device reports an interface again,
/// so in the common case (walking out of a lift, a tunnel, a basement
/// pharmacy) the user never has to touch anything. The button is for the
/// case where the interface never dropped but nothing can get out anyway —
/// a captive-portal wifi, or a mobile line with no data left.
class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await sessionController.refresh();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: GradientHeroBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              children: [
                const Spacer(),

                // Concentric rings radiating outward — a "searching" motion
                // rather than a static error mark, which matches what's
                // actually happening underneath.
                SizedBox(
                  height: 148,
                  width: 148,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      for (final delay in [0, 600, 1200])
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                          ),
                        )
                            .animate(onPlay: (c) => c.repeat())
                            .scaleXY(begin: 0.45, end: 1, duration: 1800.ms, delay: delay.ms, curve: Curves.easeOut)
                            .fadeOut(duration: 1800.ms, delay: delay.ms),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                        ),
                        child: const Icon(Icons.wifi_off_rounded, size: 44, color: Colors.white),
                      ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8)),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),
                Text(
                  l10n.offlineTitle,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.offlineBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.45),
                ).animate().fadeIn(delay: 250.ms, duration: 400.ms),

                const SizedBox(height: AppSpacing.xxl),
                GlassCard(
                  blurred: true,
                  child: Column(
                    children: [
                      // What still works with no signal, so the screen isn't
                      // purely a dead end.
                      _OfflineCapability(icon: Icons.inventory_2_outlined, label: l10n.offlineCanBrowse),
                      const SizedBox(height: AppSpacing.md),
                      _OfflineCapability(icon: Icons.forum_outlined, label: l10n.offlineCanMessage),
                      const SizedBox(height: AppSpacing.md),
                      _OfflineCapability(
                        icon: Icons.handshake_outlined,
                        label: l10n.offlineCannotDeal,
                        available: false,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 350.ms, duration: 400.ms).slideY(begin: 0.15),

                const Spacer(),
                AppGradientButton(
                  onPressed: _retrying ? null : _retry,
                  isLoading: _retrying,
                  child: Text(l10n.commonRetry),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => context.push('/profile/account'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: Text(l10n.accountSettingsTitle),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineCapability extends StatelessWidget {
  const _OfflineCapability({
    required this.icon,
    required this.label,
    this.available = true,
  });

  final IconData icon;
  final String label;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.good : AppColors.inkFaint;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: available ? AppColors.goodBg : AppColors.background,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: available ? AppColors.ink : AppColors.inkFaint,
                ),
          ),
        ),
        Icon(
          available ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
          size: 16,
          color: color,
        ),
      ],
    );
  }
}
