import '../models/fragment_models.dart';

class ContextFeatureScorer {
  const ContextFeatureScorer();

  Map<String, double> score({
    required String body,
    required List<FragmentMedia> media,
    required Map<String, dynamic> metadata,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final Map<String, double> scores = <String, double>{};

    void add(String tag, double delta) {
      scores.update(tag, (double v) => v + delta, ifAbsent: () => delta);
    }

    // Time-of-day priors.
    if (t.hour >= 21 || t.hour < 6) {
      add('夜色', 0.42);
      add('宁静', 0.26);
      add('怀旧', 0.18);
    } else if (t.hour >= 6 && t.hour < 10) {
      add('清醒', 0.34);
      add('回暖', 0.18);
    } else if (t.hour >= 12 && t.hour < 16) {
      add('慵懒', 0.24);
      add('日常', 0.14);
    }

    // Media-type priors.
    final bool hasImage = media.any((FragmentMedia m) => m.kind == MediaKind.image);
    final bool hasAudio = media.any((FragmentMedia m) => m.kind == MediaKind.audio);
    final bool hasVideo = media.any((FragmentMedia m) => m.kind == MediaKind.video);
    if (hasVideo) {
      add('电影感', 0.4);
    }
    if (hasAudio) {
      add('夜色', 0.18);
      add('通勤', 0.18);
    }
    if (hasImage) {
      add('柔光', 0.14);
      add('记录', 0.1);
    }

    // Weather snapshot priors.
    final dynamic weatherRaw = metadata['weather'];
    if (weatherRaw is String) {
      final weather = weatherRaw.toLowerCase();
      if (weather.contains('rain') || weather.contains('雨')) {
        add('雨天', 0.5);
        add('怀旧', 0.18);
      }
      if (weather.contains('sun') || weather.contains('晴')) {
        add('清醒', 0.2);
        add('发光', 0.16);
      }
    }

    // Text-length priors.
    final int len = body.trim().runes.length;
    if (len >= 80) {
      add('记录', 0.24);
    } else if (len > 0 && len <= 16) {
      add('失重', 0.12);
      add('柔光', 0.1);
    }

    return scores;
  }
}
