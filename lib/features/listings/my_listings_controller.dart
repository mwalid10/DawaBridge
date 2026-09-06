import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import 'listing_summary.dart';

/// All of the signed-in pharmacy's own listings, across every state — see
/// get_my_listings() in 0025_my_listings_rpc.sql. [stateFilter] null means
/// "all states".
class MyListingsController extends AsyncNotifier<List<ListingSummary>> {
  ListingState? stateFilter;

  @override
  Future<List<ListingSummary>> build() => _fetch();

  Future<List<ListingSummary>> _fetch() async {
    final rows = await supabase.rpc('get_my_listings', params: {'p_state': stateFilter?.name});
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
