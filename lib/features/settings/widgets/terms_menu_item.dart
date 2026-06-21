import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../screens/terms_screen.dart';

class TermsMenuItem extends StatelessWidget {
  const TermsMenuItem({super.key});

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.grey600;
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.privacy_tip_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(loc.get('terms'),
                style: AppTextStyles.bodyMedium.copyWith(color: textColor))),
            const Icon(Icons.chevron_right, color: AppColors.grey300, size: 20),
          ],
        ),
      ),
    );
  }
}