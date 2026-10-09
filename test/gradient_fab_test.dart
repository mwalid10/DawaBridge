import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_exchange_egypt/core/widgets/gradient_fab.dart';

/// The nav bar's Add button had its shadow declared inside its `Ink`
/// decoration. A Material clips every ink feature to its own bounds
/// (`_RenderInkFeatures.paint` → `canvas.clipRect(Offset.zero & size)`), and
/// that Material is exactly the 56x56 of the button — so the round blur was
/// cut off square and the button sat in a box of shadow.
///
/// Measured in pixels rather than eyeballed, because the difference is a clip
/// nobody would spot in code review twice.
void main() {
  const fab = 56.0;
  const canvas = 200.0;
  // Top-left of the button within the canvas.
  const origin = (canvas - fab) / 2;

  final key = GlobalKey();

  Future<_Pixels> render(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            // Inside the boundary, not around it: a RepaintBoundary captures
            // only its own subtree, so a background painted outside it leaves
            // these pixels transparent — and transparent reads as (0,0,0,0),
            // which any "is it dark?" measure below would score as pure
            // shadow. Hence the white-background assertion in each test.
            child: const ColoredBox(
              color: Color(0xFFFFFFFF),
              child: SizedBox(
                width: canvas,
                height: canvas,
                child: Center(
                  child: GradientFab(icon: Icons.add_rounded, onPressed: _noop),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // Rasterizing goes through the engine, which the test's fake clock never
    // pumps — awaited outside runAsync this deadlocks rather than failing.
    late final _Pixels pixels;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      pixels = _Pixels(data!.buffer.asUint8List(), image.width, image.height);
      image.dispose();
    });
    return pixels;
  }

  testWidgets('the shadow reaches past the button box instead of being clipped to it', (tester) async {
    final pixels = await render(tester);
    expect(pixels.at(4, 4).isWhite, isTrue, reason: 'the canvas is not the opaque white these readings assume');

    // Straight down from the centre, past the bottom edge of the 56x56 box.
    // Clipped to the Material, everything from the edge down is untouched
    // white. The headless rasterizer doesn't apply the mask blur, so what's
    // measured here is the shadow's *extent* — a hard-edged circle of r=28
    // offset 6 down, reaching y = centre + 34 — not its falloff. Sampled
    // well inside that rather than at the rim.
    final belowBox = pixels.at(canvas / 2, origin + fab + 3);

    expect(belowBox.isWhite, isFalse,
        reason: 'no shadow escapes the button box — the ink clip is back');
  });

  testWidgets('the shadow is round, not a square around a round button', (tester) async {
    final pixels = await render(tester);
    expect(pixels.at(4, 4).isWhite, isTrue, reason: 'the canvas is not the opaque white these readings assume');

    // Two points the same distance from the box: one straight below the
    // centre, one diagonally off the bottom-right corner. On a circle the
    // corner is further from the edge of the shape, so it must be lighter.
    // A square shadow — or a square clip of a round one — makes the corner
    // as dark as, or darker than, the point below.
    const d = 4.0;
    final below = pixels.at(canvas / 2, origin + fab + d);
    final corner = pixels.at(origin + fab + d, origin + fab + d);

    expect(corner.darkness, lessThan(below.darkness),
        reason: 'the corner is as dark as directly below it — the shadow has corners');
    expect(below.darkness, greaterThan(0), reason: 'nothing is being drawn below the button at all');
  });

}

void _noop() {}

class _Pixels {
  _Pixels(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width;
  final int height;

  _Pixel at(double x, double y) {
    final i = ((y.round() * width) + x.round()) * 4;
    return _Pixel(bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3]);
  }
}

class _Pixel {
  const _Pixel(this.r, this.g, this.b, this.a);

  final int r;
  final int g;
  final int b;
  final int a;

  bool get isWhite => a == 255 && r == 255 && g == 255 && b == 255;

  /// How far this pixel has been pulled away from the white background.
  int get darkness => (255 - r) + (255 - g) + (255 - b);
}

