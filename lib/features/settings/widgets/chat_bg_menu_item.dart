import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/chat_background_provider.dart';
import '../screens/chat_background_settings_screen.dart';

class ChatBgMenuItem extends StatelessWidget {
  final ChatBackgroundProvider provider;

  const ChatBgMenuItem({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final loc        = AppLocalizations.of(context);
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final textColor  = isDark ? Colors.white : AppColors.black;
    final subColor   = isDark ? const Color(0xFFAAAAAA) : AppColors.grey500;
    final arrowColor = isDark ? const Color(0xFF666666) : AppColors.grey400;

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatBackgroundSettingsScreen(provider: provider),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14), // ← 12→14 башкалар менен бирдей
          child: Row(
            children: [
              // ← Контейнер жок, жөн гана Icon — CacheMenuItem/SupportMenuItem/TermsMenuItem сыяктуу
              const Icon(
                Icons.wallpaper_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 12), // ← 14→12 башкалар менен бирдей
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.get('chat_background'),
                      style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                    ),
                    const SizedBox(height: 2),
                 // provider.theme.label → provider.theme.localizedLabel(context)
Text(
  provider.theme.localizedLabel(context),
  style: AppTextStyles.labelSmall.copyWith(color: subColor),
),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: arrowColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}