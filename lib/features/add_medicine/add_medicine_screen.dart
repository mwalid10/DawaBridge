import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/l10n_extensions.dart';
import '../../core/success_screen.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_gradient_button.dart';
import '../../core/widgets/glass_card.dart';
import '../drugs/drug.dart';
import '../drugs/drug_catalog_entry.dart';
import '../drugs/drug_catalog_search.dart';
import '../drugs/drugs_controller.dart';
import '../home/home_feed_controller.dart';
import '../listings/listing_summary.dart';
import '../search/search_controller.dart';
import 'add_listing_data.dart';
import 'add_medicine_controller.dart';

class AddMedicineScreen extends ConsumerStatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  ConsumerState<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends ConsumerState<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountPriceController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _submitting = false;
  String? _photoError;
  String? _submitError;
  // A freshly-created (possibly still is_pending) drug row resolved from
  // the alternatives picker won't be in drugsControllerProvider's cached
  // list (it excludes pending rows) — cache it here too so its chip shows
  // a real name instead of falling back to the raw uuid.
  final Map<String, Drug> _resolvedAlternatives = {};

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _discountPriceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _openDrugPicker() async {
    final l10n = context.l10n;
    final picked = await showModalBottomSheet<_DrugPickResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _DrugSearchSheet(),
    );
    if (picked == null) return;
    try {
      await ref.read(addMedicineControllerProvider.notifier).selectDrugByName(
            picked.tradeName,
            concentration: picked.concentration,
            company: picked.company,
            pharmaceuticalForm: picked.pharmaceuticalForm,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.addMedicineCouldntSelect)),
        );
      }
    }
  }

  /// The alternatives picker used to only offer the small, organically-grown
  /// `drugs` table (whatever's already been listed by some pharmacy before)
  /// — so a barter's accepted alternatives couldn't include most of the
  /// ~23,600-product catalog the main Medicine field can already search.
  /// Now searches the same drug_catalog, resolving each pick through
  /// find_or_create_drug just like the Medicine field does — see
  /// _AlternativesPickerSheet.
  Future<void> _openAlternativesPicker(AddListingData data) async {
    final allDrugs = ref.read(drugsControllerProvider).value ?? const <Drug>[];
    final selectedDrugs = allDrugs.where((d) => data.acceptedAlternatives.contains(d.id)).toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AlternativesPickerSheet(
        excludeDrugId: data.drug?.id,
        selectedDrugs: selectedDrugs,
        onToggle: (id) => ref.read(addMedicineControllerProvider.notifier).toggleAlternative(id),
        onResolved: (drug) => setState(() => _resolvedAlternatives[drug.id] = drug),
      ),
    );
  }

  Future<void> _pickExpiry() async {
    final l10n = context.l10n;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: l10n.fieldExpiryDate,
    );
    if (picked != null) {
      ref.read(addMedicineControllerProvider.notifier).setExpiry(picked);
    }
  }

  Future<void> _pickPhoto() async {
    final l10n = context.l10n;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final sizeBytes = await file.length();
    if (sizeBytes > 5 * 1024 * 1024) {
      setState(() => _photoError = l10n.kycFileTooLarge);
      return;
    }
    setState(() => _photoError = null);
    ref.read(addMedicineControllerProvider.notifier).setPhotoPath(file.path);
  }

  Future<void> _submit(AddListingData data) async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    if (!data.hasRequiredSelections) {
      setState(() => _submitError = l10n.addMedicineMissingFields);
      return;
    }
    final quantity = int.parse(_quantityController.text.trim());
    final priceText = _priceController.text.trim();
    final discountText = _discountPriceController.text.trim();
    final descriptionText = _descriptionController.text.trim();
    final notifier = ref.read(addMedicineControllerProvider.notifier);
    notifier.setPrice(priceText.isEmpty ? null : double.tryParse(priceText));
    notifier.setDiscountPrice(discountText.isEmpty ? null : double.tryParse(discountText));
    notifier.setDescription(descriptionText.isEmpty ? null : descriptionText);

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await notifier.submit(quantity: quantity);
      ref.invalidate(homeFeedControllerProvider);
      ref.invalidate(searchControllerProvider);
      notifier.reset();
      _quantityController.clear();
      _priceController.clear();
      _discountPriceController.clear();
      _descriptionController.clear();
      if (mounted) {
        context.push(
          '/success',
          extra: SuccessArgs(
            title: l10n.addMedicineSuccessTitle,
            message: l10n.addMedicineSuccessBody,
            ctaLabel: l10n.commonDone,
            onCta: () => context.go('/home'),
          ),
        );
      }
    } catch (e) {
      setState(() => _submitError = l10n.addMedicineCouldntCreate);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(addMedicineControllerProvider);
    final drugsAsync = ref.watch(drugsControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addMedicineTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppGradients.hero,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: const Icon(Icons.medication_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.addMedicineHeading, style: Theme.of(context).textTheme.headlineLarge),
                      Text(
                        l10n.addMedicineSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            GlassCard(
              child: InkWell(
                onTap: _openDrugPicker,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.fieldMedicine,
                    prefixIcon: const Icon(Icons.medication_liquid_rounded),
                    suffixIcon: const Icon(Icons.expand_more_rounded),
                  ),
                  child: Text(
                    data.drug?.tradeName ?? l10n.addMedicineTapToSearch,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
            if (data.drug != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _ReadOnlyField(
                      icon: Icons.factory_outlined,
                      label: l10n.fieldManufacturer,
                      value: data.drug!.company,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _ReadOnlyField(
                      icon: Icons.category_outlined,
                      label: l10n.fieldForm,
                      value: data.drug!.pharmaceuticalForm,
                    ),
                  ),
                ],
              ),
            ],
            if (data.isControlledBlocked) ...[
              const SizedBox(height: AppSpacing.lg),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(color: AppColors.dangerBg, shape: BoxShape.circle),
                          child: const Icon(Icons.block_rounded, color: AppColors.danger, size: 22),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(l10n.addMedicineControlledTitle, style: Theme.of(context).textTheme.titleMedium),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.addMedicineControlledBody(
                        '${data.drug!.tradeName}${data.drug!.activeIngredient != null ? " (${data.drug!.activeIngredient})" : ""}',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton(
                      onPressed: () => ref.read(addMedicineControllerProvider.notifier).clearDrug(),
                      child: Text(l10n.addMedicineChooseDifferent),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.lg),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.fieldListingType, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    SegmentedButton<ListingType>(
                      style: SegmentedButton.styleFrom(
                        backgroundColor: AppColors.background,
                        selectedBackgroundColor: AppColors.primary,
                        selectedForegroundColor: Colors.white,
                        foregroundColor: AppColors.inkSoft,
                        side: const BorderSide(color: AppColors.divider),
                      ),
                      segments: [
                        ButtonSegment(value: ListingType.sell, icon: const Icon(Icons.sell_rounded, size: 16), label: Text(l10n.listingTypeSell)),
                        ButtonSegment(value: ListingType.buy, icon: const Icon(Icons.shopping_bag_rounded, size: 16), label: Text(l10n.listingTypeBuy)),
                        ButtonSegment(value: ListingType.barter, icon: const Icon(Icons.swap_horiz_rounded, size: 16), label: Text(l10n.listingTypeExchange)),
                      ],
                      selected: data.type == null ? const {} : {data.type!},
                      emptySelectionAllowed: true,
                      onSelectionChanged: (selection) {
                        if (selection.isNotEmpty) {
                          ref.read(addMedicineControllerProvider.notifier).selectType(selection.first);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l10n.fieldQuantity, prefixIcon: const Icon(Icons.numbers_rounded)),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null || n <= 0) return l10n.addMedicineQuantityValidator;
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: l10n.fieldPriceEgp, prefixIcon: const Icon(Icons.payments_rounded)),
                            validator: (v) {
                              if ((v ?? '').trim().isEmpty) return null;
                              return double.tryParse(v!.trim()) == null ? l10n.listingPriceValidator : null;
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextFormField(
                            controller: _discountPriceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: l10n.fieldDiscountPrice, prefixIcon: const Icon(Icons.local_offer_rounded)),
                            validator: (v) {
                              if ((v ?? '').trim().isEmpty) return null;
                              final n = double.tryParse(v!.trim());
                              if (n == null) return l10n.listingPriceValidator;
                              final price = double.tryParse(_priceController.text.trim());
                              if (price == null) return l10n.listingPriceValidator;
                              if (n > price) return l10n.addMedicineDiscountExceeds;
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l10n.fieldDescription,
                        hintText: l10n.addMedicineDescriptionHint,
                        prefixIcon: const Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(data.expiryDate == null ? l10n.fieldExpiryDate : DateFormat.yMMMd().format(data.expiryDate!)),
                      subtitle: data.expiryDate == null ? Text(l10n.addMedicineExpiryHint) : null,
                      leading: const Icon(Icons.event_rounded, color: AppColors.primary),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                      onTap: _pickExpiry,
                    ),
                    if (data.type == ListingType.barter) ...[
                      const SizedBox(height: AppSpacing.md),
                      const Divider(height: 1),
                      const SizedBox(height: AppSpacing.lg),
                      Text(l10n.listingAcceptedAlternatives, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final id in data.acceptedAlternatives)
                            Chip(
                              label: Text(
                                (drugsAsync.value ?? const <Drug>[]).where((d) => d.id == id).firstOrNull?.tradeName ??
                                    _resolvedAlternatives[id]?.tradeName ??
                                    id,
                              ),
                              onDeleted: () => ref.read(addMedicineControllerProvider.notifier).toggleAlternative(id),
                              backgroundColor: AppColors.primarySoft,
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.add_rounded, size: 16),
                            label: Text(l10n.addMedicineAddAlternative),
                            onPressed: () => _openAlternativesPicker(data),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              GlassCard(
                child: InkWell(
                  onTap: _pickPhoto,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: SizedBox(
                    height: 96,
                    width: double.infinity,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            data.photoPath == null ? Icons.add_a_photo_rounded : Icons.check_circle_rounded,
                            color: data.photoPath == null ? AppColors.primary : AppColors.good,
                            size: 26,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            data.photoPath == null ? l10n.addMedicineAddPhoto : l10n.addMedicinePhotoAttached,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_photoError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_photoError!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger)),
              ],
              if (_submitError != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Text(_submitError!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger)),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              AppGradientButton(
                onPressed: _submitting ? null : () => _submit(data),
                isLoading: _submitting,
                child: Text(l10n.addMedicineCreateListing),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What the search sheet hands back — either a catalog match (carrying its
/// concentration/company/pharmaceutical_form so those can auto-fill) or a
/// name the user typed freehand that isn't in the catalog at all.
class _DrugPickResult {
  const _DrugPickResult({required this.tradeName, this.concentration, this.company, this.pharmaceuticalForm});

  factory _DrugPickResult.fromCatalog(DrugCatalogEntry entry) => _DrugPickResult(
        tradeName: entry.displayName,
        concentration: entry.concentration,
        company: entry.company,
        pharmaceuticalForm: entry.pharmaceuticalForm,
      );

  final String tradeName;
  final String? concentration;
  final String? company;
  final String? pharmaceuticalForm;
}

/// Search-as-you-type over the drug_catalog reference table (see
/// drug_catalog_search.dart), with a "use this name" fallback for a
/// medicine that isn't in the catalog — same Timer-debounce pattern as
/// SearchScreen's query field.
class _DrugSearchSheet extends StatefulWidget {
  const _DrugSearchSheet();

  @override
  State<_DrugSearchSheet> createState() => _DrugSearchSheetState();
}

class _DrugSearchSheetState extends State<_DrugSearchSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<DrugCatalogEntry> _results = const [];
  bool _loading = false;
  List<DrugCatalogEntry> _initialResults = const [];
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final results = await fetchInitialDrugCatalog();
      if (mounted) setState(() => _initialResults = results);
    } catch (_) {
      // Silent — the empty-state list just stays empty; typing to search
      // still works independently of this best-effort preload.
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final q = value.trim();
      if (q.isEmpty) {
        setState(() {
          _results = const [];
          _loading = false;
        });
        return;
      }
      setState(() => _loading = true);
      try {
        final results = await searchDrugCatalog(q);
        if (mounted && _controller.text.trim() == q) {
          setState(() {
            _results = results;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trimmed = _query.trim();
    final exactMatch = _results.any((e) => e.displayName.toLowerCase() == trimmed.toLowerCase());

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: l10n.addMedicineSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: trimmed.isEmpty
                    ? (_initialLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            controller: scrollController,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: Text(
                                  l10n.addMedicineSearchPrompt,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              for (final entry in _initialResults) _DrugEntryTile(entry: entry),
                            ],
                          ))
                    : ListView(
                        controller: scrollController,
                        children: [
                          if (!exactMatch)
                            ListTile(
                              leading: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                              title: Text(l10n.addMedicineUseCustom(trimmed)),
                              subtitle: Text(l10n.addMedicineNotInCatalog),
                              onTap: () => Navigator.of(context).pop(_DrugPickResult(tradeName: trimmed)),
                            ),
                          for (final entry in _results) _DrugEntryTile(entry: entry),
                          if (!_loading && _results.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                              child: Text(
                                l10n.addMedicineNoMatches,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shared row for a catalog match, used by both the pre-typing browse list
/// and the live search results.
class _DrugEntryTile extends StatelessWidget {
  const _DrugEntryTile({required this.entry});

  final DrugCatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(entry.displayName),
      subtitle: Text([
        if (entry.company != null) entry.company!,
        if (entry.pharmaceuticalForm != null) entry.pharmaceuticalForm!,
      ].join(' · ')),
      onTap: () => Navigator.of(context).pop(_DrugPickResult.fromCatalog(entry)),
    );
  }
}

String _catalogKey(String tradeName, String? concentration) =>
    '${tradeName.trim().toLowerCase()}|${(concentration ?? '').trim().toLowerCase()}';

/// Search-as-you-type over the same drug_catalog as the main Medicine field
/// (_DrugSearchSheet), multi-select instead of single-pick. Each tap
/// resolves the entry through find_or_create_drug (same RPC, same
/// converge-on-one-row-by-name+concentration behavior — see
/// 0022_drug_catalog.sql) and toggles it in the accepted-alternatives list;
/// [selectedDrugs] (already-resolved Drug rows for the current selection,
/// looked up by the caller from drugsControllerProvider) seeds a
/// name+concentration key set so previously-picked items show checked
/// immediately, without spending an RPC call just to render the list.
class _AlternativesPickerSheet extends StatefulWidget {
  const _AlternativesPickerSheet({
    required this.excludeDrugId,
    required this.selectedDrugs,
    required this.onToggle,
    required this.onResolved,
  });

  final String? excludeDrugId;
  final List<Drug> selectedDrugs;
  final void Function(String drugId) onToggle;
  final void Function(Drug drug) onResolved;

  @override
  State<_AlternativesPickerSheet> createState() => _AlternativesPickerSheetState();
}

class _AlternativesPickerSheetState extends State<_AlternativesPickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<DrugCatalogEntry> _results = const [];
  List<DrugCatalogEntry> _initialResults = const [];
  bool _loading = false;
  bool _initialLoading = true;
  bool _resolving = false;
  late final Set<String> _selectedIds;
  late final Map<String, String> _resolvedIdByKey;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.selectedDrugs.map((d) => d.id).toSet();
    _resolvedIdByKey = {for (final d in widget.selectedDrugs) _catalogKey(d.tradeName, d.concentration): d.id};
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final results = await fetchInitialDrugCatalog();
      if (mounted) setState(() => _initialResults = results);
    } catch (_) {
      // Best-effort preload — typing to search still works independently.
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final q = value.trim();
      if (q.isEmpty) {
        setState(() {
          _results = const [];
          _loading = false;
        });
        return;
      }
      setState(() => _loading = true);
      try {
        final results = await searchDrugCatalog(q);
        if (mounted && _controller.text.trim() == q) {
          setState(() {
            _results = results;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  Future<void> _toggleEntry(DrugCatalogEntry entry) async {
    if (_resolving) return;
    final l10n = context.l10n;
    setState(() => _resolving = true);
    try {
      final rows = await supabase.rpc('find_or_create_drug', params: {
        'p_trade_name': entry.tradeName,
        'p_concentration': entry.concentration,
        'p_company': entry.company,
        'p_pharmaceutical_form': entry.pharmaceuticalForm,
      });
      final row = (rows as List<dynamic>).first as Map<String, dynamic>;
      final drug = Drug.fromJson(row);
      if (drug.id == widget.excludeDrugId || drug.isControlled) return;
      widget.onResolved(drug);
      widget.onToggle(drug.id);
      setState(() {
        _resolvedIdByKey[_catalogKey(drug.tradeName, drug.concentration)] = drug.id;
        if (_selectedIds.contains(drug.id)) {
          _selectedIds.remove(drug.id);
        } else {
          _selectedIds.add(drug.id);
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.addMedicineCouldntSelect)));
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trimmed = _query.trim();
    final items = trimmed.isEmpty ? _initialResults : _results;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            children: [
              Text(l10n.listingAcceptedAlternatives, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: l10n.addMedicineSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: (trimmed.isEmpty && _initialLoading)
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                        ? Center(
                            child: Text(l10n.addMedicineNoMatches, style: Theme.of(context).textTheme.bodySmall),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: items.length,
                            itemBuilder: (context, i) {
                              final entry = items[i];
                              final key = _catalogKey(entry.tradeName, entry.concentration);
                              final resolvedId = _resolvedIdByKey[key];
                              final checked = resolvedId != null && _selectedIds.contains(resolvedId);
                              return CheckboxListTile(
                                title: Text(entry.displayName),
                                subtitle: Text([
                                  if (entry.company != null) entry.company!,
                                  if (entry.pharmaceuticalForm != null) entry.pharmaceuticalForm!,
                                ].join(' · ')),
                                value: checked,
                                onChanged: _resolving ? null : (_) => _toggleEntry(entry),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Displays Manufacturer/Form under the Medicine field once a drug is
/// selected — read-only since these come from drug_catalog or an existing
/// `drugs` row, not something the pharmacist types (see
/// find_or_create_drug in 0022_drug_catalog.sql).
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20)),
      child: Text(
        value ?? '—',
        style: Theme.of(context).textTheme.bodyMedium,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
