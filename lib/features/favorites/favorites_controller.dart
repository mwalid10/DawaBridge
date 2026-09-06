import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import '../listings/listing_summary.dart';

/// All of the signed-in pharmacy's favorited listings — see
/// get_my_favorites() in 0026_favorites.sql.
class FavoritesController extends AsyncNotifier<List<ListingSummary>> {
  @override
  Future<List<ListingSummary>> build() => _fetch();

  Future<List<ListingSummary>> _fetch() async {
    final rows = await supabase.rpc('get_my_favorites');
    return (rows as List<dynamic>).map((row) => ListingSummary.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }
}

final favoritesControllerProvider = AsyncNotifierProvider<FavoritesController, List<ListingSummary>>(FavoritesController.new);
