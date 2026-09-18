import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_extensions.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

/// DawaBridge's launch screen.
///
/// White, to hand over cleanly from the native launch window
/// (`android/app/src/main/res/drawable/launch_background.xml`), which paints
/// the same logo on the same white while the engine boots. Matching them
/// means the transition from native to Flutter is invisible instead of a
/// flash.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // This screen no longer decides anything. It used to read
    // `supabase.auth.currentSession` and send any session straight to
    // `/home` — without ever checking `pharmacies.status`, which is exactly
    // how an unapproved (or rejected, or suspended) pharmacy walked past
    // the KYC gate. Routing now belongs to the redirect in
    // `core/router.dart`, driven by `SessionController`; this just holds the
    // frame while the session resolves.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      // Nudge the router to re-evaluate in case the session resolved before
      // this route was even built (no notifyListeners would have fired).
      if (sessionController.state != SessionState.unknown) {
        context.go(_destinationFor(sessionController.state));
      }
    });
  }

  String _destinationFor(SessionState state) => switch (state) {
        SessionState.approved => '/home',
        SessionState.signedOut => '/onboarding',
        SessionState.needsRegistration => '/register/complete',
        SessionState.offline => '/offline',
        _ => '/account-status',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              Image.asset(
                'assets/branding/logo.png',
                width: 220,
                fit: BoxFit.contain,
              ).animate().fadeIn(duration: 500.ms).scale(
                    begin: const Offset(0.88, 0.88),
                    duration: 600.ms,
                    curve: Curves.easeOutCubic,
                  ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.brandName,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.primaryDark,
                      letterSpacing: -0.5,
                    ),
              ).animate().fadeIn(delay: 250.ms, duration: 450.ms).slideY(begin: 0.25),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.brandTagline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkSoft,
                      height: 1.4,
                    ),
              ).animate().fadeIn(delay: 450.ms, duration: 450.ms),
              const Spacer(flex: 4),
              // Only appears if the session is taking a while — an instant
              // resolve shouldn't flash a spinner on the way past.
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
              ).animate().fadeIn(delay: 900.ms, duration: 400.ms),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
