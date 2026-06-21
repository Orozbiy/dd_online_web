import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../home/screens/home_screen.dart';
import 'seller_login_screen.dart';
import '../../../core/supabase_client.dart';

class SellerPendingScreen extends StatelessWidget {
  const SellerPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor    = isDark ? const Color(0xFF121212) : Colors.white;
    final titleColor = isDark ? Colors.white : AppColors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD97706), Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD97706).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(child: Text('⏳', style: TextStyle(fontSize: 56))),
              ),
              const SizedBox(height: 28),
              Text(
                loc.get('pending_title'),
                style: AppTextStyles.headingLarge.copyWith(color: titleColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                loc.get('pending_desc'),
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity, height: 54,
                child: OutlinedButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    loc.get('pending_btn_home'),
                    style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class SellerRejectedScreen extends StatelessWidget {
  const SellerRejectedScreen({super.key});

  void _logout(BuildContext context) async {
    await supabase.auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SellerLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor    = isDark ? const Color(0xFF121212) : Colors.white;
    final titleColor = isDark ? Colors.white : AppColors.black;
    final iconBg     = isDark
        ? AppColors.error.withValues(alpha: 0.2)
        : AppColors.error.withValues(alpha: 0.1);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Center(child: Text('❌', style: TextStyle(fontSize: 56))),
              ),
              const SizedBox(height: 28),
              Text(
                loc.get('rejected_title'),
                style: AppTextStyles.headingLarge.copyWith(color: titleColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                loc.get('rejected_desc'),
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity, height: 54,
                child: OutlinedButton(
                  onPressed: () => _logout(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    loc.get('sign_out'),
                    style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}