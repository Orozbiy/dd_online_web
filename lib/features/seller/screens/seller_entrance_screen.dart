import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import 'seller_login_screen.dart';
import 'seller_register_screen.dart';

class SellerEntranceScreen extends StatelessWidget {
  const SellerEntranceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor    = isDark ? const Color(0xFF121212) : Colors.white;
    final appBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final arrowColor  = isDark ? Colors.white : AppColors.black;
    final titleColor  = isDark ? Colors.white : AppColors.black;
    final headColor   = isDark ? Colors.white : AppColors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back, color: arrowColor),
        ),
        title: Text(loc.get('seller_title'),
            style: AppTextStyles.headingMedium.copyWith(color: titleColor)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // ── Лого ──
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
                child: const Center(child: Text('🏪', style: TextStyle(fontSize: 56))),
              ),
              const SizedBox(height: 28),

              Text(
                loc.get('shop_title'),
                style: AppTextStyles.headingLarge.copyWith(color: headColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                loc.get('shop_desc'),
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500, height: 1.5),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),

              // ── Кирүү баскычы ──
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SellerLoginScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(loc.get('login'),
                      style: AppTextStyles.labelLarge.copyWith(color: Colors.white, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 14),

              // ── Катталуу баскычы ──
              SizedBox(
                width: double.infinity, height: 54,
                child: OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SellerRegisterScreen()),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(loc.get('register'),
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary, fontSize: 16)),
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
