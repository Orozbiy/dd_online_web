// lib/features/chat/widgets/message_bubble.dart
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/utils/image_utils.dart';
import '../models/message_model.dart';
import '../widgets/voice_message_player_mobile.dart';

// ══════════════════════════════════════════════════════
// GLASSMORPHISM HELPER
// ══════════════════════════════════════════════════════
class _GlassBubble extends StatelessWidget {
  final bool isMe;
  final BorderRadius borderRadius;
  final Widget child;

  const _GlassBubble({
    required this.isMe,
    required this.borderRadius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Таза, фон аша өтпөгөн түстөр ──
    final Color bgColor = isMe
        ? (isDark
            ? const Color(0xFF1565C0)   // dark: ачык көк
            : const Color(0xFF1976D2))  // light: көк
        : (isDark
            ? const Color(0xFF2C2C2C)   // dark: күңүрт серый
            : Colors.white);            // light: таза ак

    final Color borderColor = isMe
        ? Colors.white.withValues(alpha: 0.15)
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06));

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ══════════════════════════════════════════════════════
// ГАЛОЧКА ВИДЖЕТИ
// ══════════════════════════════════════════════════════
/// isMe=true болгондо гана көрсөтүлөт.
/// Логика:
///   isRead=true            → done_all (КОК — окулду)
///   isRead=false + isDelivered=true  → done_all (БОЗДУУ — жеткирилди, окулган жок)
///   isRead=false + isDelivered=false → done (БОЗДУУ — жөнөтүлдү)
class _MessageStatus extends StatelessWidget {
  final bool isRead;
  final bool isDelivered;
  final bool isMe;
  final bool onDarkBg; // сүрөттүн үстүндө болсо true

  const _MessageStatus({
    required this.isRead,
    required this.isDelivered,
    required this.isMe,
    this.onDarkBg = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isMe) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Окулду → ЖАЛТЫРАК АЛТЫН галочка.
    // Эскертүү: мурда бул жерде "көк" колдонулган, бирок өз билдирүүбүз
    // ар дайым КӨК баллон/фондо көрсөтүлөт (isMe = true), ошондуктан
    // көк-үстүндө-көк галочка дээрлик көрүнбөй калып жүргөн — "окулду"
    // белгиси өзгөргөн жок окшойт деп туюлган. Эми ачык-алтын түс
    // колдонулат — ал көк баллондо да, сүрөттүн үстүндөгү кара
    // котормодо да даана көрүнөт.
    if (isRead) {
      return const Icon(Icons.done_all, size: 14, color: Color(0xFFFFC94D));
    }

    // Жеткирилди → боз done_all
    if (isDelivered) {
      final greyColor = onDarkBg
          ? Colors.white.withValues(alpha: 0.65)
          : (isDark
              ? Colors.white.withValues(alpha: 0.50)
              : Colors.white.withValues(alpha: 0.65));
      return Icon(Icons.done_all, size: 14, color: greyColor);
    }

    // Жөнөтүлдү → боз done (1 галочка)
    final greyColor = onDarkBg
        ? Colors.white.withValues(alpha: 0.65)
        : (isDark
            ? Colors.white.withValues(alpha: 0.50)
            : Colors.white.withValues(alpha: 0.65));
    return Icon(Icons.done, size: 14, color: greyColor);
  }
}

// ══════════════════════════════════════════════════════
// FULLSCREEN IMAGE VIEWER
// ══════════════════════════════════════════════════════
class _FullscreenChatImage extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const _FullscreenChatImage({required this.imageUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(
          children: [
            // Толук экран интерактивдик viewer
            SizedBox.expand(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Center(
                  child: Hero(
                    tag: heroTag,
                    child: CachedNetworkImage(
                      // Fullscreen: жогорку сапат (1200px), бирок Cloudinary аркылуу оптимизацияланган
                      imageUrl: toCloudinaryThumb(imageUrl, width: 1200),
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image,
                            size: 80, color: Colors.white54),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Жабуу баскычы
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// MESSAGE BUBBLE
// ══════════════════════════════════════════════════════
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

  // ← ЖАҢЫ: башка адам online болсо true
  final bool isOtherOnline;

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
    this.isOtherOnline = false, // ← ЖАҢЫ
  });

  void _handleLongPress(BuildContext context) {
    if (isSelectionMode) {
      onLongPress?.call();
      return;
    }

    HapticFeedback.mediumImpact();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (sheetContext) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.55),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.8),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  if (message.text.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Text(
                        message.text,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark ? Colors.white : AppColors.black,
                        ),
                      ),
                    ),
                  _ActionButton(
                    icon: Icons.reply_rounded,
                    label: loc.get('msg_action_reply'),
                    color: AppColors.grey500,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onReply?.call();
                    },
                  ),
                  _ActionButton(
                    icon: Icons.select_all_rounded,
                    label: loc.get('msg_action_select'),
                    color: AppColors.grey500,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onLongPress?.call();
                    },
                  ),
                  if (message.text.isNotEmpty)
                    _ActionButton(
                      icon: Icons.copy_rounded,
                      label: loc.get('msg_action_copy'),
                      color: AppColors.primary,
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onCopy?.call();
                      },
                    ),
                  if (isMe && message.text.isNotEmpty)
                    _ActionButton(
                      icon: Icons.edit_rounded,
                      label: loc.get('msg_action_edit'),
                      color: const Color(0xFF6C63FF),
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onEdit?.call();
                      },
                    ),
                  _ActionButton(
                    icon: Icons.delete_rounded,
                    label: loc.get('msg_action_delete'),
                    color: AppColors.error,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onDelete?.call();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Галочка логикасы: online болсо delivered катары эсептейбиз
  bool get _effectiveDelivered =>
      message.isDelivered || isOtherOnline;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    if (message.messageType == 'system') {
      return _SystemMessage(text: message.text);
    }

    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 16),
    );

    final heroTag = 'chat_img_${message.id}';

    return GestureDetector(
      onLongPress: () => _handleLongPress(context),
      onTap: isSelectionMode ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        padding: EdgeInsets.only(
          left: isMe ? 60 : 12,
          right: isMe ? 12 : 60,
          bottom: 6,
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [

              // ══════════════════════════════════════════
              // СҮРӨТ БИЛДИРҮҮ — басканда fullscreen ачылат
              // ══════════════════════════════════════════
              if (message.imageUrl != null && message.imageUrl!.isNotEmpty)
                GestureDetector(
                  onTap: isSelectionMode
                      ? onTap
                      : () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              opaque: false,
                              barrierColor: Colors.black,
                              transitionDuration:
                                  const Duration(milliseconds: 220),
                              pageBuilder: (_, __, ___) =>
                                  _FullscreenChatImage(
                                imageUrl: message.imageUrl!,
                                heroTag: heroTag,
                              ),
                            ),
                          );
                        },
                  child: _GlassBubble(
                    isMe: isMe,
                    borderRadius: bubbleRadius,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Hero(
                              tag: heroTag,
                              child: CachedNetworkImage(
                                // Чатта preview: 400px сжатталган thumbnail (тез жүктөлөт)
                                imageUrl: toCloudinaryThumb(message.imageUrl!, width: 400),
                                width: 220,
                                height: 220,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  width: 220,
                                  height: 220,
                                  color: isDark
                                      ? const Color(0xFF2C2C2C)
                                      : AppColors.grey100,
                                  child: const Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  width: 220,
                                  height: 220,
                                  color: isDark
                                      ? const Color(0xFF2C2C2C)
                                      : AppColors.grey100,
                                  child: const Icon(Icons.broken_image,
                                      size: 48, color: AppColors.grey400),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // ── Сүрөттүн ичинде убакыт + галочка ──
                        if (isMe)
                          Positioned(
                            bottom: 8,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.40),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (message.isEdited)
                                    Text(
                                      '${loc.get('msg_edited')} · ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.white
                                            .withValues(alpha: 0.80),
                                      ),
                                    ),
                                  Text(
                                    message.formattedTime,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.white.withValues(alpha: 0.90),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  _MessageStatus(
                                    isRead: message.isRead,
                                    isDelivered: _effectiveDelivered,
                                    isMe: isMe,
                                    onDarkBg: true,
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Башкасынын сүрөтүндө гана убакыт (оң жакта эмес)
                        if (!isMe)
                          Positioned(
                            bottom: 8,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.40),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                message.formattedTime,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.90),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // ══════════════════════════════════════════
              // АУДИО БИЛДИРҮҮ
              // ══════════════════════════════════════════
              if (message.audioUrl != null && message.audioUrl!.isNotEmpty)
                _GlassBubble(
                  isMe: isMe,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: VoiceMessagePlayer(
                      audioUrl: message.audioUrl!,
                      durationSeconds: message.audioDuration ?? 0,
                      isMe: isMe,
                      isRead: message.isRead,
                      formattedTime: message.formattedTime,
                    ),
                  ),
                ),

              // ══════════════════════════════════════════
              // ТЕКСТ БИЛДИРҮҮ
              // ══════════════════════════════════════════
              if (message.text.isNotEmpty ||
                  (message.imageUrl == null && message.audioUrl == null))
                _GlassBubble(
                  isMe: isMe,
                  borderRadius: bubbleRadius,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Жооп preview
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
                                    : AppColors.grey100
                                        .withValues(alpha: 0.50),
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

                        // Текст
                        if (message.text.isNotEmpty)
                          Text(
                            message.text,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w500,
                              color: isMe
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A1A)),
                            ),
                          ),

                        // Убакыт + галочка
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (message.isEdited)
                              Text(
                                '${loc.get('msg_edited')} • ',
                                style: TextStyle(
                                  fontSize: 12,
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
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.55)
                                        : const Color(0xFF757575)),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              _MessageStatus(
                                isRead: message.isRead,
                                isDelivered: _effectiveDelivered,
                                isMe: isMe,
                                onDarkBg: false,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
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
// SYSTEM MESSAGE
// ══════════════════════════════════════════════════════
class _SystemMessage extends StatelessWidget {
  final String text;
  const _SystemMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            margin:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 40),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// ACTION BUTTON
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}