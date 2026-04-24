import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../app/service_locator.dart';
import '../../../core/models/fragment_models.dart';
import '../../../core/theme/palette_controller.dart';
import '../../player/presentation/player_route.dart';
import '../../shell/presentation/app_view_models.dart';
import '../../shared/presentation/glass_surface.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CalendarViewModel>(
      create: (_) => getIt<CalendarViewModel>(),
      child: const _CalendarPageBody(),
    );
  }
}

class _CalendarPageBody extends StatelessWidget {
  const _CalendarPageBody();

  @override
  Widget build(BuildContext context) {
    final calendar = context.watch<CalendarViewModel>();
    final palette = PaletteScope.of(context);
    return RefreshIndicator(
      onRefresh: calendar.refresh,
      color: palette.accent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: <Widget>[
          Text(
            '情绪日历',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          GlassSurface(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Icon(LucideIcons.flame, color: palette.accent),
                const SizedBox(width: 8),
                Text('连续记录 ${calendar.streak} 天'),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final path = await calendar.exportMonthToMarkdown();
                      messenger.showSnackBar(
                        SnackBar(content: Text('已导出：$path')),
                      );
                    } catch (error) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('导出失败：$error')),
                      );
                    }
                  },
                  icon: const Icon(LucideIcons.download, size: 16),
                  label: const Text('导出本月 MD'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassSurface(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: calendar.previousMonth,
                      icon: const Icon(LucideIcons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        '${calendar.month.year}年${calendar.month.month}月',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: calendar.nextMonth,
                      icon: const Icon(LucideIcons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (calendar.loading)
                  const Center(child: CircularProgressIndicator())
                else if (calendar.days.isEmpty)
                  const Text('本月还没有记录。')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: calendar.days.map((CalendarDaySummary day) {
                      return _DayTile(
                        summary: day,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _showDaySheet(context, day);
                        },
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassSurface(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '近 7 天记录趋势',
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (calendar.weeklyTrend.isEmpty)
                  Text('暂无趋势数据', style: TextStyle(color: palette.textSecondary))
                else
                  _TrendBarChart(points: calendar.weeklyTrend),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassSurface(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '标签分布（30天）',
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                if (calendar.tagDistribution.isEmpty)
                  Text('暂无标签分布', style: TextStyle(color: palette.textSecondary))
                else
                  _TagDistributionBars(points: calendar.tagDistribution),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassSurface(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('本周回顾', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('记录次数：${calendar.weekly.entryCount}'),
                const SizedBox(height: 4),
                Text('主情绪：${calendar.weekly.primaryMood}'),
                const SizedBox(height: 4),
                Text(
                  '高频标签：${calendar.weekly.topTags.isEmpty ? '暂无' : calendar.weekly.topTags.join(' / ')}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDaySheet(BuildContext context, CalendarDaySummary summary) {
    final palette = PaletteScope.of(context);
    final calendar = context.read<CalendarViewModel>();
    final items = calendar.fragmentsOnDay(summary.date);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return PaletteScope(
          palette: palette,
          nightMuted: PaletteScope.nightOf(context),
          child: DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            expand: false,
            builder: (BuildContext context, ScrollController controller) {
              return Container(
                decoration: BoxDecoration(
                  color: palette.gradientEnd,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Icon(LucideIcons.calendar_days, color: palette.accent),
                        const SizedBox(width: 8),
                        Text(
                          '${summary.date.year}年${summary.date.month}月${summary.date.day}日',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text('${summary.count} 条',
                            style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Text('这一天没有记录',
                                  style: TextStyle(color: palette.textSecondary)))
                          : ListView.separated(
                              controller: controller,
                              itemCount: items.length,
                              separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 10),
                              itemBuilder: (BuildContext context, int index) {
                                final FragmentRecord item = items[index];
                                return GlassSurface(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(item.title,
                                          style: TextStyle(
                                            color: palette.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          )),
                                      const SizedBox(height: 4),
                                      Text(item.previewText,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: palette.textSecondary,
                                            fontSize: 13,
                                            height: 1.4,
                                          )),
                                      if (item.tags.isNotEmpty) ...<Widget>[
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: item.tags.take(4).map((String tag) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: palette.accent.withValues(alpha: 0.16),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text('#$tag',
                                                  style: TextStyle(
                                                      color: palette.textPrimary, fontSize: 11)),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    if (items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).pop();
                            openPlayer(context);
                          },
                          icon: const Icon(LucideIcons.play),
                          label: const Text('进入放映查看'),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.summary, required this.onTap});

  final CalendarDaySummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 76,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('${summary.date.day}日', style: const TextStyle(fontSize: 11)),
              Text(
                summary.primaryTag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text('${summary.count}条',
                  style: TextStyle(fontSize: 11, color: palette.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendBarChart extends StatelessWidget {
  const _TrendBarChart({required this.points});

  final List<DailyTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    final maxValue = points.map((DailyTrendPoint point) => point.count).fold<int>(1, (int prev, int item) {
      return item > prev ? item : prev;
    });
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((DailyTrendPoint point) {
          final ratio = point.count == 0 ? 0.08 : point.count / maxValue;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    height: 78 * ratio + 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: <Color>[
                          palette.accent.withValues(alpha: 0.88),
                          palette.textSecondary.withValues(alpha: 0.78),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${point.date.month}/${point.date.day}',
                    style: TextStyle(fontSize: 10, color: palette.textSecondary),
                  ),
                  Text(
                    '${point.count}',
                    style: TextStyle(
                        fontSize: 10, color: palette.textPrimary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TagDistributionBars extends StatelessWidget {
  const _TagDistributionBars({required this.points});

  final List<TagDistributionPoint> points;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    final total = points.fold<int>(0, (int value, TagDistributionPoint point) => value + point.count);
    final maxValue = points.fold<int>(1, (int value, TagDistributionPoint point) {
      return point.count > value ? point.count : value;
    });
    return Column(
      children: points.map((TagDistributionPoint point) {
        final ratio = point.count / maxValue;
        final share = total == 0 ? 0 : ((point.count / total) * 100).round();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 56,
                child: Text(
                  point.tag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: palette.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: ratio,
                    backgroundColor: palette.surface.withValues(alpha: 0.52),
                    valueColor: AlwaysStoppedAnimation<Color>(palette.accent.withValues(alpha: 0.9)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$share%',
                style: TextStyle(color: palette.textSecondary, fontSize: 11),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
