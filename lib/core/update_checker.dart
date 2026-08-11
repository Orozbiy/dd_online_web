
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/supabase_client.dart';
import '../services/notification_service.dart'; // navigatorKey үчүн

class UpdateChecker {
  UpdateChecker._();

  static Future<void> check(BuildContext context, String langCode) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final data = await supabase
          .from('app_version')
          .select()
          .eq('id', 1)
          .single();

      final latestVersion = data['latest_version'] as String;
      final minVersion    = data['min_version'] as String;
      final storeUrl      = data['play_store_url'] as String;

      final isOutdated  = _isOlder(currentVersion, latestVersion);
      final isMandatory = _isOlder(currentVersion, minVersion);

      if (!isOutdated) return;

      // ✅ navigatorKey.currentContext колдон — context.mounted эмес
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;

      _showUpdateDialog(
        context:     ctx,
        langCode:    langCode,
        storeUrl:    storeUrl,
        isMandatory: isMandatory,
      );
    } catch (e) {
      debugPrint('⚠️ UpdateChecker ката: $e');
    }
  }

  // '1.0.0' < '1.0.1' → true
  static bool _isOlder(String current, String target) {
    final c = current.split('.').map(int.parse).toList();
    final t = target.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      final cv = i < c.length ? c[i] : 0;
      final tv = i < t.length ? t[i] : 0;
      if (cv < tv) return true;
      if (cv > tv) return false;
    }
    return false;
  }

  static void _showUpdateDialog({
    required BuildContext context,
    required String langCode,
    required String storeUrl,
    required bool isMandatory,
  }) {
    final isKy = langCode == 'ky';

    final title    = isKy ? '🚀 Жаңыртуу бар!'         : '🚀 Доступно обновление!';
    final message  = isKy
        ? 'Колдонмонун жаңы версиясы чыкты.\nЖакшыраак иштеши үчүн жаңыртыңыз.'
        : 'Вышла новая версия приложения.\nОбновите для лучшей работы.';
    final updateBtn = isKy ? 'Жаңыртуу'    : 'Обновить';
    final laterBtn  = isKy ? 'Кийинчерээк' : 'Позже';

    showDialog(
      context:    context,
      barrierDismissible: !isMandatory, // мажбур болсо жабылбасын
      builder: (_) => PopScope(
        canPop: !isMandatory,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
          actions: [
            // "Кийинчерээк" — мажбур эмес болсо гана
            if (!isMandatory)
              TextButton(
                onPressed: () => Navigator.pop(_),
                child: Text(
                  laterBtn,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ElevatedButton(
              onPressed: () async {
                final uri = Uri.parse(storeUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE87B20),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(updateBtn),
            ),
          ],
        ),
      ),
    );
  }
}