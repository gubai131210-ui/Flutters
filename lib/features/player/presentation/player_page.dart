import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../app/service_locator.dart';
import '../../../core/models/fragment_models.dart';
import '../../../core/theme/palette_controller.dart';
import 'film_grain_overlay.dart';
import 'player_particle_field.dart';
import '../../shared/presentation/fragment_media_preview.dart';
import '../../shared/presentation/glass_surface.dart';
import '../../shell/presentation/app_view_models.dart';

/// Player tab. Owns its ViewModel (lazy) and a [VisibilityProbe] so the slide
/// timer / fragment audio only run while this tab is in the foreground.
class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PlayerViewModel>(
      create: (_) {
        final vm = getIt<PlayerViewModel>();
        vm.initForFeeling('', autoStartBgm: false);
        return vm;
      },
      child: const _PlayerPageBody(),
    );
  }
}

class _PlayerPageBody extends StatefulWidget {
  const _PlayerPageBody();

  @override
  State<_PlayerPageBody> createState() => _PlayerPageBodyState();
}

class _PlayerPageBodyState extends State<_PlayerPageBody> with WidgetsBindingObserver {
  late final PageController _controller = PageController(viewportFraction: 0.92);
  bool _attemptedAutoBgm = false;
  int _lastAnimatedIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tell VM we are visible on first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<PlayerViewModel>().setVisible(true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }
    final player = context.read<PlayerViewModel>();
    if (state == AppLifecycleState.resumed) {
      player.setVisible(true);
    } else {
      player.setVisible(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (mounted) {
      try {
        context.read<PlayerViewModel>().setVisible(false);
      } catch (_) {}
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerViewModel>();
    final shell = context.watch<ShellViewModel>();
    final palette = PaletteScope.of(context);
    if (player.playlist.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_lastAnimatedIndex != player.currentIndex) {
      _lastAnimatedIndex = player.currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) {
          _controller.animateToPage(
            player.currentIndex,
            duration: const Duration(milliseconds: 560),
            curve: Curves.easeOutQuart,
          );
        }
        if (!_attemptedAutoBgm && player.bgmFiles.isNotEmpty && !player.bgmPlaying) {
          _attemptedAutoBgm = true;
          player.toggleBgm();
        }
      });
    }

    return GestureDetector(
      onDoubleTap: () {
        HapticFeedback.mediumImpact();
        shell.setImmersive(!shell.immersive);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1.2,
                        colors: <Color>[
                          palette.glow.withValues(alpha: 0.28),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: PlayerParticleField(
                    accent: palette.accent,
                    nightMuted: PaletteScope.nightOf(context),
                  ),
                ),
                PageView.builder(
                  controller: _controller,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: player.jumpTo,
                  itemCount: player.playlist.length,
                  itemBuilder: (BuildContext context, int index) {
                    final fragment = player.playlist[index];
                    // Only the active slide + direct neighbors get `inlineVideo:true`.
                    return _SlideCard(
                      fragment: fragment,
                      active: index == player.currentIndex,
                      pageController: _controller,
                      pageIndex: index.toDouble(),
                    );
                  },
                ),
                const Positioned.fill(child: FilmGrainOverlay()),
                if (shell.immersive)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: LinearProgressIndicator(
                      minHeight: 1,
                      value: player.progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(palette.accent.withValues(alpha: 0.95)),
                    ),
                  ),
                if (shell.immersive)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        shell.setImmersive(false);
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.28),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(LucideIcons.minimize_2),
                    ),
                  ),
              ],
            ),
          ),
          AnimatedSlide(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            offset: shell.immersive ? const Offset(0, 1.4) : Offset.zero,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: shell.immersive ? 0 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 12),
                  _MusicBar(
                    bgmPlaying: player.bgmPlaying,
                    hasBgm: player.bgmFiles.isNotEmpty,
                    onToggle: () async {
                      HapticFeedback.selectionClick();
                      await player.toggleBgm();
                    },
                  ),
                  const SizedBox(height: 10),
                  GlassSurface(
                    borderRadius: 24,
                    opacity: 0.74,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            player.previous();
                          },
                          icon: const Icon(LucideIcons.skip_back),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            player.toggleAutoplay();
                          },
                          icon: Icon(player.autoplay ? LucideIcons.pause : LucideIcons.play),
                          label: Text(player.autoplay ? '暂停切换' : '继续切换'),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            shell.setImmersive(true);
                          },
                          icon: const Icon(LucideIcons.maximize_2),
                        ),
                        IconButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            player.next();
                          },
                          icon: const Icon(LucideIcons.skip_forward),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({
    required this.fragment,
    required this.active,
    required this.pageController,
    required this.pageIndex,
  });

  final FragmentRecord fragment;
  final bool active;
  final PageController pageController;
  final double pageIndex;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    final accent = fragment.dominantColor == null ? palette.accent : Color(fragment.dominantColor!);
    return AnimatedBuilder(
      animation: pageController,
      builder: (BuildContext context, Widget? _) {
        final double page = pageController.hasClients && pageController.page != null
            ? pageController.page!
            : pageController.initialPage.toDouble();
        final double delta = (pageIndex - page).clamp(-1.0, 1.0);
        final double mediaShift = delta * 16;
        final double textShift = delta * -8;
        final double tagShift = delta * -4;

        return AnimatedScale(
          scale: active ? 1 : 0.92,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: active ? 1 : 0.54,
            duration: const Duration(milliseconds: 520),
            child: RepaintBoundary(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      palette.surface.withValues(alpha: 0.64),
                      Colors.black.withValues(alpha: 0.24),
                    ],
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 42,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      _iconFor(fragment.kind),
                      color: Colors.white.withValues(alpha: 0.92),
                      size: 22,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        fragment.tags.isEmpty ? '记录' : fragment.tags.first,
                        style: TextStyle(color: palette.textPrimary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final bool hasMedia = fragment.media.isNotEmpty;
                        final double fontSize = fragment.kind == FragmentKind.text ? 26 : 22;
                        return Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            if (hasMedia)
                              Positioned.fill(
                                child: Transform.translate(
                                  offset: Offset(mediaShift, 0),
                                  child: FragmentMediaPreview(
                                    key: ValueKey<String>('${fragment.id}_player_preview'),
                                    media: fragment.media,
                                    active: active,
                                    inlineVideo: active,
                                    videoVolume: 0.35,
                                    height: constraints.maxHeight,
                                    borderRadius: 28,
                                    accent: accent,
                                    gradientEnd: palette.gradientEnd,
                                  ),
                                ),
                              )
                            else
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: <Color>[
                                        accent.withValues(alpha: 0.68),
                                        palette.gradientEnd.withValues(alpha: 0.4),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: <Color>[
                                      Colors.black.withValues(alpha: 0.12),
                                      Colors.black.withValues(alpha: 0.62),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: Transform.translate(
                                offset: Offset(textShift, 0),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Text(
                                    fragment.heroText,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.w500,
                                      height: 1.42,
                                      color: Colors.white,
                                      shadows: const <Shadow>[
                                        Shadow(blurRadius: 14, color: Colors.black54, offset: Offset(0, 2)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Transform.translate(
                  offset: Offset(tagShift, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: fragment.tags.map((String tag) {
                      return Chip(
                        label: Text('#$tag'),
                        side: BorderSide.none,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                      );
                    }).toList(),
                  ),
                ),
              ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MusicBar extends StatelessWidget {
  const _MusicBar({
    required this.bgmPlaying,
    required this.hasBgm,
    required this.onToggle,
  });

  final bool bgmPlaying;
  final bool hasBgm;
  final Future<void> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    return GlassSurface(
      borderRadius: 24,
      opacity: 0.74,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: <Widget>[
          const Icon(LucideIcons.music_4),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasBgm ? '本地 BGM 已接入，可在设置页继续导入' : '暂无本地 BGM，去设置页导入一首钢琴曲',
              style: TextStyle(color: palette.textPrimary, fontSize: 12),
            ),
          ),
          IconButton(
            onPressed: hasBgm ? onToggle : null,
            icon: Icon(bgmPlaying ? LucideIcons.pause : LucideIcons.play),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(FragmentKind kind) {
  return switch (kind) {
    FragmentKind.photo => LucideIcons.image,
    FragmentKind.text => LucideIcons.book_open,
    FragmentKind.musicMeta => LucideIcons.music_4,
    FragmentKind.localAudio => LucideIcons.audio_lines,
    FragmentKind.voiceRecord => LucideIcons.mic,
    FragmentKind.video => LucideIcons.film,
    FragmentKind.moodColor => LucideIcons.palette,
    FragmentKind.bookMovie => LucideIcons.clapperboard,
    FragmentKind.weatherSnapshot => LucideIcons.cloud_sun,
    FragmentKind.location => LucideIcons.map_pinned,
  };
}
