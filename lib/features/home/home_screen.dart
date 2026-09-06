import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n_extensions.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_hero_background.dart';
import '../../core/widgets/listing_type_pill.dart';
import '../../core/widgets/notification_bell_button.dart';
import '../listings/listing_summary.dart';
import '../profile/profile_controller.dart';
import 'home_feed_controller.dart';
import 'home_stats_controller.dart';
import 'price_increased_controller.dart';
import 'price_increased_listing.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.onNavigateToTab});

  /// Lets the hero's quick-action chips jump to another AppShell tab
  /// (Search/Add/Chat) without HomeScreen needing to know about routing.
  final ValueChanged<int>? onNavigateToTab;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(homeFeedControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(homeFeedControllerProvider.notifier).refresh();
          ref.invalidate(priceIncreasedControllerProvider);
          ref.invalidate(homeStatsControllerProvider);
          ref.invalidate(ratingSummaryControllerProvider);
        },
        // The hero (profile/stats/price-increased — each already handles its
        // own loading state independently) used to be gated behind this
        // screen's outer `feed.when`, so the whole page stayed a blank
        // spinner until the "Latest Medicines" fetch specifically finished,
        // even if every other section had already resolved. Only that one
        // section needs to wait on `feed` now.
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            _HomeHero(onNavigateToTab: widget.onNavigateToTab),
            feed.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.inkFaint),
                      const SizedBox(height: AppSpacing.md),
                      Text(l10n.homeCouldntLoadListings, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton(
                        onPressed: () => ref.read(homeFeedControllerProvider.notifier).refresh(),
                        child: Text(l10n.commonRetry),
                      ),
                    ],
                  ),
                ),
              ),
              data: (listings) => _LatestMedicinesSection(listings: listings, onNavigateToTab: widget.onNavigateToTab),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHero extends ConsumerWidget {
  const _HomeHero({this.onNavigateToTab});

  final ValueChanged<int>? onNavigateToTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(pharmacyProfileControllerProvider);
    final priceIncreased = ref.watch(priceIncreasedControllerProvider);
    final stats = ref.watch(homeStatsControllerProvider);
    final ratings = ref.watch(ratingSummaryControllerProvider);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GradientHeroBackground(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.homeWelcomeBack, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            profile.when(
                              loading: () => const SizedBox.shrink(),
                              error: (_, _) => const SizedBox.shrink(),
                              data: (pharmacy) => Text(
                                pharmacy.name,
                                style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Theme(
                        data: ThemeData(iconTheme: const IconThemeData(color: Colors.white)),
                        child: const NotificationBellButton(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroStat(
                          value: stats.maybeWhen(data: (s) => '${s.activeListings}', orElse: () => '—'),
                          label: l10n.homeStatActiveListings,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _HeroStat(
                          value: stats.maybeWhen(data: (s) => '${s.completedExchanges}', orElse: () => '—'),
                          label: l10n.homeStatExchanges,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _HeroStat(
                          value: ratings.maybeWhen(
                            data: (s) => s.avgStars?.toStringAsFixed(1) ?? '—',
                            orElse: () => '—',
                          ),
                          label: l10n.homeStatRating,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(child: _QuickAction(icon: Icons.search_rounded, label: l10n.homeQuickSearch, onTap: () => onNavigateToTab?.call(1))),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _QuickAction(icon: Icons.add_circle_outline_rounded, label: l10n.homeQuickAdd, onTap: () => onNavigateToTab?.call(2))),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _QuickAction(icon: Icons.chat_bubble_outline_rounded, label: l10n.homeQuickChat, onTap: () => onNavigateToTab?.call(3))),
              ],
            ),
          ),
        ),
        priceIncreased.maybeWhen(
          data: (items) => items.isEmpty ? const _PriceIncreasedEmpty() : _PriceIncreasedRow(items: items),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Compact glass chip for the hero header's active-listings/exchanges/rating
/// stats — big bold number over a small label, three-across.
class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.trailingLabel, required this.trailingIcon, required this.onTap});

  final String label;
  final String trailingLabel;
  final IconData trailingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(trailingLabel, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.primary)),
              const SizedBox(width: 2),
              Icon(trailingIcon, size: 16, color: AppColors.primary),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

/// Shown instead of the price-increased carousel once it's known to be
/// empty (rather than hiding the whole section) — so the feature stays
/// visible per the design even before an admin has published any alerts.
class _PriceIncreasedEmpty extends StatelessWidget {
  const _PriceIncreasedEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.homePriceIncreased, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.creamSoft.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.creamDark.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up_rounded, color: AppColors.warn, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.homeNoPriceAlerts,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceIncreasedRow extends StatelessWidget {
  const _PriceIncreasedRow({required this.items});

  final List<PriceIncreasedListing> items;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, color: AppColors.warn, size: 20),
              const SizedBox(width: 6),
              Expanded(child: Text(l10n.homePriceIncreased, style: Theme.of(context).textTheme.titleMedium)),
              TextButton(
                onPressed: () => context.push('/price-alerts'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                child: Text(l10n.homeSeeAll, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.primary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) {
              final item = items[i];
              return Container(
                width: 168,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: AppColors.dangerBg, shape: BoxShape.circle),
                          child: const Icon(Icons.trending_up_rounded, size: 14, color: AppColors.danger),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(AppRadius.pill)),
                          child: Text(
                            '+${item.pctIncrease.toStringAsFixed(1)}%',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      item.tradeName,
                      style: Theme.of(context).textTheme.labelLarge,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (item.concentration != null)
                      Text(
                        item.concentration!,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('EGP ${item.newPrice.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          item.oldPrice.toStringAsFixed(0),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(decoration: TextDecoration.lineThrough, color: AppColors.inkFaint),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Home screen's curated preview of nearby listings — a small horizontal
/// showcase (photo-forward cards) rather than a long vertical feed; full
/// browsing lives on the Search tab via "View All".
class _LatestMedicinesSection extends StatelessWidget {
  const _LatestMedicinesSection({required this.listings, this.onNavigateToTab});

  final List<ListingSummary> listings;
  final ValueChanged<int>? onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _SectionHeader(
              label: l10n.homeLatestMedicines,
              trailingLabel: l10n.homeViewAll,
              trailingIcon: Icons.north_east_rounded,
              onTap: () => onNavigateToTab?.call(1),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (listings.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: GlassCard(
                child: Column(
                  children: [
                    const Icon(Icons.inventory_2_rounded, size: 40, color: AppColors.primary),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.homeNoListingsNearby, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.homeAddFirstMedicine,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 240,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: listings.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, i) {
                  final listing = listings[i];
                  return _MedicineShowcaseCard(
                    listing: listing,
                    onTap: () => context.push('/listing/${listing.id}'),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MedicineShowcaseCard extends StatelessWidget {
  const _MedicineShowcaseCard({required this.listing, required this.onTap});

  final ListingSummary listing;
  final VoidCallback onTap;

  ListingTypePillKind get _pillKind => switch (listing.type) {
        ListingType.sell => ListingTypePillKind.sell,
        ListingType.buy => ListingTypePillKind.buy,
        ListingType.barter => ListingTypePillKind.barter,
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        width: 168,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: listing.photoUrl == null
                      ? Container(
                          color: AppColors.primarySoft,
                          alignment: Alignment.center,
                          child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 32),
                        )
                      : CachedNetworkImage(
                          imageUrl: listing.photoUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 336,
                          memCacheHeight: 220,
                          placeholder: (context, url) => Container(color: AppColors.primarySoft),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.primarySoft,
                            alignment: Alignment.center,
                            child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 32),
                          ),
                        ),
                ),
                Positioned(top: 8, left: 8, child: ListingTypePill(kind: _pillKind)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.tradeName, style: textTheme.labelLarge, overflow: TextOverflow.ellipsis, maxLines: 1),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.event_rounded, size: 12, color: AppColors.inkFaint),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          DateFormat.yMMM().format(listing.expiryDate),
                          style: textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 12, color: AppColors.inkFaint),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          listing.distanceKm != null ? '${listing.distanceKm!.toStringAsFixed(1)} km' : listing.area,
                          style: textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
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
