import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../main.dart';

class LanguageSection extends StatefulWidget {
  const LanguageSection({super.key});

  @override
  State<LanguageSection> createState() => _LanguageSectionState();
}

class _LanguageSectionState extends State<LanguageSection> {
  @override
  Widget build(BuildContext context) {
    final provider = LocaleScope.of(context);
    final selected = provider.locale.languageCode;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final dividerColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Row(
              children: [
                Icon(Icons.language, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text('Тил / Язык', style: AppTextStyles.headingSmall),
              ],
            ),
          ),
          _option(provider, selected, 'ky', 'Кыргызча', '🇰🇬', dividerColor),
          Divider(height: 1, color: dividerColor),
          _option(provider, selected, 'ru', 'Орусча', '🇷🇺', dividerColor),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _option(
    dynamic provider,
    String selected,
    String code,
    String title,
    String flag,
    Color dividerColor,
  ) {
    final isSelected = selected == code;
    return InkWell(
      onTap: () async {
        await provider.setLocale(code);
        if (mounted) setState(() {});
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: AppTextStyles.bodyMedium)),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primary : AppColors.grey300,
            ),
          ],
        ),
      ),
    );
  }
}