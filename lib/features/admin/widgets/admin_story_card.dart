import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../stories/models/story_model.dart';

class AdminStoryCard extends StatelessWidget {
  final StoryModel story;
  final VoidCallback onToggleActive; // активдештирүү / өчүрүү
  final VoidCallback onDelete;       // толугу менен жок кылуу

  const AdminStoryCard({
    super.key,
    required this.story,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = story.isActive
        ? AppColors.success.withValues(alpha: 0.6)
        : AppColors.grey300;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Медиа Preview ──
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
            child: SizedBox(
              width: 90,
              height: 110,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    story.mediaUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.grey100,
                      child: const Icon(Icons.image_not_supported_outlined,
                          color: AppColors.grey400, size: 32),
                    ),
                  ),
                  // Видео белгиси
                  if (story.isVideo)
                    Container(
                      color: Colors.black38,
                      child: const Center(
                        child: Icon(Icons.play_circle_fill,
                            color: Colors.white, size: 32),
                      ),
                    ),
                  // Активдүү/өчүк белги
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: story.isActive
                            ? AppColors.success
                            : AppColors.grey400,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        story.isActive ? '● ON' : '○ OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Маалымат ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Тип
                  Row(
                    children: [
                      Icon(
                        story.isVideo ? Icons.videocam : Icons.image,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        story.isVideo ? 'Видео' : 'Сүрөт',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Дата
                  Text(
                    _formatDate(story.createdAt),
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.grey500),
                  ),
                  const SizedBox(height: 6),

                  // Лайктар
                  Row(
                    children: [
                      const Icon(Icons.favorite,
                          size: 14, color: AppColors.error),
                      const SizedBox(width: 4),
                      Text(
                        '${story.likesCount} жактыруу',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Баскычтар ──
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Активдештирүү / өчүрүү
                GestureDetector(
                  onTap: onToggleActive,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: story.isActive
                          ? AppColors.error.withValues(alpha: 0.1)
                          : AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      story.isActive
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: story.isActive
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Жок кылуу
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин мурун';
    if (diff.inHours < 24) return '${diff.inHours} саат мурун';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}
