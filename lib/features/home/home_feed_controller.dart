import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline_cache.dart';
import '../../core/supabase_client.dart';
import '../listings/listing_summary.dart';
import '../listings/listings_query.dart';

/// Nearby/recent available listings for the Home screen's preview row —
/// a fixed small page, sorted by distance from the caller's own pharmacy
/// location when known. Full browsing/pagination lives on the Search tab
/// (see search_controller.dart), which shares `fetchListings`.
class HomeFeedController extends AsyncNotifier<List<ListingSummary>> {
  static const previewSize = 5;

  @override
  Future<List<ListingSummary>> build() async {
    final uid = supabase.auth.currentUser?.id;
    double? lat;
    double? lng;
    if (uid != null) {
      final row = await supabase.from('pharmacies').select('lat,lng').eq('id', uid).maybeSingle();
      lat = (row?['lat'] as num?)?.toDouble();
      lng = (row?['lng'] as num?)?.toDouble();
    }
    return fetchListings(
      lat: lat,
      lng: lng,
      excludePharmacyId: uid,
      limit: previewSize,
      offset: 0,
      // The one listings query with a fixed shape, so it is the one that
      // can be safely served from cache with no signal.
      cacheKey: OfflineCache.feed,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final homeFeedControllerProvider = AsyncNotifierProvider<HomeFeedController, List<ListingSummary>>(HomeFeedController.new);
