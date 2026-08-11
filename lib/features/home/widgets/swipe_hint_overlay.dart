// ══════════════════════════════════════════════════════════════════════════════
// lib/features/home/widgets/swipe_hint_overlay.dart
//
// Оң тараптан панел ачуу жолун 3 жолу көрсөтүп, кийин өзү жок болот.
// SharedPreferences'та 'swipe_hint_count' ачкычы менен саналат.
//
// КОЛДОНУУ:
//   Stack(children: [
//     child,
//     const SwipeHintOverlay(),   // ← ушул жерге кош
//   ])
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SwipeHintOverlay extends StatefulWidget {
  const SwipeHintOverlay({super.key});

  @override
  State<SwipeHintOverlay> createState() => _SwipeHintOverlayState();
}

class _SwipeHintOverlayState extends State<SwipeHintOverlay>
    with TickerProviderStateMixin {
  // Жебенин солго жылуу анимациясы
  late AnimationController _arrowCtrl;
  late Animation<double> _arrowOffset;
  late Animation<double> _arrowOpacity;

  // Пайда болуу / жок болуу анимациясы
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  bool _visible = false;

  static const _prefKey = 'swipe_hint_count';
  static const _maxShows = 1000;

  @override
  void initState() {
    super.initState();

    // ── жебе анимациясы: оңдон солго жылат, кайталанат ──
    _arrowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _arrowOffset = Tween<double>(begin: 0, end: -18).animate(
      CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeInOut),
    );

    _arrowOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_arrowCtrl);

    // ── fade in/out ──
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

    _checkAndShow();
  }

  Future<void> _checkAndShow() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_prefKey) ?? 0;

    if (count >= _maxShows) return; // 3 жолу бүттү — эч нерсе кылба

    // Санды жогорулат
    await prefs.setInt(_prefKey, count + 1);

    if (!mounted) return;

    setState(() => _visible = true);
    await _fadeCtrl.forward(); // fade in

    // Жебени 3 жолу кайталат
    for (int i = 0; i < 150; i++) {
      if (!mounted) return;
      await _arrowCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      _arrowCtrl.reset();
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    await _fadeCtrl.reverse(); // fade out
    if (mounted) setState(() => _visible = false);
  }

  @override
  void dispose() {
    _arrowCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.07);
    final iconColor = isDark ? Colors.white : Colors.black87;
    final labelBg = isDark
        ? Colors.black.withOpacity(0.65)
        : Colors.white.withOpacity(0.92);
    final labelText = isDark ? Colors.white : Colors.black87;

    return Positioned(
      right: 0,
      top: screenHeight * 0.3,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: AnimatedBuilder(
          animation: _arrowCtrl,
          builder: (_, __) => Transform.translate(
            offset: Offset(_arrowOffset.value, 0),
            child: Opacity(
              opacity: _arrowOpacity.value.clamp(0.0, 1.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // ── Жебелер блогу ──
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.keyboard_arrow_left_rounded,
                            color: iconColor.withOpacity(0.4), size: 22),
                        Icon(Icons.keyboard_arrow_left_rounded,
                            color: iconColor.withOpacity(0.7), size: 26),
                        Icon(Icons.keyboard_arrow_left_rounded,
                            color: iconColor, size: 30),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // ── "Менюну ачуу" жазуусу ──
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: labelBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: iconColor.withOpacity(0.12), width: 0.5),
                    ),
                    child: Text(
                      'Менюну ачуу',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: labelText,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
