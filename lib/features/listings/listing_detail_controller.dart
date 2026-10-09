import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity.dart';
import '../../core/offline_cache.dart';
import '../../core/rpc.dart';
import '../../core/supabase_client.dart';
import '../drugs/drug.dart';
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

/// What an exchange listing's owner will take in return, in the order they
/// chose it.
///
/// Full `Drug` rows rather than names: the detail page only needs the trade
/// name, but the edit screen hands them straight back to
/// [AlternativesPickerSheet], which needs the concentration to tick the
/// right rows in the catalogue.
///
/// `listings.accepted_alternatives` holds drug ids, and the detail screen
/// used to turn them into names by looking them up in
/// `drugsControllerProvider` — the same catalogue that backs the picker,
/// which is filtered to `is_pending = false`. That filter is right for the
/// picker (an unreviewed self-service drug shouldn't be *offered* as an
/// option) and wrong for display: an alternative already chosen must still
/// be shown, whatever the review state of the row behind it. Any id it
/// couldn't resolve was dropped silently, and a listing where none resolved
/// rendered no section at all — which is what every exchange listing in the
/// database was doing.
///
/// Looking the ids up directly also means the whole catalogue no longer has
/// to be in memory to read one listing, and it can't be truncated by a row
/// cap as the drug table grows.
final acceptedAlternativeDrugsProvider =
    FutureProvider.autoDispose.family<List<Drug>, String>((ref, listingId) async {
  final listing = await ref.watch(listingDetailControllerProvider(listingId).future);
  final ids = listing.acceptedAlternatives;
  if (ids.isEmpty) return const [];

  // Read-through, like the listing itself: this screen is meant to be
  // readable with no signal, and on a barter listing this is the part of it
  // worth reading.
  final cacheKey = OfflineCache.listingAlternatives(listingId);
  try {
    final rows = await guardNetwork(() => supabase.from('drugs').select().inFilter('id', ids));
    final list = rows.cast<Map<String, dynamic>>().toList();
    unawaited(OfflineCache.write(cacheKey, list));
    return drugsInChosenOrder(ids, list);
  } catch (error) {
    if (!ConnectivityController.looksOffline(error)) rethrow;
    final cached = await OfflineCache.read(cacheKey);
    if (cached == null) rethrow;
    return drugsInChosenOrder(ids, cached.rows);
  }
});

/// `in` returns rows in whatever order Postgres finds them; the pharmacy
/// picked these in an order, so show them in it.
@visibleForTesting
List<Drug> drugsInChosenOrder(List<String> ids, List<Map<String, dynamic>> rows) {
  final byId = {for (final row in rows) row['id'] as String: Drug.fromJson(row)};
  return ids.map((id) => byId[id]).whereType<Drug>().toList();
}
