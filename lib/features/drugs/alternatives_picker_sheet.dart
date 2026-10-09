import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n_extensions.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import 'drug.dart';
import 'drug_catalog_entry.dart';
import 'drug_catalog_search.dart';

String _catalogKey(String tradeName, String? concentration) =>
    '${tradeName.trim().toLowerCase()}|${(concentration ?? '').trim().toLowerCase()}';

/// Picks what an exchange listing will accept in return.
///
/// Search-as-you-type over the same drug_catalog as the add screen's main
/// Medicine field, multi-select instead of single-pick. Each tap resolves
/// the entry through find_or_create_drug (same RPC, same
/// converge-on-one-row-by-name+concentration behavior — see
/// 0022_drug_catalog.sql) and toggles it in the accepted-alternatives list;
/// [selectedDrugs] (already-resolved `Drug` rows for the current selection)
/// seeds a name+concentration key set so previously-picked items show
/// checked immediately, without spending an RPC call just to render the
/// list.
///
/// Shared by posting a listing and editing one. It lived inside the add
/// screen until the edit screen needed it too — being able to set this only
/// at posting time meant an exchange listing that named nothing could never
/// be corrected, only deleted and posted again.
class AlternativesPickerSheet extends StatefulWidget {
  const AlternativesPickerSheet({
    super.key,
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
  State<AlternativesPickerSheet> createState() => _AlternativesPickerSheetState();
}

class _AlternativesPickerSheetState extends State<AlternativesPickerSheet> {
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
