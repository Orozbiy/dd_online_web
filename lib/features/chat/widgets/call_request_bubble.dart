// lib/features/chat/widgets/call_request_bubble.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/supabase_client.dart';
import '../models/message_model.dart';

class CallRequestBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool isSeller;
  final String myPhone;

  const CallRequestBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isSeller,
    required this.myPhone,
  });

  Future<void> _updateStatus(BuildContext ctx, String status) async {
    try {
      await supabase.rpc('update_call_status', params: {
        'p_message_id': message.id,
        'p_status': status,
      });
      if (status == 'accepted' && myPhone.isNotEmpty) {
        final uri = Uri.parse('tel:$myPhone');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    } catch (e) {
      debugPrint('❌ call_status жаңыртуу ката: $e');
      if (ctx.mounted) {
        final loc = AppLocalizations.of(ctx);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(loc.get('call_request_error'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final pending = message.isCallPending;
    final accepted = message.isCallAccepted;
    final declined = message.isCallDeclined;

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 60 : 12,
        right: isMe ? 12 : 60,
        bottom: 8,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          decoration: BoxDecoration(
            color: _bgColor(accepted, declined),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            border: Border.all(
              color: _borderColor(accepted, declined),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Иконка + аталыш ──
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _iconBg(accepted, declined),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _icon(accepted, declined),
                        color: _iconColor(accepted, declined),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title(loc, accepted, declined),
                            style: AppTextStyles.labelLarge.copyWith(
                              color: _titleColor(accepted, declined),
                            ),
                          ),
                          Text(
                            message.formattedTime,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.grey400,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Статус (pending эмес болсо) ──
                if (!pending) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accepted
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      accepted
                          ? loc.get('call_request_status_ok')
                          : loc.get('call_request_status_no'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: accepted ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                  // ✅ Кардар жагында + accepted болсо — чалуу баскычы
                  if (accepted && isMe) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        if (myPhone.isNotEmpty) {
                          final uri = Uri.parse('tel:$myPhone');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            '📞 Чалуу',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],

                // ── Сатуучунун баскычтары (pending болсо гана) ──
                if (isSeller && !isMe && pending) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppColors.grey200),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _updateStatus(context, 'declined'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                loc.get('call_request_decline_btn'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _updateStatus(context, 'accepted'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                loc.get('call_request_accept_btn'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Жардамчы методдор ────────────────────────────────────

  String _title(AppLocalizations loc, bool accepted, bool declined) {
    if (accepted) return loc.get('call_request_accepted');
    if (declined) return loc.get('call_request_declined');
    return isMe
        ? loc.get('call_request_sent')
        : loc.get('call_request_received');
  }

  Color _bgColor(bool accepted, bool declined) {
    if (accepted) return const Color(0xFFEEFFF5);
    if (declined) return const Color(0xFFFFEEEE);
    return isMe ? const Color(0xFFEEF4FF) : Colors.white;
  }

  Color _borderColor(bool accepted, bool declined) {
    if (accepted) return AppColors.success.withValues(alpha: 0.3);
    if (declined) return AppColors.error.withValues(alpha: 0.3);
    return AppColors.primary.withValues(alpha: 0.25);
  }

  Color _iconBg(bool accepted, bool declined) {
    if (accepted) return AppColors.success.withValues(alpha: 0.15);
    if (declined) return AppColors.error.withValues(alpha: 0.12);
    return AppColors.primary.withValues(alpha: 0.12);
  }

  IconData _icon(bool accepted, bool declined) {
    if (accepted) return Icons.call;
    if (declined) return Icons.call_end;
    return Icons.phone_callback_rounded;
  }

  Color _iconColor(bool accepted, bool declined) {
    if (accepted) return AppColors.success;
    if (declined) return AppColors.error;
    return AppColors.primary;
  }

  Color _titleColor(bool accepted, bool declined) {
    if (accepted) return AppColors.success;
    if (declined) return AppColors.error;
    return AppColors.black;
  }
}
