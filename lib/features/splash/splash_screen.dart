import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
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
    // Just long enough for the icon's fade/scale-in (400ms) to read as
    // deliberate rather than a flash — was 900ms, adding half a second of
    // pure dead time to every cold start for no visual payoff.
    Future.delayed(const Duration(milliseconds: 450), _route);
  }

  void _route() {
    if (!mounted) return;
    final session = supabase.auth.currentSession;
    context.go(session == null ? '/onboarding' : '/home');
  }

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
