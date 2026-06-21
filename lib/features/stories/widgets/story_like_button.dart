import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Story viewer ичиндеги жактыруу баскычы.
/// Басканда жүрөк анимациясы ойнойт + haptic feedback.
class StoryLikeButton extends StatefulWidget {
  final bool isLiked;
  final int likesCount;
  final VoidCallback onTap;

  const StoryLikeButton({
    super.key,
    required this.isLiked,
    required this.likesCount,
    required this.onTap,
  });

  @override
  State<StoryLikeButton> createState() => _StoryLikeButtonState();
}

class _StoryLikeButtonState extends State<StoryLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    // Анимация
    await _ctrl.forward();
    await _ctrl.reverse();
    // Haptic feedback
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Жүрөк иконасы — анимация менен
            ScaleTransition(
              scale: _scaleAnim,
              child: Icon(
                widget.isLiked ? Icons.favorite : Icons.favorite_border,
                color: widget.isLiked ? const Color(0xFFF87171) : Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 6),
            // Сан
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                '${widget.likesCount}',
                key: ValueKey(widget.likesCount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
