import 'dart:convert';

enum FragmentKind {
  photo,
  text,
  musicMeta,
  localAudio,
  voiceRecord,
  video,
  moodColor,
  bookMovie,
  weatherSnapshot,
  location,
}

enum MediaKind {
  image,
  audio,
  video,
}

class FeelingTagDefinition {
  const FeelingTagDefinition({
    required this.id,
    required this.label,
    required this.emoji,
    required this.category,
    required this.keywords,
    this.negations = const <String>[],
  });

  final String id;
  final String label;
  final String emoji;
  final String category;
  final List<String> keywords;

  /// Optional Chinese negation phrases that *explicitly* invalidate this tag
  /// when present in source text (e.g. "不开心" for 治愈). When a negation
  /// hits, the tag's rule score is zeroed before fusion.
  final List<String> negations;

  factory FeelingTagDefinition.fromJson(Map<String, dynamic> json) {
    return FeelingTagDefinition(
      id: json['id'] as String,
      label: json['label'] as String,
      emoji: json['emoji'] as String? ?? '✨',
      category: json['category'] as String? ?? 'feeling',
      keywords: (json['keywords'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      negations: (json['negations'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class KaomojiPreset {
  const KaomojiPreset({
    required this.id,
    required this.label,
    required this.face,
  });

  final String id;
  final String label;
  final String face;

  factory KaomojiPreset.fromJson(Map<String, dynamic> json) {
    return KaomojiPreset(
      id: json['id'] as String,
      label: json['label'] as String,
      face: json['face'] as String,
    );
  }
}

class InspirationPrompt {
  const InspirationPrompt({
    required this.id,
    required this.category,
    required this.text,
    required this.emoji,
  });

  final String id;
  final String category;
  final String text;
  final String emoji;

  factory InspirationPrompt.fromJson(Map<String, dynamic> json) {
    return InspirationPrompt(
      id: json['id'] as String,
      category: json['category'] as String,
      text: json['text'] as String,
      emoji: json['emoji'] as String? ?? '✨',
    );
  }
}

class FragmentMedia {
  const FragmentMedia({
    required this.id,
    required this.kind,
    required this.path,
    this.thumbnailPath,
    this.durationMs,
    this.width,
    this.height,
    this.sizeBytes,
  });

  final String id;
  final MediaKind kind;
  final String path;
  final String? thumbnailPath;
  final int? durationMs;
  final int? width;
  final int? height;
  final int? sizeBytes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'kind': kind.name,
      'path': path,
      'thumbnailPath': thumbnailPath,
      'durationMs': durationMs,
      'width': width,
      'height': height,
      'sizeBytes': sizeBytes,
    };
  }

  factory FragmentMedia.fromJson(Map<String, dynamic> json) {
    return FragmentMedia(
      id: json['id'] as String,
      kind: MediaKind.values.firstWhere(
        (item) => item.name == json['kind'],
        orElse: () => MediaKind.image,
      ),
      path: json['path'] as String,
      thumbnailPath: json['thumbnailPath'] as String?,
      durationMs: json['durationMs'] as int?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      sizeBytes: json['sizeBytes'] as int?,
    );
  }
}

class FragmentRecord {
  const FragmentRecord({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    required this.writtenAt,
    required this.tags,
    required this.metadata,
    required this.media,
    this.subtitle,
    this.coverPath,
    this.dominantColor,
    this.emoji = '✨',
    this.layoutHint = 'standard',
    this.randomSeed = 0,
    this.playWeight = 1,
    this.readingSeconds = 5,
    this.moodScores = const <String, double>{},
  });

  final String id;
  final FragmentKind kind;
  final String title;
  final String body;
  final String? subtitle;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime writtenAt;
  final String? coverPath;
  final int? dominantColor;
  final String emoji;
  final String layoutHint;
  final int randomSeed;
  final int playWeight;
  final int readingSeconds;
  final List<String> tags;
  final Map<String, dynamic> metadata;
  final List<FragmentMedia> media;
  final Map<String, double> moodScores;

  String get previewText {
    if (body.trim().isNotEmpty) {
      return body.trim();
    }
    if ((subtitle ?? '').trim().isNotEmpty) {
      return subtitle!.trim();
    }
    return title.trim();
  }

  String get heroText {
    if (kind == FragmentKind.musicMeta && subtitle != null) {
      return '$title · $subtitle';
    }
    return previewText;
  }

  FragmentRecord copyWith({
    String? id,
    FragmentKind? kind,
    String? title,
    String? body,
    String? subtitle,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? writtenAt,
    String? coverPath,
    int? dominantColor,
    String? emoji,
    String? layoutHint,
    int? randomSeed,
    int? playWeight,
    int? readingSeconds,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    List<FragmentMedia>? media,
    Map<String, double>? moodScores,
  }) {
    return FragmentRecord(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      body: body ?? this.body,
      subtitle: subtitle ?? this.subtitle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      writtenAt: writtenAt ?? this.writtenAt,
      coverPath: coverPath ?? this.coverPath,
      dominantColor: dominantColor ?? this.dominantColor,
      emoji: emoji ?? this.emoji,
      layoutHint: layoutHint ?? this.layoutHint,
      randomSeed: randomSeed ?? this.randomSeed,
      playWeight: playWeight ?? this.playWeight,
      readingSeconds: readingSeconds ?? this.readingSeconds,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      media: media ?? this.media,
      moodScores: moodScores ?? this.moodScores,
    );
  }

  Map<String, Object?> toDatabaseMap() {
    return <String, Object?>{
      'id': id,
      'kind': kind.name,
      'title': title,
      'body': body,
      'subtitle': subtitle,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'written_at': writtenAt.toIso8601String(),
      'cover_path': coverPath,
      'dominant_color': dominantColor,
      'emoji': emoji,
      'layout_hint': layoutHint,
      'random_seed': randomSeed,
      'play_weight': playWeight,
      'reading_seconds': readingSeconds,
      'tags_json': jsonEncode(tags),
      'metadata_json': jsonEncode(metadata),
      'media_json': jsonEncode(media.map((item) => item.toJson()).toList()),
      'mood_scores_json': jsonEncode(moodScores),
    };
  }

  factory FragmentRecord.fromDatabaseMap(Map<String, Object?> map) {
    final dynamic mediaRaw = map['media_json'];
    final dynamic tagsRaw = map['tags_json'];
    final dynamic metadataRaw = map['metadata_json'];
    final dynamic moodRaw = map['mood_scores_json'];
    final List<dynamic> mediaList =
        mediaRaw is String && mediaRaw.isNotEmpty ? jsonDecode(mediaRaw) as List<dynamic> : const <dynamic>[];
    final List<dynamic> tagsList =
        tagsRaw is String && tagsRaw.isNotEmpty ? jsonDecode(tagsRaw) as List<dynamic> : const <dynamic>[];
    final Map<String, dynamic> metadataMap =
        metadataRaw is String && metadataRaw.isNotEmpty ? Map<String, dynamic>.from(jsonDecode(metadataRaw)) : <String, dynamic>{};
    final Map<String, dynamic> moodMap =
        moodRaw is String && moodRaw.isNotEmpty ? Map<String, dynamic>.from(jsonDecode(moodRaw)) : <String, dynamic>{};

    return FragmentRecord(
      id: map['id']! as String,
      kind: FragmentKind.values.firstWhere(
        (item) => item.name == map['kind'],
        orElse: () => FragmentKind.text,
      ),
      title: map['title']! as String,
      body: map['body']! as String,
      subtitle: map['subtitle'] as String?,
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
      writtenAt: DateTime.parse(map['written_at']! as String),
      coverPath: map['cover_path'] as String?,
      dominantColor: map['dominant_color'] as int?,
      emoji: map['emoji']! as String,
      layoutHint: map['layout_hint']! as String,
      randomSeed: map['random_seed']! as int,
      playWeight: map['play_weight']! as int,
      readingSeconds: map['reading_seconds']! as int,
      tags: tagsList.map((item) => item.toString()).toList(),
      metadata: metadataMap,
      media: mediaList
          .map((item) => FragmentMedia.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      moodScores: moodMap.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
    );
  }
}
