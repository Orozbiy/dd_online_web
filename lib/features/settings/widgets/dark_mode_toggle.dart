import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/theme_provider.dart';
import '../../../main.dart';

class DarkModeToggle extends StatelessWidget {
  const DarkModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = ThemeScope.of(context);
    final loc      = AppLocalizations.of(context);
    final current  = provider.mode;
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    IconData currentIcon() {
      switch (current) {
        case AppThemeMode.light:  return Icons.wb_sunny_outlined;
        case AppThemeMode.dark:   return Icons.dark_mode_outlined;
        case AppThemeMode.system: return Icons.settings_suggest_outlined;
      }
    }

    String currentLabel() {
      switch (current) {
        case AppThemeMode.light:  return loc.get('theme_light');
        case AppThemeMode.dark:   return loc.get('theme_dark');
        case AppThemeMode.system: return loc.get('theme_system');
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.contrast, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(loc.get('theme_mode'), style: AppTextStyles.bodyMedium),
          ),

          // ── Учурдагы режим ──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(currentIcon(), size: 16, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                currentLabel(),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(width: 4),

          // ── 3 точка баскычы (Тунук Меню менен) ──
          PopupMenuButton<AppThemeMode>(
            onSelected: (mode) => provider.setMode(mode),
            color: isDark
                ? Colors.black.withValues(alpha: 0.65)
                : Colors.white.withValues(alpha: 0.75),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.50),
              ),
            ),
            icon: Icon(
              Icons.more_vert,
              size: 20,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            itemBuilder: (_) => [
              _buildItem(
                mode: AppThemeMode.light,
                icon: Icons.wb_sunny_outlined,
                label: loc.get('theme_light'),
                current: current,
                isDark: isDark,
              ),
              _buildItem(
                mode: AppThemeMode.dark,
                icon: Icons.dark_mode_outlined,
                label: loc.get('theme_dark'),
                current: current,
                isDark: isDark,
              ),
              _buildItem(
                mode: AppThemeMode.system,
                icon: Icons.settings_suggest_outlined,
                label: loc.get('theme_system'),
                current: current,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<AppThemeMode> _buildItem({
    required AppThemeMode mode,
    required IconData icon,
    required String label,
    required AppThemeMode current,
    required bool isDark,
  }) {
    final isSelected = current == mode;
    final color = isSelected
        ? AppColors.primary
        : (isDark ? Colors.white70 : Colors.black87);

    return PopupMenuItem<AppThemeMode>(
      value: mode,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(Icons.check, size: 16, color: AppColors.primary),
          ],
        ],
      ),
    );
  }
}