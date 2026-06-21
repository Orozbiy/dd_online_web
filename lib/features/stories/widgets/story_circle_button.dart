import 'package:flutter/material.dart';
import '../models/story_model.dart';

/// WhatsApp историясындагыдай тегерек кнопка.
/// Жылтылдаган анимация + "Жаңы" badge менен.
class StoryCircleButton extends StatefulWidget {
  final StoryModel story;
  final VoidCallback onTap;

  const StoryCircleButton({
    super.key,
    required this.story,
    required this.onTap,
  });

  @override
  State<StoryCircleButton> createState() => _StoryCircleButtonState();
}

class _StoryCircleButtonState extends State<StoryCircleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final errorBg    = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F6);
    final countColor = isDark ? const Color(0xFFAAAAAA) : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Тегерек + анимация ──
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) {
                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [

                    // ── Жылтылдаган сырткы жарык ──
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD97706)
                                .withValues(alpha: _glowAnim.value * 0.6),
                            blurRadius: 12 * _glowAnim.value,
                            spreadRadius: 2 * _glowAnim.value,
                          ),
                        ],
                      ),
                    ),

                    // ── Градиент чек ──
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Color.lerp(const Color(0xFFD97706),
                                const Color(0xFFEC4899), _glowAnim.value)!,
                            Color.lerp(const Color(0xFFF59E0B),
                                const Color(0xFF8B5CF6), _glowAnim.value)!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),

                    // ── Фон ──
                    Container(
                      width: 63,
                      height: 63,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),

                    // ── Медиа preview ──
                    ClipOval(
                      child: SizedBox(
                        width: 58,
                        height: 58,
                        child: Image.network(
                          widget.story.mediaUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: errorBg,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: isDark
                                  ? const Color(0xFF6B7280)
                                  : const Color(0xFF9CA3AF),
                              size: 24,
                            ),
                          ),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: errorBg,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // ── Видео белгиси ──
                    if (widget.story.isVideo)
                      Positioned(
                        bottom: 1,
                        right: 1,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFD97706),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),

                    // ── "ЖАҢЫ" badge — жогору оң бурч ──
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFEC4899)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 1.5,
                          ),
                        ),
                        child: const Text(
                          'ЖАҢЫ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 5),

            // ── Жактыруулар саны ──
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite, size: 11, color: Color(0xFFF87171)),
                const SizedBox(width: 2),
                Text(
                  '${widget.story.likesCount}',
                  style: TextStyle(
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                    color:      countColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}