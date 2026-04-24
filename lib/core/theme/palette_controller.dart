import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_services.dart';
import 'senti_theme.dart';

/// Lightweight controller that owns only the current [SentiPalette] and
/// the active theme pack id. Kept separate from [ShellViewModel] so that
/// frequent palette tweaks do not rebuild widgets that only care about
/// selected tab / user name / import hint.
class PaletteController extends ChangeNotifier {
  PaletteController(this._preferences) {
    _palette = SentiTheme.paletteForHour(DateTime.now().hour, packId: _packId);
    _scheduleNextTick();
    unawaited(_loadPackFromPrefs());
  }

  final AppPreferencesService _preferences;
  Timer? _timer;
  SentiPalette _palette = SentiTheme.paletteForHour(DateTime.now().hour);
  String _packId = 'default';
  bool _nightMuted = _isNightHour(DateTime.now().hour);

  SentiPalette get palette => _palette;
  String get packId => _packId;

  /// Whether we are in the 22:00–07:00 "night mute" window. Consumers can
  /// use this to soften UI chrome / reduce BGM ceiling.
  bool get nightMuted => _nightMuted;

  static bool _isNightHour(int hour) => hour >= 22 || hour < 7;

  Future<void> _loadPackFromPrefs() async {
    final data = await _preferences.load();
    final saved = data['themePack'] as String?;
    if (saved != null && saved.isNotEmpty && saved != _packId) {
      _packId = saved;
      _recompute(force: true);
    }
  }

  Future<void> setPack(String packId) async {
    if (packId == _packId) {
      return;
    }
    _packId = packId;
    final old = await _preferences.load();
    await _preferences.save(<String, dynamic>{...old, 'themePack': packId});
    _recompute(force: true);
  }

  void _scheduleNextTick() {
    _timer?.cancel();
    // Align to the next minute boundary to avoid drift / mid-minute jitter.
    final now = DateTime.now();
    final nextMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    final delay = nextMinute.difference(now);
    _timer = Timer(delay > Duration.zero ? delay : const Duration(seconds: 60), () {
      _recompute();
      _timer = Timer.periodic(const Duration(minutes: 1), (_) => _recompute());
    });
  }

  void _recompute({bool force = false}) {
    final now = DateTime.now();
    final next = SentiTheme.paletteForHour(now.hour, packId: _packId);
    final nextNight = _isNightHour(now.hour);
    if (!force && _paletteClose(next, _palette) && nextNight == _nightMuted) {
      return;
    }
    _palette = next;
    _nightMuted = nextNight;
    notifyListeners();
  }

  /// HSL-distance based equivalence so we only notify when the palette
  /// actually shifts meaningfully.
  bool _paletteClose(SentiPalette a, SentiPalette b) {
    double d(Color x, Color y) {
      final ax = HSLColor.fromColor(x);
      final bx = HSLColor.fromColor(y);
      return (ax.hue - bx.hue).abs() / 360.0 +
          (ax.saturation - bx.saturation).abs() +
          (ax.lightness - bx.lightness).abs();
    }

    return d(a.gradientStart, b.gradientStart) < 0.008 &&
        d(a.gradientEnd, b.gradientEnd) < 0.008 &&
        d(a.accent, b.accent) < 0.008;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// InheritedWidget surface for the current [SentiPalette]. Children that only
/// read a color should use [PaletteScope.of(context)] instead of subscribing
/// to [PaletteController] directly.
class PaletteScope extends InheritedWidget {
  const PaletteScope({
    super.key,
    required this.palette,
    required this.nightMuted,
    required super.child,
  });

  final SentiPalette palette;
  final bool nightMuted;

  static SentiPalette of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PaletteScope>();
    assert(scope != null, 'PaletteScope not found in context');
    return scope!.palette;
  }

  static bool nightOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PaletteScope>();
    return scope?.nightMuted ?? false;
  }

  @override
  bool updateShouldNotify(PaletteScope oldWidget) {
    return palette != oldWidget.palette || nightMuted != oldWidget.nightMuted;
  }
}

/// [Tween] that lerps two palettes in sRGB space. Cheap enough for 800ms
/// cross-fades and avoids jagged HSL-hue wrapping artifacts for small deltas.
class SentiPaletteTween extends Tween<SentiPalette> {
  SentiPaletteTween({required SentiPalette begin, required SentiPalette end})
      : super(begin: begin, end: end);

  @override
  SentiPalette lerp(double t) {
    final a = begin!;
    final b = end!;
    return SentiPalette(
      name: t < 0.5 ? a.name : b.name,
      gradientStart: Color.lerp(a.gradientStart, b.gradientStart, t) ?? a.gradientStart,
      gradientEnd: Color.lerp(a.gradientEnd, b.gradientEnd, t) ?? a.gradientEnd,
      surface: Color.lerp(a.surface, b.surface, t) ?? a.surface,
      accent: Color.lerp(a.accent, b.accent, t) ?? a.accent,
      textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t) ?? a.textPrimary,
      textSecondary: Color.lerp(a.textSecondary, b.textSecondary, t) ?? a.textSecondary,
      glow: Color.lerp(a.glow, b.glow, t) ?? a.glow,
    );
  }
}
