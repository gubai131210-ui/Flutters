import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/models/fragment_models.dart';
import '../../../core/theme/senti_theme.dart';

/// Shared bottom sheet for multi-select tag picking (Capture & Search).
class FeelingTagPickerSheet extends StatefulWidget {
  const FeelingTagPickerSheet({
    super.key,
    required this.scrollController,
    required this.palette,
    required this.options,
    required this.initial,
    this.title = '选择标签',
  });

  final ScrollController scrollController;
  final SentiPalette palette;
  final List<FeelingTagDefinition> options;
  final Set<String> initial;
  final String title;

  @override
  State<FeelingTagPickerSheet> createState() => _FeelingTagPickerSheetState();
}

class _FeelingTagPickerSheetState extends State<FeelingTagPickerSheet> {
  late Set<String> _selected;
  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initial);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: Material(
        color: widget.palette.surface.withValues(alpha: 0.96),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.palette.textSecondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: widget.palette.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _query,
                decoration: const InputDecoration(
                  hintText: '搜索标签…',
                  prefixIcon: Icon(LucideIcons.search),
                ),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _query,
                builder: (BuildContext context, TextEditingValue value, Widget? child) {
                  final String q = value.text.trim().toLowerCase();
                  final List<FeelingTagDefinition> filtered = q.isEmpty
                      ? widget.options
                      : widget.options
                          .where(
                            (FeelingTagDefinition d) =>
                                d.label.toLowerCase().contains(q) ||
                                d.emoji.contains(q) ||
                                d.keywords.any((String k) => k.toLowerCase().contains(q)),
                          )
                          .toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        '没有匹配的标签',
                        style: TextStyle(color: widget.palette.textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (BuildContext context, int index) {
                      final FeelingTagDefinition d = filtered[index];
                      final bool on = _selected.contains(d.label);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FilterChip(
                          label: Text('${d.emoji} ${d.label}'),
                          selected: on,
                          onSelected: (bool value) {
                            setState(() {
                              if (value) {
                                _selected.add(d.label);
                              } else {
                                _selected.remove(d.label);
                              }
                            });
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the tag picker and returns selected labels, or null if dismissed.
Future<Set<String>?> showFeelingTagPicker(
  BuildContext context, {
  required SentiPalette palette,
  required List<FeelingTagDefinition> options,
  Set<String> initial = const <String>{},
  String title = '选择标签',
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (BuildContext _, ScrollController scrollController) {
          return FeelingTagPickerSheet(
            scrollController: scrollController,
            palette: palette,
            options: options,
            initial: Set<String>.from(initial),
            title: title,
          );
        },
      );
    },
  );
}
