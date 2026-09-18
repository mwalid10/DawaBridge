import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity.dart';
import '../../core/offline_cache.dart';
import '../../core/rpc.dart';
import '../../core/supabase_client.dart';
import 'deal.dart';

/// All deals (as buyer or seller) for the signed-in pharmacy, newest
/// activity first — backs the Chat tab's conversation list.
class DealsController extends AsyncNotifier<List<Deal>> {
  @override
  Future<List<Deal>> build() async {
    final rows = await rpcList('get_my_deals', cacheKey: OfflineCache.deals);
    return rows.map(Deal.fromJson).toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final dealsControllerProvider = AsyncNotifierProvider<DealsController, List<Deal>>(DealsController.new);

/// Requests the seller still owes an answer on. Drives the Chat tab badge
/// so a seller can't miss a request and let the 48h window lapse — the old
/// flow had no concept of a request to answer at all.
final pendingSellerRequestsProvider = Provider<int>((ref) {
  final deals = ref.watch(dealsControllerProvider).value;
  return deals?.where((d) => d.isSeller && d.state.awaitsSeller).length ?? 0;
});

/// Single-deal fetch for the chat thread header — same manual-family
/// pattern as ListingDetailController (no injected `arg` getter, so the
/// deal id is threaded through the constructor instead).
class DealDetailController extends AsyncNotifier<DealDetail> {
  DealDetailController(this.dealId);

  final String dealId;

  @override
  Future<DealDetail> build() async {
    // Was `(rows as List).first` — a bare StateError when the deal isn't
    // visible to the caller (deleted, or opened from a stale notification).
    final row = await rpcSingle(
      'get_deal_detail',
      params: {'p_deal_id': dealId},
      notFoundLabel: 'deal',
    );
    return DealDetail.fromJson(row);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final dealDetailControllerProvider =
    AsyncNotifierProvider.autoDispose.family<DealDetailController, DealDetail, String>(
  (id) => DealDetailController(id),
);

/// Opens a *request* on [listingId] and posts the opening chat message;
/// returns the new deal id.
///
/// Note this no longer reserves the listing — the seller has to accept
/// first (migration 0035). Errors come back as stable codes that
/// `AppError.message` turns into a localized sentence; they are no longer
/// shown to the user as raw Postgres exception text.
Future<String> requestListing(String listingId, {String? message}) async {
  _requireConnection();
  final result = await guardNetwork(() => supabase.rpc('request_listing', params: {
        'p_listing_id': listingId,
        'p_message': message,
      }));
  return result as String;
}

/// Thrown when a deal action is attempted with no connection.
///
/// Deliberately not queued the way chat messages are. Chat is append-only
/// and a late delivery is still correct; a deal action is a decision about
/// contested state. Two sellers accepting different buyers for one listing,
/// or an acceptance replayed after the buyer already withdrew, is a
/// correctness problem that queuing would create rather than solve — the
/// database resolves those races with a row lock, and the client has to be
/// present for the answer.
class OfflineActionException implements Exception {
  const OfflineActionException();
  @override
  String toString() => 'OFFLINE_ACTION';
}

void _requireConnection() {
  if (connectivityController.isOffline) throw const OfflineActionException();
}

/// Drives a deal through its lifecycle.
///
/// [action] is one of:
///   * `accept`   — seller only, while pending. Reserves the listing and
///                  auto-declines every other pending request on it.
///   * `decline`  — seller only, while pending.
///   * `complete` — seller only, once accepted.
///   * `cancel`   — either party, while pending or accepted.
///
/// See `respond_to_deal` in 0035_deal_lifecycle_v2.sql.
Future<void> respondToDeal(String dealId, String action) async {
  _requireConnection();
  await guardNetwork(
    () => supabase.rpc('respond_to_deal', params: {'p_deal_id': dealId, 'p_action': action}),
  );
}
