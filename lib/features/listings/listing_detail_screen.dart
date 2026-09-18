import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_error.dart';
import '../../core/l10n_extensions.dart';
import '../../core/rpc.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_gradient_button.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/listing_type_pill.dart';
import '../deals/deals_controller.dart';
import '../drugs/drugs_controller.dart';
import '../favorites/favorite_controller.dart';
import 'listing_detail_controller.dart';
import 'listing_summary.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  bool _requesting = false;

  /// Shared entry point for both the "Contact" and "Exchange" actions —
  /// this app only has one seller-contact mechanism (a request that opens a
  /// deal-scoped chat thread), so both buttons lead here; [greeting] just
  /// pre-fills a different default message depending on which was tapped.
  Future<void> _requestListing({required String greeting}) async {
    final l10n = context.l10n;
    final messageController = TextEditingController();
    final send = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.listingMessageSeller, style: Theme.of(sheetContext).textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.listingMessageSellerBody,
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: InputDecoration(hintText: greeting),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppGradientButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: Text(l10n.listingSendRequest),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (send != true || !mounted) {
      messageController.dispose();
      return;
    }

    setState(() => _requesting = true);
    try {
      final message = messageController.text.trim().isEmpty ? greeting : messageController.text;
      final dealId = await requestListing(widget.listingId, message: message);
      ref.invalidate(dealsControllerProvider);
      // The listing stays 'available' until the seller accepts now, so
      // refresh it rather than assuming it just went reserved.
      ref.invalidate(listingDetailControllerProvider(widget.listingId));
      if (!mounted) return;
      context.push('/chat/$dealId');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppError.message(l10n, error))));
    } finally {
      messageController.dispose();
      if (mounted) setState(() => _requesting = false);
    }
  }

  ListingTypePillKind _pillKind(ListingType type) => switch (type) {
        ListingType.sell => ListingTypePillKind.sell,
        ListingType.buy => ListingTypePillKind.buy,
        ListingType.barter => ListingTypePillKind.barter,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final detail = ref.watch(listingDetailControllerProvider(widget.listingId));
    final drugs = ref.watch(drugsControllerProvider);
    final uid = supabase.auth.currentUser?.id;

    return Scaffold(
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => SafeArea(
          child: Column(
            children: [
              const Align(alignment: Alignment.topLeft, child: _BackButton()),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // A listing that's been completed or taken down is a
                      // routine outcome here — favourites keep listings of
                      // every state, and notifications deep-link to them —
                      // not a connection failure, so it gets its own icon
                      // and message instead of "couldn't load".
                      Icon(
                        error is NotFoundException
                            ? Icons.inventory_2_outlined
                            : Icons.cloud_off_rounded,
                        size: 40,
                        color: AppColors.inkFaint,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        error is NotFoundException
                            ? l10n.errorListingUnavailable
                            : l10n.listingCouldntLoad,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(listingDetailControllerProvider(widget.listingId)),
                        child: Text(l10n.commonRetry),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        data: (listing) {
          final alternativeNames = drugs.value == null
              ? const <String>[]
              : listing.acceptedAlternatives
                  .map((id) {
                    final match = drugs.value!.where((d) => d.id == id);
                    return match.isEmpty ? null : match.first.tradeName;
                  })
                  .whereType<String>()
                  .toList();
          final hasDiscount = listing.discountPrice != null && listing.price != null && listing.discountPrice! < listing.price!;
          final pctOff = hasDiscount ? ((1 - listing.discountPrice! / listing.price!) * 100).round() : null;

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Stack(
                children: [
                  _ListingPhoto(photoUrl: listing.photoUrl),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _BackButton(),
                          ListingTypePill(kind: _pillKind(listing.type)),
                          _FavoriteButton(listingId: listing.id),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(listing.tradeName, style: Theme.of(context).textTheme.headlineMedium),
                    if (listing.activeIngredient != null)
                      Text(listing.activeIngredient!, style: Theme.of(context).textTheme.bodyMedium),
                    if (listing.isControlled) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warn),
                          const SizedBox(width: 4),
                          Text(l10n.listingControlledSubstance, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warn)),
                        ],
                      ),
                    ],
                    if (listing.state != ListingState.available) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _StateBadge(state: listing.state),
                    ],
                    if (listing.price != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            decoration: BoxDecoration(
                              gradient: AppGradients.cta,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  'EGP ${(hasDiscount ? listing.discountPrice! : listing.price!).toStringAsFixed(0)}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                                if (hasDiscount) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    'EGP ${listing.price!.toStringAsFixed(0)}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.white70,
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (pctOff != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(AppRadius.pill)),
                              child: Text(
                                l10n.listingPercentOff(pctOff),
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        if (listing.distanceKm != null) ...[
                          const Icon(Icons.location_on_rounded, size: 15, color: AppColors.inkFaint),
                          const SizedBox(width: 4),
                          Text(l10n.listingDistanceAway(listing.distanceKm!.toStringAsFixed(1)), style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(width: AppSpacing.md),
                        ],
                        const Icon(Icons.event_rounded, size: 15, color: AppColors.inkFaint),
                        const SizedBox(width: 4),
                        Text(l10n.listingExpires(DateFormat.yMMMd().format(listing.expiryDate)), style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoCard(icon: Icons.category_rounded, label: l10n.fieldTypeLabel, value: listing.type.label(l10n)),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _InfoCard(
                            icon: Icons.opacity_rounded,
                            label: l10n.fieldConcentrationLabel,
                            value: listing.concentration ?? '—',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoCard(icon: Icons.inventory_2_rounded, label: l10n.fieldQuantityLabel, value: '${listing.quantity}'),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _InfoCard(
                            icon: Icons.event_rounded,
                            label: l10n.fieldExpiryDateLabel,
                            value: DateFormat.yMMMd().format(listing.expiryDate),
                          ),
                        ),
                      ],
                    ),
                    if (listing.company != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: _InfoCard(icon: Icons.factory_rounded, label: l10n.fieldManufacturer, value: listing.company!),
                      ),
                    ],
                    if (listing.pharmaceuticalForm != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: _InfoCard(icon: Icons.medication_liquid_rounded, label: l10n.fieldForm, value: listing.pharmaceuticalForm!),
                      ),
                    ],
                    if (listing.description != null && listing.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(l10n.fieldDescription, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text(listing.description!, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    // Owner actions. This used to be a price-only bottom
                    // sheet, which was the only mutable field anywhere — so
                    // a pharmacist opening their own listing to correct a
                    // wrong quantity or expiry date would reasonably
                    // conclude they still couldn't. It now opens the full
                    // editor (which also holds Delete), and the price form
                    // lives in exactly one place instead of two that could
                    // drift apart.
                    if (listing.pharmacyId == uid) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: listing.state == ListingState.available
                              ? () => context.push('/listing/${listing.id}/edit')
                              : null,
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: Text(
                            listing.price == null ? l10n.listingSetPrice : l10n.editListingTitle,
                          ),
                        ),
                      ),
                    ],
                    if (listing.type == ListingType.barter && alternativeNames.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.listingAcceptedAlternatives, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: alternativeNames
                                  .map((name) => Chip(label: Text(name), backgroundColor: AppColors.primarySoft))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _SellerCard(listing: listing),
                    const SizedBox(height: AppSpacing.xxl),
                    if (listing.pharmacyId == uid)
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.inkFaint),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(l10n.listingYourOwn, style: Theme.of(context).textTheme.bodySmall),
                          ),
                        ],
                      )
                    else if (listing.state != ListingState.available)
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.inkFaint),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              l10n.listingNoLongerAvailable,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _requesting ? null : () => _requestListing(greeting: l10n.listingGreetingInterested),
                              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                              label: Text(l10n.listingContact),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppGradientButton(
                              isLoading: _requesting,
                              onPressed: _requesting
                                  ? null
                                  : () => _requestListing(greeting: l10n.listingGreetingGoAhead),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(listing.type == ListingType.sell ? l10n.listingBuyNow : l10n.listingExchange),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.listingId});

  final String listingId;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      await ref.read(favoriteControllerProvider(listingId).notifier).toggle();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppError.message(l10n, error))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorited = ref.watch(favoriteControllerProvider(listingId)).value ?? false;
    final l10n = context.l10n;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: IconButton(
        tooltip: favorited ? l10n.listingUnfavoriteTooltip : l10n.listingFavoriteTooltip,
        icon: Icon(
          favorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: favorited ? AppColors.danger : AppColors.ink,
        ),
        onPressed: () => _toggle(context, ref),
      ),
    );
  }
}

/// Full-width hero photo at the top of the listing detail page — falls
/// back to a soft placeholder tile (same treatment as ListingCard's
/// thumbnail) when the pharmacy hasn't uploaded one.
class _ListingPhoto extends StatelessWidget {
  const _ListingPhoto({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: photoUrl == null
          ? Container(
              color: AppColors.primarySoft,
              alignment: Alignment.center,
              child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 56),
            )
          : CachedNetworkImage(
              imageUrl: photoUrl!,
              fit: BoxFit.cover,
              memCacheWidth: (MediaQuery.sizeOf(context).width * 2).round(),
              placeholder: (context, url) => Container(color: AppColors.primarySoft),
              errorWidget: (context, url, error) => Container(
                color: AppColors.primarySoft,
                alignment: Alignment.center,
                child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 56),
              ),
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.creamSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.listing});

  final ListingSummary listing;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary,
            child: Text(
              listing.pharmacyName.isEmpty ? '?' : listing.pharmacyName[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(listing.pharmacyName, style: Theme.of(context).textTheme.titleMedium),
                Text('${listing.governorate} · ${listing.area}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.inkFaint),
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});

  final ListingState state;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (state) {
      ListingState.reserved => (AppColors.warn, AppColors.warnBg),
      ListingState.completed => (AppColors.good, AppColors.goodBg),
      ListingState.cancelled => (AppColors.danger, AppColors.dangerBg),
      ListingState.available => (AppColors.primary, AppColors.primarySoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(
        state.label(context.l10n),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
