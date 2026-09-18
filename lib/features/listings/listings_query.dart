import '../../core/rpc.dart';
import 'listing_summary.dart';

/// Shared query helper backing both the Home feed and Search — both call
/// this with different parameters rather than duplicating the RPC call.
Future<List<ListingSummary>> fetchListings({
  String? tradeName,
  String? concentration,
  ListingType? type,
  String? governorate,
  DateTime? expiryBefore,
  double? lat,
  double? lng,
  String? excludePharmacyId,
  int limit = 30,
  int offset = 0,
  double? maxDistanceKm,
  /// Set only for a query whose shape never varies (the Home feed). A
  /// filtered search must not read rows cached by a different filter.
  String? cacheKey,
}) async {
  final params = {
    'p_trade_name': tradeName,
    'p_concentration': concentration,
    'p_type': type?.name,
    'p_governorate': governorate,
    'p_expiry_before': expiryBefore?.toIso8601String().split('T').first,
    'p_lat': lat,
    'p_lng': lng,
    'p_exclude_pharmacy_id': excludePharmacyId,
    'p_limit': limit,
    'p_offset': offset,
    'p_max_distance_km': maxDistanceKm,
  };

  // guardNetwork adds the deadline and feeds the offline signal; rpcList
  // adds the read-through cache when a key is supplied.
  final rows = await rpcList('search_listings', params: params, cacheKey: cacheKey);
  return rows.map(ListingSummary.fromJson).toList();
}
