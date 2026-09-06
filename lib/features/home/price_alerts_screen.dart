import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n_extensions.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_card.dart';
import 'price_increased_listing.dart';

final _allPriceAlertsProvider = FutureProvider.autoDispose<List<PriceIncreasedListing>>((ref) async {
  final rows = await supabase
      .from('global_price_alerts')
      .select('id, old_price, new_price, note, drugs(trade_name, concentration)')
      .eq('is_active', true)
      .order('effective_date', ascending: false);
  return (rows as List<dynamic>).map((row) => PriceIncreasedListing.fromJson(row as Map<String, dynamic>)).toList();
});

/// Full list behind Home's "Price Increased -> See all" — every active
/// admin-curated market price alert, not just the Home preview's top 10.
class PriceAlertsScreen extends ConsumerWidget {
  const PriceAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(_allPriceAlertsProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.priceAlertsTitle)),
      body: alerts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.inkFaint),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.priceAlertsCouldntLoad, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => ref.invalidate(_allPriceAlertsProvider),
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
                    const Icon(Icons.trending_up_rounded, size: 40, color: AppColors.inkFaint),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.priceAlertsEmpty, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(_allPriceAlertsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) => _PriceAlertTile(item: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _PriceAlertTile extends StatelessWidget {
  const _PriceAlertTile({required this.item});

  final PriceIncreasedListing item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: const BoxDecoration(color: AppColors.dangerBg, shape: BoxShape.circle),
            child: const Icon(Icons.trending_up_rounded, size: 20, color: AppColors.danger),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.tradeName, style: textTheme.titleMedium),
                if (item.concentration != null) Text(item.concentration!, style: textTheme.bodySmall),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('EGP ${item.newPrice.toStringAsFixed(0)}', style: textTheme.titleMedium?.copyWith(color: AppColors.primary)),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'EGP ${item.oldPrice.toStringAsFixed(0)}',
                      style: textTheme.bodySmall?.copyWith(decoration: TextDecoration.lineThrough, color: AppColors.inkFaint),
                    ),
                  ],
                ),
                if (item.note != null) ...[
                  const SizedBox(height: 2),
                  Text(item.note!, style: textTheme.bodySmall),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
            decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(AppRadius.pill)),
            child: Text(
              '+${item.pctIncrease.toStringAsFixed(1)}%',
              style: textTheme.labelSmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
