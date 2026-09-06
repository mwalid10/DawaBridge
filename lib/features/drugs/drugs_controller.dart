import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import 'drug.dart';

/// Reference drug list — fetched once per app session (drugs rarely
/// change), then reused by the accepted-alternatives picker and to
/// resolve accepted-alternative drug ids on the listing detail screen.
/// Excludes pending entries (unreviewed self-service picks from
/// find_or_create_drug, see 0024_drugs_pending_review.sql) — those
/// shouldn't be offered as a barter-alternative option until an admin has
/// looked at them.
class DrugsController extends AsyncNotifier<List<Drug>> {
  @override
  Future<List<Drug>> build() async {
    final rows = await supabase.from('drugs').select().eq('is_pending', false).order('trade_name');
    return (rows as List<dynamic>)
        .map((row) => Drug.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}

final drugsControllerProvider = AsyncNotifierProvider<DrugsController, List<Drug>>(DrugsController.new);
