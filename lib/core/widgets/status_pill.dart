import 'package:flutter/material.dart';

import '../theme.dart';

enum StatusPillKind { pending, approved, rejected }

/// Small rounded semantic badge for pending/approved/rejected states.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.kind, required this.label});

  final StatusPillKind kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (kind) {
      StatusPillKind.pending => (AppColors.warn, AppColors.warnBg),
      StatusPillKind.approved => (AppColors.good, AppColors.goodBg),
      StatusPillKind.rejected => (AppColors.danger, AppColors.dangerBg),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
