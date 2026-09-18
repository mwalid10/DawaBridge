import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/connectivity.dart';
import '../../core/l10n_extensions.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_gradient_button.dart';

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
/// pharmacy) the user never has to touch anything.
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: const BoxDecoration(
                  color: AppColors.creamSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.inkSoft),
              ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9)),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                l10n.offlineTitle,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.offlineBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Auto-retry runs in the background via
              // ConnectivityController.onReconnected; this is for the case
              // where the interface never dropped but the connection is
              // still dead (captive portal, no data allowance).
              AppGradientButton(
                onPressed: _retrying ? null : _retry,
                isLoading: _retrying,
                child: Text(l10n.commonRetry),
              ),
              const Spacer(),
              ListenableBuilder(
                listenable: connectivityController,
                builder: (context, _) => AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: connectivityController.isOffline ? 0 : 1,
                  child: Text(
                    l10n.offlineReconnecting,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () => context.push('/profile/account'),
                child: Text(l10n.accountSettingsTitle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
