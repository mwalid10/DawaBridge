import 'package:flutter/material.dart';

import '../theme.dart';

/// Wraps [child] in the brand's hero gradient — used behind splash and the
/// top portion of onboarding/login for a consistent "hero" feel.
class GradientHeroBackground extends StatelessWidget {
  const GradientHeroBackground({
    super.key,
    required this.child,
    this.gradient = AppGradients.hero,
  });

  final Widget child;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: child,
    );
  }
}
