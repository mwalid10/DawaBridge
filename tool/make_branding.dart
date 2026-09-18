// Turns the raw DawaBridge logo export into the assets the app and the
// launcher-icon generator need.
//
// The source is a 2048x2048 render with the mark floating in a lot of empty
// space. Feeding that straight to flutter_launcher_icons produces a
// launcher icon where the logo occupies a small patch in the middle — and
// Android's adaptive icons crop to the centre ~66% on top of that, which
// would shrink it further still.
//
// So: trim to the mark's true bounds first, then re-pad deliberately.
//
// Run with:  dart run tool/make_branding.dart
import 'dart:io';

import 'package:image/image.dart';

const _source = 'assets/branding/logo_source.png';

void main() {
  final bytes = File(_source).readAsBytesSync();
  final src = decodePng(bytes);
  if (src == null) {
    stderr.writeln('Could not decode $_source');
    exit(1);
  }
  stdout.writeln('source: ${src.width}x${src.height}, alpha: ${src.numChannels == 4}');

  final bounds = _contentBounds(src);
  stdout.writeln(
    'content bounds: x=${bounds.x} y=${bounds.y} w=${bounds.width} h=${bounds.height} '
    '(${(bounds.width / src.width * 100).round()}% of canvas)',
  );

  final trimmed = copyCrop(
    src,
    x: bounds.x,
    y: bounds.y,
    width: bounds.width,
    height: bounds.height,
  );

  // 1. In-app logo: transparent background, tight. Screens choose their own
  //    backdrop, so baking white in would show as a white slab on the
  //    gradient hero.
  _write('assets/branding/logo.png', _square(trimmed, 1024, padding: 0.04, background: null));

  // 2. Launcher icon: white background, as asked. More padding, because the
  //    OS rounds/masks the corners and a mark that runs to the edge gets
  //    clipped.
  _write(
    'assets/branding/icon.png',
    _square(trimmed, 1024, padding: 0.16, background: ColorRgb8(255, 255, 255)),
  );

  // 3. Adaptive-icon foreground: transparent, and padded harder still.
  //    Android guarantees only the centre 66% of this is visible; the rest
  //    can be cropped by whatever mask the launcher applies.
  _write('assets/branding/icon_foreground.png', _square(trimmed, 1024, padding: 0.30, background: null));

  // 4. Android native launch image, per density.
  //
  //    This is what shows between the process starting and Flutter's first
  //    frame. Without it the window is a flat colour and the logo appears
  //    only once Dart is up, which on a cold start reads as a stall.
  //    Transparent, so the white window background shows through.
  //
  //    Sized off a ~180dp target width: the mark is wide and short, so
  //    width is what to reason about, not the usual square-icon logic.
  const densities = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  };
  const baseWidthDp = 180;

  for (final entry in densities.entries) {
    final width = (baseWidthDp * entry.value).round();
    final height = (width * trimmed.height / trimmed.width).round();
    final image = copyResize(trimmed, width: width, height: height, interpolation: Interpolation.cubic);

    final dir = Directory('android/app/src/main/res/drawable-${entry.key}');
    dir.createSync(recursive: true);
    _write('${dir.path}/launch_image.png', image);
  }

  stdout.writeln('done');
}

/// Bounding box of everything that isn't blank.
///
/// Treats both transparent and near-white pixels as background, since the
/// export may or may not carry an alpha channel.
_Rect _contentBounds(Image image) {
  var minX = image.width, minY = image.height, maxX = -1, maxY = -1;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final isTransparent = p.a < 16;
      final isNearWhite = p.r > 244 && p.g > 244 && p.b > 244;
      if (isTransparent || isNearWhite) continue;

      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }

  if (maxX < 0) return _Rect(0, 0, image.width, image.height);
  return _Rect(minX, minY, maxX - minX + 1, maxY - minY + 1);
}

/// Centres [content] on a square canvas of [size], leaving [padding] (as a
/// fraction of the canvas) clear on the tightest axis.
Image _square(Image content, int size, {required double padding, Color? background}) {
  final canvas = Image(width: size, height: size, numChannels: 4);
  if (background != null) {
    fill(canvas, color: background);
  } else {
    fill(canvas, color: ColorRgba8(0, 0, 0, 0));
  }

  final inner = (size * (1 - padding * 2)).round();
  // Scale to fit the inner box, preserving aspect — the mark is much wider
  // than it is tall, so height must not be the driver.
  final scale = inner / (content.width > content.height ? content.width : content.height);
  final w = (content.width * scale).round();
  final h = (content.height * scale).round();

  final resized = copyResize(content, width: w, height: h, interpolation: Interpolation.cubic);
  compositeImage(canvas, resized, dstX: (size - w) ~/ 2, dstY: (size - h) ~/ 2);
  return canvas;
}

void _write(String path, Image image) {
  File(path).writeAsBytesSync(encodePng(image));
  final kb = (File(path).lengthSync() / 1024).toStringAsFixed(0);
  stdout.writeln('wrote $path (${image.width}x${image.height}, ${kb}KB)');
}

class _Rect {
  const _Rect(this.x, this.y, this.width, this.height);
  final int x, y, width, height;
}
