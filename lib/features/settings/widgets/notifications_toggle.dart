import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../services/notification_service.dart';

class NotificationsToggle extends StatefulWidget {
  const NotificationsToggle({super.key});
  @override
  State<NotificationsToggle> createState() => _NotificationsToggleState();
}

class _NotificationsToggleState extends State<NotificationsToggle> {
  static const _prefKey = 'notifications_enabled';
  static const _topic   = 'all_users';
  bool _enabled        = true;
  bool _loading        = true;
  bool _webPermission  = false; // веб'де уруксат берилгенби

  @override
  void initState() {
    super.initState();
    _loadPref();
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Веб'де уруксат абалын текшер
    if (kIsWeb) {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized;
      if (mounted) setState(() {
        _webPermission = granted;
        _enabled = prefs.getBool(_prefKey) ?? true;
        _loading = false;
      });
    } else {
      if (mounted) setState(() {
        _enabled = prefs.getBool(_prefKey) ?? true;
        _loading = false;
      });
    }
  }

  Future<void> _requestWebPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await NotificationService().saveMyToken();
      if (mounted) setState(() => _webPermission = true);
    }
  }

  Future<void> _onChanged(bool value) async {
    setState(() => _enabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    if (value) {
      await FirebaseMessaging.instance.subscribeToTopic(_topic);
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic(_topic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc     = AppLocalizations.of(context);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.grey600;

    // ── ВЕБ'ДЕ УРУКСАТ БЕРИЛГЕН ЖОК ──
    if (kIsWeb && !_loading && !_webPermission) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.notifications_off_outlined,
                color: AppColors.grey400, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                loc.get('notifications'),
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
              ),
            ),
            GestureDetector(
              onTap: _requestWebPermission,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Иштетүү',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── МОБИЛ ЖЕ ВЕБ'ДЕ УРУКСАТ БАР ──
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.notifications_outlined,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loc.get('notifications'),
              style: AppTextStyles.bodyMedium.copyWith(color: textColor),
            ),
          ),
          if (_loading)
            const SizedBox(
              width: 36, height: 20,
              child: Center(
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            )
          else
            Switch(
              value: _enabled,
              onChanged: _onChanged,
              activeColor: AppColors.primary,
            ),
        ],
      ),
    );
  }
}