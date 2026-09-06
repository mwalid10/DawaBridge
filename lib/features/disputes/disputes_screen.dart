import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n_extensions.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_card.dart';
import 'dispute.dart';
import 'disputes_controller.dart';

class DisputesScreen extends ConsumerWidget {
  const DisputesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputes = ref.watch(disputesControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.disputesTitle)),
      body: disputes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.inkFaint),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.disputesCouldntLoad, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => ref.read(disputesControllerProvider.notifier).refresh(),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flag_outlined, size: 40, color: AppColors.inkFaint),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.disputesEmpty, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.disputesEmptyBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(disputesControllerProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) => _DisputeTile(dispute: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _DisputeTile extends StatelessWidget {
  const _DisputeTile({required this.dispute});

  final Dispute dispute;

  (Color, Color) get _statusColors => switch (dispute.status) {
        DisputeStatus.open => (AppColors.danger, AppColors.dangerBg),
        DisputeStatus.underReview => (AppColors.warn, AppColors.warnBg),
        DisputeStatus.resolved => (AppColors.good, AppColors.goodBg),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final (fg, bg) = _statusColors;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: () => context.push('/chat/${dispute.dealId}'),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(Icons.flag_outlined, size: 18, color: fg),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dispute.reason, style: textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${dispute.raisedByMe ? l10n.disputeRaisedByYou : l10n.disputeRaisedByOther(dispute.counterpartName)} · ${dispute.drugTradeName}',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(DateFormat.MMMd().add_jm().format(dispute.createdAt), style: textTheme.bodySmall),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
              child: Text(
                dispute.status.label(l10n),
                style: textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
