import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/fragment_models.dart';
import '../../../core/repositories/fragment_repository.dart';
import '../../../core/services/app_services.dart';
import '../../../core/services/audio_coordinator.dart';
import '../../../core/stores/fragment_store.dart';
import '../../../core/stores/tag_usage_store.dart';

/// Slim shell state: only selected tab, user name, import hint and a reduce-motion
/// preference. Palette lives in [PaletteController] now so time-of-day ticks
/// do not rebuild every `Consumer` wired to [ShellViewModel] in the tree.
class ShellViewModel extends ChangeNotifier {
  ShellViewModel(this._mediaStorageService, this._preferences) {
    _loadHints();
    _loadPreferences();
  }

  final MediaStorageService _mediaStorageService;
  final AppPreferencesService _preferences;
  int _selectedIndex = 0;
  String _importHint = '内部存储/Senti/Imports/Audio/';
  String _userName = '你';
  bool _reduceMotion = false;
  bool _immersive = false;

  int get selectedIndex => _selectedIndex;
  String get importHint => _importHint;
  String get userName => _userName;
  bool get reduceMotion => _reduceMotion;
  bool get immersive => _immersive;

  void selectTab(int index) {
    if (_selectedIndex == index) {
      return;
    }
    _selectedIndex = index;
    notifyListeners();
  }

  void setImmersive(bool value) {
    if (_immersive == value) {
      return;
    }
    _immersive = value;
    notifyListeners();
  }

  Future<void> _loadHints() async {
    _importHint = await _mediaStorageService.importHintPath();
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    final data = await _preferences.load();
    _userName =
        (data['userName'] as String?)?.trim().isNotEmpty == true ? data['userName'] as String : '你';
    _reduceMotion = data['reduceMotion'] as bool? ?? false;
    notifyListeners();
  }

  Future<void> updateUserName(String value) async {
    final trimmed = value.trim().isEmpty ? '你' : value.trim();
    if (trimmed == _userName) {
      return;
    }
    _userName = trimmed;
    await _persist();
    notifyListeners();
  }

  Future<void> setReduceMotion(bool value) async {
    if (_reduceMotion == value) {
      return;
    }
    _reduceMotion = value;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final old = await _preferences.load();
    await _preferences.save(<String, dynamic>{
      ...old,
      'userName': _userName,
      'reduceMotion': _reduceMotion,
    });
  }
}

/// Home screen view-model. Derives its list from [FragmentStore] instead of
/// doing its own repository fetch, so saves/deletes from other flows are
/// automatically reflected here.
class HomeViewModel extends ChangeNotifier with WidgetsBindingObserver {
  HomeViewModel(this._store, this._catalog, this._weatherService, this._preferences) {
    WidgetsBinding.instance.addObserver(this);
    _store.addListener(_onStoreChanged);
    _refreshFromStore();
    unawaited(_store.ensureLoaded());
    unawaited(_hydrateWeatherFromCache());
    _scheduleWeatherTimer();
  }

  final FragmentStore _store;
  final DataCatalogService _catalog;
  final WeatherSnapshotService _weatherService;
  final AppPreferencesService _preferences;
  final Random _random = Random();

  List<FragmentRecord> _fragments = const <FragmentRecord>[];
  String _currentKaomoji = '(◕ᴗ◕✿)';
  InspirationPrompt? _prompt;
  int _todayCount = 0;
  int _streakDays = 0;
  String _greeting = '';
  int _greetingHour = -1;
  int _greetingTick = 0;
  bool _weatherVisible = false;
  String _weatherCity = '';
  String _weatherSummary = '';
  String _weatherTip = '';
  String _weatherEmoji = '';
  int _weatherCode = 0;
  bool _weatherIsDay = true;
  double _weatherTempC = 0;
  DateTime? _lastWeatherFetchAt;
  Timer? _weatherTimer;
  bool _weatherRefreshing = false;
  static const String _weatherCacheKey = 'homeWeatherCache';

  bool get loading => _store.loading && _fragments.isEmpty;
  List<FragmentRecord> get fragments => _fragments;
  String get currentKaomoji => _currentKaomoji;
  InspirationPrompt? get prompt => _prompt;
  int get todayCount => _todayCount;
  int get streakDays => _streakDays;
  String get greeting => _greeting;
  bool get weatherVisible => _weatherVisible;
  String get weatherCity => _weatherCity;
  String get weatherSummary => _weatherSummary;
  String get weatherTip => _weatherTip;
  String get weatherEmoji => _weatherEmoji;
  int get weatherCode => _weatherCode;
  bool get weatherIsDay => _weatherIsDay;
  double get weatherTempC => _weatherTempC;
  DateTime? get lastWeatherFetchAt => _lastWeatherFetchAt;

  /// "去年的今天 / 上个月的今天" echo cards.
  List<FragmentRecord> get echoes => _store.echoesFor(DateTime.now());

  void _onStoreChanged() {
    _refreshFromStore();
    notifyListeners();
  }

  void _refreshFromStore() {
    _fragments = _clusterShuffle(_store.all);
    _todayCount = _computeTodayCount(_fragments);
    _streakDays = _computeStreakDays(_fragments);
    if (_catalog.kaomojis.isNotEmpty && _currentKaomoji == '(◕ᴗ◕✿)') {
      _currentKaomoji = _catalog.kaomojis[_random.nextInt(_catalog.kaomojis.length)].face;
    }
    if (_catalog.prompts.isNotEmpty && _prompt == null) {
      _prompt = _catalog.prompts[_random.nextInt(_catalog.prompts.length)];
    }
    _refreshGreeting();
  }

  Future<void> refresh() => _store.refresh();

  void reshuffle() {
    _fragments = _clusterShuffle(_fragments);
    notifyListeners();
  }

  void nextCompanion() {
    if (_catalog.kaomojis.isEmpty) {
      return;
    }
    _currentKaomoji = _catalog.kaomojis[_random.nextInt(_catalog.kaomojis.length)].face;
    notifyListeners();
  }

  void nextPrompt() {
    if (_catalog.prompts.isEmpty) {
      return;
    }
    _prompt = _catalog.prompts[_random.nextInt(_catalog.prompts.length)];
    _refreshGreeting(forceRotate: true);
    notifyListeners();
  }

  void refreshGreeting() {
    _refreshGreeting(forceRotate: true);
    notifyListeners();
  }

  List<FragmentRecord> _clusterShuffle(List<FragmentRecord> source) {
    final buckets = <String, List<FragmentRecord>>{};
    for (final item in source) {
      final key = item.tags.isEmpty ? '其他' : item.tags.first;
      buckets.putIfAbsent(key, () => <FragmentRecord>[]).add(item);
    }
    final keys = buckets.keys.toList()..shuffle(_random);
    final output = <FragmentRecord>[];
    for (final key in keys) {
      final items = buckets[key]!..shuffle(_random);
      output.addAll(items);
    }
    return output;
  }

  int _computeTodayCount(List<FragmentRecord> source) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return source.where((item) {
      final day = DateTime(item.writtenAt.year, item.writtenAt.month, item.writtenAt.day);
      return day == today;
    }).length;
  }

  int _computeStreakDays(List<FragmentRecord> source) {
    final days = <DateTime>{};
    for (final item in source) {
      days.add(DateTime(item.writtenAt.year, item.writtenAt.month, item.writtenAt.day));
    }
    var streak = 0;
    var probe = DateTime.now();
    while (true) {
      final day = DateTime(probe.year, probe.month, probe.day);
      if (!days.contains(day)) {
        break;
      }
      streak++;
      probe = probe.subtract(const Duration(days: 1));
    }
    return streak;
  }

  void _refreshGreeting({bool forceRotate = false}) {
    final now = DateTime.now();
    if (forceRotate || _greetingHour != now.hour) {
      _greetingTick++;
      _greetingHour = now.hour;
    }
  }

  String greetingForUser(String userName) {
    final hour = DateTime.now().hour;
    if (_greeting.isEmpty || _greetingHour != hour) {
      _refreshGreeting(forceRotate: true);
    }
    final period = _periodFor(hour);
    final context = _contextType();
    final pool = _greetingPool[period]![context]!;
    final todaySeed = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    var index = (_greetingTick + todaySeed + (_fragments.length * 2)) % pool.length;
    final candidate = pool[index];
    if (_greeting == candidate && pool.length > 1) {
      index = (index + 1) % pool.length;
    }
    _greeting = pool[index].replaceAll('{name}', userName);
    return _greeting;
  }

  String _periodFor(int hour) {
    if (hour < 6) {
      return 'night';
    }
    if (hour < 12) {
      return 'morning';
    }
    if (hour < 18) {
      return 'afternoon';
    }
    return 'evening';
  }

  String _contextType() {
    if (_fragments.isEmpty) {
      return 'starter';
    }
    if (_todayCount > 0) {
      return 'review';
    }
    if (_streakDays > 0) {
      return 'streak';
    }
    return 'starter';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshWeatherIfDue());
      _scheduleWeatherTimer();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _weatherTimer?.cancel();
    }
  }

  Future<void> _hydrateWeatherFromCache() async {
    try {
      final Map<String, dynamic> prefs = await _preferences.load();
      final dynamic raw = prefs[_weatherCacheKey];
      if (raw is! Map) {
        return;
      }
      final Map<String, dynamic> cache = Map<String, dynamic>.from(raw);
      final HomeWeatherSnapshot? snapshot = _snapshotFromCache(cache);
      if (snapshot == null) {
        return;
      }
      _applyWeatherSnapshot(snapshot);
      notifyListeners();
      unawaited(_refreshWeatherIfDue());
    } catch (_) {
      // Keep hidden on cache parse failure.
    }
  }

  Future<void> _refreshWeatherIfDue({bool force = false}) async {
    if (_weatherRefreshing) {
      return;
    }
    final DateTime now = DateTime.now();
    if (!force && !_needsWeatherRefresh(now)) {
      _scheduleWeatherTimer();
      return;
    }
    _weatherRefreshing = true;
    try {
      final HomeWeatherSnapshot? weather =
          await _weatherService.fetchCurrentForDeviceLocation();
      if (weather == null) {
        _setWeatherHidden();
        await _clearWeatherCache();
      } else {
        _applyWeatherSnapshot(weather);
        await _persistWeatherCache(weather);
      }
      notifyListeners();
    } finally {
      _weatherRefreshing = false;
      _scheduleWeatherTimer();
    }
  }

  bool _needsWeatherRefresh(DateTime now) {
    final DateTime? last = _lastWeatherFetchAt;
    if (last == null) {
      return true;
    }
    final DateTime checkpoint = _latestRefreshCheckpoint(now);
    return last.isBefore(checkpoint);
  }

  void _applyWeatherSnapshot(HomeWeatherSnapshot weather) {
    _weatherVisible = true;
    _weatherCity = weather.city;
    _weatherCode = weather.weatherCode;
    _weatherIsDay = weather.isDay;
    _weatherTempC = weather.temperatureC;
    _weatherSummary = _weatherSummaryFor(weather.weatherCode, weather.isDay);
    _weatherEmoji = _weatherEmojiFor(weather.weatherCode, weather.isDay);
    _weatherTip = _pickGentleTip(weather);
    _lastWeatherFetchAt = weather.fetchedAt;
  }

  Future<void> _persistWeatherCache(HomeWeatherSnapshot weather) async {
    final Map<String, dynamic> old = await _preferences.load();
    await _preferences.save(<String, dynamic>{
      ...old,
      _weatherCacheKey: <String, dynamic>{
        'city': weather.city,
        'temperatureC': weather.temperatureC,
        'apparentTemperatureC': weather.apparentTemperatureC,
        'weatherCode': weather.weatherCode,
        'isDay': weather.isDay,
        'windSpeedKmh': weather.windSpeedKmh,
        'precipitationMm': weather.precipitationMm,
        'fetchedAt': weather.fetchedAt.toIso8601String(),
      },
    });
  }

  Future<void> _clearWeatherCache() async {
    final Map<String, dynamic> old = await _preferences.load();
    if (!old.containsKey(_weatherCacheKey)) {
      return;
    }
    final Map<String, dynamic> next = Map<String, dynamic>.from(old);
    next.remove(_weatherCacheKey);
    await _preferences.save(next);
  }

  HomeWeatherSnapshot? _snapshotFromCache(Map<String, dynamic> cache) {
    final String city = (cache['city'] as String?)?.trim() ?? '';
    final double? temperatureC = _toDouble(cache['temperatureC']);
    final double? apparentTemperatureC = _toDouble(cache['apparentTemperatureC']);
    final int? weatherCode = _toInt(cache['weatherCode']);
    final bool? isDay = cache['isDay'] is bool ? cache['isDay'] as bool : null;
    final double? windSpeedKmh = _toDouble(cache['windSpeedKmh']);
    final double? precipitationMm = _toDouble(cache['precipitationMm']);
    final String fetchedAtRaw = (cache['fetchedAt'] as String?) ?? '';
    final DateTime? fetchedAt = DateTime.tryParse(fetchedAtRaw);
    if (city.isEmpty ||
        temperatureC == null ||
        apparentTemperatureC == null ||
        weatherCode == null ||
        isDay == null ||
        windSpeedKmh == null ||
        precipitationMm == null ||
        fetchedAt == null) {
      return null;
    }
    return HomeWeatherSnapshot(
      city: city,
      temperatureC: temperatureC,
      apparentTemperatureC: apparentTemperatureC,
      weatherCode: weatherCode,
      isDay: isDay,
      windSpeedKmh: windSpeedKmh,
      precipitationMm: precipitationMm,
      fetchedAt: fetchedAt,
    );
  }

  double? _toDouble(Object? raw) {
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw);
    }
    return null;
  }

  int? _toInt(Object? raw) {
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }

  DateTime _latestRefreshCheckpoint(DateTime now) {
    final List<int> slots = <int>[7, 12, 18];
    DateTime? latest;
    for (final hour in slots) {
      final DateTime point = DateTime(now.year, now.month, now.day, hour);
      if (!point.isAfter(now)) {
        latest = point;
      }
    }
    if (latest != null) {
      return latest;
    }
    final DateTime yesterday = now.subtract(const Duration(days: 1));
    return DateTime(yesterday.year, yesterday.month, yesterday.day, slots.last);
  }

  DateTime _nextRefreshCheckpoint(DateTime now) {
    const List<int> slots = <int>[7, 12, 18];
    for (final int hour in slots) {
      final DateTime point = DateTime(now.year, now.month, now.day, hour);
      if (point.isAfter(now)) {
        return point;
      }
    }
    final DateTime tomorrow = now.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, slots.first);
  }

  void _scheduleWeatherTimer() {
    _weatherTimer?.cancel();
    final DateTime now = DateTime.now();
    final DateTime next = _nextRefreshCheckpoint(now);
    final Duration wait = next.difference(now);
    _weatherTimer = Timer(wait, () {
      unawaited(_refreshWeatherIfDue(force: true));
    });
  }

  void _setWeatherHidden() {
    _weatherVisible = false;
    _weatherCity = '';
    _weatherSummary = '';
    _weatherTip = '';
    _weatherEmoji = '';
    _weatherCode = 0;
    _weatherIsDay = true;
    _weatherTempC = 0;
  }

  String _weatherSummaryFor(int weatherCode, bool isDay) {
    if (weatherCode == 0) {
      return isDay ? '晴朗' : '晴夜';
    }
    if (weatherCode <= 3) {
      return '多云';
    }
    if (weatherCode == 45 || weatherCode == 48) {
      return '有雾';
    }
    if ((weatherCode >= 51 && weatherCode <= 67) ||
        (weatherCode >= 80 && weatherCode <= 82)) {
      return '有雨';
    }
    if (weatherCode >= 71 && weatherCode <= 77) {
      return '有雪';
    }
    if (weatherCode >= 95) {
      return '雷雨';
    }
    return '天气变化';
  }

  String _weatherEmojiFor(int weatherCode, bool isDay) {
    if (weatherCode == 0) {
      return isDay ? '☀️' : '🌙';
    }
    if (weatherCode <= 3) {
      return isDay ? '⛅' : '☁️';
    }
    if (weatherCode == 45 || weatherCode == 48) {
      return '🌫️';
    }
    if ((weatherCode >= 51 && weatherCode <= 67) ||
        (weatherCode >= 80 && weatherCode <= 82)) {
      return '🌧️';
    }
    if (weatherCode >= 71 && weatherCode <= 77) {
      return '❄️';
    }
    if (weatherCode >= 95) {
      return '⛈️';
    }
    return '🌤️';
  }

  String _pickGentleTip(HomeWeatherSnapshot weather) {
    final List<String> pool = <String>[];
    final int hour = DateTime.now().hour;
    if (weather.weatherCode >= 95) {
      pool.addAll(<String>[
        '有雷雨迹象，带伞也注意避开空旷地。',
        '天气有点躁动，路上多留心脚下。',
      ]);
    } else if ((weather.weatherCode >= 51 && weather.weatherCode <= 67) ||
        (weather.weatherCode >= 80 && weather.weatherCode <= 82)) {
      pool.addAll(<String>[
        '可能有雨，记得把伞放进包里。',
        '路面可能偏滑，今天慢一点也很好。',
        '下雨天把步子放轻，心也会稳一点。',
      ]);
    } else if (weather.weatherCode >= 71 && weather.weatherCode <= 77) {
      pool.addAll(<String>[
        '有降雪迹象，外出注意保暖与防滑。',
        '天气偏冷，围巾和手套会很有帮助。',
      ]);
    } else if (weather.weatherCode == 45 || weather.weatherCode == 48) {
      pool.addAll(<String>[
        '能见度偏低，出门记得多观察前方。',
        '有雾的日子，慢行会更安心。',
      ]);
    } else if (weather.weatherCode <= 3) {
      pool.addAll(<String>[
        '天气还不错，记得抬头看看天。',
        '给自己一点缓慢呼吸的时间。',
      ]);
    }

    if (weather.temperatureC <= 10) {
      pool.addAll(<String>[
        '气温偏低，多穿一层会更舒服。',
        '今天有点冷，记得护好手和脖子。',
      ]);
    } else if (weather.temperatureC <= 16) {
      pool.addAll(<String>[
        '稍微有点凉，薄外套会刚刚好。',
      ]);
    } else if (weather.temperatureC >= 32) {
      pool.addAll(<String>[
        '温度较高，记得补水和防晒。',
        '天热时慢慢走，别让自己太疲惫。',
      ]);
    } else if (weather.temperatureC >= 28) {
      pool.addAll(<String>[
        '今天偏暖，出门带瓶水会更从容。',
      ]);
    }

    if (weather.windSpeedKmh >= 28) {
      pool.addAll(<String>[
        '风有点大，注意防风和头发保暖。',
      ]);
    }

    if (hour >= 21 || hour < 6) {
      pool.addAll(<String>[
        '夜色渐深，早点休息也很重要。',
      ]);
    }

    if (pool.isEmpty) {
      pool.add('愿你今天按自己的节奏，慢慢发光。');
    }
    final int seed = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return pool[(seed + weather.weatherCode + weather.temperatureC.round()) % pool.length];
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    WidgetsBinding.instance.removeObserver(this);
    _weatherTimer?.cancel();
    super.dispose();
  }

  static const Map<String, Map<String, List<String>>> _greetingPool =
      <String, Map<String, List<String>>>{
    'night': <String, List<String>>{
      'starter': <String>[
        '{name}，夜色很轻，留一小片心情就好。',
        '{name}，晚风适合把今天慢慢收起来。',
        '{name}，先记一句话，其他交给夜晚。',
        '{name}，给今天一个柔软的句点吧。',
        '{name}，夜里最适合温柔地开始记录。',
        '{name}，不必完整，写下一点就很好。',
      ],
      'streak': <String>[
        '{name}，你已经连续在发光，今晚也继续。',
        '{name}，这份坚持很难得，夜里也算数。',
        '{name}，streak 在延续，心也会慢慢安稳。',
        '{name}，连着记录的你，真的很了不起。',
        '{name}，再写一条，连续天数会更好看。',
        '{name}，你在一点点把生活串成线。',
      ],
      'review': <String>[
        '{name}，今天已经留下痕迹，睡前回看一眼吧。',
        '{name}，你今天的记录很温柔，晚安前再补一句。',
        '{name}，夜里复盘一下，明天会更轻松。',
        '{name}，今天写得不错，给自己一句收尾。',
        '{name}，把今天的情绪轻轻归档吧。',
        '{name}，你已经做得很好，再留一行晚安语。',
      ],
    },
    'morning': <String, List<String>>{
      'starter': <String>[
        '{name}，早安，今天从一句轻记录开始。',
        '{name}，早晨适合把心情调到温柔频道。',
        '{name}，今天第一条碎片，就从现在写下。',
        '{name}，晨光正好，记下今天的期待。',
        '{name}，给今天一个小开场吧。',
        '{name}，先写一句，今天就会更有方向。',
      ],
      'streak': <String>[
        '{name}，连续记录进行中，今天也别断。',
        '{name}，你的晨间坚持很有力量。',
        '{name}，streak 会记住你的每个早晨。',
        '{name}，继续保持，今天又是新的一格。',
        '{name}，连贯的你，正在把日子写亮。',
        '{name}，早晨这一条，会让连续更漂亮。',
      ],
      'review': <String>[
        '{name}，你今天已经启动，继续保持这个节奏。',
        '{name}，早晨已打卡，接下来让灵感慢慢来。',
        '{name}，今天第一条已就位，状态很好。',
        '{name}，你已经开始记录了，继续发光。',
        '{name}，今天有进展，再补一条会更完整。',
        '{name}，晨间节奏不错，继续写下去。',
      ],
    },
    'afternoon': <String, List<String>>{
      'starter': <String>[
        '{name}，午后好，把灵感轻轻装进口袋。',
        '{name}，此刻写一句，下午会更顺。',
        '{name}，午后最适合记录一个细节。',
        '{name}，给今天下午留一段小注脚。',
        '{name}，慢一点写，也是一种效率。',
        '{name}，现在记下来的，会在晚上发光。',
      ],
      'streak': <String>[
        '{name}，连续记录还在延续，午后也别缺席。',
        '{name}，你在稳定地前进，继续保持。',
        '{name}，streak 不只数字，是你的节奏感。',
        '{name}，午后这一条，会让坚持更完整。',
        '{name}，你已经很稳了，再写一句就更好。',
        '{name}，这份连续感，正在变成习惯。',
      ],
      'review': <String>[
        '{name}，今天已经有记录，午后回看会更清晰。',
        '{name}，你今天状态不错，再补一条灵感。',
        '{name}，把上午的感受连成一段下午故事。',
        '{name}，已有碎片在发光，继续衔接吧。',
        '{name}，你的今天正在成形，再写一句。',
        '{name}，午后复盘一下，晚些会更从容。',
      ],
    },
    'evening': <String, List<String>>{
      'starter': <String>[
        '{name}，傍晚好，给今天留一小段温柔。',
        '{name}，落日时分最适合写下感受。',
        '{name}，一天快结束了，记一句就很好。',
        '{name}，把傍晚的颜色收进今天的碎片里。',
        '{name}，现在开始也不晚，写下当下吧。',
        '{name}，给今天一个轻轻的总结。',
      ],
      'streak': <String>[
        '{name}，连续记录很棒，傍晚这一条别落下。',
        '{name}，你的坚持在发热，继续保持。',
        '{name}，streak 正在变长，今晚继续。',
        '{name}，再写一句，连续会更好看。',
        '{name}，你在稳定地记录生活，很珍贵。',
        '{name}，把这份连贯感留到今天结尾。',
      ],
      'review': <String>[
        '{name}，今天已有记录，傍晚适合回顾一遍。',
        '{name}，你的碎片已经很有画面，再补一句收尾。',
        '{name}，今天写得不错，给它一个温柔结论。',
        '{name}，晚些进入放映模式会更有氛围。',
        '{name}，把今天的亮点标记下来吧。',
        '{name}，你今天的情绪轨迹很值得回看。',
      ],
    },
  };
}

class SearchViewModel extends ChangeNotifier {
  SearchViewModel(this._store, this._catalog) {
    _store.addListener(_onStoreChanged);
    unawaited(_store.ensureLoaded());
    _applyInternal(_query);
  }

  final FragmentStore _store;
  final DataCatalogService _catalog;

  List<FragmentRecord> _filtered = const <FragmentRecord>[];
  String _query = '';

  List<FragmentRecord> get filtered => _filtered;
  String get query => _query;
  List<FeelingTagDefinition> get quickTags => _catalog.tags.take(18).toList();
  List<FeelingTagDefinition> get allTagDefinitions => _catalog.tags;

  void _onStoreChanged() {
    _applyInternal(_query);
    notifyListeners();
  }

  void applyQuery(String value) {
    _query = value.trim();
    _applyInternal(_query);
    notifyListeners();
  }

  void _applyInternal(String q) {
    if (q.isEmpty) {
      _filtered = _store.all;
    } else {
      _filtered = _store.all.where((item) {
        return item.title.contains(q) ||
            item.body.contains(q) ||
            item.tags.any((tag) => tag.contains(q));
      }).toList();
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }
}

enum JournalTemplate {
  gratitude,
  review,
  bedtime,
}

extension JournalTemplateText on JournalTemplate {
  String get label {
    return switch (this) {
      JournalTemplate.gratitude => '感恩',
      JournalTemplate.review => '复盘',
      JournalTemplate.bedtime => '睡前清单',
    };
  }

  String get defaultTitle {
    return switch (this) {
      JournalTemplate.gratitude => '今天想感谢的三件事',
      JournalTemplate.review => '今天复盘',
      JournalTemplate.bedtime => '睡前清单',
    };
  }

  String get defaultBody {
    return switch (this) {
      JournalTemplate.gratitude => '1. \n2. \n3. \n\n今天最柔软的瞬间：',
      JournalTemplate.review => '今天完成了什么：\n- \n\n遇到的卡点：\n- \n\n明天最重要的一件事：',
      JournalTemplate.bedtime => '今天值得记住的片段：\n- \n\n让自己安心的小事：\n- \n\n睡前一句话：',
    };
  }

  JournalTemplate get next {
    return switch (this) {
      JournalTemplate.gratitude => JournalTemplate.review,
      JournalTemplate.review => JournalTemplate.bedtime,
      JournalTemplate.bedtime => JournalTemplate.gratitude,
    };
  }
}

class CalendarDaySummary {
  const CalendarDaySummary({
    required this.date,
    required this.count,
    required this.primaryTag,
  });

  final DateTime date;
  final int count;
  final String primaryTag;
}

class WeeklyReviewSummary {
  const WeeklyReviewSummary({
    required this.entryCount,
    required this.topTags,
    required this.primaryMood,
  });

  final int entryCount;
  final List<String> topTags;
  final String primaryMood;
}

class DailyTrendPoint {
  const DailyTrendPoint({
    required this.date,
    required this.count,
  });

  final DateTime date;
  final int count;
}

class TagDistributionPoint {
  const TagDistributionPoint({
    required this.tag,
    required this.count,
  });

  final String tag;
  final int count;
}

class CalendarViewModel extends ChangeNotifier {
  CalendarViewModel(this._store, this._storage)
      : _month = DateTime(DateTime.now().year, DateTime.now().month, 1) {
    _store.addListener(_onStoreChanged);
    unawaited(_store.ensureLoaded());
    _rebuild();
  }

  final FragmentStore _store;
  final MediaStorageService _storage;
  DateTime _month;
  List<CalendarDaySummary> _days = const <CalendarDaySummary>[];
  int _streak = 0;
  WeeklyReviewSummary _weekly = const WeeklyReviewSummary(
    entryCount: 0,
    topTags: <String>[],
    primaryMood: '暂无',
  );
  List<DailyTrendPoint> _weeklyTrend = const <DailyTrendPoint>[];
  List<TagDistributionPoint> _tagDistribution = const <TagDistributionPoint>[];

  DateTime get month => _month;
  bool get loading => _store.loading && _days.isEmpty;
  List<CalendarDaySummary> get days => _days;
  int get streak => _streak;
  WeeklyReviewSummary get weekly => _weekly;
  List<DailyTrendPoint> get weeklyTrend => _weeklyTrend;
  List<TagDistributionPoint> get tagDistribution => _tagDistribution;

  void _onStoreChanged() {
    _rebuild();
    notifyListeners();
  }

  void previousMonth() {
    _month = DateTime(_month.year, _month.month - 1, 1);
    _rebuild();
    notifyListeners();
  }

  void nextMonth() {
    _month = DateTime(_month.year, _month.month + 1, 1);
    _rebuild();
    notifyListeners();
  }

  Future<void> refresh() => _store.refresh();

  List<FragmentRecord> fragmentsOnDay(DateTime day) => _store.fragmentsOnDay(day);

  void _rebuild() {
    final monthStart = DateTime(_month.year, _month.month, 1);
    final monthEnd = DateTime(_month.year, _month.month + 1, 1);
    final monthItems = _store.fragmentsBetween(monthStart, monthEnd);
    _days = _buildDaySummaries(monthItems);
    _streak = _computeStreak(_store.all);
    _weekly = _buildWeeklySummary(_store.all);
    _weeklyTrend = _buildWeeklyTrend(_store.all);
    _tagDistribution = _buildTagDistribution(_store.all);
  }

  /// Export the currently selected month's fragments as a Markdown file into
  /// the Senti/Imports directory. Returns the file path.
  Future<String> exportMonthToMarkdown() async {
    final monthStart = DateTime(_month.year, _month.month, 1);
    final monthEnd = DateTime(_month.year, _month.month + 1, 1);
    final items = _store.fragmentsBetween(monthStart, monthEnd);
    final buffer = StringBuffer()..writeln('# ${_month.year} 年 ${_month.month} 月');
    buffer.writeln('\n共 ${items.length} 条碎片\n');
    for (final item in items) {
      buffer.writeln('## ${item.writtenAt.year}-${_pad(item.writtenAt.month)}-${_pad(item.writtenAt.day)} · ${item.title}');
      if ((item.subtitle ?? '').trim().isNotEmpty) {
        buffer.writeln('> ${item.subtitle}');
      }
      buffer.writeln();
      buffer.writeln(item.body.isEmpty ? '_(无正文)_' : item.body);
      if (item.tags.isNotEmpty) {
        buffer.writeln('\n_${item.tags.map((String t) => '#$t').join(' ')}_');
      }
      buffer.writeln('\n---\n');
    }
    return _storage.writeMonthlyExport(
      year: _month.year,
      month: _month.month,
      contents: buffer.toString(),
    );
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  List<CalendarDaySummary> _buildDaySummaries(List<FragmentRecord> records) {
    final byDay = <String, List<FragmentRecord>>{};
    for (final item in records) {
      final day = DateTime(item.writtenAt.year, item.writtenAt.month, item.writtenAt.day);
      byDay.putIfAbsent(day.toIso8601String(), () => <FragmentRecord>[]).add(item);
    }
    final output = <CalendarDaySummary>[];
    for (final entry in byDay.entries) {
      final items = entry.value;
      final tags = <String, int>{};
      for (final item in items) {
        for (final tag in item.tags) {
          tags.update(tag, (value) => value + 1, ifAbsent: () => 1);
        }
      }
      final sortedTags = tags.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      output.add(
        CalendarDaySummary(
          date: DateTime.parse(entry.key),
          count: items.length,
          primaryTag: sortedTags.isEmpty ? '记录' : sortedTags.first.key,
        ),
      );
    }
    output.sort((a, b) => a.date.compareTo(b.date));
    return output;
  }

  int _computeStreak(List<FragmentRecord> records) {
    if (records.isEmpty) {
      return 0;
    }
    final days = <String>{};
    for (final item in records) {
      final day = DateTime(item.writtenAt.year, item.writtenAt.month, item.writtenAt.day);
      days.add(day.toIso8601String());
    }
    var streak = 0;
    var pointer = DateTime.now();
    while (true) {
      final key = DateTime(pointer.year, pointer.month, pointer.day).toIso8601String();
      if (!days.contains(key)) {
        break;
      }
      streak++;
      pointer = pointer.subtract(const Duration(days: 1));
    }
    return streak;
  }

  WeeklyReviewSummary _buildWeeklySummary(List<FragmentRecord> records) {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final inWeek = records.where((item) => item.writtenAt.isAfter(since)).toList();
    if (inWeek.isEmpty) {
      return const WeeklyReviewSummary(entryCount: 0, topTags: <String>[], primaryMood: '暂无');
    }
    final tags = <String, int>{};
    for (final item in inWeek) {
      for (final tag in item.tags) {
        tags.update(tag, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final sorted = tags.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return WeeklyReviewSummary(
      entryCount: inWeek.length,
      topTags: sorted.take(3).map((entry) => entry.key).toList(),
      primaryMood: sorted.isEmpty ? '记录' : sorted.first.key,
    );
  }

  List<DailyTrendPoint> _buildWeeklyTrend(List<FragmentRecord> records) {
    final now = DateTime.now();
    final counts = <DateTime, int>{};
    for (var offset = 6; offset >= 0; offset--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: offset));
      counts[day] = 0;
    }
    for (final item in records) {
      final day = DateTime(item.writtenAt.year, item.writtenAt.month, item.writtenAt.day);
      if (counts.containsKey(day)) {
        counts[day] = (counts[day] ?? 0) + 1;
      }
    }
    return counts.entries
        .map((MapEntry<DateTime, int> entry) => DailyTrendPoint(date: entry.key, count: entry.value))
        .toList()
      ..sort((DailyTrendPoint a, DailyTrendPoint b) => a.date.compareTo(b.date));
  }

  List<TagDistributionPoint> _buildTagDistribution(List<FragmentRecord> records) {
    final since = DateTime.now().subtract(const Duration(days: 30));
    final byTag = <String, int>{};
    for (final item in records.where((FragmentRecord item) => item.writtenAt.isAfter(since))) {
      for (final tag in item.tags) {
        byTag.update(tag, (int value) => value + 1, ifAbsent: () => 1);
      }
    }
    final sorted = byTag.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
    return sorted
        .take(6)
        .map((MapEntry<String, int> entry) => TagDistributionPoint(tag: entry.key, count: entry.value))
        .toList();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }
}

class PlayerViewModel extends ChangeNotifier with WidgetsBindingObserver {
  PlayerViewModel(
    this._store,
    this._planner,
    this._audio,
  ) {
    _store.addListener(_onStoreChanged);
    unawaited(_store.ensureLoaded());
    _rebuildPlaylist();
    WidgetsBinding.instance.addObserver(this);
  }

  final FragmentStore _store;
  final PlaybackPlanner _planner;
  final AudioCoordinator _audio;

  List<FragmentRecord> _playlist = const <FragmentRecord>[];
  int _currentIndex = 0;
  String _feeling = '';
  Timer? _timer;
  bool _autoplay = true;
  bool _visible = false;
  List<String> _bgmFiles = const <String>[];

  List<FragmentRecord> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  String get feeling => _feeling;
  bool get autoplay => _autoplay;
  bool get bgmPlaying => _audio.bgmPlaying;
  double get progress {
    if (_playlist.length <= 1) {
      return 1.0;
    }
    return (_currentIndex / (_playlist.length - 1)).clamp(0.0, 1.0);
  }
  FragmentRecord? get current =>
      _playlist.isEmpty ? null : _playlist[_currentIndex.clamp(0, _playlist.length - 1)];
  List<String> get bgmFiles => _bgmFiles;

  Future<void> initForFeeling(String feeling, {bool autoStartBgm = false}) async {
    _feeling = feeling;
    _rebuildPlaylist();
    _bgmFiles = await _audio.listBgmFiles();
    if (autoStartBgm && _bgmFiles.isNotEmpty && !_audio.bgmPlaying) {
      await _audio.startBgmIfAvailable();
    }
    _scheduleCurrent();
    notifyListeners();
    unawaited(_syncActiveClip());
  }

  void _onStoreChanged() {
    _rebuildPlaylist();
    notifyListeners();
  }

  void _rebuildPlaylist() {
    _playlist = _planner.buildPlaylist(_store.all, feeling: _feeling);
    if (_currentIndex >= _playlist.length) {
      _currentIndex = 0;
    }
  }

  void next() {
    if (_playlist.isEmpty) {
      return;
    }
    _currentIndex = (_currentIndex + 1) % _playlist.length;
    _scheduleCurrent();
    notifyListeners();
    unawaited(_syncActiveClip());
  }

  void previous() {
    if (_playlist.isEmpty) {
      return;
    }
    _currentIndex = (_currentIndex - 1) % _playlist.length;
    _scheduleCurrent();
    notifyListeners();
    unawaited(_syncActiveClip());
  }

  void jumpTo(int index) {
    if (_playlist.isEmpty || index < 0 || index >= _playlist.length) {
      return;
    }
    if (_currentIndex == index) {
      return;
    }
    _currentIndex = index;
    _scheduleCurrent();
    notifyListeners();
    unawaited(_syncActiveClip());
  }

  void toggleAutoplay() {
    _autoplay = !_autoplay;
    if (_autoplay && _visible) {
      _scheduleCurrent();
    } else {
      _timer?.cancel();
    }
    notifyListeners();
  }

  /// Called by the Player page when it enters/leaves the foreground so we can
  /// pause the slide timer and the fragment clip when the tab is not visible.
  void setVisible(bool visible) {
    if (_visible == visible) {
      return;
    }
    _visible = visible;
    if (!visible) {
      _timer?.cancel();
      unawaited(_audio.stopClip());
    } else {
      _scheduleCurrent();
      unawaited(_syncActiveClip());
    }
  }

  Future<void> toggleBgm() async {
    await _audio.toggleBgm();
    if (_audio.bgmPlaying) {
      _bgmFiles = await _audio.listBgmFiles();
    }
    notifyListeners();
  }

  Future<void> refreshBgmList() async {
    _bgmFiles = await _audio.listBgmFiles(forceRefresh: true);
    notifyListeners();
  }

  bool _pathExists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  String? _firstExistingAudioPath(FragmentRecord fragment) {
    for (final FragmentMedia m in fragment.media) {
      if (m.kind == MediaKind.audio && _pathExists(m.path)) {
        return m.path;
      }
    }
    return null;
  }

  bool _hasVideo(FragmentRecord fragment) {
    return fragment.media.any((FragmentMedia m) => m.kind == MediaKind.video && _pathExists(m.path));
  }

  Future<void> _syncActiveClip() async {
    final frag = current;
    if (frag == null || !_visible) {
      await _audio.stopClip();
      return;
    }
    // Let inline video supply its own audio track.
    if (_hasVideo(frag)) {
      await _audio.stopClip();
      return;
    }
    final String? audio = _firstExistingAudioPath(frag);
    if (audio != null) {
      await _audio.playClip(audio);
    } else {
      await _audio.stopClip();
    }
  }

  void _scheduleCurrent() {
    _timer?.cancel();
    final fragment = current;
    if (!_autoplay || fragment == null || !_visible) {
      return;
    }
    final duration = Duration(seconds: _planner.computeDurationSeconds(fragment));
    _timer = Timer(duration, next);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _timer?.cancel();
      unawaited(_audio.stopClip());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.removeListener(_onStoreChanged);
    _timer?.cancel();
    unawaited(_audio.stopClip());
    super.dispose();
  }
}

class CaptureViewModel extends ChangeNotifier {
  CaptureViewModel(
    this._repository,
    this._store,
    this._storage,
    this._permissionService,
    this._weatherSnapshotService,
    this._recordingService,
    this._pickerService,
    this._preferences,
    this._catalog,
    this._tagModel,
    this._tagService,
    this._tagUsageStore,
  ) {
    _loadTemplateRecommendation();
  }

  final FragmentRepository _repository;
  final FragmentStore _store;
  final MediaStorageService _storage;
  final PermissionService _permissionService;
  final WeatherSnapshotService _weatherSnapshotService;
  final RecordingService _recordingService;
  final ImportPickerService _pickerService;
  final AppPreferencesService _preferences;
  final DataCatalogService _catalog;
  final TfliteTagModelService _tagModel;
  final FeelingTagService _tagService;
  final TagUsageStore _tagUsageStore;
  final ImagePicker _imagePicker = ImagePicker();

  List<FeelingTagDefinition> get tagOptions => _catalog.tags;

  FragmentKind selectedKind = FragmentKind.text;
  bool saving = false;
  bool recording = false;
  String? activeRecordingPath;
  final List<FragmentMedia> importedMedia = <FragmentMedia>[];
  JournalTemplate _recommendedTemplate = JournalTemplate.gratitude;
  List<String> _suggestedTags = const <String>[];
  Timer? _suggestDebounce;

  JournalTemplate get recommendedTemplate => _recommendedTemplate;
  List<String> get suggestedTags => _suggestedTags;

  void setKind(FragmentKind kind) {
    selectedKind = kind;
    notifyListeners();
  }

  Future<void> importPhotos() async {
    final picked = await _imagePicker.pickMultiImage(imageQuality: 92);
    if (picked.isEmpty) {
      return;
    }
    for (final item in picked) {
      final media = await _storage.importImage(item.path);
      if (media != null) {
        importedMedia.add(media);
      }
    }
    notifyListeners();
  }

  Future<void> importAudio() async {
    final path = await _pickerService.pickAudio();
    if (path == null) {
      return;
    }
    final media = await _storage.importAudio(path);
    if (media != null) {
      importedMedia.add(media);
      notifyListeners();
    }
  }

  Future<void> importVideo() async {
    final path = await _pickerService.pickVideo();
    if (path == null) {
      return;
    }
    final media = await _storage.importVideo(path);
    if (media != null) {
      importedMedia.add(media);
      notifyListeners();
    }
  }

  Future<void> toggleRecording() async {
    if (recording) {
      final path = await _recordingService.stopRecording();
      recording = false;
      if (path != null) {
        final media = await _storage.importAudio(path);
        if (media != null) {
          importedMedia.add(media);
        }
      }
      notifyListeners();
      return;
    }
    final granted = await _permissionService.ensureMicrophonePermission();
    if (!granted) {
      return;
    }
    activeRecordingPath = await _storage.createRecordingPath();
    recording = await _recordingService.startRecording(activeRecordingPath!);
    notifyListeners();
  }

  Future<Map<String, dynamic>> currentWeatherSnapshot() async {
    return _weatherSnapshotService.buildSnapshot(DateTime.now());
  }

  /// Debounced on-device tag suggestion based on body text. Reuses the already
  /// warmed-up TFLite model. Safe if the model is unavailable (returns empty).
  void requestTagSuggestions(String body) {
    _suggestDebounce?.cancel();
    if (body.trim().length < 4) {
      if (_suggestedTags.isNotEmpty) {
        _suggestedTags = const <String>[];
        notifyListeners();
      }
      return;
    }
    _suggestDebounce = Timer(const Duration(milliseconds: 800), () async {
      try {
        final labels = await _tagService.analyze(
          title: '',
          body: body,
          manualTags: const <String>[],
          metadata: const <String, dynamic>{},
          media: importedMedia,
          recordUsage: false,
        );
        _suggestedTags = labels.take(4).toList();
      } catch (_) {
        try {
          final scores = await _tagModel.predict(body);
          final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          _suggestedTags = sorted.take(4).map((MapEntry<String, double> e) => e.key).toList();
        } catch (_) {
          _suggestedTags = const <String>[];
        }
      }
      notifyListeners();
    });
  }

  Future<void> save({
    required String title,
    required String body,
    String? subtitle,
    List<String> manualTags = const <String>[],
    Map<String, dynamic> metadata = const <String, dynamic>{},
    String emoji = '✨',
    int? colorValue,
  }) async {
    saving = true;
    notifyListeners();
    final mergedMetadata = Map<String, dynamic>.from(metadata);
    if (selectedKind == FragmentKind.weatherSnapshot) {
      mergedMetadata.addAll(await currentWeatherSnapshot());
    }
    await _repository.saveDraft(
      kind: selectedKind,
      title: title,
      body: body,
      subtitle: subtitle,
      manualTags: manualTags,
      metadata: mergedMetadata,
      media: List<FragmentMedia>.from(importedMedia),
      coverPath: importedMedia.isEmpty ? null : importedMedia.first.thumbnailPath ?? importedMedia.first.path,
      emoji: emoji,
      dominantColor: colorValue,
    );
    importedMedia.clear();
    saving = false;
    notifyListeners();
    // Update the single store so all listeners refresh.
    await _store.refresh();
    await _tagUsageStore.record(<String>[
      ...manualTags,
      ..._suggestedTags.take(2),
    ]);
  }

  /// Clears tag suggestions and kind hint so the next opened draft starts clean.
  void resetDraftUiState() {
    _suggestDebounce?.cancel();
    _suggestedTags = const <String>[];
    selectedKind = FragmentKind.text;
    notifyListeners();
  }

  Future<void> markTemplateUsed(JournalTemplate template) async {
    final old = await _preferences.load();
    await _preferences.save(<String, dynamic>{
      ...old,
      'lastTemplate': template.name,
    });
    _recommendedTemplate = template.next;
    notifyListeners();
  }

  JournalTemplate templateForToday() => _recommendedTemplate;

  Future<void> _loadTemplateRecommendation() async {
    final saved = await _preferences.load();
    final last = saved['lastTemplate'] as String?;
    if (last == null) {
      _recommendedTemplate = _templateByDate(DateTime.now());
      notifyListeners();
      return;
    }
    final parsed = JournalTemplate.values.firstWhere(
      (item) => item.name == last,
      orElse: () => JournalTemplate.gratitude,
    );
    _recommendedTemplate = parsed.next;
    notifyListeners();
  }

  JournalTemplate _templateByDate(DateTime now) {
    switch (now.weekday % 3) {
      case 0:
        return JournalTemplate.gratitude;
      case 1:
        return JournalTemplate.review;
      default:
        return JournalTemplate.bedtime;
    }
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _recordingService.dispose();
    super.dispose();
  }
}

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(
    this._mediaStorageService,
    this._modelService,
    this._pickerService,
    this._preferences,
    this._shell,
    this._catalog,
    this._tagService,
    this._audio,
  );

  final MediaStorageService _mediaStorageService;
  final TfliteTagModelService _modelService;
  final ImportPickerService _pickerService;
  final AppPreferencesService _preferences;
  final ShellViewModel _shell;
  final DataCatalogService _catalog;
  final FeelingTagService _tagService;
  final AudioCoordinator _audio;

  String importHint = '';
  String bgmHint = '';
  List<String> bgmFiles = const <String>[];
  bool revealImportPath = false;
  bool revealBgmPath = false;
  String userName = '你';
  String themePack = 'default';
  bool reduceMotion = false;
  List<FeelingTagDefinition> customTags = const <FeelingTagDefinition>[];

  bool get modelReady => _modelService.isReady;
  bool get tokenizerReady => _modelService.tokenizerReady;
  String get modelStatus => _modelService.status;
  String get importSummary => importHint.isEmpty ? '媒体库未初始化' : '媒体库已连接';
  String get bgmSummary => '已导入 ${bgmFiles.length} 首 BGM';

  static const List<({String id, String label})> themePacks = <({String id, String label})>[
    (id: 'default', label: '默认'),
    (id: 'wafuu', label: '和风'),
    (id: 'island', label: '岛屿'),
    (id: 'morandi', label: '莫兰迪'),
    (id: 'code', label: '代码夜'),
  ];

  Future<void> load() async {
    await _modelService.warmUp();
    final data = await _preferences.load();
    importHint = await _mediaStorageService.importHintPath();
    bgmHint = await _mediaStorageService.importBgmPathHint();
    bgmFiles = await _audio.listBgmFiles();
    userName = (data['userName'] as String?)?.trim().isNotEmpty == true
        ? data['userName'] as String
        : _shell.userName;
    themePack = (data['themePack'] as String?) ?? 'default';
    reduceMotion = data['reduceMotion'] as bool? ?? _shell.reduceMotion;
    _tagService.setMode(TagEngineMode.rulesV2);
    final rawCustom = (data['customTags'] as List<dynamic>? ?? const <dynamic>[])
        .map((dynamic item) => FeelingTagDefinition.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    customTags = rawCustom;
    _catalog.setCustomTags(customTags);
    notifyListeners();
  }

  Future<void> importBgm() async {
    final file = await _pickerService.pickAudio();
    if (file == null) {
      return;
    }
    await _mediaStorageService.importBgm(file);
    _audio.invalidateBgmCache();
    bgmFiles = await _audio.listBgmFiles(forceRefresh: true);
    notifyListeners();
  }

  Future<void> setUserName(String value) async {
    userName = value.trim().isEmpty ? '你' : value.trim();
    await _shell.updateUserName(userName);
    await _persist();
    notifyListeners();
  }

  Future<void> setThemePack(String packId) async {
    themePack = packId;
    await _persist();
    notifyListeners();
  }

  Future<void> setReduceMotion(bool value) async {
    reduceMotion = value;
    await _shell.setReduceMotion(value);
    await _persist();
    notifyListeners();
  }

  Future<void> addCustomTag({
    required String label,
    required String emoji,
    required String keywordsText,
  }) async {
    final trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty) {
      return;
    }
    final keywords = keywordsText
        .split(RegExp(r'[,，\s]+'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
    final tag = FeelingTagDefinition(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      label: trimmedLabel,
      emoji: emoji.trim().isEmpty ? '✨' : emoji.trim(),
      category: 'custom',
      keywords: keywords,
    );
    customTags = <FeelingTagDefinition>[...customTags, tag];
    _catalog.setCustomTags(customTags);
    await _persist();
    notifyListeners();
  }

  Future<void> removeCustomTag(String id) async {
    customTags = customTags.where((FeelingTagDefinition item) => item.id != id).toList();
    _catalog.setCustomTags(customTags);
    await _persist();
    notifyListeners();
  }

  void toggleImportPathVisibility() {
    revealImportPath = !revealImportPath;
    notifyListeners();
  }

  void toggleBgmPathVisibility() {
    revealBgmPath = !revealBgmPath;
    notifyListeners();
  }

  Future<void> _persist() async {
    final old = await _preferences.load();
    await _preferences.save(<String, dynamic>{
      ...old,
      'userName': userName,
      'themePack': themePack,
      'reduceMotion': reduceMotion,
      'customTags': customTags
          .map((FeelingTagDefinition item) => <String, dynamic>{
                'id': item.id,
                'label': item.label,
                'emoji': item.emoji,
                'category': item.category,
                'keywords': item.keywords,
                'negations': item.negations,
              })
          .toList(),
    });
  }
}
