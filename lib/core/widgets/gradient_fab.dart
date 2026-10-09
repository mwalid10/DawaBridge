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
    // The shadow is painted out here, not in the Ink decoration below, and
    // that placement is the whole point. A Material clips every ink feature
    // it paints to its own bounds — `_RenderInkFeatures.paint` ends with
    // `canvas.clipRect(Offset.zero & size)` — and an `Ink` decoration is an
    // ink feature. This Material is exactly the 56x56 of the button, so a
    // shadow declared in that decoration was sliced off at the square edge:
    // what reached the screen was a box of shadow around a round button,
    // with corners the button itself never had. Out here it's an ordinary
    // DecoratedBox, clipped by nothing, so the blur stays circular.
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          width: 56,
          height: 56,
          decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}
