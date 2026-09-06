import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n_extensions.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/listing_type_pill.dart';
import '../listing_summary.dart';

class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing, required this.onTap});

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
    final l10n = context.l10n;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumbnail(photoUrl: listing.photoUrl, isControlled: listing.isControlled),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          listing.tradeName,
                          style: textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ListingTypePill(kind: _pillKind),
                    ],
                  ),
                  if (listing.activeIngredient != null)
                    Text(listing.activeIngredient!, style: textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                  if (listing.price != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _PriceRow(price: listing.price!, discountPrice: listing.discountPrice),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_rounded, size: 13, color: AppColors.inkFaint),
                      const SizedBox(width: 4),
                      Text(l10n.listingQtyLabel(listing.quantity), style: textTheme.bodySmall),
                      const SizedBox(width: AppSpacing.md),
                      const Icon(Icons.event_rounded, size: 13, color: AppColors.inkFaint),
                      const SizedBox(width: 4),
                      Text(DateFormat.yMMMd().format(listing.expiryDate), style: textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 13, color: AppColors.inkFaint),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${listing.governorate} · ${listing.area}',
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ),
                      if (listing.distanceKm != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${listing.distanceKm!.toStringAsFixed(1)} km',
                          style: textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
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

/// Square photo thumbnail with a rounded-pill placeholder when the listing
/// has no photo — never blank space, always reads as a "card with an
/// image slot" even before a pharmacy uploads one.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.photoUrl, required this.isControlled});

  final String? photoUrl;
  final bool isControlled;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: SizedBox(
            width: 76,
            height: 76,
            child: photoUrl == null
                ? Container(
                    color: AppColors.primarySoft,
                    child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 30),
                  )
                : CachedNetworkImage(
                    imageUrl: photoUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 152,
                    memCacheHeight: 152,
                    placeholder: (context, url) => Container(color: AppColors.primarySoft),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.primarySoft,
                      child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 30),
                    ),
                  ),
          ),
        ),
        if (isControlled)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: AppColors.warnBg, shape: BoxShape.circle),
              child: const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warn),
            ),
          ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.price, this.discountPrice});

  final double price;
  final double? discountPrice;

  String _fmt(double v) => 'EGP ${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)}';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasDiscount = discountPrice != null && discountPrice! < price;
    if (!hasDiscount) {
      return Text(_fmt(price), style: textTheme.titleMedium?.copyWith(color: AppColors.primary));
    }
    return Row(
      children: [
        Text(
          _fmt(price),
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.inkFaint,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(_fmt(discountPrice!), style: textTheme.titleMedium?.copyWith(color: AppColors.primary)),
      ],
    );
  }
}
