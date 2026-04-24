import 'package:flutter/material.dart';

class SentiPalette {
  const SentiPalette({
    required this.name,
    required this.gradientStart,
    required this.gradientEnd,
    required this.surface,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.glow,
  });

  final String name;
  final Color gradientStart;
  final Color gradientEnd;
  final Color surface;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color glow;
}

class CardTone {
  const CardTone({
    required this.gradientStart,
    required this.gradientEnd,
    required this.chipColor,
    required this.iconColor,
    required this.shadowColor,
    required this.textColor,
  });

  final Color gradientStart;
  final Color gradientEnd;
  final Color chipColor;
  final Color iconColor;
  final Color shadowColor;
  final Color textColor;
}

class SentiTheme {
  static ThemeData build(SentiPalette palette, {String fontFamily = 'sans-serif'}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: Brightness.light,
      surface: palette.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: fontFamily,
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: palette.textPrimary,
            displayColor: palette.textPrimary,
          ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.surface.withValues(alpha: 0.68),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.44),
          ),
        ),
      ),
    );
  }

  static SentiPalette paletteForHour(int hour, {String packId = 'default'}) {
    final anchors = <int, SentiPalette>{
      0: const SentiPalette(
        name: 'midnight',
        gradientStart: Color(0xFF171B2E),
        gradientEnd: Color(0xFF2B3048),
        surface: Color(0xCC2A3046),
        accent: Color(0xFFC2B7FF),
        textPrimary: Color(0xFFF4EEFF),
        textSecondary: Color(0xFFD1C6F0),
        glow: Color(0xAA9C89FF),
      ),
      6: const SentiPalette(
        name: 'morning',
        gradientStart: Color(0xFFF8E9DD),
        gradientEnd: Color(0xFFF9F4EB),
        surface: Color(0xCCFFF8F0),
        accent: Color(0xFF77A27C),
        textPrimary: Color(0xFF473731),
        textSecondary: Color(0xFF7A6B63),
        glow: Color(0xAAEECF8A),
      ),
      12: const SentiPalette(
        name: 'afternoon',
        gradientStart: Color(0xFFE0ECF8),
        gradientEnd: Color(0xFFF4F9FF),
        surface: Color(0xCCEAF5FF),
        accent: Color(0xFF5F89B9),
        textPrimary: Color(0xFF26364A),
        textSecondary: Color(0xFF5C7086),
        glow: Color(0xAA90D6FF),
      ),
      18: const SentiPalette(
        name: 'evening',
        gradientStart: Color(0xFFE7D2C5),
        gradientEnd: Color(0xFFF7EADF),
        surface: Color(0xCCFFF4ED),
        accent: Color(0xFFB7836A),
        textPrimary: Color(0xFF42312B),
        textSecondary: Color(0xFF7D645B),
        glow: Color(0xAAF8B7A3),
      ),
      21: const SentiPalette(
        name: 'night',
        gradientStart: Color(0xFF20273E),
        gradientEnd: Color(0xFF3A3651),
        surface: Color(0xCC2D3148),
        accent: Color(0xFFD5A8FF),
        textPrimary: Color(0xFFF4EFFF),
        textSecondary: Color(0xFFD8CCE8),
        glow: Color(0xAA67B8FF),
      ),
      24: const SentiPalette(
        name: 'midnight',
        gradientStart: Color(0xFF171B2E),
        gradientEnd: Color(0xFF2B3048),
        surface: Color(0xCC2A3046),
        accent: Color(0xFFC2B7FF),
        textPrimary: Color(0xFFF4EEFF),
        textSecondary: Color(0xFFD1C6F0),
        glow: Color(0xAA9C89FF),
      ),
    };

    final entries = anchors.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    for (var index = 0; index < entries.length - 1; index++) {
      final current = entries[index];
      final next = entries[index + 1];
      if (hour >= current.key && hour < next.key) {
        final span = (next.key - current.key).toDouble();
        final t = span == 0 ? 0.0 : (hour - current.key) / span;
        final base = _lerpPalette(current.value, next.value, t);
        return _applyThemePack(base, packId);
      }
    }
    return _applyThemePack(entries.first.value, packId);
  }

  static List<Color> cardRamp(SentiPalette palette, int seed) {
    final hueShift = (seed % 23) - 11.0;
    final primary = HSLColor.fromColor(palette.surface);
    final accent = HSLColor.fromColor(palette.accent);
    return <Color>[
      primary
          .withHue((primary.hue + hueShift).clamp(0, 360))
          .withSaturation((primary.saturation + 0.08).clamp(0.18, 0.86))
          .withLightness((primary.lightness + 0.12).clamp(0.22, 0.95))
          .toColor(),
      accent
          .withHue((accent.hue + hueShift * 0.7).clamp(0, 360))
          .withSaturation((accent.saturation * 0.78).clamp(0.18, 0.86))
          .withLightness((accent.lightness + 0.06).clamp(0.18, 0.9))
          .toColor(),
    ];
  }

  static CardTone cardTone(
    SentiPalette palette,
    int seed, {
    bool hasMedia = false,
    bool highlight = false,
  }) {
    final tier = seed.abs() % 3; // 0 soft, 1 mid, 2 deep
    final base = HSLColor.fromColor(palette.surface);
    final accent = HSLColor.fromColor(palette.accent);
    final roleBias = hasMedia ? 0.04 : -0.01;
    final deepBias = highlight ? 0.05 : 0.0;
    final hueShift = (seed % 31) - 15.0;
    final tierLightness = switch (tier) {
      0 => 0.14,
      1 => 0.06,
      _ => -0.02,
    };

    final start = base
        .withHue((base.hue + hueShift * 0.45).clamp(0, 360))
        .withSaturation((base.saturation + 0.1 + (tier * 0.05)).clamp(0.16, 0.86))
        .withLightness((base.lightness + tierLightness + roleBias).clamp(0.22, 0.94))
        .toColor();
    final end = accent
        .withHue((accent.hue + hueShift * 0.7).clamp(0, 360))
        .withSaturation((accent.saturation * (0.66 + (tier * 0.1))).clamp(0.18, 0.9))
        .withLightness((accent.lightness + (tier == 2 ? -0.03 : 0.08) + deepBias).clamp(0.18, 0.9))
        .toColor();

    final textColor = tier == 2
        ? Color.lerp(palette.textPrimary, Colors.white, 0.35) ?? palette.textPrimary
        : palette.textPrimary;

    return CardTone(
      gradientStart: start.withValues(alpha: 0.92),
      gradientEnd: end.withValues(alpha: 0.9),
      chipColor: end.withValues(alpha: tier == 2 ? 0.22 : 0.16),
      iconColor: end.withValues(alpha: 0.2),
      shadowColor: end.withValues(alpha: tier == 2 ? 0.24 : 0.18),
      textColor: textColor,
    );
  }

  static SentiPalette _lerpPalette(SentiPalette a, SentiPalette b, double t) {
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

  static SentiPalette _applyThemePack(SentiPalette palette, String packId) {
    final start = HSLColor.fromColor(palette.gradientStart);
    final end = HSLColor.fromColor(palette.gradientEnd);
    final accent = HSLColor.fromColor(palette.accent);
    switch (packId) {
      case 'wafuu':
        return SentiPalette(
          name: '${palette.name}_wafuu',
          gradientStart: start.withHue(18).withSaturation(0.34).toColor(),
          gradientEnd: end.withHue(38).withSaturation(0.28).toColor(),
          surface: palette.surface.withValues(alpha: 0.8),
          accent: accent.withHue(24).withSaturation(0.42).toColor(),
          textPrimary: palette.textPrimary,
          textSecondary: palette.textSecondary,
          glow: accent.withHue(12).withSaturation(0.35).toColor().withValues(alpha: 0.5),
        );
      case 'island':
        return SentiPalette(
          name: '${palette.name}_island',
          gradientStart: start.withHue(186).withSaturation(0.42).toColor(),
          gradientEnd: end.withHue(156).withSaturation(0.4).toColor(),
          surface: palette.surface.withValues(alpha: 0.78),
          accent: accent.withHue(168).withSaturation(0.5).toColor(),
          textPrimary: palette.textPrimary,
          textSecondary: palette.textSecondary,
          glow: accent.withHue(178).toColor().withValues(alpha: 0.54),
        );
      case 'code':
        return SentiPalette(
          name: '${palette.name}_code',
          gradientStart: const Color(0xFF0F1521),
          gradientEnd: const Color(0xFF161E2E),
          surface: const Color(0xCC1A2232),
          accent: const Color(0xFF7FE8C1),
          textPrimary: const Color(0xFFE4FFF4),
          textSecondary: const Color(0xFF9FD7C1),
          glow: const Color(0xAA7FE8C1),
        );
      case 'morandi':
        return SentiPalette(
          name: '${palette.name}_morandi',
          gradientStart: start.withSaturation(0.14).withLightness((start.lightness + 0.08).clamp(0.2, 0.95)).toColor(),
          gradientEnd: end.withSaturation(0.16).withLightness((end.lightness + 0.07).clamp(0.2, 0.95)).toColor(),
          surface: palette.surface.withValues(alpha: 0.8),
          accent: accent.withSaturation(0.2).withLightness((accent.lightness + 0.04).clamp(0.18, 0.9)).toColor(),
          textPrimary: palette.textPrimary,
          textSecondary: palette.textSecondary,
          glow: palette.glow.withValues(alpha: 0.34),
        );
      default:
        return palette;
    }
  }
}
