import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n_extensions.dart';
import '../../../core/theme.dart';
import '../listing_summary.dart';
import 'listing_card.dart';

/// A listing on the owner's own My listings screen: the shared [ListingCard]
/// plus the two things only the owner sees — what state it's in, and a way
/// to edit it.
///
/// Both of those used to be floated over the card's corners with physical
/// `left` and `right`, on the reasoning that nothing else was drawn there.
/// That reasoning only held in English. In Arabic the card mirrors but the
/// overlays didn't: the state chip landed on the listing type pill, and the
/// edit button landed on the photo, on top of the controlled-substance
/// badge already in that corner.

class MyListingTile extends StatelessWidget {
  const MyListingTile({super.key, required this.listing});

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
        ListingCard(
          listing: listing,
          onTap: () => context.push('/listing/${listing.id}'),
          // Laid out in the card's own title row rather than floated over
          // its corner. As an overlay this landed on top of the listing
          // type pill in English, and on top of the photo in Arabic, where
          // `right` is where the thumbnail lives.
          //
          // Edit/remove had no entry point at all before: price was the only
          // mutable field, via a sheet on the detail screen, so a listing
          // with a typo'd quantity or expiry stayed wrong and public.
          trailing: listing.state == ListingState.available
              ? IconButton(
                  tooltip: context.l10n.editListingTitle,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.inkSoft),
                  onPressed: () => context.push('/listing/${listing.id}/edit'),
                )
              : null,
        ),
        // Over the thumbnail's outer corner — `start`, not `left`, because
        // the thumbnail is the card's leading child and so changes sides
        // with the text direction. The controlled-substance badge takes the
        // thumbnail's inner corner, also directionally, so the two can't
        // meet.
        PositionedDirectional(
          top: AppSpacing.sm,
          start: AppSpacing.sm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
            child: Text(
              listing.state.label(context.l10n),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
