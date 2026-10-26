import 'dart:async';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';

class VoiceRecordButton extends StatefulWidget {
  final void Function(String path, int durationSeconds) onRecorded;
  final VoidCallback? onCancel;
  final VoidCallback? onRecordingStart;
  final VoidCallback? onRecordingEnd;

  const VoiceRecordButton({
    super.key,
    required this.onRecorded,
    this.onCancel,
    this.onRecordingStart,
    this.onRecordingEnd,
  });

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  final _recorder = AudioRecorder();
  final _player   = AudioPlayer();

  bool _isRecording       = false;
  bool _isLocked          = false; // жогору сүйрөп кулпулоо
  bool _isPaused          = false; // паузага коюу
  bool _isCancelling      = false; // солго сүйрөп жокко чыгаруу
  bool _awaitingPermission = false;

  Duration _elapsed = Duration.zero;
  Timer? _timer;

  double _dragX = 0;
  double _dragY = 0;

  // Солго сүйрөп жокко чыгаруу чеги
  static const double _cancelThreshold = -80;
  // Жогору сүйрөп кулпулоо чеги
  static const double _lockThreshold   = -60;

  // Жаздырылган файлдын жолу (паузадан кийин жөнөтүү үчүн)
  // ignore: unused_field
  String? _recordedPath;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  bool _sfxContextSet = false;

  /// Добуш эффекттеринин AudioContext'и аудио ФОКУСТУ СУРАБАЙ турган
  /// кылып орнотулат (AndroidAudioFocus.none). Мунусуз record_start.wav
  /// ойнотулганда Android аудио фокусту башка колдонмого/сессияга алып,
  /// микрофон жаздырууну үзүп коёт — жаздыруу экранда "9 секунд"
  /// көрсөтсө да, чыныгы файл ~1 секунд (8KB) гана болуп калат жана
  /// алуучуда "зыың" деп токтойт.
  Future<void> _ensureSfxContext() async {
    if (_sfxContextSet) return;
    try {
      await _player.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
        ),
      ));
      _sfxContextSet = true;
    } catch (e) {
      debugPrint('🎤⚠️ SFX AudioContext орнотулбады: $e');
    }
  }

  // ── Үн эффекттери ──
  Future<void> _playSound(String asset) async {
    try {
      await _ensureSfxContext();
      await _player.stop();
      await _player.play(AssetSource(asset));
    } catch (_) {}
  }

  // ── Уруксат текшерүү ──
  Future<bool> _checkAndRequestPermission() async {
    // ВЕБ: permission_handler иштебейт — браузер өзү уруксат сурайт
    if (kIsWeb) {
      final ok = await _recorder.hasPermission();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Үн жаздыруу үчүн браузерде микрофонго уруксат бериңиз'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return ok;
    }
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (mounted) _showPermissionDialog();
      return false;
    }

    status = await Permission.microphone.request();
    if (status.isGranted) return true;

    if (mounted) {
      if (status.isPermanentlyDenied) {
        _showPermissionDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Үн жаздыруу үчүн микрофонго уруксат бериңиз'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    return false;
  }

  void _showPermissionDialog() {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.get('voice_mic_permission_title')),
        content: Text(loc.get('voice_mic_permission_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.get('no')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text(loc.get('voice_mic_permission_settings')),
          ),
        ],
      ),
    );
  }

  // ── Жаздырууну баштоо ──
  Future<void> _startRecording() async {
    setState(() => _awaitingPermission = true);
    final granted = await _checkAndRequestPermission();
    if (!mounted) return;
    setState(() => _awaitingPermission = false);
    if (!granted) return;

    // ВЕБ: файл жолу жок — record пакети blob URL кайтарат (opus/webm)
    final String path;
    if (kIsWeb) {
      path = '';
    } else {
      final dir = await getTemporaryDirectory();
      path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }
    _recordedPath = path;

    await _recorder.start(
      RecordConfig(
        encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
      ),
      path: path,
    );

    if (!mounted) return;
    setState(() {
      _isRecording  = true;
      _isLocked     = false;
      _isPaused     = false;
      _isCancelling = false;
      _elapsed      = Duration.zero;
      _dragX        = 0;
      _dragY        = 0;
    });

    widget.onRecordingStart?.call();
    _startTimer();

    // Жаздыруу башталганда үн жана дирилдөө
    HapticFeedback.mediumImpact();
    _playSound('sounds/record_start.wav');
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isPaused) {
        setState(() => _elapsed += const Duration(seconds: 1));
      }
    });
  }

  // ── Паузага коюу / Улантуу ──
  Future<void> _togglePause() async {
    if (!_isRecording) return;
    if (_isPaused) {
      await _recorder.resume();
      setState(() => _isPaused = false);
      _startTimer();
    } else {
      await _recorder.pause();
      _timer?.cancel();
      setState(() => _isPaused = true);
    }
  }

  // ── Жаздырууну токтотуу ──
  Future<void> _stopRecording({required bool cancelled}) async {
    if (!_isRecording) return;

    _timer?.cancel();
    _timer = null;

    final path     = await _recorder.stop();
    final duration = _elapsed.inSeconds;

    if (!mounted) return;
    setState(() {
      _isRecording  = false;
      _isLocked     = false;
      _isPaused     = false;
      _isCancelling = false;
      _dragX        = 0;
      _dragY        = 0;
    });

    widget.onRecordingEnd?.call();

    if (cancelled || path == null || duration < 1) {
      // Жокко чыгарылганда үн жана дирилдөө
      HapticFeedback.lightImpact();
      _playSound('sounds/record_cancel.wav');
      widget.onCancel?.call();
      return;
    }

    // Жөнөтүлгөндө үн жана дирилдөө
    HapticFeedback.selectionClick();
    _playSound('sounds/record_stop.wav');
    widget.onRecorded(path, duration);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Манжа сүйрөлгөндө ──
  void _onMoveUpdate(Offset offset) {
    if (!_isRecording) return;
    setState(() {
      _dragX        = offset.dx;
      _dragY        = offset.dy;
      _isCancelling = _dragX < _cancelThreshold;

      // Жогору сүйрөлсө → кулпулоо режими
      if (_dragY < _lockThreshold && !_isLocked) {
        _isLocked     = true;
        _isCancelling = false;
      }
    });
  }

  // ── Манжа коё берилгенде ──
  void _onLongPressEnd() {
    if (_awaitingPermission || !_isRecording) return;
    // Кулпу режими активдүү болсо — жөнөтпөйбүз, кулпуланган UI көрсөтөбүз
    if (_isLocked) return;
    _stopRecording(cancelled: _isCancelling);
  }

  @override
  Widget build(BuildContext context) {
    // ── Кулпу режиминдеги UI (жогору сүйрөгөндө) ──
    if (_isLocked && _isRecording) {
      return _LockedRecordingBar(
        elapsed:   _elapsed,
        isPaused:  _isPaused,
        onSend:    () => _stopRecording(cancelled: false),
        onDelete:  () => _stopRecording(cancelled: true),
        onPause:   _togglePause,
        formatDuration: _formatDuration,
      );
    }

    // ── Жаздырып жаткандагы UI (манжа басылуу) ──
    if (_isRecording) {
      return GestureDetector(
        onLongPressEnd:        (_) => _onLongPressEnd(),
        onLongPressMoveUpdate: (d) => _onMoveUpdate(d.offsetFromOrigin),
        child: _RecordingBar(
          elapsed:       _elapsed,
          isCancelling:  _isCancelling,
          isLocking:     _dragY < _lockThreshold,
          formatDuration: _formatDuration,
        ),
      );
    }

    // ── Демейки микрофон баскычы ──
    return GestureDetector(
      onLongPressStart:      (_) => _startRecording(),
      onLongPressEnd:        (_) => _onLongPressEnd(),
      onLongPressMoveUpdate: (d) => _onMoveUpdate(d.offsetFromOrigin),
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.mic, color: Colors.white, size: 22),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Жаздырып жаткандагы тилке (манжа дагы эле басылуу)
// ══════════════════════════════════════════════════════════════════
class _RecordingBar extends StatelessWidget {
  final Duration elapsed;
  final bool isCancelling;
  final bool isLocking;
  final String Function(Duration) formatDuration;

  const _RecordingBar({
    required this.elapsed,
    required this.isCancelling,
    required this.isLocking,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isCancelling
            ? AppColors.error.withValues(alpha: 0.1)
            : isLocking
                ? AppColors.primary.withValues(alpha: 0.1)
                : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BlinkingDot(active: !isCancelling),
          const SizedBox(width: 8),
          Text(
            formatDuration(elapsed),
            style: AppTextStyles.bodyMedium.copyWith(
              color: isCancelling
                  ? AppColors.error
                  : AppColors.black,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          if (isCancelling) ...[
            const Icon(Icons.arrow_back_ios_rounded,
                size: 14, color: AppColors.error),
            const SizedBox(width: 4),
            Text(
              'Коё бериңиз',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
            ),
          ] else if (isLocking) ...[
            const Icon(Icons.arrow_upward_rounded,
                size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              'Кулпулоо',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
            ),
          ] else ...[
            const Icon(Icons.arrow_back_ios_rounded,
                size: 14, color: AppColors.grey400),
            const SizedBox(width: 4),
            Text(
              '← Жокко чыгаруу  ↑ Кулпулоо',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey400),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Кулпуланган жаздыруу UI (жогору сүйрөгөндөн кийин)
// ══════════════════════════════════════════════════════════════════
class _LockedRecordingBar extends StatelessWidget {
  final Duration elapsed;
  final bool isPaused;
  final VoidCallback onSend;
  final VoidCallback onDelete;
  final VoidCallback onPause;
  final String Function(Duration) formatDuration;

  const _LockedRecordingBar({
    required this.elapsed,
    required this.isPaused,
    required this.onSend,
    required this.onDelete,
    required this.onPause,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Жок кылуу баскычы
          _IconBtn(
            icon: Icons.delete_outline_rounded,
            color: AppColors.error,
            onTap: onDelete,
          ),
          const SizedBox(width: 6),

          // Таймер
          Row(
            children: [
              if (!isPaused) const _BlinkingDot(active: true)
              else Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.grey400,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                formatDuration(elapsed),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),

          // Пауза / Улантуу баскычы
          _IconBtn(
            icon: isPaused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            color: AppColors.primary,
            onTap: onPause,
          ),
          const SizedBox(width: 6),

          // Жөнөтүү баскычы
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Жардамчы: иконка баскычы ──
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

// ── Жыпылдаган чекит ──
class _BlinkingDot extends StatefulWidget {
  final bool active;
  const _BlinkingDot({required this.active});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppColors.error,
          shape: BoxShape.circle,
        ),
      );
    }
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppColors.error,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}