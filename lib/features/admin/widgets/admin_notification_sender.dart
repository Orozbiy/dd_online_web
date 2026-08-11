// lib/features/admin/widgets/admin_notification_sender.dart

import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../services/notification_service.dart';

class AdminNotificationSender extends StatefulWidget {
  const AdminNotificationSender({super.key});

  @override
  State<AdminNotificationSender> createState() =>
      _AdminNotificationSenderState();
}

class _AdminNotificationSenderState extends State<AdminNotificationSender> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  bool _isSending  = false;
  String? _lastResult;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body  = _bodyCtrl.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Аталышты жана текстти жазыңыз'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() { _isSending = true; _lastResult = null; });

    try {
      // ✅ FCM аркылуу бардык токендерге түздөн жөнөт
      final count = await NotificationService().sendBroadcastNotification(
        title: title,
        body: body,
      );

      _titleCtrl.clear();
      _bodyCtrl.clear();

      setState(() => _lastResult = '✅ $count колдонуучуга жеткирилди');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $count колдонуучуга жөнөтүлдү!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      setState(() => _lastResult = '❌ Ката: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ката: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fillColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : AppColors.black;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Башлык ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD97706), Color(0xFFEF4444)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.campaign_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Колдонуучуларга билдирүү',
                style: AppTextStyles.headingSmall.copyWith(color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Аталышы ──
          Text('Аталышы',
              style: AppTextStyles.labelMedium
                  .copyWith(color: isDark ? Colors.white70 : AppColors.grey600)),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Мис: Жаңы акция! 🔥',
              hintStyle: TextStyle(color: AppColors.grey400),
              filled: true,
              fillColor: fillColor,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
          const SizedBox(height: 12),

          // ── Текст ──
          Text('Текст',
              style: AppTextStyles.labelMedium
                  .copyWith(color: isDark ? Colors.white70 : AppColors.grey600)),
          const SizedBox(height: 6),
          TextField(
            controller: _bodyCtrl,
            maxLines: 3,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Билдирүүнүн толук текстин жазыңыз...',
              hintStyle: TextStyle(color: AppColors.grey400),
              filled: true,
              fillColor: fillColor,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),

          // ── Жөнөт баскычы ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.grey300,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
              label: Text(
                _isSending ? 'Жөнөтүлүүдө...' : 'Баардыгына жөнөт',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // ── Акыркы натыйжа ──
          if (_lastResult != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _lastResult!.startsWith('✅')
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _lastResult!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: _lastResult!.startsWith('✅')
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}