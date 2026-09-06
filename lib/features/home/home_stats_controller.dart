import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import 'home_stats.dart';

/// Active-listings / completed-exchanges counts for the Home header —
/// same one-shot RPC shape as RatingSummaryController.
class HomeStatsController extends AsyncNotifier<HomeStats> {
  @override
  Future<HomeStats> build() async {
    final rows = await supabase.rpc('get_my_home_stats');
    final row = (rows as List<dynamic>).first as Map<String, dynamic>;
    return HomeStats.fromJson(row);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final homeStatsControllerProvider = AsyncNotifierProvider<HomeStatsController, HomeStats>(HomeStatsController.new);
