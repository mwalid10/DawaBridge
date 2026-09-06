import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import 'deal.dart';

/// All deals (as buyer or seller) for the signed-in pharmacy, newest
/// activity first — backs the Chat tab's conversation list.
class DealsController extends AsyncNotifier<List<Deal>> {
  @override
  Future<List<Deal>> build() async {
    final rows = await supabase.rpc('get_my_deals');
    return (rows as List<dynamic>).map((row) => Deal.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final dealsControllerProvider = AsyncNotifierProvider<DealsController, List<Deal>>(DealsController.new);

/// Single-deal fetch for the chat thread header — same manual-family
/// pattern as ListingDetailController (no injected `arg` getter, so the
/// deal id is threaded through the constructor instead).
class DealDetailController extends AsyncNotifier<DealDetail> {
  DealDetailController(this.dealId);

  final String dealId;

  @override
  Future<DealDetail> build() async {
    final rows = await supabase.rpc('get_deal_detail', params: {'p_deal_id': dealId});
    final row = (rows as List<dynamic>).first as Map<String, dynamic>;
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

/// Creates a deal for [listingId] (reserving it) and posts the opening
/// chat message; returns the new deal id. Thrown Postgres exceptions from
/// request_listing (already reserved, own listing, etc.) surface as-is —
/// callers show `error.toString()` to the user.
Future<String> requestListing(String listingId, {String? message}) async {
  final result = await supabase.rpc('request_listing', params: {
    'p_listing_id': listingId,
    'p_message': message,
  });
  return result as String;
}

/// Marks a deal complete (seller only) or cancels it (either party) via
/// the respond_to_deal RPC — see 0007_deals_chat_notifications.sql for the
/// server-side rules this enforces.
Future<void> respondToDeal(String dealId, String action) async {
  await supabase.rpc('respond_to_deal', params: {'p_deal_id': dealId, 'p_action': action});
}
