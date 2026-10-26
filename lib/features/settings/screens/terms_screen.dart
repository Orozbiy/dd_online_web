import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7),
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
          loc.get('terms_title'),
          style: AppTextStyles.headingSmall.copyWith(color: textColor),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.of(context).padding.top + kToolbarHeight + 12,
          16,
          40,
        ),
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

            // ── Байланыш блогу ──
            const SizedBox(height: 4),
            _glassCard(
              isDark: isDark,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _contactRow(context, Icons.business_outlined, 'DD Online'),
                    const SizedBox(height: 10),
                    _contactRow(context, Icons.email_outlined, 'support@ddonline.kg'),
                    const SizedBox(height: 10),
                    _contactRow(context, Icons.phone_outlined, '+996 (XXX) XX-XX-XX'),
                    const SizedBox(height: 10),
                    _contactRow(context, Icons.location_on_outlined, loc.get('terms_contact_addr')),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Text(
              loc.get('terms_disclaimer'),
              style: AppTextStyles.labelSmall.copyWith(
                  color: isDark ? AppColors.grey500 : AppColors.grey400),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.black;
    final bodyColor = isDark ? const Color(0xFFCCCCCC) : AppColors.black;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _glassCard(
        isDark: isDark,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.headingSmall.copyWith(color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: AppTextStyles.bodyMedium.copyWith(
                  height: 1.5,
                  color: bodyColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassCard({required bool isDark, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.80),
              width: 1,
            ),
          ),
          child: child,
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