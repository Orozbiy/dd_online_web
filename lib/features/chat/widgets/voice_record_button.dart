import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';

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

  bool _isRecording   = false;
  bool _isCancelling  = false;
  // ← бул флаг: уруксат диалогу ачык турганда onLongPressEnd игнорланат
  bool _awaitingPermission = false;
  Duration _elapsed   = Duration.zero;
  Timer? _timer;

  double _dragX = 0;
  static const double _cancelThreshold = -80;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ── Уруксат текшерүү ──
  Future<bool> _checkAndRequestPermission() async {
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Микрофон уруксаты'),
        content: const Text(
          'Үн жаздыруу үчүн микрофонго уруксат керек.\n'
          'Жөндөөлөр → Тиркемелер → DD Online → Уруксаттар',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Жок'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Жөндөөлөргө өтүү'),
          ),
        ],
      ),
    );
  }

  Future<void> _startRecording() async {
    // Уруксат диалогу ачылып жатканын белгилейбиз
    setState(() => _awaitingPermission = true);

    final granted = await _checkAndRequestPermission();

    // Диалог бүттү — флагды жок кылабыз
    if (!mounted) return;
    setState(() => _awaitingPermission = false);

    if (!granted) return; // уруксат жок — жаздырбайбыз

    // Уруксат бар — жаздырууну баштайбыз
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
      ),
      path: path,
    );

    if (!mounted) return;
    setState(() {
      _isRecording  = true;
      _isCancelling = false;
      _elapsed      = Duration.zero;
      _dragX        = 0;
    });

    widget.onRecordingStart?.call();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording({required bool cancelled}) async {
    if (!_isRecording) return;

    _timer?.cancel();
    _timer = null;

    final path     = await _recorder.stop();
    final duration = _elapsed.inSeconds;

    if (!mounted) return;
    setState(() {
      _isRecording  = false;
      _isCancelling = false;
      _dragX        = 0;
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
        onLongPressEnd: (_) {
          // ← МАСЕЛЕНИН ЧЕЧИМИ:
          // Уруксат диалогу ачык турса же жаздыруу жок болсо — эч нерсе кылбайбыз
          if (_awaitingPermission || !_isRecording) return;
          _stopRecording(cancelled: _isCancelling);
        },
        onLongPressMoveUpdate: (details) {
          if (_isRecording) {
            setState(() {
              _dragX        = details.offsetFromOrigin.dx;
              _isCancelling = _dragX < _cancelThreshold;
            });
          }
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

    return GestureDetector(
      onLongPressEnd: (_) => _stopRecording(cancelled: _isCancelling),
      onLongPressMoveUpdate: (details) {
        setState(() {
          _dragX        = details.offsetFromOrigin.dx;
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
    )..repeat(reverse: true);
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