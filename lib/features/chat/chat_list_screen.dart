import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n_extensions.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/listing_type_pill.dart';
import '../deals/deal.dart';
import '../deals/deals_controller.dart';
import '../listings/listing_summary.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = ref.watch(dealsControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatTitle)),
      body: deals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.inkFaint),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.chatCouldntLoad, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => ref.read(dealsControllerProvider.notifier).refresh(),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
        data: (deals) {
          if (deals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppColors.inkFaint),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.chatEmpty, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.chatEmptyBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(dealsControllerProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: deals.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) => _DealTile(deal: deals[i]),
            ),
          );
        },
      ),
    );
  }
}

class _DealTile extends StatelessWidget {
  const _DealTile({required this.deal});

  final Deal deal;

  ListingTypePillKind get _pillKind => switch (deal.listingType) {
        ListingType.sell => ListingTypePillKind.sell,
        ListingType.buy => ListingTypePillKind.buy,
        ListingType.barter => ListingTypePillKind.barter,
      };

  // Deals have their own status enum now (migration 0035) instead of
  // borrowing listing_state, and 'pending'/'declined' are new states the
  // old flow had no way to express.
  (Color, Color)? get _stateBadge => switch (deal.state) {
        DealState.pending => (AppColors.warn, AppColors.warnBg),
        DealState.completed => (AppColors.good, AppColors.goodBg),
        DealState.declined || DealState.cancelled => (AppColors.danger, AppColors.dangerBg),
        DealState.accepted => null,
      };

  String _stateLabel(AppLocalizations l10n) => switch (deal.state) {
        DealState.pending => deal.isSeller ? l10n.chatBadgeNeedsYourAnswer : l10n.chatBadgeAwaitingSeller,
        DealState.accepted => '',
        DealState.declined => l10n.chatBadgeDeclined,
        DealState.completed => l10n.chatBadgeCompleted,
        DealState.cancelled => l10n.chatBadgeCancelled,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final badge = _stateBadge;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: () => context.push('/chat/${deal.id}'),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primarySoft,
              child: Text(
                deal.counterpartName.isEmpty ? '?' : deal.counterpartName[0].toUpperCase(),
                style: textTheme.titleMedium?.copyWith(color: AppColors.primaryDark),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          deal.counterpartName,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium,
                        ),
                      ),
                      if (deal.lastMessageAt != null)
                        Text(DateFormat.MMMd().add_jm().format(deal.lastMessageAt!), style: textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    deal.lastMessage ?? l10n.chatNoMessagesYet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      ListingTypePill(kind: _pillKind),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          deal.drugTradeName,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                          decoration: BoxDecoration(color: badge.$2, borderRadius: BorderRadius.circular(AppRadius.pill)),
                          child: Text(
                            _stateLabel(l10n),
                            style: textTheme.labelSmall?.copyWith(color: badge.$1, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
