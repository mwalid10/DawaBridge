import '../../core/supabase_client.dart';
import 'drug_catalog_entry.dart';

/// Server-side search over the ~23,600-row `drug_catalog` reference table
/// — called on a debounce timer from the picker sheet (same
/// Timer-in-State pattern as search_screen.dart), never fetched wholesale
/// like the small `drugs` table is.
Future<List<DrugCatalogEntry>> searchDrugCatalog(String query, {int limit = 20}) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final rows = await supabase.from('drug_catalog').select().ilike('display_name', '%$q%').order('display_name').limit(limit);
  return (rows as List<dynamic>).map((row) => DrugCatalogEntry.fromJson(row as Map<String, dynamic>)).toList();
}

/// A default slice of the catalog shown before the user has typed anything,
/// so the picker sheet never opens to a blank "start typing" screen — just
/// alphabetical, since there's no popularity/usage signal to rank by.
Future<List<DrugCatalogEntry>> fetchInitialDrugCatalog({int limit = 10}) async {
  final rows = await supabase.from('drug_catalog').select().order('display_name').limit(limit);
  return (rows as List<dynamic>).map((row) => DrugCatalogEntry.fromJson(row as Map<String, dynamic>)).toList();
}

/// Distinct concentration values for the search filter's concentration
/// picker — unlike [searchDrugCatalog], there's no dedicated column index
/// or RPC for this, so it over-fetches a batch of matching rows and dedupes
/// client-side. `concentration` has low cardinality across the ~23,600-row
/// catalog (mostly "500mg"-style strings repeated across many products), so
/// a few hundred rows reliably yield well over [limit] distinct values.
Future<List<String>> searchConcentrations(String query, {int limit = 20}) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final rows = await supabase
      .from('drug_catalog')
      .select('concentration')
      .not('concentration', 'is', null)
      .ilike('concentration', '%$q%')
      .order('concentration')
      .limit(300);
  return _distinctConcentrations(rows, limit);
}

/// Default slice of concentration values shown before the user types,
/// mirroring [fetchInitialDrugCatalog]'s empty-state preload.
Future<List<String>> fetchInitialConcentrations({int limit = 12}) async {
  final rows = await supabase
      .from('drug_catalog')
      .select('concentration')
      .not('concentration', 'is', null)
      .order('concentration')
      .limit(200);
  return _distinctConcentrations(rows, limit);
}

List<String> _distinctConcentrations(List<dynamic> rows, int limit) {
  final values = rows
      .map((row) => (row as Map<String, dynamic>)['concentration'] as String?)
      .whereType<String>()
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return values.take(limit).toList();
}
