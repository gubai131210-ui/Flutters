import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/palette_controller.dart';

/// Frosted-glass surface without BackdropFilter.
///
/// The app intentionally renders only ONE real BackdropFilter (at the
/// AppShell background). All inner cards use this cheaper simulated glass:
/// a translucent tinted fill + fine highlight border. Saves a full
/// `saveLayer` per card on every frame.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.opacity = 0.72,
    this.borderOpacity = 0.3,
    this.onTap,
    this.highlight = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double opacity;
  final double borderOpacity;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    final night = PaletteScope.nightOf(context);
    final effectiveOpacity = night ? (opacity + 0.08).clamp(0.0, 0.95) : opacity;
    final surface = palette.surface.withValues(alpha: effectiveOpacity);

    final decorated = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: borderOpacity),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: highlight ? 0.08 : 0.04),
            blurRadius: highlight ? 18 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: decorated,
        ),
      );
    }
    return decorated;
  }
}

/// The ONE real blur layer in the app. Put as backmost element behind
/// the AppShell so everything layered above gets the frosted look without
/// needing its own `BackdropFilter`.
class AppBackgroundBlur extends StatelessWidget {
  const AppBackgroundBlur({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: const SizedBox.expand(),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
