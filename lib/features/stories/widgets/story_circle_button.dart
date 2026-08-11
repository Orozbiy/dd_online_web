import 'package:flutter/material.dart';
import '../models/story_model.dart';

class StoryCircleButton extends StatelessWidget {
  final StoryModel story;
  final VoidCallback onTap;

  const StoryCircleButton({
    super.key,
    required this.story,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isViewed = story.isViewed;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Чаңкур белги (viewed/unviewed) ──
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isViewed
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFD97706), Color(0xFFEF4444)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: isViewed ? const Color(0xFFCCCCCC) : null,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: story.mediaUrl.isNotEmpty
                      ? Image.network(
                          story.mediaUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const _DefaultStoryIcon(),
                        )
                      : const _DefaultStoryIcon(),
                ),
              ),
            ),
            const SizedBox(height: 5),
            // ── Аты ──
            Text(
              story.isVideo ? '🎬 Видео' : '🖼 Жаңылык',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isViewed
                    ? const Color(0xFF999999)
                    : const Color(0xFF333333),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultStoryIcon extends StatelessWidget {
  const _DefaultStoryIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFEDD5),
      child: const Icon(Icons.auto_awesome, color: Color(0xFFD97706), size: 28),
    );
  }
}