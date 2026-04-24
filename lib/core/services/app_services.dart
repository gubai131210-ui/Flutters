import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../models/fragment_models.dart';
import '../stores/tag_usage_store.dart';
import 'bert_tokenizer.dart';
import 'context_feature_scorer.dart';

class DataCatalogService {
  List<FeelingTagDefinition> _tags = const <FeelingTagDefinition>[];
  List<FeelingTagDefinition> _customTags = const <FeelingTagDefinition>[];
  List<KaomojiPreset> _kaomojis = const <KaomojiPreset>[];
  List<InspirationPrompt> _prompts = const <InspirationPrompt>[];

  List<FeelingTagDefinition> get tags => <FeelingTagDefinition>[
        ..._tags,
        ..._customTags,
      ];
  List<FeelingTagDefinition> get builtInTags => _tags;
  List<FeelingTagDefinition> get customTags => _customTags;
  List<KaomojiPreset> get kaomojis => _kaomojis;
  List<InspirationPrompt> get prompts => _prompts;

  Future<void> load() async {
    _tags = await _readList(
      'assets/data/tags.json',
      (Map<String, dynamic> json) => FeelingTagDefinition.fromJson(json),
    );
    _kaomojis = await _readList(
      'assets/data/kaomojis.json',
      (Map<String, dynamic> json) => KaomojiPreset.fromJson(json),
    );
    _prompts = await _readList(
      'assets/data/inspirations.json',
      (Map<String, dynamic> json) => InspirationPrompt.fromJson(json),
    );
  }

  void setCustomTags(List<FeelingTagDefinition> tags) {
    _customTags = tags;
  }

  Future<List<T>> _readList<T>(
    String path,
    T Function(Map<String, dynamic>) parser,
  ) async {
    try {
      final content = await rootBundle.loadString(path);
      final decoded = jsonDecode(content) as List<dynamic>;
      return decoded.map((item) => parser(Map<String, dynamic>.from(item as Map))).toList();
    } catch (_) {
      return <T>[];
    }
  }
}

class AppPreferencesService {
  Future<File> _settingsFile() async {
    final base = await getApplicationDocumentsDirectory();
    final sentiDir = Directory(p.join(base.path, 'Senti'));
    if (!await sentiDir.exists()) {
      await sentiDir.create(recursive: true);
    }
    return File(p.join(sentiDir.path, 'settings.json'));
  }

  Future<Map<String, dynamic>> load() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) {
        return <String, dynamic>{};
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return <String, dynamic>{};
      }
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> save(Map<String, dynamic> value) async {
    final file = await _settingsFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(value),
      flush: true,
    );
  }
}

class PermissionService {
  Future<bool> ensureMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> ensureLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  Future<bool> ensurePhotosPermission() async {
    final statuses = await <Permission>[
      Permission.photos,
      Permission.videos,
      Permission.audio,
    ].request();
    return statuses.values.any((status) => status.isGranted || status.isLimited);
  }
}

class TfliteTagModelService {
  Interpreter? _interpreter;
  BertTokenizer? _tokenizer;
  SentimentModelMetadata? _metadata;
  bool _attemptedLoad = false;
  String _status = '未初始化';

  bool get isReady => _interpreter != null && _tokenizer != null && _metadata != null;
  bool get tokenizerReady => _tokenizer != null && _metadata != null;
  String get status => _status;

  Future<void> warmUp() async {
    if (_attemptedLoad) {
      return;
    }
    _attemptedLoad = true;
    await _loadTokenizerAssets();
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/feeling_model.tflite');
      _status = isReady ? '词表与 TFLite 模型均已就绪' : '模型已加载，但 tokenizer 未准备完成';
    } catch (_) {
      _interpreter = null;
      _status = tokenizerReady ? '词表已加载，等待 feeling_model.tflite' : '词表或模型资源缺失';
    }
  }

  Future<Map<String, double>> predict(String text) async {
    await warmUp();
    if (!isReady || text.trim().isEmpty) {
      return <String, double>{};
    }
    final encoding = _tokenizer!.encode(
      text,
      sequenceLength: _metadata!.sequenceLength,
    );
    final probabilities = _runClassifier(encoding);
    return _metadata!.projectToFeelingScores(probabilities);
  }

  Future<void> _loadTokenizerAssets() async {
    try {
      final vocabContent = await rootBundle.loadString('assets/models/sentiment_vocab.txt');
      final configContent = await rootBundle.loadString('assets/models/sentiment_model_config.json');
      final vocab = const LineSplitter()
          .convert(vocabContent)
          .where((line) => line.trim().isNotEmpty)
          .toList();
      _metadata = SentimentModelMetadata.fromJson(
        jsonDecode(configContent) as Map<String, dynamic>,
      );
      _tokenizer = BertTokenizer(
        vocab: vocab,
        maxSequenceLength: _metadata!.sequenceLength,
      );
      _status = '词表与模型配置已就绪';
    } catch (_) {
      _tokenizer = null;
      _metadata = null;
      _status = '缺少 sentiment_vocab.txt 或 sentiment_model_config.json';
    }
  }

  Map<String, double> _runClassifier(BertEncoding encoding) {
    final interpreter = _interpreter!;
    final inputTensors = interpreter.getInputTensors();
    final outputTensor = interpreter.getOutputTensors().first;
    final inputs = <Object>[];

    for (final tensor in inputTensors) {
      inputs.add(_inputForTensor(tensor.name, encoding));
    }

    final outputs = <int, Object>{
      0: _outputBufferFor(outputTensor),
    };
    interpreter.runForMultipleInputs(inputs, outputs);
    final raw = _flattenToDoubleList(outputs[0]!);
    final trimmed = raw.take(_metadata!.labels.length).toList();
    final probs = _softmax(trimmed);
    return <String, double>{
      for (var index = 0; index < probs.length; index++) _metadata!.labels[index]: probs[index],
    };
  }

  Object _inputForTensor(String name, BertEncoding encoding) {
    if (name.contains('segment') || name.contains('token_type')) {
      return <List<int>>[encoding.tokenTypeIds];
    }
    if (name.contains('mask')) {
      return <List<int>>[encoding.attentionMask];
    }
    return <List<int>>[encoding.inputIds];
  }

  Object _outputBufferFor(Tensor tensor) {
    final shape = tensor.shape;
    if (shape.length == 2) {
      return List<List<double>>.generate(
        shape[0],
        (_) => List<double>.filled(shape[1], 0),
      );
    }
    if (shape.length == 1) {
      return List<double>.filled(shape[0], 0);
    }
    return List<dynamic>.filled(shape.fold<int>(1, (value, element) => value * element), 0.0);
  }

  List<double> _flattenToDoubleList(Object value) {
    final buffer = <double>[];
    void visit(Object current) {
      if (current is List) {
        for (final item in current) {
          visit(item as Object);
        }
      } else if (current is double) {
        buffer.add(current);
      } else if (current is int) {
        buffer.add(current.toDouble());
      } else if (current is Uint8List) {
        buffer.addAll(current.map((item) => item.toDouble()));
      }
    }

    visit(value);
    return buffer;
  }

  List<double> _softmax(List<double> logits) {
    if (logits.isEmpty) {
      return <double>[];
    }
    final maxLogit = logits.reduce(max);
    final exps = logits.map((item) => exp(item - maxLogit)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((item) => item / sum).toList();
  }
}

class SentimentModelMetadata {
  const SentimentModelMetadata({
    required this.modelId,
    required this.sequenceLength,
    required this.labels,
    required this.feelingProjection,
  });

  final String modelId;
  final int sequenceLength;
  final List<String> labels;
  final Map<String, Map<String, double>> feelingProjection;

  factory SentimentModelMetadata.fromJson(Map<String, dynamic> json) {
    final projectionRaw = Map<String, dynamic>.from(json['feelingProjection'] as Map);
    return SentimentModelMetadata(
      modelId: json['modelId'] as String,
      sequenceLength: json['sequenceLength'] as int? ?? 128,
      labels: (json['labels'] as List<dynamic>).map((item) => item.toString()).toList(),
      feelingProjection: projectionRaw.map(
        (key, value) => MapEntry(
          key,
          Map<String, double>.from(
            (value as Map).map(
              (innerKey, innerValue) => MapEntry(
                innerKey.toString(),
                (innerValue as num).toDouble(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<String, double> projectToFeelingScores(Map<String, double> labelProbabilities) {
    final scores = <String, double>{};
    labelProbabilities.forEach((label, probability) {
      final projection = feelingProjection[label];
      if (projection == null) {
        return;
      }
      projection.forEach((feeling, weight) {
        scores.update(
          feeling,
          (value) => value + (probability * weight),
          ifAbsent: () => probability * weight,
        );
      });
    });
    return scores;
  }
}

enum TagEngineMode {
  rulesV2,
  lexicon,
  tfliteHybrid,
}

class FeelingTagService {
  FeelingTagService(
    this._catalog,
    this._modelService,
    this._contextScorer,
    this._usageStore,
  );

  final DataCatalogService _catalog;
  final TfliteTagModelService _modelService;
  final ContextFeatureScorer _contextScorer;
  final TagUsageStore _usageStore;
  TagEngineMode _mode = TagEngineMode.rulesV2;
  bool _usageWarm = false;

  TagEngineMode get mode => _mode;

  void setMode(TagEngineMode mode) {
    _mode = mode;
  }

  Future<List<String>> analyze({
    required String title,
    required String body,
    required List<String> manualTags,
    required Map<String, dynamic> metadata,
    List<FragmentMedia> media = const <FragmentMedia>[],
    bool recordUsage = false,
  }) async {
    if (!_usageWarm) {
      await _usageStore.warmUp();
      _usageWarm = true;
    }
    final buffer = StringBuffer()
      ..write(title)
      ..write(' ')
      ..write(body)
      ..write(' ')
      ..write(metadata.values.join(' '));
    final source = buffer.toString().trim();
    final Map<String, double> scores = _ruleScores(source);
    final Map<String, double> rulesOnly = Map<String, double>.from(scores);

    if (_mode == TagEngineMode.lexicon) {
      _mergeScores(scores, _lexiconScores(source), factor: 0.45);
    }
    if (_mode == TagEngineMode.tfliteHybrid) {
      final modelScores = await _modelService.predict(source);
      final double topProb = modelScores.values.fold<double>(0.0, max);
      if (topProb >= 0.48) {
        _mergeScores(scores, modelScores, factor: 0.36);
      }
    }

    final contextScores = _contextScorer.score(
      body: body,
      media: media,
      metadata: metadata,
    );
    _mergeScores(scores, contextScores, factor: 0.56);

    final usageScores = _usageStore.weightFor(_catalog.tags.map((FeelingTagDefinition t) => t.label));
    _mergeScores(scores, usageScores, factor: 0.8);

    for (final tag in manualTags) {
      scores.update(tag, (value) => value + 0.9, ifAbsent: () => 0.9);
    }

    List<MapEntry<String, double>> sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final double topScore = sorted.isEmpty ? 0 : sorted.first.value;
    if (topScore < 0.52 && rulesOnly.isNotEmpty) {
      sorted = rulesOnly.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    }

    final labels = sorted.take(4).map((entry) => entry.key).toList();
    if (labels.isEmpty) {
      return <String>['治愈', '记录'];
    }
    if (recordUsage) {
      await _usageStore.record(<String>[
        ...manualTags,
        ...labels.take(2),
      ]);
    }
    return labels;
  }

  void _mergeScores(
    Map<String, double> base,
    Map<String, double> incoming, {
    double factor = 1.0,
  }) {
    for (final entry in incoming.entries) {
      final double value = entry.value * factor;
      base.update(entry.key, (double v) => v + value, ifAbsent: () => value);
    }
  }

  Map<String, double> _ruleScores(String source) {
    final String text = source.toLowerCase();
    final String compact = text.replaceAll(RegExp(r'\s+'), '');
    final Set<String> bigrams = _buildBigrams(compact);
    final Map<String, double> scores = <String, double>{};
    const intensifiers = <String, double>{
      '很': 1.15,
      '特别': 1.2,
      '非常': 1.25,
      '超级': 1.3,
      '太': 1.22,
    };
    const baseNegations = <String>['不', '没', '无', '别'];
    for (final tag in _catalog.tags) {
      double score = 0.0;
      bool negated = false;
      for (final String phrase in tag.negations) {
        final String p = phrase.trim().toLowerCase();
        if (p.isNotEmpty && compact.contains(p)) {
          negated = true;
          break;
        }
      }

      for (final keyword in tag.keywords) {
        final String key = keyword.trim().toLowerCase();
        if (key.isEmpty) {
          continue;
        }
        double weight = 0.34;
        final bool hit = text.contains(key) || compact.contains(key) || (key.length == 2 && bigrams.contains(key));
        if (hit) {
          for (final intensifier in intensifiers.entries) {
            if (text.contains('${intensifier.key}$key')) {
              weight *= intensifier.value;
            }
          }
          for (final String neg in baseNegations) {
            if (text.contains('$neg$key')) {
              weight *= 0.45;
            }
          }
          if (key.length == 2 && bigrams.contains(key)) {
            weight += 0.16;
          }
          score += weight;
        }
      }

      if (negated) {
        score = 0;
      }
      if (score > 0.05) {
        scores[tag.label] = score;
      }
    }
    return scores;
  }

  Set<String> _buildBigrams(String input) {
    final List<int> units = input.runes.toList();
    if (units.length < 2) {
      return const <String>{};
    }
    final Set<String> out = <String>{};
    for (int i = 0; i < units.length - 1; i++) {
      final String a = String.fromCharCode(units[i]).trim();
      final String b = String.fromCharCode(units[i + 1]).trim();
      if (a.isEmpty || b.isEmpty) {
        continue;
      }
      out.add('$a$b');
    }
    return out;
  }

  Map<String, double> _lexiconScores(String source) {
    final text = source.toLowerCase();
    final scores = <String, double>{};
    const lexicon = <String, Map<String, double>>{
      '开心': <String, double>{'治愈': 0.75, '发光': 0.52},
      '温柔': <String, double>{'温柔': 0.78, '安心': 0.66},
      '难过': <String, double>{'想念': 0.72, '心碎': 0.88},
      '疲惫': <String, double>{'宁静': 0.62, '夜色': 0.54},
      '平静': <String, double>{'宁静': 0.82, '清醒': 0.65},
      '期待': <String, double>{'回暖': 0.63, '发光': 0.72},
      '雨': <String, double>{'雨天': 0.86, '怀旧': 0.55},
      '夜': <String, double>{'夜色': 0.88, '怀旧': 0.42},
    };
    for (final entry in lexicon.entries) {
      if (!text.contains(entry.key)) {
        continue;
      }
      for (final projected in entry.value.entries) {
        scores.update(
          projected.key,
          (value) => value + projected.value,
          ifAbsent: () => projected.value,
        );
      }
    }
    return scores;
  }
}

class MediaStorageService {
  MediaStorageService() : _uuid = const Uuid();

  final Uuid _uuid;
  static const String bundledDefaultBgmAsset = 'first thoughts - Get Up And Dive.mp3';
  static const String _bundledAssetPrefix = 'asset:';

  Future<Directory> _root() async {
    final directory = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(directory.path, 'Senti'));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<String> importHintPath() async {
    final root = await _root();
    return p.join(root.path, 'Imports', 'Audio');
  }

  Future<String> importBgmPathHint() async {
    final root = await _root();
    return p.join(root.path, 'bgm');
  }

  Future<File> _customBgmMarker() async {
    final root = await _root();
    return File(p.join(root.path, '.bgm_imported_once'));
  }

  Future<String> copyIntoApp({
    required String sourcePath,
    required String folderName,
  }) async {
    final root = await _root();
    final folder = Directory(p.join(root.path, folderName));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final extension = p.extension(sourcePath);
    final target = p.join(folder.path, '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}$extension');
    await File(sourcePath).copy(target);
    return target;
  }

  Future<FragmentMedia?> importImage(String path) async {
    final copied = await copyIntoApp(sourcePath: path, folderName: 'images');
    return FragmentMedia(
      id: _uuid.v4(),
      kind: MediaKind.image,
      path: copied,
      thumbnailPath: copied,
      sizeBytes: await File(copied).length(),
    );
  }

  Future<FragmentMedia?> importAudio(String path) async {
    final copied = await copyIntoApp(sourcePath: path, folderName: 'audio');
    return FragmentMedia(
      id: _uuid.v4(),
      kind: MediaKind.audio,
      path: copied,
      sizeBytes: await File(copied).length(),
    );
  }

  Future<FragmentMedia?> importVideo(String path) async {
    final copied = await copyIntoApp(sourcePath: path, folderName: 'videos');
    final root = await _root();
    final thumbnailDir = Directory(p.join(root.path, 'video_thumbnails'));
    if (!await thumbnailDir.exists()) {
      await thumbnailDir.create(recursive: true);
    }
    final thumbnailPath = await VideoThumbnail.thumbnailFile(
      video: copied,
      thumbnailPath: thumbnailDir.path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 512,
      quality: 80,
    );
    return FragmentMedia(
      id: _uuid.v4(),
      kind: MediaKind.video,
      path: copied,
      thumbnailPath: thumbnailPath,
      sizeBytes: await File(copied).length(),
    );
  }

  Future<String> createRecordingPath() async {
    final root = await _root();
    final folder = Directory(p.join(root.path, 'recordings'));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return p.join(folder.path, '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}.m4a');
  }

  Future<String> importBgm(String sourcePath) async {
    final copied = await copyIntoApp(sourcePath: sourcePath, folderName: 'bgm');
    final marker = await _customBgmMarker();
    if (!await marker.exists()) {
      await marker.writeAsString('1', flush: true);
    }
    return copied;
  }

  Future<String> writeMonthlyExport({
    required int year,
    required int month,
    required String contents,
  }) async {
    final root = await _root();
    final folder = Directory(p.join(root.path, 'Exports'));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final pad = month.toString().padLeft(2, '0');
    final target = File(p.join(folder.path, 'Senti-$year-$pad.md'));
    await target.writeAsString(contents, flush: true);
    return target.path;
  }

  Future<List<String>> listBgmFiles() async {
    final root = await _root();
    final folder = Directory(p.join(root.path, 'bgm'));
    if (await folder.exists()) {
      final customFiles = folder
          .listSync()
          .whereType<File>()
          .map((item) => item.path)
          .toList()
        ..sort();
      if (customFiles.isNotEmpty) {
        return customFiles;
      }
    }
    final marker = await _customBgmMarker();
    if (await marker.exists()) {
      return <String>[];
    }
    return <String>['$_bundledAssetPrefix$bundledDefaultBgmAsset'];
  }
}

class AudioPlaybackService {
  AudioPlaybackService() : _player = AudioPlayer();

  final AudioPlayer _player;

  AudioPlayer get player => _player;

  Future<void> setFile(String path) async {
    await _player.setFilePath(path);
  }

  Future<void> setAsset(String assetPath) async {
    await _player.setAsset(assetPath);
  }

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> stop() => _player.stop();

  Future<void> setVolume(double volume) => _player.setVolume(volume.clamp(0.0, 1.0));

  Future<void> dispose() => _player.dispose();
}

/// Second audio track for fragment clips (recording / imported audio), parallel to BGM.
class FragmentMediaAudioService {
  FragmentMediaAudioService() : _player = AudioPlayer();

  final AudioPlayer _player;

  AudioPlayer get player => _player;

  Future<void> setFile(String path) async {
    await _player.setFilePath(path);
  }

  Future<void> setVolume(double volume) => _player.setVolume(volume.clamp(0.0, 1.0));

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() => _player.dispose();
}

class PlaybackPlanner {
  List<FragmentRecord> buildPlaylist(
    List<FragmentRecord> fragments, {
    String? feeling,
  }) {
    if (fragments.isEmpty) {
      return <FragmentRecord>[];
    }

    final pool = feeling == null || feeling.isEmpty
        ? List<FragmentRecord>.from(fragments)
        : fragments.where((item) => item.tags.contains(feeling)).toList();
    final working = pool.isEmpty ? List<FragmentRecord>.from(fragments) : pool;
    working.sort((a, b) => _score(b, feeling).compareTo(_score(a, feeling)));
    final playlist = <FragmentRecord>[working.removeAt(0)];

    while (working.isNotEmpty) {
      final previous = playlist.last;
      working.sort((a, b) => _transitionScore(b, previous).compareTo(_transitionScore(a, previous)));
      playlist.add(working.removeAt(0));
    }

    return playlist;
  }

  int computeDurationSeconds(FragmentRecord fragment) {
    final bodyLength = fragment.body.runes.length;
    final mediaBonus = max(1, fragment.media.length) * 2;
    final writingBoost = min(4, bodyLength ~/ 45);
    final duration = fragment.readingSeconds + mediaBonus + writingBoost + fragment.playWeight;
    if (duration <= 4) {
      return 4;
    }
    if (duration <= 7) {
      return 5;
    }
    if (duration <= 10) {
      return 8;
    }
    return 12;
  }

  int _score(FragmentRecord fragment, String? feeling) {
    final feelingScore = feeling == null ? 0 : (fragment.tags.contains(feeling) ? 100 : 0);
    return feelingScore + fragment.playWeight + fragment.tags.length + fragment.media.length;
  }

  int _transitionScore(FragmentRecord candidate, FragmentRecord previous) {
    final sharedTags = candidate.tags.where(previous.tags.contains).length * 10;
    final sameKindPenalty = candidate.kind == previous.kind ? -4 : 6;
    return sharedTags + sameKindPenalty + candidate.playWeight;
  }
}

class HomeWeatherSnapshot {
  const HomeWeatherSnapshot({
    required this.city,
    required this.temperatureC,
    required this.apparentTemperatureC,
    required this.weatherCode,
    required this.isDay,
    required this.windSpeedKmh,
    required this.precipitationMm,
    required this.fetchedAt,
  });

  final String city;
  final double temperatureC;
  final double apparentTemperatureC;
  final int weatherCode;
  final bool isDay;
  final double windSpeedKmh;
  final double precipitationMm;
  final DateTime fetchedAt;
}

class WeatherSnapshotService {
  static const String _openMeteoHost = 'api.open-meteo.com';

  Future<HomeWeatherSnapshot?> fetchCurrentForDeviceLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }
      final LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return null;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final String city = await _resolveCity(position.latitude, position.longitude);
      if (city.isEmpty) {
        return null;
      }

      final Map<String, dynamic>? current = await _fetchCurrentWeather(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (current == null) {
        return null;
      }

      final double? temperature = _toDouble(current['temperature_2m']);
      final double? apparentTemperature = _toDouble(current['apparent_temperature']);
      final int? weatherCode = _toInt(current['weather_code']);
      final int? isDay = _toInt(current['is_day']);
      final double? windSpeed = _toDouble(current['wind_speed_10m']);
      final double precipitation =
          _toDouble(current['precipitation']) ??
          (_toDouble(current['rain']) ?? 0) +
              (_toDouble(current['showers']) ?? 0) +
              (_toDouble(current['snowfall']) ?? 0);
      if (temperature == null ||
          apparentTemperature == null ||
          weatherCode == null ||
          isDay == null ||
          windSpeed == null) {
        return null;
      }

      return HomeWeatherSnapshot(
        city: city,
        temperatureC: temperature,
        apparentTemperatureC: apparentTemperature,
        weatherCode: weatherCode,
        isDay: isDay == 1,
        windSpeedKmh: windSpeed,
        precipitationMm: precipitation,
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> buildSnapshot(DateTime now) {
    final options = <Map<String, dynamic>>[
      <String, dynamic>{'emoji': '🌤️', 'label': '晴朗', 'temperature': 24},
      <String, dynamic>{'emoji': '🌥️', 'label': '多云', 'temperature': 22},
      <String, dynamic>{'emoji': '🌧️', 'label': '小雨', 'temperature': 18},
      <String, dynamic>{'emoji': '🌙', 'label': '夜色', 'temperature': 20},
    ];
    final item = options[now.hour % options.length];
    return <String, dynamic>{
      'emoji': item['emoji'],
      'label': item['label'],
      'temperature': item['temperature'],
      'weekday': now.weekday,
      'hour': now.hour,
    };
  }

  Future<String> _resolveCity(double latitude, double longitude) async {
    try {
      final List<Placemark> marks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (marks.isEmpty) {
        return '';
      }
      final Placemark p = marks.first;
      final List<String> parts = <String>[
        if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
        if ((p.subAdministrativeArea ?? '').trim().isNotEmpty) p.subAdministrativeArea!.trim(),
        if ((p.administrativeArea ?? '').trim().isNotEmpty) p.administrativeArea!.trim(),
      ];
      for (final String s in parts) {
        if (s.endsWith('市') || s.endsWith('自治州') || s.endsWith('地区')) {
          return s;
        }
      }
      return parts.isEmpty ? '' : parts.first;
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, dynamic>?> _fetchCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    final Uri uri = Uri.https(_openMeteoHost, '/v1/forecast', <String, String>{
      'latitude': latitude.toStringAsFixed(6),
      'longitude': longitude.toStringAsFixed(6),
      'current':
          'temperature_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,wind_speed_10m',
      'timezone': 'auto',
    });

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final HttpClientRequest req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final HttpClientResponse resp = await req.close();
      if (resp.statusCode != 200) {
        return null;
      }
      final String body = await utf8.decoder.bind(resp).join();
      final Map<String, dynamic> json = Map<String, dynamic>.from(
        jsonDecode(body) as Map,
      );
      final dynamic currentRaw = json['current'];
      if (currentRaw is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(currentRaw);
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
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
}

class RecordingService {
  RecordingService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;

  Future<bool> startRecording(String path) async {
    if (!await _recorder.hasPermission()) {
      return false;
    }
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
    return true;
  }

  Future<String?> stopRecording() => _recorder.stop();

  Future<void> dispose() => _recorder.dispose();
}

class ImportPickerService {
  Future<String?> pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    return result?.files.single.path;
  }

  Future<String?> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    return result?.files.single.path;
  }
}
