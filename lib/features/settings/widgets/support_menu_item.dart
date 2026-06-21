import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';

class SupportMenuItem extends StatelessWidget {
  const SupportMenuItem({super.key});

  static const String _supportEmail = 'orozbijhodzebekov@gmail.com';

  Future<void> _openSupport(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final emailUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: 'subject=${Uri.encodeComponent('DD Online - ${loc.get('support')}')}'
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(loc.get('email_not_found')),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return InkWell(
      onTap: () => _openSupport(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.support_agent_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(loc.get('support'), style: AppTextStyles.bodyMedium)),
            const Icon(Icons.chevron_right, color: AppColors.grey300, size: 20),
          ],
        ),
      ),
    );
  }
}
