import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../app/service_locator.dart';
import '../../../core/theme/palette_controller.dart';
import '../../shared/presentation/glass_surface.dart';
import '../../shell/presentation/app_view_models.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SettingsViewModel>(
      create: (_) {
        final vm = getIt<SettingsViewModel>();
        unawaited(vm.load());
        return vm;
      },
      child: const _SettingsPageBody(),
    );
  }
}

class _SettingsPageBody extends StatefulWidget {
  const _SettingsPageBody();

  @override
  State<_SettingsPageBody> createState() => _SettingsPageBodyState();
}

class _SettingsPageBodyState extends State<_SettingsPageBody> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final TextEditingController _tagLabelController = TextEditingController();
  final TextEditingController _tagEmojiController = TextEditingController(text: '✨');
  final TextEditingController _tagKeywordsController = TextEditingController();
  Timer? _nameDebounce;

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _nameFocus.dispose();
    _nameController.dispose();
    _tagLabelController.dispose();
    _tagEmojiController.dispose();
    _tagKeywordsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    final palette = PaletteScope.of(context);
    final paletteController = context.watch<PaletteController>();
    if (!_nameFocus.hasFocus && _nameController.text != settings.userName) {
      _nameController.text = settings.userName;
    }
    // Pushed routes are outside AppShell; mirror its backdrop and insets so
    // sections are not clipped and glass chips read the same as in-tab.
    final LinearGradient pageGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        palette.gradientStart,
        palette.gradientEnd,
      ],
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: pageGradient),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: palette.textPrimary,
        title: Text(
          '设置与资源',
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: pageGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
            children: <Widget>[
        Text(
          '这里集中管理用户名、主题氛围、标签引擎、自定义标签与资源。',
          style: TextStyle(color: palette.textSecondary),
        ),
        const SizedBox(height: 16),
        _Section(
          title: '个人化',
          icon: LucideIcons.user_round,
          child: TextField(
            controller: _nameController,
            focusNode: _nameFocus,
            decoration: const InputDecoration(labelText: '用户名（用于欢迎语）'),
            onChanged: (String value) {
              _nameDebounce?.cancel();
              _nameDebounce = Timer(const Duration(milliseconds: 500), () {
                settings.setUserName(value);
              });
            },
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: '主题氛围包',
          icon: LucideIcons.palette,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '切换整体配色基调。所有页面会平滑过渡到新的氛围。',
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SettingsViewModel.themePacks.map(
                  (({String id, String label}) pack) {
                    final selected = settings.themePack == pack.id;
                    return ChoiceChip(
                      label: Text(pack.label),
                      selected: selected,
                      onSelected: (_) async {
                        HapticFeedback.selectionClick();
                        await settings.setThemePack(pack.id);
                        await paletteController.setPack(pack.id);
                      },
                    );
                  },
                ).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: '交互偏好',
          icon: LucideIcons.sliders_horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('减少动效'),
                subtitle: Text(
                  '关闭 Tab 切换的淡入淡出、卡片的缩放，改为静态切换（省电 & 更朴素）。',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
                value: settings.reduceMotion,
                onChanged: (bool value) {
                  HapticFeedback.selectionClick();
                  settings.setReduceMotion(value);
                },
              ),
              const SizedBox(height: 4),
              Text(
                '夜间时段（22:00–07:00）会自动柔化背景色与 BGM 音量。',
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: '自定义标签',
          icon: LucideIcons.tags,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _tagLabelController,
                decoration: const InputDecoration(labelText: '标签名'),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _tagEmojiController,
                      decoration: const InputDecoration(labelText: 'Emoji'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _tagKeywordsController,
                      decoration: const InputDecoration(labelText: '关键词（逗号分隔）'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () async {
                  await settings.addCustomTag(
                    label: _tagLabelController.text,
                    emoji: _tagEmojiController.text,
                    keywordsText: _tagKeywordsController.text,
                  );
                  _tagLabelController.clear();
                  _tagKeywordsController.clear();
                },
                icon: const Icon(LucideIcons.plus),
                label: const Text('新增标签'),
              ),
              const SizedBox(height: 10),
              if (settings.customTags.isEmpty)
                const Text('还没有自定义标签。')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: settings.customTags.map((item) {
                    return InputChip(
                      label: Text('${item.emoji} ${item.label}'),
                      onDeleted: () => settings.removeCustomTag(item.id),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: '音乐导入路径',
          icon: LucideIcons.folder_input,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(settings.importSummary),
              const SizedBox(height: 8),
              Text(settings.bgmSummary),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: settings.toggleImportPathVisibility,
                icon: Icon(settings.revealImportPath ? LucideIcons.eye_off : LucideIcons.eye),
                label: Text(settings.revealImportPath ? '隐藏导入路径' : '查看导入路径'),
              ),
              if (settings.revealImportPath) Text('导入目录：${settings.importHint}'),
              TextButton.icon(
                onPressed: settings.toggleBgmPathVisibility,
                icon: Icon(settings.revealBgmPath ? LucideIcons.eye_off : LucideIcons.eye),
                label: Text(settings.revealBgmPath ? '隐藏 BGM 路径' : '查看 BGM 路径'),
              ),
              if (settings.revealBgmPath) Text('BGM 目录：${settings.bgmHint}'),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: settings.importBgm,
                icon: const Icon(LucideIcons.music_4),
                label: const Text('导入一首本地 BGM'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: '已导入 BGM',
          icon: LucideIcons.list_music,
          child: settings.bgmFiles.isEmpty
              ? const Text('还没有导入本地音乐。建议先准备平缓钢琴曲或轻氛围器乐。')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: settings.bgmFiles.map((String path) {
                    final isBundled = path.startsWith('asset:');
                    final label = isBundled
                        ? path.replaceFirst('asset:', '')
                        : path.split(RegExp(r'[\\/]')).last;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(isBundled ? '$label（内置默认）' : label),
                    );
                  }).toList(),
                ),
        ),
              ],
            ),
          ),
        ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    return GlassSurface(
      borderRadius: 24,
      opacity: 0.74,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: palette.textPrimary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DefaultTextStyle(
            style: TextStyle(color: palette.textPrimary, fontSize: 13, height: 1.5),
            child: child,
          ),
        ],
      ),
    );
  }
}
