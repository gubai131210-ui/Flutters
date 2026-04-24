import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../../../core/models/fragment_models.dart';
import '../../../core/theme/palette_controller.dart';
import '../../../core/theme/senti_theme.dart';
import '../../player/presentation/player_route.dart';
import '../../settings/presentation/settings_page.dart';
import '../../shared/presentation/fragment_detail_sheet.dart';
import '../../shared/presentation/fragment_media_preview.dart';
import '../../shared/presentation/glass_surface.dart';
import '../../shell/presentation/app_view_models.dart';
import 'pull_to_play.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeViewModel>();
    final shell = context.watch<ShellViewModel>();
    final palette = PaletteScope.of(context);
    final dateText = _dateText(DateTime.now());

    return Stack(
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Text(
                  _timeText(DateTime.now()),
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.textSecondary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    openPlayer(context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '进入放映',
                    style: TextStyle(
                      color: palette.accent,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: home.weatherVisible
                  ? Padding(
                      key: ValueKey<String>(
                        '${home.weatherCity}_${home.weatherSummary}_${home.weatherTempC.round()}',
                      ),
                      padding: const EdgeInsets.only(top: 6),
                      child: _TopWeatherCard(home: home),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: <Widget>[
                  _GlassChip(
                    icon: LucideIcons.wind,
                    label: '${shell.userName}，慢慢呼吸',
                    labelFontSize: 11,
                    onTap: home.nextPrompt,
                    leading: const _BreathingHalo(),
                  ),
                  const SizedBox(width: 8),
                  _GlassChip(
                    icon: LucideIcons.calendar_days,
                    label: dateText,
                  ),
                  const SizedBox(width: 8),
                  _GlassChip(
                    icon: LucideIcons.sparkles,
                    label: home.currentKaomoji,
                    onTap: home.nextCompanion,
                  ),
                  const SizedBox(width: 8),
                  const _SettingsChip(),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: home.refreshGreeting,
              child: Text(
                home.greetingForUser(shell.userName),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: palette.textPrimary,
                      fontSize: 18,
                    ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '碎片不按时间排列，而按你此刻的感觉发光。',
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
            if (home.echoes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _EchoCard(echoes: home.echoes),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: home.loading
                  ? const Center(child: CircularProgressIndicator())
                  : PullToPlay(
                      onRefresh: home.refresh,
                      childBuilder: (ScrollController scroll) => MasonryGridView.count(
                        controller: scroll,
                        clipBehavior: Clip.none,
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        itemCount: home.fragments.length,
                        itemBuilder: (BuildContext context, int index) {
                          final fragment = home.fragments[index];
                          return _MemoryCard(fragment: fragment);
                        },
                      ),
                    ),
            ),
          ],
        ),
        Positioned(
          right: 0,
          bottom: 84,
          child: FloatingActionButton.small(
            heroTag: 'inspiration',
            elevation: 0,
            backgroundColor: palette.surface.withValues(alpha: 0.86),
            foregroundColor: palette.textPrimary,
            onPressed: () {
              HapticFeedback.selectionClick();
              home.nextPrompt();
              final prompt = home.prompt;
              if (prompt == null) {
                return;
              }
              final snackBackground = _inspirationSnackBackground(palette);
              final snackTextColor = _bestContrastText(snackBackground, palette);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: snackBackground,
                  content: Text(
                    '${prompt.emoji} ${prompt.text}',
                    style: TextStyle(
                      color: snackTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      shadows: <Shadow>[
                        Shadow(
                          color: snackTextColor.withValues(alpha: 0.22),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            child: const Icon(LucideIcons.lightbulb),
          ),
        ),
      ],
    );
  }

  String _dateText(DateTime now) {
    const weekdays = <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${now.month}月${now.day}日 ${weekdays[now.weekday - 1]}';
  }

  String _timeText(DateTime now) {
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Color _inspirationSnackBackground(SentiPalette palette) {
    final blended = Color.alphaBlend(
      palette.accent.withValues(alpha: 0.22),
      palette.surface.withValues(alpha: 0.95),
    );
    return blended.withValues(alpha: 0.96);
  }

  Color _bestContrastText(Color background, SentiPalette palette) {
    final useDark = background.computeLuminance() > 0.45;
    if (useDark) {
      return Colors.black.withValues(alpha: 0.86);
    }
    if (palette.textPrimary.computeLuminance() > 0.62) {
      return Colors.white.withValues(alpha: 0.96);
    }
    return palette.textPrimary.withValues(alpha: 0.96);
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.leading,
    this.labelFontSize = 12,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? leading;
  final double labelFontSize;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    return GlassSurface(
      borderRadius: 28,
      opacity: 0.7,
      borderOpacity: 0.34,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          leading ?? Icon(icon, size: 16, color: palette.textPrimary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: palette.textPrimary, fontSize: labelFontSize),
          ),
        ],
      ),
    );
  }
}

class _SettingsChip extends StatelessWidget {
  const _SettingsChip();

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    return GlassSurface(
      borderRadius: 28,
      opacity: 0.7,
      borderOpacity: 0.34,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
        );
      },
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(LucideIcons.settings_2, size: 16, color: palette.textPrimary),
          const SizedBox(width: 8),
          Text('设置', style: TextStyle(color: palette.textPrimary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _TopWeatherCard extends StatelessWidget {
  const _TopWeatherCard({required this.home});

  final HomeViewModel home;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    return GlassSurface(
      borderRadius: 16,
      opacity: 0.68,
      borderOpacity: 0.32,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: <Widget>[
          _WeatherAnimatedBadge(
            emoji: home.weatherEmoji,
            icon: _iconForWeather(home.weatherCode, home.weatherIsDay),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${home.weatherCity} · ${home.weatherTempC.round()}°C ${home.weatherSummary}',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  home.weatherTip,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForWeather(int weatherCode, bool isDay) {
    if (weatherCode == 0) {
      return isDay ? LucideIcons.sun : LucideIcons.moon_star;
    }
    if (weatherCode <= 3) {
      return LucideIcons.cloud_sun;
    }
    if (weatherCode == 45 || weatherCode == 48) {
      return LucideIcons.cloud_fog;
    }
    if ((weatherCode >= 51 && weatherCode <= 67) ||
        (weatherCode >= 80 && weatherCode <= 82)) {
      return LucideIcons.cloud_rain;
    }
    if (weatherCode >= 71 && weatherCode <= 77) {
      return LucideIcons.cloud_snow;
    }
    if (weatherCode >= 95) {
      return LucideIcons.cloud_lightning;
    }
    return LucideIcons.cloud;
  }
}

class _WeatherAnimatedBadge extends StatefulWidget {
  const _WeatherAnimatedBadge({
    required this.emoji,
    required this.icon,
  });

  final String emoji;
  final IconData icon;

  @override
  State<_WeatherAnimatedBadge> createState() => _WeatherAnimatedBadgeState();
}

class _WeatherAnimatedBadgeState extends State<_WeatherAnimatedBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeInOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(0, -1.2 + (t * 2.4)),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Icon(widget.icon, size: 15, color: palette.accent.withValues(alpha: 0.9)),
                Positioned(
                  bottom: 1,
                  right: 2,
                  child: Text(
                    widget.emoji,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _EchoCard extends StatelessWidget {
  const _EchoCard({required this.echoes});

  final List<FragmentRecord> echoes;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    final first = echoes.first;
    final dayText = '${first.writtenAt.year}年${first.writtenAt.month}月${first.writtenAt.day}日';
    return GlassSurface(
      borderRadius: 18,
      opacity: 0.66,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Icon(LucideIcons.history, size: 18, color: palette.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('那天的你 · $dayText',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 4),
                Text(
                  first.previewText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          if (echoes.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('+${echoes.length - 1}',
                  style: TextStyle(color: palette.textPrimary, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.fragment,
  });

  final FragmentRecord fragment;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    final accent = fragment.dominantColor == null ? palette.accent : Color(fragment.dominantColor!);
    final tone = SentiTheme.cardTone(
      palette,
      fragment.randomSeed + fragment.id.hashCode,
      hasMedia: fragment.media.isNotEmpty,
      highlight: fragment.tags.length >= 3,
    );
    final mediaStats = _mediaStats(fragment.media);

    return Material(
      color: Colors.transparent,
      child: InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () {
        HapticFeedback.selectionClick();
        showFragmentDetail(context, fragment: fragment);
      },
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              tone.gradientStart,
              tone.gradientEnd,
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: tone.shadowColor,
              blurRadius: 30,
              spreadRadius: 3,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.44)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: tone.iconColor,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          _iconFor(fragment.kind),
                          size: 18,
                          color: tone.textColor,
                        ),
                      ),
                      const Spacer(),
                      if (mediaStats.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            mediaStats,
                            style: TextStyle(fontSize: 11, color: tone.textColor),
                          ),
                        ),
                    ],
                  ),
                  if (fragment.media.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    FragmentMediaPreview(
                      key: ValueKey<String>('${fragment.id}_home_preview'),
                      media: fragment.media,
                      active: true,
                      inlineVideo: false,
                      height: 128,
                      borderRadius: 22,
                      accent: accent,
                      gradientEnd: palette.gradientEnd,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: fragment.tags.take(3).map((String tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: tone.chipColor,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(fontSize: 11, color: tone.textColor),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    fragment.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tone.textColor,
                    ),
                  ),
                  if ((fragment.subtitle ?? '').isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      fragment.subtitle!,
                      style: TextStyle(color: tone.textColor.withValues(alpha: 0.78), fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    fragment.previewText,
                    maxLines: fragment.layoutHint == 'quote' ? 5 : 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: tone.textColor.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ),
    );
  }

  IconData _iconFor(FragmentKind kind) {
    return switch (kind) {
      FragmentKind.photo => LucideIcons.ticket,
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

  String _mediaStats(List<FragmentMedia> media) {
    if (media.isEmpty) {
      return '';
    }
    var image = 0;
    var audio = 0;
    var video = 0;
    for (final item in media) {
      switch (item.kind) {
        case MediaKind.image:
          image++;
        case MediaKind.audio:
          audio++;
        case MediaKind.video:
          video++;
      }
    }
    final parts = <String>[
      if (image > 0) '图$image',
      if (audio > 0) '音$audio',
      if (video > 0) '视$video',
    ];
    return parts.join(' · ');
  }
}

class _BreathingHalo extends StatefulWidget {
  const _BreathingHalo();

  @override
  State<_BreathingHalo> createState() => _BreathingHaloState();
}

class _BreathingHaloState extends State<_BreathingHalo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: 18 + (t * 6),
          height: 18 + (t * 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.accent.withValues(alpha: 0.16 + (t * 0.12)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: palette.accent.withValues(alpha: 0.3),
                blurRadius: 8 + (t * 12),
                spreadRadius: t * 2,
              ),
            ],
          ),
          child: Icon(
            LucideIcons.wind,
            size: 12,
            color: palette.textPrimary,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
