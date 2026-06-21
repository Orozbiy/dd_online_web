import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../main.dart';

class DarkModeToggle extends StatelessWidget {
  const DarkModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final provider = ThemeScope.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.dark_mode_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(loc.get('dark_mode'), style: AppTextStyles.bodyMedium)),
          Switch(
            value: provider.isDark,
            onChanged: (val) => provider.setDark(val),
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}