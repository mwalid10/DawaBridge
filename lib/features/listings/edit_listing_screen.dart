import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_error.dart';
import '../../core/l10n_extensions.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_gradient_button.dart';
import '../../core/widgets/glass_card.dart';
import 'listing_detail_controller.dart';
import 'listing_summary.dart';
import 'my_listings_controller.dart';

/// Edit or remove one of your own listings.
///
/// Before this, the *only* mutable field on a listing was price (and its
/// discount), changed through a bottom sheet on the detail screen with a
/// direct PostgREST update. Quantity, expiry date, and description were
/// fixed at creation — so a listing entered with the wrong quantity or a
/// typo'd expiry stayed wrong and stayed public. There was no delete at
/// all: `listings` had no DELETE policy, so a seller could not take their
/// own listing down by any means.
///
/// Both paths now go through validated RPCs (`update_my_listing` /
/// `delete_my_listing`, migration 0036) rather than a raw table write, so
/// the price/discount relationship, the expiry rule and the "can't edit
/// while someone has it reserved" rule are enforced server-side.
class EditListingScreen extends ConsumerStatefulWidget {
  const EditListingScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends ConsumerState<EditListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _discount = TextEditingController();
  final _description = TextEditingController();

  DateTime? _expiry;
  bool _seeded = false;
  bool _saving = false;
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _discount.dispose();
    _description.dispose();
    super.dispose();
  }

  void _seed(ListingSummary listing) {
    if (_seeded) return;
    _seeded = true;
    _quantity.text = listing.quantity.toString();
    _price.text = listing.price?.toStringAsFixed(2) ?? '';
    _discount.text = listing.discountPrice?.toStringAsFixed(2) ?? '';
    _description.text = listing.description ?? '';
    _expiry = listing.expiryDate;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final expiry = _expiry;
    if (expiry == null) return;

    final l10n = context.l10n;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final discountText = _discount.text.trim();
      final priceText = _price.text.trim();
      await supabase.rpc('update_my_listing', params: {
        'p_listing_id': widget.listingId,
        'p_quantity': int.parse(_quantity.text.trim()),
        'p_expiry_date': expiry.toIso8601String().split('T').first,
        'p_price': priceText.isEmpty ? null : double.parse(priceText),
        'p_discount_price': discountText.isEmpty ? null : double.parse(discountText),
        'p_description': _description.text.trim(),
        'p_clear_discount': discountText.isEmpty,
      });

      ref.invalidate(listingDetailControllerProvider(widget.listingId));
      ref.invalidate(myListingsControllerProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.editListingSaved)));
      context.pop();
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(l10n, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.editListingDeleteTitle),
        content: Text(l10n.editListingDeleteWarning),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.commonCancel)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.editListingDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await supabase.rpc('delete_my_listing', params: {'p_listing_id': widget.listingId});
      ref.invalidate(myListingsControllerProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.editListingDeleted)));
      context.go('/my-listings');
    } catch (error) {
      // Refused while a request or reservation is live, so the counterparty
      // isn't left holding a deal on a listing that vanished.
      if (mounted) setState(() => _error = AppError.message(l10n, error));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry != null && _expiry!.isAfter(now) ? _expiry! : now.add(const Duration(days: 30)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final listingAsync = ref.watch(listingDetailControllerProvider(widget.listingId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editListingTitle)),
      body: listingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Text(AppError.message(l10n, error), textAlign: TextAlign.center),
          ),
        ),
        data: (listing) {
          _seed(listing);

          // Only an available listing is editable; once it's reserved the
          // buyer has agreed terms against these numbers.
          if (listing.state != ListingState.available) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.inkFaint),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      listing.state == ListingState.reserved
                          ? l10n.editListingReserved
                          : l10n.editListingClosed,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(listing.tradeName, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: AppSpacing.xl),
                      TextFormField(
                        controller: _quantity,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: l10n.fieldQuantityLabel),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n <= 0 || n > 1000000) return l10n.editListingQuantityValidator;
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      InkWell(
                        onTap: _pickExpiry,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: InputDecorator(
                          decoration: InputDecoration(labelText: l10n.fieldExpiryDate),
                          child: Text(
                            _expiry == null ? '—' : DateFormat.yMMMd().format(_expiry!),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: l10n.fieldPriceEgp),
                        validator: (v) {
                          final text = (v ?? '').trim();
                          if (text.isEmpty) return null;
                          final n = double.tryParse(text);
                          if (n == null || n <= 0) return l10n.listingPriceValidator;
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _discount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: l10n.fieldDiscountPriceOptional),
                        validator: (v) {
                          final text = (v ?? '').trim();
                          if (text.isEmpty) return null;
                          final n = double.tryParse(text);
                          if (n == null || n <= 0) return l10n.listingPriceValidator;
                          final price = double.tryParse(_price.text.trim());
                          if (price == null) return l10n.editListingDiscountNeedsPrice;
                          if (n > price) return l10n.listingDiscountExceedsPrice;
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _description,
                        maxLines: 4,
                        maxLength: 1000,
                        decoration: InputDecoration(labelText: l10n.fieldDescriptionOptional),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                AppGradientButton(
                  onPressed: _saving || _deleting ? null : _save,
                  isLoading: _saving,
                  child: Text(l10n.commonSave),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextButton.icon(
                  onPressed: _saving || _deleting ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  icon: _deleting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.danger),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 20),
                  label: Text(l10n.editListingDelete),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
