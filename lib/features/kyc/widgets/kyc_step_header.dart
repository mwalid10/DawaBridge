import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme.dart';

/// Shared header for each KYC wizard step: a gradient icon badge with small
/// floating accent dots, above the step title/subtitle. Gives each step a
/// distinct bit of "artwork" instead of a bare form with a plain heading.
class KycStepHeader extends StatelessWidget {
  const KycStepHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 88,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: AppGradients.hero,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withValues(alpha: 0.28),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 32),
                ).animate(key: ValueKey(icon)).fadeIn(duration: 300.ms).scale(begin: const Offset(0.85, 0.85)),
              ),
              Positioned(left: 58, top: -4, child: _dot(AppColors.creamDark, 16)),
              Positioned(left: 76, top: 42, child: _dot(AppColors.primaryLight, 10)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _dot(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 3))],
        ),
      );
}
