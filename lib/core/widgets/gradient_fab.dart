import 'package:flutter/material.dart';

import '../theme.dart';

/// Circular gradient-filled FAB — same `Ink`+`InkWell`+shadow technique as
/// [AppGradientButton], just round instead of pill-shaped, for the bottom
/// nav's floating "Add" action.
class GradientFab extends StatelessWidget {
  const GradientFab({super.key, required this.onPressed, required this.icon, this.gradient = AppGradients.cta});

  final VoidCallback onPressed;
  final IconData icon;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: gradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
