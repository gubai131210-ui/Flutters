import 'dart:math' as math;

import 'package:flutter/material.dart';

class PlayerParticleField extends StatefulWidget {
  const PlayerParticleField({
    super.key,
    required this.accent,
    this.nightMuted = false,
  });

  final Color accent;
  final bool nightMuted;

  @override
  State<PlayerParticleField> createState() => _PlayerParticleFieldState();
}

class _PlayerParticleFieldState extends State<PlayerParticleField> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, _) {
          return CustomPaint(
            painter: _ParticlePainter(
              t: _controller.value,
              accent: widget.accent,
              particleCount: widget.nightMuted ? 16 : 32,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter({
    required this.t,
    required this.accent,
    required this.particleCount,
  });

  final double t;
  final Color accent;
  final int particleCount;

  @override
  void paint(Canvas canvas, Size size) {
    final math.Random random = math.Random(17);
    for (int i = 0; i < particleCount; i++) {
      final double baseX = random.nextDouble();
      final double baseY = random.nextDouble();
      final double drift = ((t + (i / particleCount)) % 1.0);
      final double x = (baseX * size.width) + math.sin((drift * math.pi * 2) + i) * 10;
      final double y = ((baseY + drift) % 1.0) * size.height;
      final double radius = 0.8 + random.nextDouble() * 2.3;
      final Paint paint = Paint()
        ..color = accent.withValues(alpha: 0.08 + random.nextDouble() * 0.14);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.accent != accent || oldDelegate.particleCount != particleCount;
  }
}
