import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../core/models/fragment_models.dart';
import '../../../core/theme/palette_controller.dart';
import '../../shared/presentation/feeling_tag_picker_sheet.dart';
import '../../shared/presentation/fragment_detail_sheet.dart';
import '../../shared/presentation/glass_surface.dart';
import '../../shell/presentation/app_view_models.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchViewModel>();
    final palette = PaletteScope.of(context);
    return Scaffold(
      backgroundColor: palette.gradientEnd,
      appBar: AppBar(
        title: const Text('感觉搜索'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '输入一种氛围，或在下方用标签轻触筛选。',
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            _SearchField(
              value: search.query,
              onChanged: search.applyQuery,
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      HapticFeedback.selectionClick();
                      final Set<String>? picked = await showFeelingTagPicker(
                        context,
                        palette: palette,
                        options: search.allTagDefinitions,
                        initial: const <String>{},
                        title: '按标签筛选',
                      );
                      if (picked == null || picked.isEmpty) {
                        return;
                      }
                      search.applyQuery(picked.first);
                    },
                    icon: const Icon(LucideIcons.list_filter, size: 18),
                    label: const Text('标签筛选'),
                  ),
                  if (search.query.isNotEmpty) ...<Widget>[
                    const SizedBox(width: 8),
                    InputChip(
                      label: Text(
                        search.query,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted: () {
                        HapticFeedback.selectionClick();
                        search.applyQuery('');
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: search.filtered.isEmpty
                  ? Center(
                      child: Text('没有匹配的碎片', style: TextStyle(color: palette.textSecondary)))
                  : ListView.separated(
                      itemCount: search.filtered.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (BuildContext context, int index) {
                        final fragment = search.filtered[index];
                        return _ResultTile(fragment: fragment);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    return GlassSurface(
      borderRadius: 26,
      opacity: 0.78,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: '例如：治愈 / 夜色 / 怀旧 / 通勤',
          prefixIcon: const Icon(LucideIcons.search),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: palette.accent.withValues(alpha: 0.6)),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.fragment});

  final FragmentRecord fragment;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          HapticFeedback.selectionClick();
          showFragmentDetail(context, fragment: fragment);
        },
        child: GlassSurface(
          borderRadius: 24,
          opacity: 0.72,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                fragment.title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (fragment.tags.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  fragment.tags.map((String tag) => '#$tag').join(' '),
                  style: TextStyle(color: palette.accent, fontSize: 12),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                fragment.previewText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textSecondary, height: 1.4, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
