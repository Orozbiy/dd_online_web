import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';

/// "Эрежелер жана купуялык саясаты" — толук маалымат экраны.
/// Эки тилди колдойт: кыргызча (ky) жана орусча (ru).
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.black,
        elevation: 0,
        title: Text(loc.get('terms_title'), style: AppTextStyles.headingSmall),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(context, loc.get('terms_s1_title'), loc.get('terms_s1_body')),
            _section(context, loc.get('terms_s2_title'), loc.get('terms_s2_body')),
            _section(context, loc.get('terms_s3_title'), loc.get('terms_s3_body')),
            _section(context, loc.get('terms_s4_title'), loc.get('terms_s4_body')),
            _section(context, loc.get('terms_s5_title'), loc.get('terms_s5_body')),
            _section(context, loc.get('terms_s6_title'), loc.get('terms_s6_body')),
            _section(context, loc.get('terms_s7_title'), loc.get('terms_s7_body')),
            _section(context, loc.get('terms_s8_title'), loc.get('terms_s8_body')),
            _section(context, loc.get('terms_s9_title'), loc.get('terms_s9_body')),
            const SizedBox(height: 4),
            _contactRow(context, Icons.business_outlined, 'DD Online'),
            const SizedBox(height: 8),
            _contactRow(context, Icons.email_outlined, 'support@ddonline.kg'),
            const SizedBox(height: 8),
            _contactRow(context, Icons.phone_outlined, '+996 (XXX) XX-XX-XX'),
            const SizedBox(height: 8),
            _contactRow(context, Icons.location_on_outlined, loc.get('terms_contact_addr')),
            const SizedBox(height: 24),
            Text(
              loc.get('terms_disclaimer'),
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey400),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.headingSmall.copyWith(
                color: isDark ? Colors.white : AppColors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: AppTextStyles.bodyMedium.copyWith(
                height: 1.5,
                color: isDark ? const Color(0xFFCCCCCC) : AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactRow(BuildContext context, IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? Colors.white : AppColors.black,
            ),
          ),
        ),
      ],
    );
  }
}