import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import '../listings/listing_summary.dart';
import '../listings/listings_query.dart';

class SearchFilters {
  final String query;
  final String concentration;
  final ListingType? type;
  final String? governorate;
  final DateTime? expiryBefore;

  const SearchFilters({
    this.query = '',
    this.concentration = '',
    this.type,
    this.governorate,
    this.expiryBefore,
  });

  SearchFilters copyWith({
    String? query,
    String? concentration,
    ListingType? type,
    bool clearType = false,
    String? governorate,
    bool clearGovernorate = false,
    DateTime? expiryBefore,
    bool clearExpiryBefore = false,
  }) {
    return SearchFilters(
      query: query ?? this.query,
      concentration: concentration ?? this.concentration,
      type: clearType ? null : (type ?? this.type),
      governorate: clearGovernorate ? null : (governorate ?? this.governorate),
      expiryBefore: clearExpiryBefore ? null : (expiryBefore ?? this.expiryBefore),
    );
  }
}

/// Filtered listings search — shares `fetchListings` with the Home feed.
/// Distance sort is opt-in here (via [nearest]) rather than the default,
/// since search is usually a name/type lookup, not a proximity browse.
class SearchController extends AsyncNotifier<List<ListingSummary>> {
  static const _pageSize = 30;
  static const _nearestMaxDistanceKm = 60.0;

  SearchFilters filters = const SearchFilters();
  bool nearest = false;
  int _offset = 0;
  bool _hasMore = true;
  double? _lat;
  double? _lng;
  bool _locationLoaded = false;

  bool get hasMore => _hasMore;

  @override
  Future<List<ListingSummary>> build() async {
    return _fetchPage(0);
  }

  Future<void> _loadOwnLocation() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final row = await supabase.from('pharmacies').select('lat,lng').eq('id', uid).maybeSingle();
    _lat = (row?['lat'] as num?)?.toDouble();
    _lng = (row?['lng'] as num?)?.toDouble();
    _locationLoaded = true;
  }

  Future<List<ListingSummary>> _fetchPage(int offset) async {
    final page = await fetchListings(
      tradeName: filters.query.trim().isEmpty ? null : filters.query.trim(),
      concentration: filters.concentration.trim().isEmpty ? null : filters.concentration.trim(),
      type: filters.type,
      governorate: filters.governorate,
      expiryBefore: filters.expiryBefore,
      lat: nearest ? _lat : null,
      lng: nearest ? _lng : null,
      excludePharmacyId: supabase.auth.currentUser?.id,
      limit: _pageSize,
      offset: offset,
      maxDistanceKm: nearest ? _nearestMaxDistanceKm : null,
    );
    _hasMore = page.length == _pageSize;
    _offset = offset + page.length;
    return page;
  }

  Future<void> applyFilters(SearchFilters newFilters) async {
    filters = newFilters;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchPage(0));
  }

  Future<void> toggleNearest() async {
    nearest = !nearest;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      if (nearest && !_locationLoaded) await _loadOwnLocation();
      return _fetchPage(0);
    });
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final current = state.value ?? [];
    final more = await _fetchPage(_offset);
    state = AsyncValue.data([...current, ...more]);
  }
}

final searchControllerProvider = AsyncNotifierProvider<SearchController, List<ListingSummary>>(SearchController.new);
