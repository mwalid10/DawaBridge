import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/session.dart';
import '../../core/widgets/gradient_hero_background.dart';

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
    // the KYC gate. Routing now belongs to the redirect in `core/router.dart`,
    // driven by `SessionController`; this just holds the frame while the
    // session resolves.
    //
    // The delay is only so the icon's 400ms fade/scale-in reads as
    // deliberate when the session resolves instantly from cache.
    Future.delayed(const Duration(milliseconds: 450), () {
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
        _ => '/account-status',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientHeroBackground(
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 64),
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOut),
        ),
      ),
    );
  }
}
