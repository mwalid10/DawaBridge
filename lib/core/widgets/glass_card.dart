import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// A rounded, soft-shadowed card with a translucent glass surface. Use
/// [blurred] when the card sits directly over a gradient/image background
/// (e.g. the login sheet) for a true glassmorphism effect; leave it off for
/// cards that sit on the plain scaffold background, where a flat white fill
/// reads better and avoids the cost of a backdrop filter.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.borderRadius = AppRadius.xl,
    this.blurred = false,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool blurred;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: blurred ? 0.85 : 1.0),
        borderRadius: radius,
        boxShadow: AppShadows.card,
      ),
      child: child,
    );

    if (!blurred) {
      return Container(margin: margin, child: surface);
    }

    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: surface,
      ),
    );
  }
}
