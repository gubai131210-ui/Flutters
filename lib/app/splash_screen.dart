import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/palette_controller.dart';
import '../features/shell/presentation/app_view_models.dart';

const String kSplashTagline = '感念所及，光阴可栖。';

/// Same artwork as the launcher (generated from Senti.svg via flutter_launcher_icons).
const String kSplashAppIconAsset = 'assets/brand/launcher_icon.png';

/// Shown on cold start; after [duration] shows [child] (usually [AppShell]).
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2800),
  });

  final Widget child;
  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final bool reduce = context.read<ShellViewModel>().reduceMotion;
      final Duration d = reduce ? const Duration(milliseconds: 900) : widget.duration;
      Future<void>.delayed(d, () {
        if (mounted) {
          setState(() => _ready = true);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return widget.child;
    }
    final palette = PaletteScope.of(context);
    return ColoredBox(
      color: palette.gradientEnd,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: palette.accent.withValues(alpha: 0.22),
                      blurRadius: 32,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: ColoredBox(
                    color: palette.surface.withValues(alpha: 0.9),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        kSplashAppIconAsset,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder:
                            (BuildContext context, Object error, StackTrace? stack) {
                          return Icon(
                            Icons.image_not_supported_outlined,
                            color: palette.textSecondary,
                            size: 40,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                kSplashTagline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
