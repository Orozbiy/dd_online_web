// lib/features/seller/screens/seller_entrance_screen.dart
import 'dart:ui';
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── ФОН ГРАДИЕНТ ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF0D0F1A),
                          Color(0xFF12103A),
                          Color(0xFF0D1525),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: [0.0, 0.5, 1.0],
                      )
                    : const LinearGradient(
                        colors: [
                          Color(0xFFF8F0E8),
                          Color(0xFFFFF5EE),
                          Color(0xFFF0E8FF),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              ),
            ),
          ),

          // ── ОРНАМЕНТ ЧӨЙРӨЛӨР ──
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.12 : 0.10),
              ),
            ),
          ),
          Positioned(
            bottom: 80, left: -80,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.08 : 0.07),
              ),
            ),
          ),

          // ── APPBAR (айнек) ──
          Positioned(
            top: 0, left: 0, right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: kToolbarHeight + MediaQuery.of(context).padding.top,
                  color: Colors.transparent,
                  child: SafeArea(
                    bottom: false,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 4,
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              color: isDark ? Colors.white : AppColors.black,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        Text(
                          loc.get('seller_title'),
                          style: AppTextStyles.headingMedium.copyWith(
                            color: isDark ? Colors.white : AppColors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── МАЗМУН ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // ── Лого (айнек шар) ──
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD97706), Color(0xFFEF4444)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD97706).withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.asset(
                            'assets/images/seller_logo.jpg',
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.storefront_rounded,
                                size: 62,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    loc.get('shop_title'),
                    style: AppTextStyles.headingLarge.copyWith(
                      color: isDark ? Colors.white : AppColors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    loc.get('shop_desc'),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.55)
                          : AppColors.grey500,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(flex: 3),

                  // ── КИРҮҮ — градиент + айнек ──
                  _GlassButton(
                    label: loc.get('login'),
                    isPrimary: true,
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SellerLoginScreen()),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── КАТТАЛУУ — айнек outline ──
                  _GlassButton(
                    label: loc.get('register'),
                    isPrimary: false,
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SellerRegisterScreen()),
                    ),
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// GLASS BUTTON
// ══════════════════════════════════════════════════════
class _GlassButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final bool isDark;
  final VoidCallback onTap;

  const _GlassButton({
    required this.label,
    required this.isPrimary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: isPrimary
                  ? const LinearGradient(
                      colors: [Color(0xFFD97706), Color(0xFFEF4444)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: isPrimary
                  ? null
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.55)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPrimary
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFD97706).withValues(alpha: 0.60),
                width: 1.5,
              ),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: const Color(0xFFD97706).withValues(alpha: 0.30),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  color: isPrimary
                      ? Colors.white
                      : const Color(0xFFD97706),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}