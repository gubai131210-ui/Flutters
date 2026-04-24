import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../app/service_locator.dart';
import '../../../core/models/fragment_models.dart';
import '../../../core/services/audio_coordinator.dart';
import '../../../core/theme/palette_controller.dart';
import '../check_in_format.dart';
import 'fragment_media_preview.dart';
import 'glass_surface.dart';

/// Shows fragment detail in a bottom sheet (card style, not full-screen Scaffold).
Future<void> showFragmentDetail(
  BuildContext context, {
  required FragmentRecord fragment,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (BuildContext ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (BuildContext context, ScrollController controller) {
          return _FragmentDetailCard(
            fragment: fragment,
            scrollController: controller,
          );
        },
      );
    },
  );
}

class _FragmentDetailCard extends StatefulWidget {
  const _FragmentDetailCard({
    required this.fragment,
    required this.scrollController,
  });

  final FragmentRecord fragment;
  final ScrollController scrollController;

  @override
  State<_FragmentDetailCard> createState() => _FragmentDetailCardState();
}

class _FragmentDetailCardState extends State<_FragmentDetailCard> {
  bool _playInlineVideo = false;
  String? _audioPath;
  bool _audioPlaying = false;

  @override
  void initState() {
    super.initState();
    for (final FragmentMedia m in widget.fragment.media) {
      if (m.kind == MediaKind.audio) {
        _audioPath = m.path;
        break;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // Defer video init until after sheet animation to reduce crashes.
      Future<void>.delayed(const Duration(milliseconds: 420), () {
        if (mounted) {
          setState(() => _playInlineVideo = true);
        }
      });
    });
  }

  @override
  void dispose() {
    unawaited(_stopAudio());
    super.dispose();
  }

  Future<void> _stopAudio() async {
    final audio = getIt<AudioCoordinator>();
    await audio.stopClip();
  }

  Future<void> _toggleAudio() async {
    final path = _audioPath;
    if (path == null) {
      return;
    }
    HapticFeedback.selectionClick();
    final audio = getIt<AudioCoordinator>();
    if (_audioPlaying) {
      await audio.stopClip();
      if (mounted) {
        setState(() => _audioPlaying = false);
      }
      return;
    }
    await audio.playClip(path);
    if (mounted) {
      setState(() => _audioPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    final accent = widget.fragment.dominantColor == null
        ? palette.accent
        : Color(widget.fragment.dominantColor!);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Material(
        color: palette.gradientEnd,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.textSecondary.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: <Widget>[
                  Text(
                    widget.fragment.title,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassSurface(
                    borderRadius: 28,
                    opacity: 0.72,
                    borderOpacity: 0.28,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (widget.fragment.media.isNotEmpty) ...<Widget>[
                          FragmentMediaPreview(
                            key: ValueKey<String>('${widget.fragment.id}_detail_preview'),
                            media: widget.fragment.media,
                            active: true,
                            inlineVideo: _playInlineVideo,
                            height: 220,
                            borderRadius: 22,
                            accent: accent,
                            gradientEnd: palette.gradientEnd,
                          ),
                          if (_audioPath != null) ...<Widget>[
                            const SizedBox(height: 10),
                            FilledButton.tonalIcon(
                              onPressed: _toggleAudio,
                              icon: Icon(_audioPlaying ? LucideIcons.pause : LucideIcons.play),
                              label: Text(_audioPlaying ? '暂停播放' : '播放录音 / 音频'),
                            ),
                          ],
                        ],
                        if ((widget.fragment.subtitle ?? '').trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            widget.fragment.subtitle!,
                            style: TextStyle(color: palette.textSecondary, fontSize: 14),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          widget.fragment.body.isEmpty ? widget.fragment.title : widget.fragment.body,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 15,
                            height: 1.55,
                          ),
                        ),
                        if (widget.fragment.tags.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.fragment.tags.map((String tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: palette.accent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: TextStyle(color: palette.textPrimary, fontSize: 12),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        if (widget.fragment.metadata.containsKey('checkInLat')) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            formatCheckInDisplayLine(
                              Map<String, dynamic>.from(widget.fragment.metadata),
                            ),
                            style: TextStyle(color: palette.textSecondary, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
