import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/services/yandex_storage_service.dart';

// ══════════════════════════════════════════════════════
// Глобалдык активдүү плеер — бир эле убакта бир гана
// ══════════════════════════════════════════════════════
AudioPlayer? _activePlayer;

class VoiceMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final int durationSeconds;
  final bool isMe;
  final bool isRead;
  final String formattedTime;

  const VoiceMessagePlayer({
    super.key,
    required this.audioUrl,
    required this.durationSeconds,
    required this.isMe,
    this.isRead = false,
    this.formattedTime = '',
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _audioContextSet = false;
  double _progress = 0.0;
  int _currentSeconds = 0;
  int _totalSeconds = 0;

  // Жергиликтүү кэшке толук жүктөп алынган аудио файлдын жолу.
  // Тармак (HTTP) аркылуу агым түрүндө ойнотуу Backblaze B2'нин
  // presigned URL'дери менен ExoPlayer'де туура иштебей, бир нече
  // миллисекунд ("зыың") үн чыгарып токтоп калчу — ошон үчүн ойнотуудан
  // мурун файлды ТОЛУК жүктөп алып, андан кийин локалдык файлдан ойнотобуз.

  static const int _barCount = 27;
  late final List<double> _barHeights = _generateBarHeights(widget.audioUrl);

  static List<double> _generateBarHeights(String seed) {
    final rnd = Random(seed.hashCode);
    return List.generate(_barCount, (_) => 0.28 + rnd.nextDouble() * 0.72);
  }

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _totalSeconds = widget.durationSeconds;

    _player.setReleaseMode(ReleaseMode.stop);

    // PlayerState өзгөргөндө UI жаңыртуу
    _player.onPlayerStateChanged.listen((state) {
      debugPrint('🔊 PlayerState: $state');
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
        if (state == PlayerState.playing ||
            state == PlayerState.stopped ||
            state == PlayerState.paused) {
          _isLoading = false;
        }
      });
    });

    _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      final total = _totalSeconds > 0 ? _totalSeconds : 1;
      setState(() {
        _currentSeconds = pos.inSeconds;
        _progress = (pos.inSeconds / total).clamp(0.0, 1.0);
      });
    });

    _player.onDurationChanged.listen((d) {
      debugPrint('🔊 Duration changed: ${d.inMilliseconds}ms');
      if (!mounted) return;
      setState(() => _totalSeconds = d.inSeconds > 0 ? d.inSeconds : _totalSeconds);
    });

    _player.onPlayerComplete.listen((_) {
      debugPrint('🔊 Playback complete');
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _isLoading = false;
        _progress = 0.0;
        _currentSeconds = 0;
      });
      if (_activePlayer == _player) _activePlayer = null;
    });

    _player.onLog.listen((msg) => debugPrint('🔊 audioplayers log: $msg'));
  }

  @override
  void dispose() {
    if (_activePlayer == _player) _activePlayer = null;
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  /// AudioContext биринчи ойнотуудан мурун бир жолу орнотулат
  Future<void> _ensureAudioContext() async {
    if (_audioContextSet) return;
    try {
      await _player.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
        ),
      ));
      _audioContextSet = true;
      debugPrint('🔊✅ AudioContext орнотулду');
    } catch (e) {
      debugPrint('🔊❌ AudioContext катасы: $e');
      // AudioContext орнотуу кетсе да ойнотуу улантылат
    }
  }

  /// Ойнотуучу URL: Backblaze (колдонмодон жүктөлгөн, жеке bucket) болсо —
  /// убактылуу signed URL; Supabase (веб'ден жүктөлгөн) болсо — түз URL.
  String _getPlayUrl() {
    try {
      if (YandexStorageService.extractObjectKey(widget.audioUrl) == null) {
        return widget.audioUrl;
      }
      return YandexStorageService.instance.presignedUrl(widget.audioUrl);
    } catch (e) {
      debugPrint('🔊❌ Presigned URL жасалбады: $e, түп URL колдонулат');
      return widget.audioUrl;
    }
  }

  Future<void> _togglePlay() async {
    debugPrint('🔊 _togglePlay чакырылды. isLoading=$_isLoading isPlaying=$_isPlaying url=${widget.audioUrl}');
    if (_isLoading) return;
    if (widget.audioUrl.isEmpty) {
      debugPrint('🔊❌ audioUrl бош!');
      return;
    }

    // Ойноп жатса — пауза
    if (_isPlaying) {
      await _player.pause();
      debugPrint('🔊 Пауза коюлду');
      return;
    }

    // Башка плеер ойнотулуп жатса — аны токтот
    if (_activePlayer != null && _activePlayer != _player) {
      await _activePlayer!.stop();
      _activePlayer = null;
    }

    setState(() => _isLoading = true);

    try {
      // AudioContext бир жолу орнотулат (await менен!)
      await _ensureAudioContext();

      final currentState = _player.state;
      debugPrint('🔊 Учурдагы player.state = $currentState, currentSeconds=$_currentSeconds, progress=$_progress');

      if (currentState == PlayerState.paused &&
          _currentSeconds > 0 &&
          _progress < 0.99) {
        // Паузадан улантуу
        debugPrint('🔊 Паузадан улантылат (resume)');
        await _player.resume();
      } else {
        // Жаңыдан баштоо
        if (_progress >= 0.99) {
          setState(() {
            _progress = 0.0;
            _currentSeconds = 0;
          });
        }
        // ВЕБ: браузердин <audio> элементи URL'ди түздөн-түз стрим кылат
        final playUrl = _getPlayUrl();
        debugPrint('🔊▶️ play() чакырылат: $playUrl');
        await _player.play(UrlSource(playUrl));
        debugPrint('🔊✅ play() ийгиликтүү чакырылды');
      }
      _activePlayer = _player;
    } catch (e, st) {
      debugPrint('🔊❌ Ойнотуу катасы: $e\n$st');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Үн ойнотулбай жатат: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    // 8 секунд ичинде ойнобосо — loading өчүр (timeout)
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _isLoading) {
        debugPrint('🔊⏱️ Timeout — loading өчүрүлдү (аудио 8 сек ичинде башталбады)');
        setState(() => _isLoading = false);
      }
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final iconColor     = widget.isMe ? Colors.white : AppColors.primary;
    final trackColor    = widget.isMe
        ? Colors.white.withValues(alpha: 0.3)
        : AppColors.grey200;
    final progressColor = widget.isMe ? Colors.white : AppColors.primary;
    final subColor      = widget.isMe
        ? Colors.white.withValues(alpha: 0.70)
        : AppColors.grey400;

    final displaySeconds = _currentSeconds > 0
        ? _currentSeconds
        : widget.durationSeconds;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Play / Pause баскычы ──
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.isMe
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: _isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: iconColor,
                        ),
                      )
                    : Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: iconColor,
                        size: 22,
                      ),
              ),
            ),
            const SizedBox(width: 8),

            // ── Progress bar + убакыт ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Толкун (waveform) ──
                  LayoutBuilder(
                    builder: (context, constraints) {
                      void seekTo(double localX) {
                        final ratio = (localX / constraints.maxWidth)
                            .clamp(0.0, 1.0);
                        final seekMs =
                            (ratio * _totalSeconds * 1000).toInt();
                        _player.seek(Duration(milliseconds: seekMs));
                      }

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) => seekTo(d.localPosition.dx),
                        onHorizontalDragUpdate: (d) =>
                            seekTo(d.localPosition.dx),
                        child: SizedBox(
                          height: 22,
                          width: double.infinity,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(_barCount, (i) {
                              final barProgress = i / _barCount;
                              final played = barProgress <= _progress;
                              return Container(
                                width: 2.5,
                                height: 22 * _barHeights[i],
                                decoration: BoxDecoration(
                                  color: played ? progressColor : trackColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),

                  // ── Убакыт + птичка ──
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDuration(displaySeconds),
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 13,
                          color: subColor,
                        ),
                      ),
                      if (widget.formattedTime.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          '· ${widget.formattedTime}',
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 13,
                            color: subColor,
                          ),
                        ),
                      ],
                      if (widget.isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          widget.isRead
                              ? Icons.done_all
                              : Icons.done,
                          size: 14,
                          color: widget.isRead
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}