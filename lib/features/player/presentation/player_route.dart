import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'player_page.dart';

Future<void> openPlayer(BuildContext context) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 520),
      reverseTransitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
          const PlayerPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final eased = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return AnimatedBuilder(
          animation: eased,
          builder: (context, _) {
            return ClipPath(
              clipper: _CircleRevealClipper(progress: eased.value),
              child: child,
            );
          },
        );
      },
    ),
  );
}

class _CircleRevealClipper extends CustomClipper<Path> {
  const _CircleRevealClipper({required this.progress});

  final double progress;

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, 0);
    final maxRadius = math.sqrt((size.width * size.width) + (size.height * size.height));
    final radius = maxRadius * progress.clamp(0.0, 1.0);
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant _CircleRevealClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}
