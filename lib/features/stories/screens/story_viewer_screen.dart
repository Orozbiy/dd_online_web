import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // ── Прогресс AnimationController (сүрөт үчүн 5 сек) ──
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;

  static const int _imageDuration = 5;

  bool _isPaused = false;

  // ── Video player ──
  CachedVideoPlayerPlusController? _videoCtrl;
  bool _videoReady = false;
  bool _isVideoStory = false;
  

  // ── Сүрөт жүктөлдүбү ──
  bool _imageReady = false;

  // ── Видео прогрессти жаңыртуу таймер ──
  Timer? _videoProgressTimer;

  // ── Видео прогресс (0.0 → 1.0) ──
  double _videoProgress = 0.0;

  // ── Viewed IDs ──
  Set<String> _viewedIds = {};

  @override
  void initState() {
    super.initState();
    _stories      = List<StoryModel>.from(widget.stories);
    _currentIndex = widget.initialIndex.clamp(0, _stories.length - 1);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // AnimationController — сүрөт үчүн гана
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _imageDuration),
    );
    _progressAnim = CurvedAnimation(
      parent: _progressCtrl,
      curve:  Curves.linear,
    );

    // БИР ЖОЛУ ГАНА баштайбыз
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadViewedIds();
      if (mounted) _startStory(_currentIndex);
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _progressCtrl.dispose();
    _videoProgressTimer?.cancel();
    _disposeVideo();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Viewed IDs
  // ─────────────────────────────────────────────
  Future<void> _loadViewedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('viewed_story_ids') ?? [];
    _viewedIds = ids.toSet();
    if (mounted) {
      setState(() {
        _stories = _stories
            .map((s) => s.copyWith(isViewed: _viewedIds.contains(s.id)))
            .toList();
      });
    }
  }

  Future<void> _markViewed(String storyId) async {
    if (_viewedIds.contains(storyId)) return;
    _viewedIds.add(storyId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('viewed_story_ids', _viewedIds.toList());
    if (!mounted) return;
    setState(() {
      final i = _stories.indexWhere((s) => s.id == storyId);
      if (i != -1) _stories[i] = _stories[i].copyWith(isViewed: true);
    });
  }

  // ─────────────────────────────────────────────
  // Video dispose
  // ─────────────────────────────────────────────
  void _disposeVideo() {
    _videoProgressTimer?.cancel();
    _videoProgressTimer = null;
    _videoCtrl?.pause();
    _videoCtrl?.dispose();
    _videoCtrl = null;
    _videoReady = false;
    _videoProgress = 0.0;
    _isVideoStory = false;
  }

  // ─────────────────────────────────────────────
  // Story баштоо
  // ─────────────────────────────────────────────
  Future<void> _startStory(int index) async {
    if (index >= _stories.length) {
      _close();
      return;
    }

    _disposeVideo();

    // Прогрессти баштапкы абалга келтир
    _progressCtrl.removeStatusListener(_onProgressStatus);
    _progressCtrl.stop();
    _progressCtrl.reset();

    final story = _stories[index];
    _markViewed(story.id);

    if (story.isVideo) {
      setState(() => _isVideoStory = true);
      await _initVideo(story.mediaUrl);
    } else {
      // ── СҮРӨТ: жүктөлгөндөн кийин 5 секунд ──
      setState(() {
        _isVideoStory = false;
        _imageReady = false; // жүктөлүп жатат
      });
      _progressCtrl.duration = const Duration(seconds: _imageDuration);
      // Таймер _onImageLoaded() чакырылганда башталат
    }
  }

  // ─────────────────────────────────────────────
  // Видео инициализация
  // ─────────────────────────────────────────────
  Future<void> _initVideo(String url) async {
    try {
      final ctrl = CachedVideoPlayerPlusController.networkUrl(
        Uri.parse(url),
        invalidateCacheIfOlderThan: const Duration(days: 2),
      );
      _videoCtrl = ctrl;

      await ctrl.initialize();
      if (!mounted) return;

      setState(() => _videoReady = true);
      await ctrl.play();

      // ── Таймер: видеонун позициясын окуп прогрессти жаңыртат ──
      _videoProgressTimer = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) {
          if (!mounted) return;
          final dur = ctrl.value.duration.inMilliseconds;
          final pos = ctrl.value.position.inMilliseconds;
          if (dur <= 0) return;

          final progress = (pos / dur).clamp(0.0, 1.0);
          setState(() => _videoProgress = progress);

          // Видео бүткөндө (акыркы 200ms)
          if (pos >= dur - 200 && !_isPaused) {
            _videoProgressTimer?.cancel();
            _videoProgressTimer = null;
            _goNext();
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Video init error: $e');
      if (mounted) {
        setState(() {
          _videoReady = false;
          _isVideoStory = false;
        });
        _progressCtrl.duration = const Duration(seconds: _imageDuration);
        _progressCtrl.forward();
        _progressCtrl.addStatusListener(_onProgressStatus);
      }
    }
  }

  // ── Сүрөт толук жүктөлгөндө чакырылат ──
  void _onImageLoaded() {
    if (_imageReady || _isVideoStory) return; // эки жолу чакырылбасын
    _imageReady = true;
    _progressCtrl.removeStatusListener(_onProgressStatus);
    _progressCtrl.stop();
    _progressCtrl.reset();
    _progressCtrl.forward();
    _progressCtrl.addStatusListener(_onProgressStatus);
  }

  // Сүрөт прогресс бүттү
  void _onProgressStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _progressCtrl.removeStatusListener(_onProgressStatus);
      _goNext();
    }
  }

  // ─────────────────────────────────────────────
  // Навигация
  // ─────────────────────────────────────────────
  bool _isNavigating = false;

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
      _isNavigating = false;
      _close();
    }
  }

  void _goPrev() {
    _progressCtrl.removeStatusListener(_onProgressStatus);
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    } else {
      _progressCtrl.reset();
    }
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
    if (_isVideoStory) {
      _videoProgressTimer?.cancel();
      _videoCtrl?.pause();
    } else {
      _progressCtrl.stop();
    }
    setState(() => _isPaused = true);
  }

  void _resume() {
    if (!_isPaused) return;
    if (_isVideoStory && _videoCtrl != null) {
      _videoCtrl!.play();
      // Таймерди кайра баштайбыз
      final ctrl = _videoCtrl!;
      _videoProgressTimer = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) {
          if (!mounted) return;
          final dur = ctrl.value.duration.inMilliseconds;
          final pos = ctrl.value.position.inMilliseconds;
          if (dur <= 0) return;
          final progress = (pos / dur).clamp(0.0, 1.0);
          setState(() => _videoProgress = progress);
          if (pos >= dur - 200 && !_isPaused) {
            _videoProgressTimer?.cancel();
            _videoProgressTimer = null;
            _goNext();
          }
        },
      );
    } else {
      _progressCtrl.forward();
    }
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

            // ── Прогресс сызык + жабуу ──
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ Видео болсо — видеонун позициясы, сүрөт болсо — AnimationController
                    _isVideoStory
                        ? _VideoProgressBar(
                            count:        _stories.length,
                            currentIndex: _currentIndex,
                            progress:     _videoProgress,
                          )
                        : StoryProgressBar(
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
    if (story.isImage) {
      return CachedNetworkImage(
        key:      ValueKey(story.id),
        imageUrl: story.mediaUrl,
        fit:      BoxFit.cover,
        width:    double.infinity,
        height:   double.infinity,
        // ✅ Сүрөт жүктөлгөндөн кийин таймер башталат
        imageBuilder: (_, imageProvider) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _onImageLoaded());
          return Image(
            image: imageProvider,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        },
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorWidget: (_, __, ___) {
          // Ката болсо да таймерди башта
          WidgetsBinding.instance.addPostFrameCallback((_) => _onImageLoaded());
          return const Center(
            child: Icon(Icons.image_not_supported_outlined,
                color: Colors.white54, size: 64),
          );
        },
      );
    }

    if (_videoReady && _videoCtrl != null && _videoCtrl!.value.isInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width:  _videoCtrl!.value.size.width,
            height: _videoCtrl!.value.size.height,
            child:  CachedVideoPlayerPlus(_videoCtrl!),
          ),
        ),
      );
    }

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
}

// ─────────────────────────────────────────────
// Видео прогресс сызыгы — double progress (0.0→1.0) кабыл алат
// ─────────────────────────────────────────────
class _VideoProgressBar extends StatelessWidget {
  final int count;
  final int currentIndex;
  final double progress; // 0.0 → 1.0, видеонун позициясынан

  const _VideoProgressBar({
    required this.count,
    required this.currentIndex,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < count - 1 ? 4 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: i < currentIndex
                      ? 1.0
                      : i == currentIndex
                          ? progress
                          : 0.0,
                  backgroundColor: Colors.white.withValues(alpha: 0.4),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}