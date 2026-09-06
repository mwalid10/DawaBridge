import 'package:flutter/material.dart';

import '../theme.dart';

/// A rounded "balloon" pin for flutter_map markers — gradient badge, white
/// ring, icon, drop shadow and a pointer tail, with a soft ground shadow so
/// it reads as sitting on the map rather than floating. Used for every map
/// marker in the app (search results, KYC pin-drop, shared chat location)
/// so pins look consistent wherever a map shows up.
class AppMapPin extends StatelessWidget {
  const AppMapPin({
    super.key,
    this.icon = Icons.local_pharmacy_rounded,
    this.size = 44,
    this.gradient = AppGradients.hero,
    this.selected = false,
    this.ringColor = Colors.white,
  });

  final IconData icon;
  final double size;
  final Gradient gradient;
  final bool selected;
  final Color ringColor;

  /// Total footprint a marker of this [size] needs — pass to `Marker.width`
  /// / `Marker.height` so the pointer tail and shadow aren't clipped.
  static double footprint(double size) => size * 1.5;

  /// Vertical distance from the pin's bounding-box center down to its visual
  /// tip (the ground-shadow ellipse) — derived from the fixed proportions
  /// used in [build] (footprint = 1.5·size, shadow center ≈ 0.873·footprint
  /// from the top). Widgets that place this pin as a fixed map-center
  /// overlay (not a flutter_map `Marker`, which has its own `alignment`)
  /// need to shift it up by this amount so the tip — not the icon's
  /// center — lands on the actual coordinate.
  static double tipOffset(double size) => size * 0.56;

  @override
  Widget build(BuildContext context) {
    final badgeSize = selected ? size * 1.15 : size;
    final footprint = AppMapPin.footprint(size);
    return SizedBox(
      width: footprint,
      height: footprint,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: footprint * 0.08,
            child: Container(
              width: badgeSize * 0.42,
              height: badgeSize * 0.14,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            top: footprint * 0.28,
            child: Transform.rotate(
              angle: 0.785398,
              child: Container(
                width: badgeSize * 0.3,
                height: badgeSize * 0.3,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                gradient: gradient,
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 3),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: badgeSize * 0.48),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular gradient badge used for clustered markers — shows how many
/// pins are grouped at the current zoom level.
class MapClusterPin extends StatelessWidget {
  const MapClusterPin({super.key, required this.count, this.size = 48});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }
}
