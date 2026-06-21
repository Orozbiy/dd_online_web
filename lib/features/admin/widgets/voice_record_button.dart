import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';

/// WhatsApp сымал: басып кармап жаздыруу, өйдө сүйрөп жокко чыгаруу.
///
/// `onRecorded(path, durationSeconds)` — жаздыруу ийгиликтүү бүтсө чакырылат.
/// `onCancel()` — колдонуучу swipe-to-cancel кылса чакырылат.
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

  bool _isRecording = false;
  bool _isCancelling = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  // Swipe-to-cancel: горизонталдык жылдыруу аралыгы
  double _dragX = 0;
  static const double _cancelThreshold = -80;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Микрофонго уруксат бериңиз (Жөндөөлөр → Тиркемелер).'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final dir = await _getTempDir();
    final path =
        '$dir/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
      ),
      path: path,
    );

    setState(() {
      _isRecording = true;
      _isCancelling = false;
      _elapsed = Duration.zero;
      _dragX = 0;
    });

    widget.onRecordingStart?.call();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<String> _getTempDir() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  Future<void> _stopRecording({required bool cancelled}) async {
    _timer?.cancel();
    _timer = null;

    final path = await _recorder.stop();
    final duration = _elapsed.inSeconds;

    setState(() {
      _isRecording = false;
      _isCancelling = false;
      _dragX = 0;
    });

    widget.onRecordingEnd?.call();

    if (cancelled || path == null || duration < 1) {
      widget.onCancel?.call();
      return;
    }

    widget.onRecorded(path, duration);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRecording) {
      return GestureDetector(
        onLongPressStart: (_) => _startRecording(),
        onLongPressEnd: (_) => _stopRecording(cancelled: _isCancelling),
        onLongPressMoveUpdate: (details) {
          setState(() {
            _dragX = details.offsetFromOrigin.dx;
            _isCancelling = _dragX < _cancelThreshold;
          });
        },
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

    // ── Жаздыруу учурундагы UI: таймер + "сүйрөп жокко чыгаруу" көрсөтмөсү ──
    return GestureDetector(
      onLongPressEnd: (_) => _stopRecording(cancelled: _isCancelling),
      onLongPressMoveUpdate: (details) {
        setState(() {
          _dragX = details.offsetFromOrigin.dx;
          _isCancelling = _dragX < _cancelThreshold;
        });
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _isCancelling
              ? AppColors.error.withValues(alpha: 0.1)
              : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Жаздыруу индикатору (кызыл чекит) ──
            _BlinkingDot(active: !_isCancelling),
            const SizedBox(width: 8),
            Text(
              _formatDuration(_elapsed),
              style: AppTextStyles.bodyMedium.copyWith(
                color: _isCancelling ? AppColors.error : AppColors.black,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.arrow_back_ios_rounded,
              size: 14,
              color: _isCancelling ? AppColors.error : AppColors.grey400,
            ),
            const SizedBox(width: 4),
            Text(
              _isCancelling ? 'Коё бериңиз' : 'Жокко чыгаруу үчүн сүйрөңүз',
              style: AppTextStyles.labelSmall.copyWith(
                color: _isCancelling ? AppColors.error : AppColors.grey400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Жаздыруу учурунда кызыл чекит жанып-өчүп туруу ──
class _BlinkingDot extends StatefulWidget {
  final bool active;
  const _BlinkingDot({required this.active});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.active ? AppColors.error : AppColors.grey400,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}