import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class FilmGrainOverlay extends StatefulWidget {
  const FilmGrainOverlay({super.key});

  @override
  State<FilmGrainOverlay> createState() => _FilmGrainOverlayState();
}

class _FilmGrainOverlayState extends State<FilmGrainOverlay> {
  ui.Image? _tile;

  @override
  void initState() {
    super.initState();
    _buildTile();
  }

  Future<void> _buildTile() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final math.Random random = math.Random(42);
    final Paint paint = Paint();
    for (int i = 0; i < 1800; i++) {
      final double x = random.nextDouble() * 256;
      final double y = random.nextDouble() * 256;
      final int c = 110 + random.nextInt(120);
      paint.color = Color.fromARGB(255, c, c, c);
      canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
    }
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(256, 256);
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() {
      _tile = image;
    });
  }

  @override
  void dispose() {
    _tile?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui.Image? tile = _tile;
    if (tile == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _FilmGrainPainter(tile),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _FilmGrainPainter extends CustomPainter {
  const _FilmGrainPainter(this.tile);

  final ui.Image tile;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..blendMode = BlendMode.softLight
      ..color = Colors.white.withValues(alpha: 0.06);
    final Shader shader = ImageShader(
      tile,
      TileMode.repeated,
      TileMode.repeated,
      Matrix4.identity().storage,
    );
    p.shader = shader;
    canvas.drawRect(Offset.zero & size, p);
  }

  @override
  bool shouldRepaint(covariant _FilmGrainPainter oldDelegate) => oldDelegate.tile != tile;
}
