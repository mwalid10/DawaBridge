import '../../core/rpc.dart';
import '../../core/supabase_client.dart';
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
}) async {
  // guardNetwork adds the deadline and feeds the offline signal — search is
  // the app's highest-traffic read and the one most likely to be attempted
  // in a basement pharmacy with one bar.
  final rows = await guardNetwork(() => supabase.rpc('search_listings', params: {
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
  }));
  return (rows as List<dynamic>)
      .map((row) => ListingSummary.fromJson(row as Map<String, dynamic>))
      .toList();
}
