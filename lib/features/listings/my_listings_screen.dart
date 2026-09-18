import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_extensions.dart';
import '../../core/theme.dart';
import 'listing_summary.dart';
import 'my_listings_controller.dart';
import 'widgets/listing_card.dart';

/// A pharmacy's own listings across every state (available/reserved/
/// completed/cancelled) — search_listings only ever shows 'available'
/// listings (it's the public browse feed), so this is the one place a
/// pharmacy can see what they've listed historically, not just what's
/// currently live.
class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  ListingState? _filter;

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(myListingsControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myListingsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                _FilterChip(
                  label: l10n.commonAll,
                  selected: _filter == null,
                  onTap: () {
                    setState(() => _filter = null);
                    ref.read(myListingsControllerProvider.notifier).setStateFilter(null);
                  },
                ),
                for (final s in ListingState.values)
                  _FilterChip(
                    label: s.label(l10n),
                    selected: _filter == s,
                    onTap: () {
                      setState(() => _filter = s);
                      ref.read(myListingsControllerProvider.notifier).setStateFilter(s);
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: listings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.inkFaint),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.myListingsCouldntLoad, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: () => ref.read(myListingsControllerProvider.notifier).refresh(),
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
                          const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.inkFaint),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _filter == null ? l10n.myListingsEmpty : l10n.myListingsEmptyFiltered(_filter!.label(l10n).toLowerCase()),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            l10n.myListingsEmptyBody,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(myListingsControllerProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, i) => _MyListingTile(listing: items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primarySoft,
      labelStyle: TextStyle(color: selected ? AppColors.primaryDark : AppColors.inkSoft, fontWeight: FontWeight.w600),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.divider),
    );
  }
}

class _MyListingTile extends StatelessWidget {
  const _MyListingTile({required this.listing});

  final ListingSummary listing;

  (Color, Color) get _stateColors => switch (listing.state) {
        ListingState.available => (AppColors.good, AppColors.goodBg),
        ListingState.reserved => (AppColors.warn, AppColors.warnBg),
        ListingState.completed => (AppColors.inkSoft, AppColors.background),
        ListingState.cancelled => (AppColors.danger, AppColors.dangerBg),
      };

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _stateColors;
    return Stack(
      children: [
        ListingCard(listing: listing, onTap: () => context.push('/listing/${listing.id}')),
        // Top-left, over the thumbnail — the only corner ListingCard never
        // draws anything in (the controlled-substance icon uses the
        // thumbnail's top-right, and text content starts well right of
        // this point regardless of card width, so this never collides).
        Positioned(
          top: AppSpacing.sm,
          left: AppSpacing.sm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
            child: Text(
              listing.state.label(context.l10n),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        // Edit/remove. There was no entry point for either: price was the
        // only mutable field (via a sheet on the detail screen) and there
        // was no delete path at all, so a listing with a typo'd quantity or
        // expiry stayed wrong and public forever.
        if (listing.state == ListingState.available)
          Positioned(
            top: AppSpacing.xs,
            right: AppSpacing.xs,
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                tooltip: context.l10n.editListingTitle,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.inkSoft),
                onPressed: () => context.push('/listing/${listing.id}/edit'),
              ),
            ),
          ),
      ],
    );
  }
}
