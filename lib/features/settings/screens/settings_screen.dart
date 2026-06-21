import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../widgets/settings_header.dart';
import '../widgets/language_section.dart';
import '../widgets/notifications_toggle.dart';
import '../widgets/dark_mode_toggle.dart';
import '../widgets/cache_menu_item.dart';
import '../widgets/support_menu_item.dart';
import '../widgets/terms_menu_item.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final loc      = AppLocalizations.of(context);
    final bgColor  = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final divColor  = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.black,
        elevation: 0,
        title: Text(loc.get('settings'),
            style: AppTextStyles.headingSmall.copyWith(
              color: isDark ? Colors.white : AppColors.black,
            )),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SettingsHeader(),
            const SizedBox(height: 32),
            const LanguageSection(),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? [] : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const NotificationsToggle(),
                  Divider(height: 1, color: divColor),
                  const DarkModeToggle(),
                  Divider(height: 1, color: divColor),
                  const CacheMenuItem(),
                  Divider(height: 1, color: divColor),
                  const SupportMenuItem(),
                  Divider(height: 1, color: divColor),
                  const TermsMenuItem(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
