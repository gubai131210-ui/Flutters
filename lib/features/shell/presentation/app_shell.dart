import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../app/service_locator.dart';
import '../../../core/theme/palette_controller.dart';
import '../../calendar/presentation/calendar_page.dart';
import '../../capture/presentation/capture_page.dart';
import '../../home/presentation/home_page.dart';
import '../../search/presentation/search_page.dart';
import '../../shared/presentation/glass_surface.dart';
import 'app_view_models.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellViewModel>();
    final palette = PaletteScope.of(context);
    final immersive = shell.immersive;

    // Player is NOT a tab anymore. Three resident pages only.
    final pageBuilders = <WidgetBuilder>[
      (_) => const HomePage(),
      (_) => const CalendarPage(),
      (_) => ChangeNotifierProvider<SearchViewModel>(
            create: (_) => getIt<SearchViewModel>(),
            child: const SearchPage(),
          ),
    ];

    return Scaffold(
      body: Stack(
        children: <Widget>[
          const _AnimatedBackdrop(),
          Positioned(
            top: -80,
            right: -40,
            child: _GlowOrb(color: palette.glow),
          ),
          Positioned(
            bottom: -120,
            left: -60,
            child: _GlowOrb(color: palette.accent.withValues(alpha: 0.25)),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: LazyIndexedStack(
                      index: shell.selectedIndex,
                      reduceMotion: shell.reduceMotion,
                      itemCount: pageBuilders.length,
                      itemBuilder: (BuildContext context, int index) => pageBuilders[index](context),
                    ),
                  ),
                ),
                AnimatedSlide(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  offset: immersive ? const Offset(0, 1.2) : Offset.zero,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: immersive ? 0 : 1,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                      child: _GlassBottomBar(
                        selectedIndex: shell.selectedIndex,
                        onHome: () => _selectTab(context, 0),
                        onCalendar: () => _selectTab(context, 1),
                        onSearch: () => _selectTab(context, 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _selectTab(BuildContext context, int index) {
    final shell = context.read<ShellViewModel>();
    if (shell.selectedIndex != index) {
      HapticFeedback.selectionClick();
    }
    shell.selectTab(index);
  }
}

class _AnimatedBackdrop extends StatelessWidget {
  const _AnimatedBackdrop();

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              palette.gradientStart,
              palette.gradientEnd,
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.itemCount,
    required this.itemBuilder,
    this.reduceMotion = false,
  });

  final int index;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool reduceMotion;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final Set<int> _visited = <int>{};

  @override
  void initState() {
    super.initState();
    _visited.add(widget.index);
  }

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visited.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      for (int i = 0; i < widget.itemCount; i++)
        _visited.contains(i)
            ? _KeepAlivePage(child: widget.itemBuilder(context, i))
            : const SizedBox.shrink(),
    ];

    if (widget.reduceMotion) {
      return IndexedStack(index: widget.index, children: pages);
    }

    return PageTransitionSwitcher(
      duration: const Duration(milliseconds: 320),
      reverse: false,
      transitionBuilder: (
        Widget child,
        Animation<double> primaryAnimation,
        Animation<double> secondaryAnimation,
      ) {
        return FadeThroughTransition(
          animation: primaryAnimation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(widget.index),
        child: pages[widget.index],
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _GlassBottomBar extends StatelessWidget {
  const _GlassBottomBar({
    required this.selectedIndex,
    required this.onHome,
    required this.onCalendar,
    required this.onSearch,
  });

  final int selectedIndex;
  final VoidCallback onHome;
  final VoidCallback onCalendar;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    return GlassSurface(
      borderRadius: 18,
      opacity: 0.74,
      borderOpacity: 0.32,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: _BarItem(
              icon: LucideIcons.house,
              label: '首页',
              selected: selectedIndex == 0,
              onTap: onHome,
            ),
          ),
          Expanded(
            child: _BarItem(
              icon: LucideIcons.calendar_check_2,
              label: '日历',
              selected: selectedIndex == 1,
              onTap: onCalendar,
            ),
          ),
          // Center capture button uses OpenContainer for a container-transform animation.
          Expanded(
            child: OpenContainer(
              closedElevation: 0,
              closedColor: Colors.transparent,
              openColor: palette.surface,
              closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              transitionType: ContainerTransitionType.fadeThrough,
              transitionDuration: const Duration(milliseconds: 420),
              closedBuilder: (BuildContext context, VoidCallback open) {
                return _BarItem(
                  icon: LucideIcons.square_pen,
                  label: '记录',
                  selected: false,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    open();
                  },
                );
              },
              openBuilder: (BuildContext context, _) {
                return ChangeNotifierProvider<CaptureViewModel>(
                  create: (_) => getIt<CaptureViewModel>(),
                  child: const CapturePage(),
                );
              },
            ),
          ),
          Expanded(
            child: _BarItem(
              icon: LucideIcons.search,
              label: '搜索',
              selected: selectedIndex == 2,
              onTap: onSearch,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: selected ? palette.accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              scale: selected ? 1.12 : 1.0,
              child: Icon(
                icon,
                color: selected ? palette.accent : palette.textSecondary,
                size: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? palette.textPrimary : palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
