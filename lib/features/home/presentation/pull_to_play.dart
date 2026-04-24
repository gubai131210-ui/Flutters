import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/palette_controller.dart';
import '../../player/presentation/player_route.dart';

class PullToPlay extends StatefulWidget {
  const PullToPlay({
    super.key,
    required this.childBuilder,
    required this.onRefresh,
    this.threshold = 150,
  });

  final Widget Function(ScrollController scroll) childBuilder;
  final Future<void> Function() onRefresh;
  final double threshold;

  @override
  State<PullToPlay> createState() => _PullToPlayState();
}

class _PullToPlayState extends State<PullToPlay> {
  late final ScrollController _scroll = ScrollController();
  double _pullDistance = 0;
  bool _armed = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _updatePullFromMetrics(ScrollMetrics m) {
    if (m.pixels < 0) {
      final pull = -m.pixels;
      if (pull > _pullDistance) {
        _pullDistance = pull;
        final bool armed = _pullDistance >= widget.threshold;
        if (armed != _armed) {
          _armed = armed;
          if (_armed) {
            HapticFeedback.selectionClick();
          }
        }
        setState(() {});
      }
    } else if (m.pixels == 0 && m.minScrollExtent == 0) {
      if (_pullDistance > 0) {
        _pullDistance = 0;
        if (_armed) {
          _armed = false;
        }
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    return Stack(
      children: <Widget>[
        NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notification) {
            if (notification is ScrollUpdateNotification) {
              _updatePullFromMetrics(notification.metrics);
            } else if (notification is OverscrollNotification) {
              if (notification.overscroll < 0) {
                _pullDistance += -notification.overscroll;
                final bool armed = _pullDistance >= widget.threshold;
                if (armed != _armed) {
                  _armed = armed;
                  if (_armed) {
                    HapticFeedback.selectionClick();
                  }
                }
                setState(() {});
              }
            } else if (notification is ScrollEndNotification) {
              if (notification.metrics.pixels >= 0) {
                _pullDistance = 0;
                if (_armed) {
                  _armed = false;
                }
                setState(() {});
              }
            }
            return false;
          },
          child: RefreshIndicator(
            color: palette.accent,
            onRefresh: () async {
              final bool shouldOpen = _armed;
              _pullDistance = 0;
              _armed = false;
              setState(() {});
              if (shouldOpen) {
                HapticFeedback.mediumImpact();
                await openPlayer(context);
                return;
              }
              await widget.onRefresh();
            },
            child: widget.childBuilder(_scroll),
          ),
        ),
        if (_pullDistance > 0)
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: palette.surface.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.accent.withValues(alpha: _armed ? 0.85 : 0.35)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: palette.accent.withValues(alpha: _armed ? 0.24 : 0.12),
                        blurRadius: _armed ? 16 : 8,
                        spreadRadius: _armed ? 2 : 0,
                      ),
                    ],
                  ),
                  child: Text(
                    _armed ? '松手，让今天的碎片开始放映。' : '再往下拉一点，像把幕布慢慢揭开。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 11,
                      fontWeight: _armed ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
