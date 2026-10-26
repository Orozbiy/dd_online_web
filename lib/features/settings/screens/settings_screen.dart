import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/dd_design.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/chat_background_provider.dart';
import '../../auth/screens/profile_screen.dart';
import '../widgets/settings_header.dart';
import '../widgets/language_section.dart';
import '../widgets/notifications_toggle.dart';
import '../widgets/dark_mode_toggle.dart';
import '../widgets/chat_bg_menu_item.dart';
import '../widgets/cache_menu_item.dart';
import '../widgets/support_menu_item.dart';
import '../widgets/terms_menu_item.dart';
import '../../home/widgets/suggestion_button.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final loc        = AppLocalizations.of(context);
    final divColor   = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);
    final textColor  = isDark ? Colors.white : AppColors.black;
    final subColor   = isDark ? const Color(0xFFAAAAAA) : AppColors.grey500;
    final cardBg     = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.55);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.80);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.40),
            ),
          ),
        ),
        foregroundColor: textColor,
        title: Text(
          loc.get('settings'),
          style: AppTextStyles.headingMedium.copyWith(color: textColor),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + kToolbarHeight + 12,
          20,
          120,
        ),
        child: Column(
          children: [
            const SettingsHeader(),
            const SizedBox(height: 24),

            // ── Profile Card ──
            _glassCard(
              cardBg: cardBg,
              cardBorder: cardBorder,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: DD.accentGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: DD.accent.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.get('profile'),
                              style: AppTextStyles.labelLarge.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              loc.get('profile_view_edit'),
                              style: AppTextStyles.bodySmall.copyWith(color: subColor),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: isDark ? AppColors.grey500 : AppColors.grey400,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Негизги айнек блок ──
            _glassCard(
              cardBg: cardBg,
              cardBorder: cardBorder,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const LanguageSection(),
                    Divider(height: 1, color: divColor),
                    const NotificationsToggle(),
                    Divider(height: 1, color: divColor),
                    const DarkModeToggle(),
                    Divider(height: 1, color: divColor),
                    ChatBgMenuItem(provider: ChatBackgroundProvider.instance),
                    Divider(height: 1, color: divColor),
                    const CacheMenuItem(),
                    Divider(height: 1, color: divColor),

                    // ── Өтүнүч жиберүү ──
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        builder: (_) => ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.55)
                                    : Colors.white.withValues(alpha: 0.60),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                                border: Border(
                                  top: BorderSide(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.12)
                                        : Colors.black.withValues(alpha: 0.08),
                                  ),
                                ),
                              ),
                              child: const SuggestionButton(),
                            ),
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded,
                                color: DD.accent, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.get('call_request_tooltip'),
                                    style: AppTextStyles.bodyMedium
                                        .copyWith(color: textColor),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    loc.get('rty'),
                                    
                                    style: AppTextStyles.labelSmall
                                        .copyWith(color: subColor),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: AppColors.grey300, size: 20),
                          ],
                        ),
                      ),
                    ),

                    Divider(height: 1, color: divColor),
                    const SupportMenuItem(),
                    Divider(height: 1, color: divColor),
                    const TermsMenuItem(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _glassCard({
    required Color cardBg,
    required Color cardBorder,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}