import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import '../models/story_model.dart';
import '../services/story_service.dart';
import '../widgets/story_progress_bar.dart';
import '../widgets/story_like_button.dart';

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

  // Сүрөт үчүн убакыт
  static const int _imageDuration = 5;
  // Видео узундугу белгисиз болгондо колдонулат
  static const int _fallbackVideoDuration = 15;

  bool _isPaused    = false;
  bool _isNavigating = false;

  // ── Video player ──
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;

  // Видео узундугун listener менен күтөбүз
  Timer? _durationTimer;

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
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Video dispose
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

  // ─────────────────────────────────────────────
  // Story баштоо
  // ─────────────────────────────────────────────
  Future<void> _startStory(int index) async {
    if (index < 0 || index >= _stories.length) return;

    _disposeVideo();
    _progressCtrl.removeStatusListener(_onProgressStatus);
    _progressCtrl.stop();
    _progressCtrl.reset();

    final story = _stories[index];

    if (story.isVideo) {
      await _initVideo(story.mediaUrl);
    } else {
      _progressCtrl.duration = const Duration(seconds: _imageDuration);
      _progressCtrl.forward();
      _progressCtrl.addStatusListener(_onProgressStatus);
    }
  }

  // ─────────────────────────────────────────────
  // Видео инициализация
  // ─────────────────────────────────────────────
  Future<void> _initVideo(String url) async {
    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        httpHeaders: kIsWeb ? {} : {'Cache-Control': 'max-age=604800'},
      );
      _videoCtrl = ctrl;

      await ctrl.initialize();
      if (!mounted) return;

      setState(() => _videoReady = true);
      ctrl.play();

      // ── Видео узундугун туура окуу ──
      // Веб'де initialize() бүткөндө duration нөл болуп калат,
      // ошондуктан listener менен күтөбүз
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

  // Duration'ды listener менен күтүү (веб үчүн маанилүү)
  void _waitForDurationAndStartProgress(VideoPlayerController ctrl) {
    // Эгер дароо жеткиликтүү болсо
    final dur = ctrl.value.duration;
    if (dur.inMilliseconds > 500) {
      _startProgressForVideo(dur);
      return;
    }

    // Болбосо 50ms сайын текшерип турабыз (максимум 5 сек)
    int attempts = 0;
    _durationTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (!mounted) { t.cancel(); return; }
      attempts++;
      final d = ctrl.value.duration;
      if (d.inMilliseconds > 500) {
        t.cancel();
        _startProgressForVideo(d);
      } else if (attempts > 100) {
        // 5 секунд күттүк, эч нерсе жок — fallback
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

  // Видео listener — бүткөндү текшерет
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
      setState(() {
        _currentIndex++;
        _isNavigating = false;
      });
      _startStory(_currentIndex);
    } else {
      setState(() {
        _currentIndex  = 0;
        _isNavigating  = false;
      });
      _startStory(0);
    }
  }

  void _goPrev() {
    if (_isNavigating) return;
    _progressCtrl.removeStatusListener(_onProgressStatus);
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
    _isNavigating = false;
    _startStory(_currentIndex);
  }

  void _close() {
    Navigator.of(context).pop(_stories);
  }

  // ─────────────────────────────────────────────
  // Пауза / Resume
  // ─────────────────────────────────────────────
  void _pause() {
    if (_isPaused) return;
    _durationTimer?.cancel();
    _progressCtrl.stop();
    _videoCtrl?.pause();
    setState(() => _isPaused = true);
  }

  void _resume() {
    if (!_isPaused) return;
    _progressCtrl.forward();
    _videoCtrl?.play();
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
            // ── Медиа ──
            _buildMedia(story),

            // ── Градиент жогору ──
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.topCenter,
                  end:    Alignment.center,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
            ),

            // ── Градиент төмөн ──
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

            // ── Прогресс + жабуу ──
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

            // ── Лайк баскычы ──
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

    // ── ВИДЕО жүктөлүп жатат ──
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

    // ── ВИДЕО — кат жок, туура пропорция ──
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
