import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/egypt_governorates.dart';
import '../../core/app_error.dart';
import '../../core/l10n_extensions.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_gradient_button.dart';
import '../../core/widgets/glass_card.dart';
import '../drugs/drug_catalog_search.dart';
import '../listings/listing_summary.dart';
import '../listings/widgets/listing_card.dart';
import 'listing_alerts.dart';
import 'search_controller.dart';
import 'widgets/search_map_view.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  Timer? _debounce;
  bool _loadingMore = false;
  bool _mapView = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final controller = ref.read(searchControllerProvider.notifier);
      controller.applyFilters(controller.filters.copyWith(query: value));
    });
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      await ref.read(searchControllerProvider.notifier).loadMore();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.searchLoadMoreError)),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openFilterSheet() async {
    final controller = ref.read(searchControllerProvider.notifier);
    final newFilters = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FilterSheet(filters: controller.filters),
    );
    if (newFilters != null) controller.applyFilters(newFilters);
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchControllerProvider);
    final controllerNotifier = ref.watch(searchControllerProvider.notifier);
    final filters = controllerNotifier.filters;
    final hasMore = controllerNotifier.hasMore;
    final l10n = context.l10n;
    final activeFilterCount = [
      filters.type != null,
      filters.governorate != null,
      filters.concentration.isNotEmpty,
      filters.expiryBefore != null,
    ].where((x) => x).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.searchTitle),
        actions: [
          IconButton(
            tooltip: _mapView ? l10n.searchListView : l10n.searchMapViewTooltip,
            icon: Icon(_mapView ? Icons.list_rounded : Icons.map_outlined, color: AppColors.primary),
            onPressed: () => setState(() => _mapView = !_mapView),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: _onQueryChanged,
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Badge(
                  isLabelVisible: activeFilterCount > 0,
                  label: Text('$activeFilterCount'),
                  backgroundColor: AppColors.primary,
                  child: IconButton.filledTonal(
                    style: IconButton.styleFrom(backgroundColor: AppColors.primarySoft, foregroundColor: AppColors.primaryDark),
                    onPressed: _openFilterSheet,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                selected: controllerNotifier.nearest,
                onSelected: (_) => controllerNotifier.toggleNearest(),
                avatar: Icon(
                  Icons.near_me_rounded,
                  size: 16,
                  color: controllerNotifier.nearest ? Colors.white : AppColors.primary,
                ),
                label: Text(l10n.searchNearest),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.primarySoft,
                labelStyle: TextStyle(
                  color: controllerNotifier.nearest ? Colors.white : AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide.none,
                showCheckmark: false,
              ),
            ),
          ),
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.inkFaint),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.searchCouldntSearch, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: () => controllerNotifier.applyFilters(filters),
                      child: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              ),
              data: (listings) {
                if (listings.isEmpty) {
                  return _NotifyMeEmptyState(filters: filters);
                }
                if (_mapView) {
                  return SearchMapView(listings: listings);
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: listings.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    if (i == listings.length) {
                      if (!hasMore) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: Center(
                          child: _loadingMore
                              ? const CircularProgressIndicator()
                              : TextButton(onPressed: _loadMore, child: Text(l10n.searchLoadMore)),
                        ),
                      );
                    }
                    final listing = listings[i];
                    return ListingCard(
                      listing: listing,
                      onTap: () => context.push('/listing/${listing.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifyMeEmptyState extends StatefulWidget {
  const _NotifyMeEmptyState({required this.filters});

  final SearchFilters filters;

  @override
  State<_NotifyMeEmptyState> createState() => _NotifyMeEmptyStateState();
}

class _NotifyMeEmptyStateState extends State<_NotifyMeEmptyState> {
  bool _subscribing = false;
  bool _subscribed = false;

  Future<void> _subscribe() async {
    if (widget.filters.query.trim().isEmpty) return;
    setState(() => _subscribing = true);
    try {
      await subscribeToListingAlert(
        tradeName: widget.filters.query.trim(),
        governorate: widget.filters.governorate,
      );
      if (mounted) setState(() => _subscribed = true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppError.message(context.l10n, error))));
      }
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.search_off_rounded, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.searchNoMatches, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.searchTryDifferent,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (widget.filters.query.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              GlassCard(
                child: _subscribed
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.good, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(child: Text(l10n.searchNotifyMeSet, style: Theme.of(context).textTheme.bodyMedium)),
                        ],
                      )
                    : Column(
                        children: [
                          Text(
                            l10n.searchNotifyMeBody,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppGradientButton(
                            isLoading: _subscribing,
                            onPressed: _subscribing ? null : _subscribe,
                            child: Text(l10n.searchNotifyMeCta),
                          ),
                        ],
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.filters});

  final SearchFilters filters;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ListingType? _type = widget.filters.type;
  late String? _governorate = widget.filters.governorate;
  late String _concentration = widget.filters.concentration;
  late DateTime? _expiryBefore = widget.filters.expiryBefore;

  Future<void> _openConcentrationPicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ConcentrationPickerSheet(),
    );
    if (picked != null) setState(() => _concentration = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              Text(l10n.searchFilters, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<ListingType?>(
                initialValue: _type,
                decoration: InputDecoration(
                  labelText: l10n.fieldType,
                  prefixIcon: const Icon(Icons.category_rounded),
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.searchAllTypes)),
                  ...ListingType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label(l10n)))),
                ],
                onChanged: (v) => setState(() => _type = v),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String?>(
                initialValue: _governorate,
                decoration: InputDecoration(
                  labelText: l10n.fieldGovernorate,
                  prefixIcon: const Icon(Icons.map_rounded),
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.searchAllGovernorates)),
                  ...egyptGovernorates.map((g) => DropdownMenuItem(value: g, child: Text(g))),
                ],
                onChanged: (v) => setState(() => _governorate = v),
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: _openConcentrationPicker,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.fieldConcentration,
                    prefixIcon: const Icon(Icons.opacity_rounded),
                    suffixIcon: _concentration.isEmpty
                        ? const Icon(Icons.expand_more_rounded)
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() => _concentration = ''),
                          ),
                  ),
                  child: Text(
                    _concentration.isEmpty ? l10n.searchAnyConcentration : _concentration,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: _concentration.isEmpty ? AppColors.inkFaint : AppColors.ink,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_expiryBefore == null ? l10n.searchExpiryBefore : DateFormat.yMMMd().format(_expiryBefore!)),
                leading: const Icon(Icons.event_rounded, color: AppColors.primary),
                trailing: _expiryBefore == null
                    ? const Icon(Icons.chevron_right_rounded, size: 20)
                    : IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () => setState(() => _expiryBefore = null)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expiryBefore ?? DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    helpText: l10n.searchExpiryBefore,
                  );
                  if (picked != null) setState(() => _expiryBefore = picked);
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(
                        SearchFilters(query: widget.filters.query),
                      ),
                      child: Text(l10n.searchClear),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppGradientButton(
                      onPressed: () => Navigator.of(context).pop(
                        widget.filters.copyWith(
                          type: _type,
                          clearType: _type == null,
                          governorate: _governorate,
                          clearGovernorate: _governorate == null,
                          concentration: _concentration,
                          expiryBefore: _expiryBefore,
                          clearExpiryBefore: _expiryBefore == null,
                        ),
                      ),
                      child: Text(l10n.searchApply),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search-as-you-type over distinct concentration values in the drug
/// catalog (see drug_catalog_search.dart), replacing a free-text guess with
/// real values pulled from the same ~23,600-row reference table Add
/// Medicine already searches — same Timer-debounce pattern as
/// _DrugSearchSheet there and SearchScreen's own query field.
class _ConcentrationPickerSheet extends StatefulWidget {
  const _ConcentrationPickerSheet();

  @override
  State<_ConcentrationPickerSheet> createState() => _ConcentrationPickerSheetState();
}

class _ConcentrationPickerSheetState extends State<_ConcentrationPickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<String> _results = const [];
  bool _loading = false;
  List<String> _initialResults = const [];
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final results = await fetchInitialConcentrations();
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
        final results = await searchConcentrations(q);
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
    final items = trimmed.isEmpty ? _initialResults : _results;
    final exactMatch = items.any((c) => c.toLowerCase() == trimmed.toLowerCase());

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
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
              Text(l10n.fieldConcentration, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: l10n.searchConcentrationHint,
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
                    : ListView(
                        controller: scrollController,
                        children: [
                          if (trimmed.isNotEmpty && !exactMatch)
                            ListTile(
                              leading: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                              title: Text(l10n.searchUseConcentration(trimmed)),
                              onTap: () => Navigator.of(context).pop(trimmed),
                            ),
                          for (final value in items)
                            ListTile(
                              leading: const Icon(Icons.opacity_rounded, color: AppColors.primary),
                              title: Text(value),
                              onTap: () => Navigator.of(context).pop(value),
                            ),
                          if (!_loading && trimmed.isNotEmpty && items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                              child: Text(l10n.addMedicineNoMatches, style: Theme.of(context).textTheme.bodySmall),
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
