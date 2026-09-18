import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline_cache.dart';
import '../../core/rpc.dart';
import 'listing_summary.dart';

/// Per-listing detail fetch. The manual (non-codegen) family API has no
/// injected `arg` getter — the listing id is threaded in via the
/// constructor from the provider's family factory closure instead.
class ListingDetailController extends AsyncNotifier<ListingSummary> {
  ListingDetailController(this.listingId);

  final String listingId;

  @override
  Future<ListingSummary> build() async {
    // `get_listing_detail` returns nothing when the listing is neither
    // available nor owned by the caller. This used to be
    // `(rows as List).first`, which threw `StateError: No element` — a red
    // error screen rather than a message. It's a routine path: favourites
    // keep listings of every state, so a saved listing the seller has since
    // completed landed here, as did any notification deep link to a closed
    // listing. rpcSingle raises NotFoundException, which the screen renders
    // as "this listing is no longer available".
    final row = await rpcSingleCached(
      'get_listing_detail',
      params: {'p_listing_id': listingId},
      cacheKey: OfflineCache.listing(listingId),
      notFoundLabel: 'listing',
    );
    return ListingSummary.fromJson(row);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final listingDetailControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ListingDetailController, ListingSummary, String>(
  (id) => ListingDetailController(id),
);
