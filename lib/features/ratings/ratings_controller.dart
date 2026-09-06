import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';

/// Whether the signed-in pharmacy has already rated a given deal — the
/// ratings select policy is public read, so this is a direct table query
/// filtered to the caller's own rater_id, not an RPC.
class HasRatedController extends AsyncNotifier<bool> {
  HasRatedController(this.dealId);

  final String dealId;

  @override
  Future<bool> build() async {
    final uid = supabase.auth.currentUser!.id;
    final row = await supabase.from('ratings').select('id').eq('deal_id', dealId).eq('rater_id', uid).maybeSingle();
    return row != null;
  }
}

final hasRatedControllerProvider = AsyncNotifierProvider.autoDispose.family<HasRatedController, bool, String>(
  (id) => HasRatedController(id),
);

/// Posts a rating for a completed deal via the submit_rating RPC (see
/// 0008_ratings_rpc.sql) — it verifies the caller was a participant and
/// the deal is completed, and the ratings table's unique(deal_id, rater_id)
/// constraint blocks a second rating for the same deal.
Future<void> submitRating(
  String dealId, {
  required int stars,
  int? credibility,
  int? responsiveness,
  int? packaging,
}) async {
  await supabase.rpc('submit_rating', params: {
    'p_deal_id': dealId,
    'p_stars': stars,
    'p_credibility': credibility,
    'p_responsiveness': responsiveness,
    'p_packaging': packaging,
  });
}
