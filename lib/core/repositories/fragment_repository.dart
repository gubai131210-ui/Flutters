import 'dart:math';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart';
import '../models/fragment_models.dart';
import '../services/app_services.dart';

class FragmentRepository {
  FragmentRepository(
    this._database,
    this._catalog,
    this._tagService,
  ) : _uuid = const Uuid();

  final AppDatabase _database;
  final DataCatalogService _catalog;
  final FeelingTagService _tagService;
  final Uuid _uuid;

  Future<List<FragmentRecord>> getAllFragments() async {
    final db = await _database.database;
    final rows = await db.query('fragments', orderBy: 'updated_at DESC');
    return rows.map(FragmentRecord.fromDatabaseMap).toList();
  }

  Future<List<FragmentRecord>> getFragmentsBetween(DateTime start, DateTime end) async {
    final db = await _database.database;
    final rows = await db.query(
      'fragments',
      where: 'written_at >= ? AND written_at <= ?',
      whereArgs: <Object>[start.toIso8601String(), end.toIso8601String()],
      orderBy: 'written_at ASC',
    );
    return rows.map(FragmentRecord.fromDatabaseMap).toList();
  }

  Future<void> upsert(FragmentRecord fragment) async {
    final db = await _database.database;
    await db.insert(
      'fragments',
      fragment.toDatabaseMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveDraft({
    required FragmentKind kind,
    required String title,
    required String body,
    String? subtitle,
    String? coverPath,
    int? dominantColor,
    List<String> manualTags = const <String>[],
    Map<String, dynamic> metadata = const <String, dynamic>{},
    List<FragmentMedia> media = const <FragmentMedia>[],
    String emoji = '✨',
  }) async {
    final now = DateTime.now();
    final analyzedTags = await _tagService.analyze(
      title: title,
      body: body,
      manualTags: manualTags,
      metadata: metadata,
    );

    final fragment = FragmentRecord(
      id: _uuid.v4(),
      kind: kind,
      title: title.isEmpty ? '未命名碎片' : title,
      body: body,
      subtitle: subtitle,
      createdAt: now,
      updatedAt: now,
      writtenAt: now,
      coverPath: coverPath,
      dominantColor: dominantColor,
      emoji: emoji,
      layoutHint: _layoutHintFor(kind),
      randomSeed: now.millisecondsSinceEpoch % 1000,
      playWeight: _playWeightFor(kind, body, media),
      readingSeconds: _readingSecondsFor(body, media),
      tags: analyzedTags,
      metadata: metadata,
      media: media,
      moodScores: <String, double>{
        for (final tag in analyzedTags) tag: 0.8,
      },
    );
    await upsert(fragment);
  }

  Future<void> ensureSeedData() async {
    final existing = await getAllFragments();
    if (existing.isNotEmpty) {
      return;
    }

    final samples = <FragmentRecord>[
      FragmentRecord(
        id: _uuid.v4(),
        kind: FragmentKind.photo,
        title: '电影票根',
        body: '一个人坐在角落，眼泪安静地流。散场时风很轻，像是把情绪轻轻收走。',
        subtitle: '《海上钢琴师》',
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
        writtenAt: DateTime.now().subtract(const Duration(days: 8)),
        coverPath: null,
        dominantColor: 0xFFB7A69B,
        emoji: '🎫',
        layoutHint: 'imageTall',
        randomSeed: 18,
        playWeight: 4,
        readingSeconds: 8,
        tags: <String>['治愈', '怀旧', '电影感'],
        metadata: <String, dynamic>{'scene': 'cinema'},
        media: const <FragmentMedia>[],
        moodScores: const <String, double>{'治愈': 0.88, '怀旧': 0.74},
      ),
      FragmentRecord(
        id: _uuid.v4(),
        kind: FragmentKind.text,
        title: '某日书摘',
        body: '“日子是明亮的，我把它收进褶皱里。”',
        createdAt: DateTime.now().subtract(const Duration(days: 6)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        writtenAt: DateTime.now().subtract(const Duration(days: 6)),
        dominantColor: 0xFFE8D4C6,
        emoji: '📖',
        layoutHint: 'quote',
        randomSeed: 37,
        playWeight: 3,
        readingSeconds: 6,
        tags: <String>['温柔', '治愈', '书页感'],
        metadata: <String, dynamic>{'author': '佚名'},
        media: const <FragmentMedia>[],
        moodScores: const <String, double>{'温柔': 0.86, '治愈': 0.8},
      ),
      FragmentRecord(
        id: _uuid.v4(),
        kind: FragmentKind.musicMeta,
        title: 'Lullaby',
        subtitle: 'Roo Panes',
        body: '像被云朵接住，适合在傍晚慢慢放。',
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        writtenAt: DateTime.now().subtract(const Duration(days: 4)),
        dominantColor: 0xFFACC3D9,
        emoji: '🎵',
        layoutHint: 'music',
        randomSeed: 55,
        playWeight: 5,
        readingSeconds: 5,
        tags: <String>['慵懒', '治愈', '夜色'],
        metadata: <String, dynamic>{'artist': 'Roo Panes'},
        media: const <FragmentMedia>[],
        moodScores: const <String, double>{'慵懒': 0.78, '治愈': 0.84},
      ),
      FragmentRecord(
        id: _uuid.v4(),
        kind: FragmentKind.weatherSnapshot,
        title: '今天的天气快照',
        body: '窗外的风把云层推得很慢，适合记一点轻轻的东西。',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now(),
        writtenAt: DateTime.now().subtract(const Duration(days: 2)),
        dominantColor: 0xFF98A89E,
        emoji: '🌤️',
        layoutHint: 'weather',
        randomSeed: 63,
        playWeight: 2,
        readingSeconds: 5,
        tags: <String>['宁静', '清醒', '日常'],
        metadata: <String, dynamic>{'temperature': 23, 'weather': '多云'},
        media: const <FragmentMedia>[],
        moodScores: const <String, double>{'宁静': 0.71, '清醒': 0.76},
      ),
      FragmentRecord(
        id: _uuid.v4(),
        kind: FragmentKind.moodColor,
        title: '今天像奶雾玫瑰',
        body: '#d8b8b6，偏暖一点，也带一点想念。',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now(),
        writtenAt: DateTime.now().subtract(const Duration(days: 1)),
        dominantColor: 0xFFD8B8B6,
        emoji: '🎨',
        layoutHint: 'color',
        randomSeed: 82,
        playWeight: 2,
        readingSeconds: 4,
        tags: <String>['回暖', '想念', '发光'],
        metadata: const <String, dynamic>{'hex': '#d8b8b6'},
        media: const <FragmentMedia>[],
        moodScores: const <String, double>{'回暖': 0.69, '想念': 0.82},
      ),
    ];

    for (final item in samples) {
      await upsert(item);
    }
  }

  List<FeelingTagDefinition> availableTags() => _catalog.tags;

  String _layoutHintFor(FragmentKind kind) {
    switch (kind) {
      case FragmentKind.photo:
      case FragmentKind.video:
        return 'imageTall';
      case FragmentKind.text:
        return 'quote';
      case FragmentKind.musicMeta:
      case FragmentKind.localAudio:
      case FragmentKind.voiceRecord:
        return 'music';
      case FragmentKind.moodColor:
        return 'color';
      case FragmentKind.weatherSnapshot:
        return 'weather';
      default:
        return 'standard';
    }
  }

  int _playWeightFor(FragmentKind kind, String body, List<FragmentMedia> media) {
    final base = switch (kind) {
      FragmentKind.photo => 4,
      FragmentKind.video => 5,
      FragmentKind.localAudio || FragmentKind.voiceRecord || FragmentKind.musicMeta => 5,
      FragmentKind.text => 3,
      _ => 2,
    };
    return base + min(3, media.length).toInt() + min(2, body.length ~/ 60).toInt();
  }

  int _readingSecondsFor(String body, List<FragmentMedia> media) {
    return max(4, min(12, 4 + (body.length ~/ 24) + media.length));
  }
}
