import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';

import 'app_services.dart';

/// Owns both BGM and fragment-clip audio players.
class AudioCoordinator {
  AudioCoordinator(this._bgm, this._clip, this._storage);

  final AudioPlaybackService _bgm;
  final FragmentMediaAudioService _clip;
  final MediaStorageService _storage;

  static const double _bgmLoud = 0.88;
  static const double _clipVolume = 0.45;
  static const String _bundledAssetPrefix = 'asset:';

  List<String>? _bgmFilesCache;
  bool _bgmPlaying = false;
  StreamSubscription<PlayerState>? _clipSub;
  double _bgmCeiling = _bgmLoud;

  bool get bgmPlaying => _bgmPlaying;

  /// Sets the upper limit for BGM volume (e.g. lowered during night mute).
  Future<void> setBgmCeiling(double ceiling) async {
    _bgmCeiling = ceiling.clamp(0.0, 1.0);
    if (_bgmPlaying) {
      await _bgm.setVolume(_bgmCeiling);
    }
  }

  Future<List<String>> listBgmFiles({bool forceRefresh = false}) async {
    if (_bgmFilesCache != null && !forceRefresh) {
      return _bgmFilesCache!;
    }
    _bgmFilesCache = await _storage.listBgmFiles();
    return _bgmFilesCache!;
  }

  void invalidateBgmCache() {
    _bgmFilesCache = null;
  }

  Future<bool> startBgmIfAvailable() async {
    if (_bgmPlaying) {
      return true;
    }
    final files = await listBgmFiles();
    if (files.isEmpty) {
      return false;
    }
    await _setBgmSource(files.first);
    await _bgm.setVolume(_bgmCeiling);
    await _bgm.play();
    _bgmPlaying = true;
    return true;
  }

  Future<void> stopBgm() async {
    if (!_bgmPlaying) {
      return;
    }
    await _bgm.pause();
    _bgmPlaying = false;
  }

  Future<void> toggleBgm() async {
    if (_bgmPlaying) {
      await stopBgm();
    } else {
      await startBgmIfAvailable();
    }
  }

  /// Plays a clip (audio fragment) at [path].
  Future<void> playClip(String path) async {
    await stopClip();
    if (!File(path).existsSync()) {
      return;
    }
    await _clip.setFile(path);
    await _clip.setVolume(_clipVolume);
    await _clip.play();
    _clipSub = _clip.player.playerStateStream.listen((PlayerState state) async {
      if (state.processingState == ProcessingState.completed) {
        await stopClip();
      }
    });
  }

  Future<void> stopClip() async {
    await _clipSub?.cancel();
    _clipSub = null;
    await _clip.stop();
  }

  Future<void> _setBgmSource(String source) async {
    if (source.startsWith(_bundledAssetPrefix)) {
      await _bgm.setAsset(source.replaceFirst(_bundledAssetPrefix, ''));
    } else {
      await _bgm.setFile(source);
    }
  }

  Future<void> dispose() async {
    await _clipSub?.cancel();
    _clipSub = null;
  }
}
