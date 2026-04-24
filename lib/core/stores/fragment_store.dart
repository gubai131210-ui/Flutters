import 'package:flutter/foundation.dart';

import '../models/fragment_models.dart';
import '../repositories/fragment_repository.dart';

/// Single source of truth for all [FragmentRecord]s.
///
/// Home / Player / Calendar used to each call `getAllFragments()` and keep
/// independent copies. Now they all listen to this store; saves / deletes
/// call [refresh] once and every page gets notified.
class FragmentStore extends ChangeNotifier {
  FragmentStore(this._repository);

  final FragmentRepository _repository;
  List<FragmentRecord> _all = const <FragmentRecord>[];
  bool _loaded = false;
  bool _loading = false;

  List<FragmentRecord> get all => _all;
  bool get loaded => _loaded;
  bool get loading => _loading;

  Future<void> ensureLoaded() async {
    if (_loaded || _loading) {
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (_loading) {
      return;
    }
    _loading = true;
    notifyListeners();
    _all = await _repository.getAllFragments();
    _loaded = true;
    _loading = false;
    notifyListeners();
  }

  List<FragmentRecord> fragmentsByTag(String tag) {
    if (tag.isEmpty) {
      return _all;
    }
    return _all.where((FragmentRecord item) => item.tags.contains(tag)).toList();
  }

  List<FragmentRecord> fragmentsOnDay(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    return _all.where((FragmentRecord item) {
      final d = DateTime(item.writtenAt.year, item.writtenAt.month, item.writtenAt.day);
      return d == target;
    }).toList();
  }

  List<FragmentRecord> fragmentsBetween(DateTime start, DateTime endExclusive) {
    return _all.where((FragmentRecord item) {
      return !item.writtenAt.isBefore(start) && item.writtenAt.isBefore(endExclusive);
    }).toList();
  }

  /// Same day-of-year lookback. Used by the "去年的今天" / "上个月的今天" echo card.
  List<FragmentRecord> echoesFor(DateTime anchor) {
    final y1 = DateTime(anchor.year - 1, anchor.month, anchor.day);
    final m1 = DateTime(anchor.year, anchor.month - 1, anchor.day);
    final out = <FragmentRecord>[];
    out.addAll(fragmentsOnDay(y1));
    out.addAll(fragmentsOnDay(m1));
    return out;
  }
}
