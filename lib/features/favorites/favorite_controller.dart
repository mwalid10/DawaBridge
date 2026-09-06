import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import 'favorites_controller.dart';

/// Whether the signed-in pharmacy has favorited a given listing — a direct
/// table query against `favorites`, not an RPC, since its RLS policy already
/// scopes reads/writes to the caller's own pharmacy_id. Same pattern as
/// HasRatedController.
class FavoriteController extends AsyncNotifier<bool> {
  FavoriteController(this.listingId);

  final String listingId;

  @override
  Future<bool> build() async {
    final uid = supabase.auth.currentUser!.id;
    final row = await supabase.from('favorites').select('listing_id').eq('listing_id', listingId).eq('pharmacy_id', uid).maybeSingle();
    return row != null;
  }

  /// Optimistically flips the heart, then writes through; reverts on
  /// failure (e.g. offline) so the icon never lies about what's saved.
  Future<void> toggle() async {
    final wasFavorited = state.value ?? false;
    state = AsyncValue.data(!wasFavorited);
    final uid = supabase.auth.currentUser!.id;
    try {
      if (wasFavorited) {
        await supabase.from('favorites').delete().eq('listing_id', listingId).eq('pharmacy_id', uid);
      } else {
        await supabase.from('favorites').insert({'listing_id': listingId, 'pharmacy_id': uid});
      }
      ref.invalidate(favoritesControllerProvider);
    } catch (_) {
      state = AsyncValue.data(wasFavorited);
      rethrow;
    }
  }
}

final favoriteControllerProvider = AsyncNotifierProvider.autoDispose.family<FavoriteController, bool, String>(
  (id) => FavoriteController(id),
);
