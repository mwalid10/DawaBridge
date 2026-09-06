import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/l10n_extensions.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/map_controls.dart';
import '../../../core/widgets/map_pin.dart';
import '../../listings/listing_summary.dart';

/// Map view for search results — pins for every result with a known
/// pharmacy location (0011_search_and_detail_v2.sql exposes
/// pharmacy_lat/pharmacy_lng), tap a pin for a mini-card with a View
/// button. Same FlutterMap/OSM-tile setup as AddressStep's pin-drop map.
///
/// Nearby pins are grouped into a count badge (grid-bucketed by zoom, not a
/// full clustering library — flutter_map_marker_cluster's latlong2 pin is
/// older than the one flutter_map 8 requires) so a dense governorate doesn't
/// turn into a wall of overlapping pins.
class SearchMapView extends StatefulWidget {
  const SearchMapView({super.key, required this.listings});

  final List<ListingSummary> listings;

  @override
  State<SearchMapView> createState() => _SearchMapViewState();
}

class _SearchMapViewState extends State<SearchMapView> {
  static const _cairo = LatLng(30.0444, 31.2357);
  static const _pinSize = 42.0;

  final _mapController = MapController();
  ListingSummary? _selected;
  double _zoom = 11;

  List<ListingSummary> get _pinned =>
      widget.listings.where((l) => l.pharmacyLat != null && l.pharmacyLng != null).toList();

  /// Buckets pins into a lat/lng grid whose cell size shrinks as the user
  /// zooms in, so clusters break apart into individual pins near street
  /// level and merge back into count badges when zoomed out.
  List<_MapCluster> _buildClusters(List<ListingSummary> pinned) {
    if (pinned.isEmpty) return const [];
    final cellDeg = 40.0 / (1 << _zoom.clamp(2, 18).round());
    final buckets = <String, List<ListingSummary>>{};
    for (final listing in pinned) {
      final key = '${(listing.pharmacyLat! / cellDeg).round()}:${(listing.pharmacyLng! / cellDeg).round()}';
      buckets.putIfAbsent(key, () => []).add(listing);
    }
    return buckets.values.map((group) {
      final lat = group.map((l) => l.pharmacyLat!).reduce((a, b) => a + b) / group.length;
      final lng = group.map((l) => l.pharmacyLng!).reduce((a, b) => a + b) / group.length;
      return _MapCluster(point: LatLng(lat, lng), listings: group);
    }).toList();
  }

  void _fitToPins(List<ListingSummary> pinned) {
    if (pinned.isEmpty) return;
    if (pinned.length == 1) {
      _mapController.move(LatLng(pinned.first.pharmacyLat!, pinned.first.pharmacyLng!), 14);
      return;
    }
    final bounds = LatLngBounds.fromPoints(
      pinned.map((l) => LatLng(l.pharmacyLat!, l.pharmacyLng!)).toList(),
    );
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pinned = _pinned;
    final center = pinned.isEmpty ? _cairo : LatLng(pinned.first.pharmacyLat!, pinned.first.pharmacyLng!);
    final clusters = _buildClusters(pinned);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.card),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: pinned.isEmpty ? 6 : _zoom,
                  onPositionChanged: (camera, hasGesture) {
                    if ((camera.zoom - _zoom).abs() > 0.2) {
                      setState(() => _zoom = camera.zoom);
                    }
                  },
                  onTap: (_, _) => setState(() => _selected = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.pharmaexchangeegypt.app',
                  ),
                  MarkerLayer(
                    markers: clusters.map((cluster) {
                      final isCluster = cluster.listings.length > 1;
                      return Marker(
                        point: cluster.point,
                        width: isCluster ? 56 : AppMapPin.footprint(_pinSize),
                        height: isCluster ? 56 : AppMapPin.footprint(_pinSize),
                        // Cluster badges are plain circles (center = point);
                        // pins visually point at their tip, near the
                        // bottom of the footprint, so anchor there instead.
                        alignment: isCluster ? Alignment.center : Alignment.bottomCenter,
                        child: GestureDetector(
                          onTap: () {
                            if (isCluster) {
                              _mapController.move(cluster.point, (_zoom + 2).clamp(2, 18));
                            } else {
                              setState(() => _selected = cluster.listings.first);
                            }
                          },
                          child: isCluster
                              ? MapClusterPin(count: cluster.listings.length)
                              : AppMapPin(
                                  size: _pinSize,
                                  selected: _selected?.id == cluster.listings.first.id,
                                ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          if (pinned.isNotEmpty)
            Positioned(
              left: AppSpacing.md,
              top: AppSpacing.md,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: AppShadows.card,
                ),
                child: Text(
                  l10n.mapPinnedCount(pinned.length),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.primaryDark),
                ),
              ),
            ),
          Positioned(
            right: AppSpacing.md,
            top: AppSpacing.md,
            child: Column(
              children: [
                MapZoomControls(mapController: _mapController),
                const SizedBox(height: AppSpacing.sm),
                MapRoundButton(icon: Icons.center_focus_strong_rounded, onPressed: () => _fitToPins(pinned)),
              ],
            ),
          ),
          if (_selected != null)
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.card,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(gradient: AppGradients.cta, shape: BoxShape.circle),
                      child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selected!.tradeName,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${_selected!.pharmacyName} · ${_selected!.governorate}',
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _selected = null),
                      icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.inkFaint),
                      visualDensity: VisualDensity.compact,
                    ),
                    TextButton(
                      onPressed: () => context.push('/listing/${_selected!.id}'),
                      child: Text(l10n.mapViewButtonView),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapCluster {
  const _MapCluster({required this.point, required this.listings});

  final LatLng point;
  final List<ListingSummary> listings;
}
