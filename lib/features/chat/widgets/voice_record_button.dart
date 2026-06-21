import 'package:flutter/material.dart';


/// Веб үчүн: үн жаздыруу жок — бош виджет
class VoiceRecordButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Веб'те микрофон баскычы жок
  }
}