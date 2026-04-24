import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../../app/service_locator.dart';
import '../../../core/models/fragment_models.dart';
import '../../../core/services/app_services.dart';
import '../../../core/theme/palette_controller.dart';
import '../../shared/check_in_format.dart';
import '../../shared/presentation/feeling_tag_picker_sheet.dart';
import '../../shared/presentation/glass_surface.dart';
import '../../shell/presentation/app_view_models.dart';

class CapturePage extends StatefulWidget {
  const CapturePage({super.key});

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final Set<String> _selectedTagLabels = <String>{};
  JournalTemplate? _template;
  Map<String, dynamic> _checkInMeta = <String, dynamic>{};
  bool _locating = false;

  @override
  Widget build(BuildContext context) {
    final capture = context.watch<CaptureViewModel>();
    final palette = PaletteScope.of(context);
    _template ??= capture.templateForToday();
    return Scaffold(
      backgroundColor: palette.gradientEnd,
      appBar: AppBar(
        title: const Text('录入碎片'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: <Widget>[
          Text('只需标题和内容，附件可以随时加。',
              style: TextStyle(color: palette.textSecondary, height: 1.5)),
          const SizedBox(height: 16),
          _Block(
            title: '基本信息（必填）',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: JournalTemplate.values.map((JournalTemplate item) {
                    final selected = _template == item;
                    return ChoiceChip(
                      label: Text(item.label),
                      selected: selected,
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _template = item;
                          _titleController.text = item.defaultTitle;
                          _bodyController.text = item.defaultBody;
                        });
                        capture.requestTagSuggestions(_bodyController.text);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  '今日推荐模板：${capture.templateForToday().label}',
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: '标题'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _bodyController,
                  maxLines: 6,
                  onChanged: capture.requestTagSuggestions,
                  decoration: const InputDecoration(labelText: '内容'),
                ),
                if (capture.suggestedTags.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text('AI 推荐', style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: capture.suggestedTags.map((String tag) {
                        final on = _selectedTagLabels.contains(tag);
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text('#$tag'),
                            selected: on,
                            onSelected: (bool value) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                if (value) {
                                  _selectedTagLabels.add(tag);
                                } else {
                                  _selectedTagLabels.remove(tag);
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                GlassSurface(
                  borderRadius: 16,
                  opacity: 0.7,
                  onTap: () => _openTagPicker(context, capture),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: <Widget>[
                      Icon(LucideIcons.tags, size: 18, color: palette.textPrimary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedTagLabels.isEmpty
                              ? '点这里选择标签（可选）'
                              : '已选 ${_selectedTagLabels.length} 个标签，点按可修改',
                          style: TextStyle(color: palette.textPrimary, fontSize: 13),
                        ),
                      ),
                      Icon(LucideIcons.chevron_right, size: 18, color: palette.textSecondary),
                    ],
                  ),
                ),
                if (_selectedTagLabels.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _selectedTagLabels.map((String label) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InputChip(
                            label: Text('#$label'),
                            onDeleted: () {
                              setState(() {
                                _selectedTagLabels.remove(label);
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Block(
            title: '附件栏',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: capture.importPhotos,
                  icon: const Icon(LucideIcons.image),
                  label: const Text('图片（可多选）'),
                ),
                FilledButton.tonalIcon(
                  onPressed: capture.importAudio,
                  icon: const Icon(LucideIcons.audio_lines),
                  label: const Text('音频'),
                ),
                FilledButton.tonalIcon(
                  onPressed: capture.importVideo,
                  icon: const Icon(LucideIcons.film),
                  label: const Text('视频'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    capture.toggleRecording();
                  },
                  icon: Icon(capture.recording ? LucideIcons.square : LucideIcons.mic),
                  label: Text(capture.recording ? '结束录音' : '录音'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _locating ? null : () => _onLocationCheckIn(context),
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.map_pinned),
                  label: Text(_checkInMeta.isEmpty ? '定位打卡' : '已记录位置'),
                ),
              ],
            ),
          ),
          if (capture.importedMedia.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _Block(
              title: '已附加媒体',
              child: Column(
                children: capture.importedMedia.map((FragmentMedia media) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_mediaIcon(media.kind)),
                    title: Text(media.path.split(RegExp(r'[\\/]')).last),
                    subtitle: Text(media.kind.name),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: capture.saving ? null : () => _save(context, capture),
            icon: capture.saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.save),
            label: const Text('保存这条碎片'),
          ),
        ],
      ),
    );
  }

  Future<void> _openTagPicker(BuildContext context, CaptureViewModel capture) async {
    final palette = PaletteScope.of(context);
    HapticFeedback.selectionClick();
    final Set<String>? picked = await showFeelingTagPicker(
      context,
      palette: palette,
      options: capture.tagOptions,
      initial: Set<String>.from(_selectedTagLabels),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedTagLabels
          ..clear()
          ..addAll(picked);
      });
    }
  }

  Future<void> _onLocationCheckIn(BuildContext context) async {
    HapticFeedback.selectionClick();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final perms = getIt<PermissionService>();
    final ok = await perms.ensureLocationPermission();
    if (!context.mounted) {
      return;
    }
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('需要位置权限才能打卡')),
      );
      return;
    }
    setState(() => _locating = true);
    try {
      final Position pos = await Geolocator.getCurrentPosition();
      if (!context.mounted) {
        return;
      }
      String placeText = '';
      try {
        final List<Placemark> marks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (marks.isNotEmpty) {
          placeText = placeTextFromPlacemark(marks.first);
        }
      } catch (_) {
        // System geocoder may fail on some devices; coordinates still stored.
      }
      if (!context.mounted) {
        return;
      }
      final Map<String, dynamic> meta = <String, dynamic>{
        'checkInLat': pos.latitude,
        'checkInLng': pos.longitude,
        'checkInAccuracy': pos.accuracy,
        'checkInAt': DateTime.now().toIso8601String(),
        'checkInPlaceText': placeText,
      };
      setState(() {
        _checkInMeta = meta;
        _locating = false;
      });
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(formatCheckInDisplayLine(meta))),
        );
      }
    } catch (_) {
      if (context.mounted) {
        setState(() => _locating = false);
        messenger.showSnackBar(
          const SnackBar(content: Text('定位失败，请稍后再试')),
        );
      }
    }
  }

  Future<void> _save(BuildContext context, CaptureViewModel capture) async {
    final NavigatorState navigator = Navigator.of(context);
    final manualTags = _selectedTagLabels.toList();

    final inferredKind = _inferKind(capture.importedMedia);
    capture.setKind(inferredKind);
    final emoji = _emojiFor(inferredKind);
    HapticFeedback.mediumImpact();
    await capture.save(
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      manualTags: manualTags,
      metadata: Map<String, dynamic>.from(_checkInMeta),
      emoji: emoji,
    );
    if (_template != null) {
      await capture.markTemplateUsed(_template!);
    }
    capture.resetDraftUiState();
    if (!context.mounted) {
      return;
    }
    setState(() {
      _titleController.clear();
      _bodyController.clear();
      _selectedTagLabels.clear();
      _checkInMeta = <String, dynamic>{};
      _template = null;
    });
    navigator.pop(true);
  }

  FragmentKind _inferKind(List<FragmentMedia> media) {
    if (media.any((FragmentMedia item) => item.kind == MediaKind.video)) {
      return FragmentKind.video;
    }
    if (media.any((FragmentMedia item) => item.kind == MediaKind.image)) {
      return FragmentKind.photo;
    }
    if (media.any((FragmentMedia item) => item.kind == MediaKind.audio)) {
      return FragmentKind.localAudio;
    }
    return FragmentKind.text;
  }

  String _emojiFor(FragmentKind kind) {
    return switch (kind) {
      FragmentKind.photo => '📸',
      FragmentKind.text => '📝',
      FragmentKind.musicMeta => '🎵',
      FragmentKind.localAudio => '🎧',
      FragmentKind.voiceRecord => '🎙️',
      FragmentKind.video => '🎞️',
      FragmentKind.moodColor => '🎨',
      FragmentKind.bookMovie => '🎬',
      FragmentKind.weatherSnapshot => '🌤️',
      FragmentKind.location => '📍',
    };
  }

  IconData _mediaIcon(MediaKind kind) {
    return switch (kind) {
      MediaKind.image => LucideIcons.image,
      MediaKind.audio => LucideIcons.audio_lines,
      MediaKind.video => LucideIcons.film,
    };
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    return GlassSurface(
      borderRadius: 24,
      opacity: 0.74,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
