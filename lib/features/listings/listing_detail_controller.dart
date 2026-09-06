import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import 'listing_summary.dart';

/// Per-listing detail fetch. The manual (non-codegen) family API has no
/// injected `arg` getter — the listing id is threaded in via the
/// constructor from the provider's family factory closure instead.
class ListingDetailController extends AsyncNotifier<ListingSummary> {
  ListingDetailController(this.listingId);

  final String listingId;

  @override
  Future<ListingSummary> build() async {
    final rows = await supabase.rpc('get_listing_detail', params: {'p_listing_id': listingId});
    final row = (rows as List<dynamic>).first as Map<String, dynamic>;
    return ListingSummary.fromJson(row);
  }
}

final listingDetailControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ListingDetailController, ListingSummary, String>(
  (id) => ListingDetailController(id),
);
