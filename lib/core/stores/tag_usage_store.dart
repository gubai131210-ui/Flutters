import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TagUsageStore {
  static const String _kRecent = 'tag_usage_recent_v1';
  static const int _maxRecent = 20;

  SharedPreferences? _prefs;
  List<String> _recent = <String>[];

  Future<void> warmUp() async {
    _prefs ??= await SharedPreferences.getInstance();
    final String? raw = _prefs!.getString(_kRecent);
    if (raw == null || raw.trim().isEmpty) {
      _recent = <String>[];
      return;
    }
    try {
      final List<dynamic> parsed = jsonDecode(raw) as List<dynamic>;
      _recent = parsed.map((dynamic e) => e.toString()).where((String e) => e.isNotEmpty).toList();
    } catch (_) {
      _recent = <String>[];
    }
  }

  Future<void> record(Iterable<String> tags) async {
    if (_prefs == null) {
      await warmUp();
    }
    for (final String raw in tags) {
      final String tag = raw.trim();
      if (tag.isEmpty) {
        continue;
      }
      _recent.remove(tag);
      _recent.insert(0, tag);
    }
    if (_recent.length > _maxRecent) {
      _recent = _recent.take(_maxRecent).toList();
    }
    await _prefs!.setString(_kRecent, jsonEncode(_recent));
  }

  Map<String, double> weightFor(Iterable<String> candidates) {
    final Map<String, double> score = <String, double>{};
    if (_recent.isEmpty) {
      return score;
    }
    final Set<String> set = candidates.map((String e) => e.trim()).where((String e) => e.isNotEmpty).toSet();
    if (set.isEmpty) {
      return score;
    }
    for (int i = 0; i < _recent.length; i++) {
      final String tag = _recent[i];
      if (!set.contains(tag)) {
        continue;
      }
      // Newer tags get larger weight.
      final double w = 0.38 * (1.0 - (i / _maxRecent));
      score.update(tag, (double v) => v + w, ifAbsent: () => w);
    }
    return score;
  }
}
