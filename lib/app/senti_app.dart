import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/stores/fragment_store.dart';
import '../core/theme/palette_controller.dart';
import '../core/theme/senti_theme.dart';
import 'splash_screen.dart';
import '../features/shell/presentation/app_shell.dart';
import '../features/shell/presentation/app_view_models.dart';
import 'service_locator.dart';

/// Root of the app.
///
/// We keep the first-frame provider list minimal: only Shell + Palette +
/// FragmentStore + Home are eager. Player/Calendar/Settings/Capture/Search
/// are created on-demand by their page widgets so cold-start does not spin
/// up audio players, playlists, tflite predictions etc. for tabs the user
/// may never open.
class SentiApp extends StatelessWidget {
  const SentiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ShellViewModel>.value(
          value: getIt<ShellViewModel>(),
        ),
        ChangeNotifierProvider<PaletteController>.value(
          value: getIt<PaletteController>(),
        ),
        ChangeNotifierProvider<FragmentStore>.value(
          value: getIt<FragmentStore>(),
        ),
        ChangeNotifierProvider<HomeViewModel>(
          create: (_) => getIt<HomeViewModel>(),
        ),
      ],
      child: Consumer<PaletteController>(
        builder: (BuildContext context, PaletteController palette, _) {
          return TweenAnimationBuilder<double>(
            key: ValueKey<String>('${palette.palette.name}_${palette.packId}'),
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double t, _) {
              // During key change the tween restarts, and the palette
              // itself is already the "end" palette. We use t only for a
              // soft "fade-in" opacity of the whole tree on switch.
            return AnimatedTheme(
              data: SentiTheme.build(palette.palette),
              duration: const Duration(milliseconds: 600),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'Senti',
                theme: SentiTheme.build(palette.palette),
                // PaletteScope wraps every navigator route (including push)
                // via builder so Capture / Search / Detail / Calendar sheet /
                // Player full-screen all inherit palette context.
                builder: (BuildContext context, Widget? child) {
                  return PaletteScope(
                    palette: palette.palette,
                    nightMuted: palette.nightMuted,
                    child: Opacity(
                      opacity: 0.4 + 0.6 * t,
                      child: child ?? const SizedBox.shrink(),
                    ),
                  );
                },
                home: const SplashScreen(
                  duration: Duration(milliseconds: 2800),
                  child: AppShell(),
                ),
              ),
            );
            },
          );
        },
      ),
    );
  }
}

