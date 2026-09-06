import 'package:flutter/material.dart';

import '../theme.dart';

/// Connected pill-segment progress indicator for multi-step flows (the KYC
/// wizard). Purely presentational — takes the same step labels/index the
/// screen already computes, animates the active/completed segment color.
class StepProgressBar extends StatelessWidget {
  const StepProgressBar({
    super.key,
    required this.labels,
    required this.currentStep,
  });

  final List<String> labels;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      child: Row(
        children: List.generate(labels.length, (i) {
          final completed = i < currentStep;
          final active = i <= currentStep;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    height: 5,
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.divider,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (completed) ...[
                        const Icon(Icons.check_circle, size: 12, color: AppColors.primary),
                        const SizedBox(width: 3),
                      ],
                      Flexible(
                        child: Text(
                          labels[i],
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: active ? AppColors.primary : AppColors.inkFaint,
                                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
