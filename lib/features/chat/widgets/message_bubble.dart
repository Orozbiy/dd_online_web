import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/utils/image_utils.dart';
import '../models/message_model.dart';
import '../widgets/voice_message_player_mobile.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  // ── Select режими ──
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  // ── Long-press menu / reply ──
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final VoidCallback? onReplyTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onTap,
    this.onCopy,
    this.onDelete,
    this.onReply,
    this.onReplyTap,
  });

  void _handleLongPress(BuildContext context) {
    if (isSelectionMode) {
      onLongPress?.call();
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            if (message.text.isNotEmpty)
              ListTile(
                leading:
                    const Icon(Icons.copy_outlined, color: AppColors.primary),
                title:
                    const Text('Көчүрүү', style: AppTextStyles.labelLarge),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onCopy?.call();
                },
              ),
            ListTile(
              leading:
                  const Icon(Icons.reply_outlined, color: AppColors.primary),
              title: const Text('Жооп берүү',
                  style: AppTextStyles.labelLarge),
              onTap: () {
                Navigator.pop(sheetContext);
                onReply?.call();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.error),
              title:
                  const Text('Өчүрүү', style: AppTextStyles.labelLarge),
              onTap: () {
                Navigator.pop(sheetContext);
                onDelete?.call();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Сүрөттү толук экранда ачуу ──
  void _openFullscreen(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => _FullscreenImageScreen(
          imageUrl: imageUrl,
          heroTag: 'chat_image_${message.id}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _handleLongPress(context),
      onTap: isSelectionMode ? onTap : null,
      child: Container(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Padding(
          padding: EdgeInsets.only(
            left: isMe ? 60 : 12,
            right: isMe ? 12 : 60,
            top: 4,
            bottom: 4,
          ),
          child: Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    color:
                        isSelected ? AppColors.primary : AppColors.grey300,
                    size: 22,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // ── СҮРӨТ БИЛДИРҮҮ ──
                    if (message.imageUrl != null &&
                        message.imageUrl!.isNotEmpty)
                      GestureDetector(
                        // select режиминде баспайт, анын ордуна тандалат
                        onTap: isSelectionMode
                            ? onTap
                            : () => _openFullscreen(
                                context, message.imageUrl!),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          constraints:
                              const BoxConstraints(maxWidth: 200),
                          child: Hero(
                            tag: 'chat_image_${message.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: toCloudinaryThumb(
                                  message.imageUrl!,
                                  width: 400,
                                ),
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  width: 200,
                                  height: 150,
                                  color: AppColors.grey100,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  width: 200,
                                  height: 150,
                                  color: AppColors.grey100,
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: AppColors.grey300,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // ── ҮН БИЛДИРҮҮ ──
                    if (message.audioUrl != null &&
                        message.audioUrl!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: VoiceMessagePlayer(
                          audioUrl: message.audioUrl!,
                          durationSeconds: message.audioDuration ?? 0,
                          isMe: isMe,
                        ),
                      ),

                    // ── ТЕКСТ БИЛДИРҮҮ ──
                    if (message.text.isNotEmpty ||
                        (message.imageUrl == null &&
                            message.audioUrl == null))
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.primary
                              : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft:
                                Radius.circular(isMe ? 16 : 4),
                            bottomRight:
                                Radius.circular(isMe ? 4 : 16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Жооп preview ──
                            if (message.replyToId != null &&
                                message.replyToText != null)
                              GestureDetector(
                                onTap: onReplyTap,
                                child: Container(
                                  margin: const EdgeInsets.only(
                                      bottom: 6),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? Colors.white
                                            .withValues(alpha: 0.15)
                                        : AppColors.grey100,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: Border(
                                      left: BorderSide(
                                        color: isMe
                                            ? Colors.white
                                            : AppColors.primary,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    message.replyToText!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        AppTextStyles.labelSmall.copyWith(
                                      color: isMe
                                          ? Colors.white
                                              .withValues(alpha: 0.85)
                                          : AppColors.grey600,
                                    ),
                                  ),
                                ),
                              ),

                            // ── Текст ──
                            if (message.text.isNotEmpty)
                              Text(
                                message.text,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isMe
                                      ? Colors.white
                                      : AppColors.black,
                                ),
                              ),

                            // ── Убакыт + окулду ──
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  message.formattedTime,
                                  style:
                                      AppTextStyles.labelSmall.copyWith(
                                    color: isMe
                                        ? Colors.white
                                            .withValues(alpha: 0.7)
                                        : AppColors.grey400,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    message.isRead
                                        ? Icons.done_all
                                        : Icons.done,
                                    size: 14,
                                    color: message.isRead
                                        ? Colors.white
                                        : Colors.white
                                            .withValues(alpha: 0.6),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// СҮРӨТТҮ ТОЛУК ЭКРАНДА КӨРСӨТҮҮ (zoom/pan + Hero)
// ══════════════════════════════════════════════════════
class _FullscreenImageScreen extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const _FullscreenImageScreen({
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Zoom + pan ──
          Center(
            child: Hero(
              tag: heroTag,
              child: 
              
              InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),

          // ── Жабуу баскычы ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
