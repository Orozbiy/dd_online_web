// ══════════════════════════════════════════════════════
// Товар деталь экранында колдонулган эки кичи баскыч виджети.
// product_detail_screen.dart файлынан бөлүнүп чыгарылды.
// ══════════════════════════════════════════════════════
import 'dart:ui';
import 'package:flutter/material.dart';

/// Айнек эффектүү (blur) баскыч — мисалы фулскрин сүрөт көрүнүшүндө.
class GlassButton extends StatefulWidget {
  final double width;
  final double height;
  final VoidCallback? onTap;
  final bool isDark;
  final Color color;
  final Widget child;

  const GlassButton({
    super.key,
    required this.width,
    required this.height,
    required this.onTap,
    required this.isDark,
    required this.color,
    required this.child,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: _pressed ? 0.88 : 0.80),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.80),
                  width: 1.2,
                ),
              ),
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Градиент фондуу баскыч — мисалы "Арыздануу", "Чат", "Маршрут" баскычтары.
/// Басканда кичирейип-жарчыйт (AnimatedScale) — бардык жерде бирдей сезилет.
class GradientButton extends StatefulWidget {
  final double height;
  final VoidCallback? onTap;
  final Widget child;
  // Берилбесе — демейки амбер/кызыл градиент ("Арыздануу"/"Маршрут")
  final List<Color>? colors;
  final List<Color>? pressedColors;
  final Color? shadowColor;
  final double borderRadius;

  const GradientButton({
    super.key,
    required this.height,
    required this.onTap,
    required this.child,
    this.colors,
    this.pressedColors,
    this.shadowColor,
    this.borderRadius = 16,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final baseColors = widget.colors ??
        const [Color(0xFFD97706), Color(0xFFEF4444)];
    final pressedColors = widget.pressedColors ??
        const [Color(0xFFB45309), Color(0xFFD97706)];
    final shadowColor = widget.shadowColor ?? const Color(0xFFD97706);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: widget.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: (_pressed ? pressedColors : baseColors)
                  .map((c) => c.withValues(alpha: 0.80))
                  .toList(),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withValues(alpha: _pressed ? 0.25 : 0.40),
                blurRadius: _pressed ? 8 : 16,
                offset: const Offset(0, 4),
                spreadRadius: -2,
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}