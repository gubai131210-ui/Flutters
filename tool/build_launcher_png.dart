// Raster-style PNG for Android launcher (1024), matching Senti.svg layout without Flutter.
// Run: dart run tool/build_launcher_png.dart
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final String root = Directory.current.path;
  final Directory outDir = Directory('$root${Platform.pathSeparator}assets${Platform.pathSeparator}brand');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }
  final File out = File('${outDir.path}${Platform.pathSeparator}launcher_icon.png');

  const int w = 1024;
  const int h = 1024;
  final img.Image pic = img.Image(width: w, height: h);
  img.fill(pic, color: img.ColorRgb8(0xf3, 0xec, 0xe2));

  const int tx = 307;
  const int ty = 256;

  // Rounded frosted plate (matches Senti.svg rects)
  img.fillRect(
    pic,
    x1: 128,
    y1: 128,
    x2: 896,
    y2: 896,
    color: img.ColorRgba8(255, 255, 255, (0.35 * 255).round()),
    radius: 154,
  );
  img.drawRect(
    pic,
    x1: 128,
    y1: 128,
    x2: 896,
    y2: 896,
    color: img.ColorRgba8(255, 255, 255, (0.6 * 255).round()),
    thickness: 2,
    radius: 154,
  );

  void strokePolyline(List<(int, int)> pts, num thickness, img.Color color) {
    for (var i = 0; i < pts.length - 1; i++) {
      img.drawLine(
        pic,
        x1: pts[i].$1,
        y1: pts[i].$2,
        x2: pts[i + 1].$1,
        y2: pts[i + 1].$2,
        color: color,
        thickness: thickness,
        antialias: true,
      );
    }
  }

  List<(int, int)> quad(int x0, int y0, int cx, int cy, int x1, int y1, {int steps = 24}) {
    final out = <(int, int)>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final ox = (1 - t) * (1 - t) * x0 + 2 * (1 - t) * t * cx + t * t * x1;
      final oy = (1 - t) * (1 - t) * y0 + 2 * (1 - t) * t * cy + t * t * y1;
      out.add((ox.round() + tx, oy.round() + ty));
    }
    return out;
  }

  List<(int, int)> line(int x0, int y0, int x1, int y1, {int steps = 12}) {
    final out = <(int, int)>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      out.add(((x0 + (x1 - x0) * t).round() + tx, (y0 + (y1 - y0) * t).round() + ty));
    }
    return out;
  }

  // Jelly strokes (local coords from Senti.svg <g>)
  strokePolyline(
    <(int, int)>[...quad(108, 81, 162, 45, 216, 81), ...line(216, 81, 270, 126)],
    4,
    img.ColorRgb8(0xa6, 0xb9, 0xc9),
  );
  strokePolyline(
    <(int, int)>[...quad(81, 144, 135, 99, 189, 144), ...line(189, 144, 252, 189)],
    3,
    img.ColorRgb8(0xb8, 0xc8, 0xd6),
  );
  strokePolyline(
    <(int, int)>[...quad(63, 207, 135, 153, 207, 216), ...line(207, 216, 279, 252)],
    2,
    img.ColorRgb8(0x93, 0xa8, 0xb9),
  );
  strokePolyline(quad(99, 270, 162, 225, 225, 270), 4, img.ColorRgb8(0xc5, 0xd2, 0xde));
  strokePolyline(quad(126, 297, 171, 270, 216, 306), 3, img.ColorRgb8(0xa2, 0xb5, 0xc5));

  // "senti" label (bitmap font; centered)
  img.drawString(
    pic,
    'senti',
    font: img.arial48,
    x: 512 - 110,
    y: 720,
    color: img.ColorRgb8(0x6e, 0x84, 0x98),
  );

  // Underline bar
  img.fillRect(
    pic,
    x1: 494,
    y1: 792,
    x2: 494 + 65,
    y2: 792 + 2,
    color: img.ColorRgba8(0xa0, 0xb4, 0xc4, (0.3 * 255).round()),
  );

  final bytes = img.encodePng(pic);
  out.writeAsBytesSync(bytes);
  stdout.writeln('Wrote ${out.path} (${bytes.length} bytes)');
}
