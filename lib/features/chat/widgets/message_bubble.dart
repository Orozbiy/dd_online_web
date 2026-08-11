import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/utils/image_utils.dart';
import '../models/message_model.dart';
import '../widgets/voice_message_player_mobile.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  final VoidCallback? onCopy;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final VoidCallback? onReplyTap;
  final VoidCallback? onEdit;

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
    this.onEdit,
  });

  void _handleLongPress(BuildContext context) {
    if (isSelectionMode) {
      onLongPress?.call();
      return;
    }

    // Вибрация
    HapticFeedback.mediumImpact();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final divColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle ──
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3A3A3A) : AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Билдирүү preview ──
              if (message.text.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A2A2A)
                        : AppColors.grey100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF3A3A3A)
                          : AppColors.grey200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isDark ? Colors.white70 : AppColors.grey600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Divider(height: 1, color: divColor),

              // ── Баскычтар ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Жооп берүү
                    _ActionButton(
                      icon: Icons.reply_rounded,
                      label: 'Жооп',
                      color: AppColors.primary,
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onReply?.call();
                      },
                    ),

                    // Көчүрүү
                    if (message.text.isNotEmpty)
                      _ActionButton(
                        icon: Icons.copy_rounded,
                        label: 'Көчүрүү',
                        color: AppColors.primary,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          onCopy?.call();
                        },
                      ),

                    // Өзгөртүү (өзүнүн билдирүүсү гана)
                    if (isMe && message.text.isNotEmpty)
                      _ActionButton(
                        icon: Icons.edit_rounded,
                        label: 'Өзгөртүү',
                        color: const Color(0xFF6C63FF),
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          onEdit?.call();
                        },
                      ),

                    // Өчүрүү
                    _ActionButton(
                      icon: Icons.delete_rounded,
                      label: 'Өчүрүү',
                      color: AppColors.error,
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onDelete?.call();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

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
                    color: isSelected ? AppColors.primary : AppColors.grey300,
                    size: 22,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // ── СҮРӨТ БИЛДИРҮҮ ──
                    if (message.imageUrl != null && message.imageUrl!.isNotEmpty)
                      GestureDetector(
                        onTap: isSelectionMode
                            ? onTap
                            : () => _openFullscreen(context, message.imageUrl!),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          constraints: const BoxConstraints(maxWidth: 200),
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
                    if (message.audioUrl != null && message.audioUrl!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
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
                        (message.imageUrl == null && message.audioUrl == null))
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
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
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? Colors.white.withValues(alpha: 0.15)
                                        : AppColors.grey100,
                                    borderRadius: BorderRadius.circular(8),
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
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: isMe
                                          ? Colors.white.withValues(alpha: 0.85)
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
                                  color: isMe ? Colors.white : AppColors.black,
                                ),
                              ),

                            // ── Убакыт + окулду ──
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (message.isEdited)
                                  Text(
                                    'өзгөртүлдү • ',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                      color: isMe
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : AppColors.grey400,
                                    ),
                                  ),
                                Text(
                                  message.formattedTime,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: isMe
                                        ? Colors.white.withValues(alpha: 0.7)
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
                                        : Colors.white.withValues(alpha: 0.6),
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
// ACTION BUTTON — горизонталдык меню баскычы
// ══════════════════════════════════════════════════════
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : AppColors.grey600,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// СҮРӨТТҮ ТОЛУК ЭКРАНДА КӨРСӨТҮҮ
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
          Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
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
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}