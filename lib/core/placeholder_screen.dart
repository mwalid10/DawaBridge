import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'theme.dart';

/// Marks a tab/screen that's scaffolded but not yet built — every one of
/// these is a named item on the roadmap (Phase 2/3), not a forgotten stub.
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String phase;
  const PlaceholderScreen({super.key, required this.title, required this.icon, required this.phase});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: AppColors.primary),
            ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.85, 0.85)),
            const SizedBox(height: AppSpacing.lg),
            Text('$title — coming in $phase', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
