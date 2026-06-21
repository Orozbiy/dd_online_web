import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import '../models/story_model.dart';
import '../services/story_service.dart';
import '../widgets/story_progress_bar.dart';
import '../widgets/story_like_button.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class StoryViewerScreen extends StatefulWidget {
  final List<StoryModel> stories;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late List<StoryModel> _stories;
  late int _currentIndex;

  // ── Прогресс ──
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;

  static const int _imageDuration        = 5;
  static const int _fallbackVideoDuration = 15;

  bool _isPaused     = false;
  bool _isNavigating = false;

  // ── Mobile video player ──
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  Timer? _durationTimer;

  // ── Web HTML video ──
  html.VideoElement? _webVideo;
  String _webViewId = '';

  @override
  void initState() {
    super.initState();
    _stories      = List<StoryModel>.from(widget.stories);
    _currentIndex = widget.initialIndex.clamp(0, _stories.length - 1);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _progressCtrl = AnimationController(vsync: this);
    _progressAnim = CurvedAnimation(
      parent: _progressCtrl,
      curve:  Curves.linear,
    );

    _startStory(_currentIndex);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _progressCtrl.dispose();
    _durationTimer?.cancel();
    _disposeVideo();
    _disposeWebVideo();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Dispose
  // ─────────────────────────────────────────────
  void _disposeVideo() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _videoCtrl?.removeListener(_onVideoListener);
    _videoCtrl?.pause();
    _videoCtrl?.dispose();
    _videoCtrl  = null;
    _videoReady = false;
  }

  void _disposeWebVideo() {
    _webVideo?.pause();
    _webVideo?.src = '';
    _webVideo = null;
  }

  // ─────────────────────────────────────────────
  // Story баштоо
  // ─────────────────────────────────────────────
  Future<void> _startStory(int index) async {
    if (index < 0 || index >= _stories.length) return;

    _disposeVideo();
    _disposeWebVideo();
    _progressCtrl.removeStatusListener(_onProgressStatus);
    _progressCtrl.stop();
    _progressCtrl.reset();

    final story = _stories[index];

    if (story.isVideo) {
      if (kIsWeb) {
        await _initWebVideo(story.mediaUrl);
      } else {
        await _initVideo(story.mediaUrl);
      }
    } else {
      _progressCtrl.duration = const Duration(seconds: _imageDuration);
      _progressCtrl.forward();
      _progressCtrl.addStatusListener(_onProgressStatus);
    }
  }

  // ─────────────────────────────────────────────
  // WEB: HTML <video> элементи
  // ─────────────────────────────────────────────
  Future<void> _initWebVideo(String url) async {
    debugPrint('🎬 Web видео URL: $url');

    final viewId = 'story-video-${DateTime.now().millisecondsSinceEpoch}';
    _webViewId   = viewId;

    final video = html.VideoElement()
      ..src        = url
      ..autoplay   = true
      ..controls   = false
      ..style.width  = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      ..style.backgroundColor = 'black'
      ..setAttribute('playsinline', 'true')
      ..setAttribute('crossorigin', 'anonymous');

    _webVideo = video;

    // View катары каттоо
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (_) => video,
    );

    // Видео жүктөлгөндө прогресс баштоо
    video.onCanPlay.listen((_) {
      if (!mounted) return;
      debugPrint('✅ Web видео ready, duration: ${video.duration}s');
      setState(() {});

      final dur = video.duration;
      if (dur > 0 && dur.isFinite) {
        _startProgressForVideo(
          Duration(milliseconds: (dur * 1000).toInt()),
        );
      } else {
        _startProgressForVideo(
          const Duration(seconds: _fallbackVideoDuration),
        );
      }
    });

    // Видео бүткөндө кийинкиге өтүү
    video.onEnded.listen((_) {
      if (!mounted) return;
      _goNext();
    });

    // Ката
    video.onError.listen((_) {
      debugPrint('❌ Web видео ката: ${video.error?.message}');
      if (!mounted) return;
      _startProgressForVideo(
        const Duration(seconds: _fallbackVideoDuration),
      );
    });

    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────
  // MOBILE: video_player
  // ─────────────────────────────────────────────
  Future<void> _initVideo(String url) async {
    try {
      debugPrint('🎬 Mobile видео URL: $url');
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        httpHeaders: {'Cache-Control': 'max-age=604800'},
      );
      _videoCtrl = ctrl;

      await ctrl.initialize();
      debugPrint('✅ Mobile видео initialize: ${ctrl.value.duration}');
      if (!mounted) return;

      setState(() => _videoReady = true);
      ctrl.play();
      _waitForDurationAndStartProgress(ctrl);
      ctrl.addListener(_onVideoListener);
    } catch (e) {
      debugPrint('❌ Video init error: $e');
      if (mounted) {
        _progressCtrl.duration =
            const Duration(seconds: _fallbackVideoDuration);
        _progressCtrl.forward();
        _progressCtrl.addStatusListener(_onProgressStatus);
      }
    }
  }

  void _waitForDurationAndStartProgress(VideoPlayerController ctrl) {
    final dur = ctrl.value.duration;
    if (dur.inMilliseconds > 500) {
      _startProgressForVideo(dur);
      return;
    }

    int attempts = 0;
    _durationTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (!mounted) { t.cancel(); return; }
      attempts++;
      final d = ctrl.value.duration;
      if (d.inMilliseconds > 500) {
        t.cancel();
        _startProgressForVideo(d);
      } else if (attempts > 100) {
        t.cancel();
        _startProgressForVideo(
            const Duration(seconds: _fallbackVideoDuration));
      }
    });
  }

  void _startProgressForVideo(Duration duration) {
    if (!mounted) return;
    _progressCtrl.removeStatusListener(_onProgressStatus);
    _progressCtrl.stop();
    _progressCtrl.reset();
    _progressCtrl.duration = duration;
    _progressCtrl.forward();
    _progressCtrl.addStatusListener(_onProgressStatus);
  }

  void _onVideoListener() {
    if (!mounted) return;
    final ctrl = _videoCtrl;
    if (ctrl == null) return;
    final pos = ctrl.value.position;
    final dur = ctrl.value.duration;
    if (dur.inMilliseconds > 0 &&
        pos.inMilliseconds >= dur.inMilliseconds - 200) {
      _goNext();
    }
  }

  void _onProgressStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _progressCtrl.removeStatusListener(_onProgressStatus);
      _goNext();
    }
  }

  // ─────────────────────────────────────────────
  // Навигация
  // ─────────────────────────────────────────────
  void _goNext() {
    if (_isNavigating) return;
    _isNavigating = true;
    _progressCtrl.removeStatusListener(_onProgressStatus);

    if (_currentIndex < _stories.length - 1) {
      setState(() { _currentIndex++; _isNavigating = false; });
      _startStory(_currentIndex);
    } else {
      setState(() { _currentIndex = 0; _isNavigating = false; });
      _startStory(0);
    }
  }

  void _goPrev() {
    if (_isNavigating) return;
    _progressCtrl.removeStatusListener(_onProgressStatus);
    if (_currentIndex > 0) setState(() => _currentIndex--);
    _isNavigating = false;
    _startStory(_currentIndex);
  }

  void _close() => Navigator.of(context).pop(_stories);

  // ─────────────────────────────────────────────
  // Пауза / Resume
  // ─────────────────────────────────────────────
  void _pause() {
    if (_isPaused) return;
    _durationTimer?.cancel();
    _progressCtrl.stop();
    _videoCtrl?.pause();
    _webVideo?.pause();
    setState(() => _isPaused = true);
  }

  void _resume() {
    if (!_isPaused) return;
    _progressCtrl.forward();
    _videoCtrl?.play();
    _webVideo?.play();
    setState(() => _isPaused = false);
  }

  // ─────────────────────────────────────────────
  // Лайк
  // ─────────────────────────────────────────────
  Future<void> _toggleLike() async {
    final story  = _stories[_currentIndex];
    final result = await StoryService.instance.toggleLike(story);
    if (mounted) {
      setState(() {
        _stories[_currentIndex] = story.copyWith(
          isLikedByMe: result.liked,
          likesCount:  result.newCount,
        );
      });
    }
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final story = _stories[_currentIndex];
    final size  = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final x = details.globalPosition.dx;
          if (x < size.width / 3) {
            _goPrev();
          } else if (x > size.width * 2 / 3) {
            _goNext();
          }
        },
        onLongPressStart: (_) => _pause(),
        onLongPressEnd:   (_) => _resume(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildMedia(story),

            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.topCenter,
                  end:    Alignment.center,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
            ),

            const Positioned(
              bottom: 0, left: 0, right: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.bottomCenter,
                    end:    Alignment.center,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: SizedBox(height: 120),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StoryProgressBar(
                      count:        _stories.length,
                      currentIndex: _currentIndex,
                      progress:     _progressAnim,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Spacer(),
                        if (_isPaused)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.pause_circle_outline,
                                color: Colors.white70, size: 22),
                          ),
                        GestureDetector(
                          onTap: _close,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      StoryLikeButton(
                        isLiked:    story.isLikedByMe,
                        likesCount: story.likesCount,
                        onTap:      _toggleLike,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Медиа виджет
  // ─────────────────────────────────────────────
  Widget _buildMedia(StoryModel story) {
    // ── СҮРӨТ ──
    if (story.isImage) {
      return CachedNetworkImage(
        key:      ValueKey(story.id),
        imageUrl: story.mediaUrl,
        fit:      BoxFit.cover,
        width:    double.infinity,
        height:   double.infinity,
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorWidget: (_, __, ___) => const Center(
          child: Icon(Icons.image_not_supported_outlined,
              color: Colors.white54, size: 64),
        ),
      );
    }

    // ── WEB ВИДЕО ──
    if (kIsWeb) {
      if (_webViewId.isEmpty) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 12),
              Text('Видео жүктөлүп жатат...',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        );
      }
      return Container(
        color: Colors.black,
        child: HtmlElementView(viewType: _webViewId),
      );
    }

    // ── MOBILE ВИДЕО жүктөлүп жатат ──
    if (!_videoReady || _videoCtrl == null ||
        !_videoCtrl!.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text('Видео жүктөлүп жатат...',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      );
    }

    // ── MOBILE ВИДЕО ──
    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: _videoCtrl!.value.aspectRatio,
          child: VideoPlayer(_videoCtrl!),
        ),
      ),
    );
  }
}
