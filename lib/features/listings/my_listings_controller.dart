import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline_cache.dart';
import '../../core/rpc.dart';
import 'listing_summary.dart';

/// All of the signed-in pharmacy's own listings, across every state — see
/// get_my_listings() in 0025_my_listings_rpc.sql. [stateFilter] null means
/// "all states".
class MyListingsController extends AsyncNotifier<List<ListingSummary>> {
  ListingState? stateFilter;

  @override
  Future<List<ListingSummary>> build() => _fetch();

  Future<List<ListingSummary>> _fetch() async {
    // Only the unfiltered view is cached: a cached 'all' list must not be
    // served to someone who asked for just the reserved ones.
    final rows = await rpcList(
      'get_my_listings',
      params: {'p_state': stateFilter?.name},
      cacheKey: stateFilter == null ? OfflineCache.myListings : null,
    );
    return (rows as List<dynamic>).map((row) => ListingSummary.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<void> setStateFilter(ListingState? filter) async {
    stateFilter = filter;
    await refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }
}

final myListingsControllerProvider = AsyncNotifierProvider<MyListingsController, List<ListingSummary>>(MyListingsController.new);
