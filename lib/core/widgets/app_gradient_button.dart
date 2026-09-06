import 'package:flutter/material.dart';

import '../theme.dart';

/// A gradient-filled pill button reserved for the app's highest-visibility
/// calls to action (e.g. "Get started", "Sign in", final KYC submit).
/// Mirrors [ElevatedButton]'s onPressed/child contract, including an
/// [isLoading] flag so call sites can swap in a spinner exactly like they do
/// today with plain [ElevatedButton]s.
class AppGradientButton extends StatelessWidget {
  const AppGradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.gradient = AppGradients.cta,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    return Opacity(
      opacity: disabled && isLoading ? 1 : (onPressed == null ? 0.5 : 1),
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: onPressed == null
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: disabled ? null : onPressed,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : DefaultTextStyle(
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.white),
                      child: child,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
