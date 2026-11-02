import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// One tab in [AppNavBar].
class AppNavDestination {
  const AppNavDestination({required this.icon, required this.selectedIcon, required this.label, required this.index});

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Index into the shell's tab list — not this bar's own position. The Add
  /// screen occupies a slot in that list without having a tab of its own.
  final int index;
}

/// The shell's bottom navigation: a white bar floating clear of the screen
/// edges, green on white, with a notch along its top edge for the Add
/// button to sit in.
///
/// White on white needs the shadow to do the work a background colour would
/// otherwise do — the page behind this is also [AppColors.surface], so
/// without it the bar has no edge at all. It's tinted green rather than
/// grey, which is also what makes the notch legible: the curve is visible
/// because the glow follows it, not because two fills meet along it.
///
/// Every destination gets an equal slot. Before, two sat in one half and
/// three in the other around a fixed gap for the Add button, so the spacing
/// on the left of the bar visibly differed from the right. Keeping that
/// while also notching the centre is geometrically impossible with five
/// destinations — a centred gap between groups of two and three can't have
/// equal slots either side — so the notch is shallow enough to clear the
/// middle destination instead of replacing it.
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.destinations, required this.selectedIndex, required this.onSelect});

  /// Deep enough for an icon over its label, plus the band along the top
  /// that the notch cuts into.
  static const barHeight = 80.0;

  /// The bar's own inset from the screen edges. The Add button's position
  /// is derived from it — see [AboveNavBarFabLocation].
  static const horizontalInset = AppSpacing.sm;
  static const bottomInset = AppSpacing.md;

  /// Distance from the bottom of the bar to the bottom of a destination's
  /// label. The destinations sit low rather than centred so the notch has a
  /// band of its own along the top to cut into.
  static const _contentBottomPadding = 10.0;

  /// Must match [GradientFab]'s diameter; the notch is cut from it.
  static const fabSize = 56.0;

  /// Breathing room between the Add button's edge and the cut — and the
  /// knob that sets how wide the curve opens.
  static const notchMargin = 14.0;

  /// How far the Add button's lowest point sits below the bar's top edge.
  ///
  /// These two numbers are the whole geometry. The notch is
  /// `notchMargin + fabDip` deep and `2 * sqrt(R² - c²)` wide across the top
  /// edge, where R is the cut's radius and c the button's centre above that
  /// edge — 20pt deep and about 72 wide here. The destinations have to clear
  /// the depth, or the middle one is half-swallowed by the curve, which is
  /// what [_contentBottomPadding] and [barHeight] are sized against.
  static const fabDip = 6.0;

  /// The notch circle, in the coordinates of a bar occupying [rect].
  static Rect notchFor(Rect rect) => Rect.fromCircle(
    center: Offset(rect.center.dx, rect.top - (fabSize / 2 - fabDip)),
    radius: fabSize / 2 + notchMargin,
  );

  final List<AppNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(horizontalInset, 0, horizontalInset, bottomInset),
        // Painted rather than left to Material's own elevation, which on a
        // white bar over a white page was too faint to find. This draws the
        // bar's exact shape, blurred, so the glow follows the notch instead
        // of running straight across beneath it, and the strength is a
        // colour and a blur rather than an elevation step.
        child: CustomPaint(
          painter: const _BarGlow(),
          child: Material(
            color: AppColors.surface,
            shape: const NotchedBarBorder(radius: AppRadius.xl),
            // So a tap's ripple stays inside the shape instead of squaring
            // off its corners and spilling across the notch.
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: barHeight,
              child: Row(
                children: [
                  for (final destination in destinations)
                    Expanded(
                      child: _NavItem(
                        destination: destination,
                        selected: destination.index == selectedIndex,
                        onTap: onSelect,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The green glow the white bar is read against.
///
/// Paints [AppNavBar]'s own shape, blurred and offset, so the glow follows
/// the notch. Strong enough to see on white: the page behind the bar is the
/// same colour as the bar, so this is the only thing giving it an edge.
class _BarGlow extends CustomPainter {
  const _BarGlow();

  static const _color = AppColors.primary;
  static const _opacity = 0.42;
  static const _blur = 13.0;
  static const _offset = Offset(0, 7);

  @override
  void paint(Canvas canvas, Size size) {
    final path = const NotchedBarBorder(radius: AppRadius.xl).getOuterPath(Offset.zero & size);
    canvas.drawPath(
      path.shift(_offset),
      Paint()
        ..color = _color.withValues(alpha: _opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _blur),
    );
  }

  @override
  bool shouldRepaint(_BarGlow oldDelegate) => false;
}

/// A rounded bar with a circular bite taken out of its top edge for the Add
/// button to sit in.
///
/// Built from both of Flutter's pieces rather than one: [CircularNotchedRectangle]
/// draws the notch with the soft tangential run-in and run-out that makes it
/// read as a curve rather than a hole punched in the edge, but it knows
/// nothing about rounded corners and returns a square-cornered rectangle.
/// Intersecting that with the rounded rect keeps the notch's curve and the
/// bar's corners.
class NotchedBarBorder extends ShapeBorder {
  const NotchedBarBorder({required this.radius});

  final double radius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final rounded = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final notched = const CircularNotchedRectangle().getOuterPath(rect, AppNavBar.notchFor(rect));
    return Path.combine(PathOperation.intersect, rounded, notched);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => NotchedBarBorder(radius: radius * t);

  @override
  bool operator ==(Object other) => other is NotchedBarBorder && other.radius == radius;

  @override
  int get hashCode => radius.hashCode;
}

/// Seats the Add button in [AppNavBar]'s notch.
///
/// Not `centerDocked`, which sinks the button to its middle. Here it dips
/// by [AppNavBar.fabDip] and no further, which is what keeps the notch
/// shallow enough for the destination underneath it to survive.
///
/// It stays the Scaffold's floating action button rather than becoming part
/// of the bar, so the bar reserves only its own height and the button hovers
/// over the page as it always has, instead of costing every screen another
/// 50-odd points of bottom padding.
class AboveNavBarFabLocation extends FloatingActionButtonLocation {
  const AboveNavBarFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final x = (geometry.scaffoldSize.width - geometry.floatingActionButtonSize.width) / 2;
    // contentBottom is the top of the bottom navigation bar — which, since
    // AppNavBar puts its padding *below* the bar, is the bar's own top edge.
    final y = geometry.contentBottom + AppNavBar.fabDip - geometry.floatingActionButtonSize.height;
    return Offset(x, y);
  }

  @override
  String toString() => 'AboveNavBarFabLocation';
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.destination, required this.selected, required this.onTap});

  final AppNavDestination destination;
  final bool selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // Green on white, and the inactive ones a muted green-grey from the same
    // family rather than a neutral: on a white bar the only thing holding
    // the row together is the hue.
    final color = selected ? AppColors.primary : AppColors.inkFaint;
    return InkWell(
      onTap: () => onTap(destination.index),
      child: Padding(
        // Low in the slot, not centred: the band along the top of the bar
        // belongs to the notch, and the middle destination has to live
        // below it.
        padding: const EdgeInsets.only(bottom: AppNavBar._contentBottomPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? AppColors.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                child: Icon(selected ? destination.selectedIcon : destination.icon, color: color, size: 23),
              ),
            ),
            const SizedBox(height: 3),
            // A slot is a fifth of the screen wide, and the label has to fit
            // it in both languages — "Search"/"Profile" in English, and the
            // Arabic for Home and Chat, which are longer still. So it shrinks
            // rather than wrapping or overflowing the bar.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  destination.label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
