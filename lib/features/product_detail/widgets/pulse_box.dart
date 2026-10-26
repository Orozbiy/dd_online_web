import 'package:flutter/material.dart';

/// Токтобой жай чоңоюп-кичирейген кутуча.
/// Кнопка көзгө урунуп турсун үчүн колдонулат.
class PulseBox extends StatefulWidget {
  const PulseBox({
    super.key,
    required this.child,
    this.minScale = 1.0,
    this.maxScale = 1.09,
    this.duration = const Duration(milliseconds: 850),
  });

  final Widget child;
  final double minScale;
  final double maxScale;
  final Duration duration;

  @override
  State<PulseBox> createState() => _PulseBoxState();
}

class _PulseBoxState extends State<PulseBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat(reverse: true); // ← чексиз кайталанат

  late final Animation<double> _scale = Tween<double>(
    begin: widget.minScale,
    end: widget.maxScale,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
