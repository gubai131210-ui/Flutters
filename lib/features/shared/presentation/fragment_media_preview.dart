import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/fragment_models.dart';

/// A single app-wide 5s beat used by every image carousel. Replaces the
/// per-card `Timer.periodic` that used to allocate N timers per Home grid.
final ValueNotifier<int> _carouselTick = ValueNotifier<int>(0);
Timer? _carouselTimer;
int _carouselSubscribers = 0;

void _subscribeTick() {
  _carouselSubscribers++;
  _carouselTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
    _carouselTick.value++;
  });
}

void _unsubscribeTick() {
  _carouselSubscribers--;
  if (_carouselSubscribers <= 0) {
    _carouselSubscribers = 0;
    _carouselTimer?.cancel();
    _carouselTimer = null;
  }
}

/// Image carousel, optional inline video when [active], or static thumbnail / audio placeholder.
class FragmentMediaPreview extends StatefulWidget {
  const FragmentMediaPreview({
    super.key,
    required this.media,
    required this.active,
    this.inlineVideo = false,
    this.height = 128,
    this.borderRadius = 22,
    this.accent,
    this.gradientEnd,
    this.videoVolume = 0.35,
  });

  final List<FragmentMedia> media;
  final bool active;
  final bool inlineVideo;
  final double height;
  final double borderRadius;
  final Color? accent;
  final Color? gradientEnd;
  final double videoVolume;

  @override
  State<FragmentMediaPreview> createState() => _FragmentMediaPreviewState();
}

class _FragmentMediaPreviewState extends State<FragmentMediaPreview> {
  PageController? _pageController;
  VideoPlayerController? _video;
  String? _videoPathLoaded;
  bool _subscribedTick = false;
  int _imageCount = 0;
  /// Bumped on each [_syncVideo] entry and in [dispose] so stale async work never calls [setState].
  int _videoSyncGen = 0;

  List<String> _existingImagePaths() {
    final out = <String>[];
    for (final FragmentMedia m in widget.media) {
      if (m.kind == MediaKind.image && _exists(m.path)) {
        out.add(m.path);
      }
    }
    return out;
  }

  bool _exists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  String? _existingVideoPath() {
    for (final FragmentMedia m in widget.media) {
      if (m.kind == MediaKind.video && _exists(m.path)) {
        return m.path;
      }
    }
    return null;
  }

  bool _hasAudio() {
    return widget.media.any((FragmentMedia m) => m.kind == MediaKind.audio && _exists(m.path));
  }

  @override
  void initState() {
    super.initState();
    _setupImageCarousel();
    unawaited(_syncVideo());
  }

  void _setupImageCarousel() {
    final paths = _existingImagePaths();
    _imageCount = paths.length;
    _pageController?.dispose();
    _pageController = null;
    _unsubscribeTickIfNeeded();
    if (paths.length > 1 && widget.active) {
      _pageController = PageController();
      _subscribeTickIfNeeded();
    }
  }

  void _subscribeTickIfNeeded() {
    if (_subscribedTick) {
      return;
    }
    _subscribedTick = true;
    _subscribeTick();
    _carouselTick.addListener(_onTick);
  }

  void _unsubscribeTickIfNeeded() {
    if (!_subscribedTick) {
      return;
    }
    _subscribedTick = false;
    _carouselTick.removeListener(_onTick);
    _unsubscribeTick();
  }

  void _onTick() {
    if (!mounted || !widget.active) {
      return;
    }
    final pc = _pageController;
    if (pc == null || !pc.hasClients || _imageCount <= 1) {
      return;
    }
    final next = ((pc.page?.round() ?? 0) + 1) % _imageCount;
    pc.animateToPage(
      next,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(FragmentMediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media != widget.media) {
      _setupImageCarousel();
    } else if (oldWidget.active != widget.active) {
      if (!widget.active) {
        _pageController?.dispose();
        _pageController = null;
        _unsubscribeTickIfNeeded();
      } else {
        _setupImageCarousel();
      }
    }
    unawaited(_syncVideo());
  }

  Future<void> _syncVideo() async {
    final int gen = ++_videoSyncGen;
    final path = _existingVideoPath();
    if (path == null) {
      await _disposeVideo();
      return;
    }
    if (!widget.inlineVideo || !widget.active) {
      await _disposeVideo();
      if (mounted && gen == _videoSyncGen) {
        setState(() {});
      }
      return;
    }
    if (_videoPathLoaded == path && _video != null && _video!.value.isInitialized) {
      try {
        await _video!.setVolume(widget.videoVolume);
        await _video!.play();
      } catch (_) {}
      return;
    }
    await _disposeVideo();
    if (!mounted || gen != _videoSyncGen) {
      return;
    }
    final VideoPlayerController controller = VideoPlayerController.file(
      File(path),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize();
      if (!mounted || gen != _videoSyncGen) {
        await controller.dispose();
        return;
      }
      await controller.setVolume(widget.videoVolume);
      await controller.setLooping(true);
      await controller.play();
      if (!mounted || gen != _videoSyncGen) {
        await controller.dispose();
        return;
      }
      setState(() {
        _video = controller;
        _videoPathLoaded = path;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted && gen == _videoSyncGen) {
        setState(() {});
      }
    }
  }

  Future<void> _disposeVideo() async {
    final v = _video;
    _video = null;
    _videoPathLoaded = null;
    if (v != null) {
      await v.pause();
      await v.dispose();
    }
  }

  @override
  void dispose() {
    _videoSyncGen++;
    _unsubscribeTickIfNeeded();
    _pageController?.dispose();
    unawaited(_disposeVideo());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? videoPath = _existingVideoPath();
    final List<String> imagePaths = _existingImagePaths();
    final Color accent = widget.accent ?? Theme.of(context).colorScheme.primary;
    final Color gradientEnd = widget.gradientEnd ?? Theme.of(context).colorScheme.secondary;

    if (widget.inlineVideo &&
        widget.active &&
        videoPath != null &&
        _video != null &&
        _video!.value.isInitialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _video!.value.size.width,
              height: _video!.value.size.height,
              child: VideoPlayer(_video!),
            ),
          ),
        ),
      );
    }

    if (videoPath != null) {
      String? thumb;
      for (final FragmentMedia m in widget.media) {
        if (m.kind == MediaKind.video &&
            m.path == videoPath &&
            m.thumbnailPath != null &&
            _exists(m.thumbnailPath!)) {
          thumb = m.thumbnailPath;
          break;
        }
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: thumb != null && _exists(thumb)
              ? Image.file(File(thumb), fit: BoxFit.cover, cacheWidth: 800)
              : Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: const Center(
                    child: Icon(LucideIcons.film, color: Colors.white, size: 36),
                  ),
                ),
        ),
      );
    }

    if (imagePaths.isNotEmpty) {
      if (imagePaths.length == 1) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: Image.file(
              File(imagePaths.first),
              fit: BoxFit.cover,
              cacheWidth: 800,
              errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                return _placeholder(accent, gradientEnd, LucideIcons.image);
              },
            ),
          ),
        );
      }
      final PageController? pc = _pageController;
      if (pc == null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: Image.file(
              File(imagePaths.first),
              fit: BoxFit.cover,
              cacheWidth: 800,
              errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                return _placeholder(accent, gradientEnd, LucideIcons.image);
              },
            ),
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: PageView.builder(
            controller: pc,
            itemCount: imagePaths.length,
            itemBuilder: (BuildContext context, int index) {
              return Image.file(
                File(imagePaths[index]),
                fit: BoxFit.cover,
                width: double.infinity,
                cacheWidth: 800,
                errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                  return _placeholder(accent, gradientEnd, LucideIcons.image);
                },
              );
            },
          ),
        ),
      );
    }

    if (_hasAudio()) {
      String name = '音频';
      for (final FragmentMedia m in widget.media) {
        if (m.kind == MediaKind.audio && _exists(m.path)) {
          name = m.path.split(RegExp(r'[\\/]')).last;
          break;
        }
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: <Color>[
                accent.withValues(alpha: 0.72),
                gradientEnd.withValues(alpha: 0.55),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(LucideIcons.audio_lines, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _placeholder(Color accent, Color gradientEnd, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        gradient: LinearGradient(
          colors: <Color>[
            accent.withValues(alpha: 0.68),
            gradientEnd.withValues(alpha: 0.5),
          ],
        ),
      ),
      child: Center(child: Icon(icon, color: Colors.white, size: 32)),
    );
  }
}
