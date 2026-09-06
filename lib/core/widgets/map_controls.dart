import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../theme.dart';

/// Floating +/- zoom pill for a [FlutterMap], styled to match the app's
/// white-card + soft-shadow language instead of flutter_map's bare default.
class MapZoomControls extends StatelessWidget {
  const MapZoomControls({super.key, required this.mapController});

  final MapController mapController;

  void _zoomBy(double delta) {
    final camera = mapController.camera;
    final next = (camera.zoom + delta).clamp(2.0, 19.0);
    mapController.move(camera.center, next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomButton(icon: Icons.add_rounded, onTap: () => _zoomBy(1)),
          const Divider(height: 1, color: AppColors.divider),
          _ZoomButton(icon: Icons.remove_rounded, onTap: () => _zoomBy(-1)),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20, color: AppColors.primaryDark)),
    );
  }
}

/// Small round white FAB for map overlays (recenter / locate-me), matching
/// [MapZoomControls]'s card styling rather than a full-bleed Material FAB.
class MapRoundButton extends StatelessWidget {
  const MapRoundButton({super.key, required this.icon, required this.onPressed, this.loading = false});

  final IconData icon;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: loading ? null : onPressed,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : Icon(icon, size: 19, color: AppColors.primaryDark),
          ),
        ),
      ),
    );
  }
}
