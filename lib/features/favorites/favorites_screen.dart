import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_extensions.dart';
import '../../core/theme.dart';
import '../listings/listing_summary.dart';
import '../listings/widgets/listing_card.dart';
import 'favorites_controller.dart';

/// A pharmacy's saved (heart-favorited) listings — mirrors MyListingsScreen's
/// structure, minus the state filter chips (favorites don't need one).
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.favoritesTitle)),
      body: favorites.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.inkFaint),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.favoritesCouldntLoad, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => ref.read(favoritesControllerProvider.notifier).refresh(),
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
                    const Icon(Icons.favorite_border_rounded, size: 40, color: AppColors.inkFaint),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.favoritesEmpty, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.favoritesEmptyBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(favoritesControllerProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) => _FavoriteTile(listing: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({required this.listing});

  final ListingSummary listing;

  (Color, Color)? get _stateColors => switch (listing.state) {
        ListingState.available => null,
        ListingState.reserved => (AppColors.warn, AppColors.warnBg),
        ListingState.completed => (AppColors.inkSoft, AppColors.background),
        ListingState.cancelled => (AppColors.danger, AppColors.dangerBg),
      };

  @override
  Widget build(BuildContext context) {
    final colors = _stateColors;
    return Stack(
      children: [
        ListingCard(listing: listing, onTap: () => context.push('/listing/${listing.id}')),
        if (colors != null)
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
              decoration: BoxDecoration(color: colors.$2, borderRadius: BorderRadius.circular(AppRadius.pill)),
              child: Text(
                listing.state.label(context.l10n),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.$1, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}
