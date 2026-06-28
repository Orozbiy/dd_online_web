import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/auth_service.dart';
import '../../home/screens/home_screen.dart';
import '../../seller/screens/seller_login_screen.dart';
import '../../../core/supabase_client.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _isLoading = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();

    _authSub = AuthService.instance.authStateChanges.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn) {

        // ✅ ТЕЗДЕТҮҮ: syncProfile() күтпөй дароо HomeScreen'ге өт
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );

        // ✅ Фондо: profile sync + role текшерүү (экранды ТОКТОТПОЙТ)
        final user = AuthService.instance.currentUser;
        if (user != null) {
          // await жок — фондо иштейт
          AuthService.instance.syncProfile();

          try {
            final profile = await supabase
                .from('profiles')
                .select('role, seller_status')
                .eq('id', user.id)
                .maybeSingle();
            final role = profile?['role'] as String?;
            final sellerStatus = profile?['seller_status'] as String?;
            if (role != 'seller' && sellerStatus != null) {
              await supabase
                  .from('profiles')
                  .update({'seller_status': null}).eq('id', user.id);
            }
          } catch (_) {}
        }

      } else if (data.event == AuthChangeEvent.signedOut && mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signInWithGoogle();
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final loc = AppLocalizations.of(context);
        _showSnack('${loc.get('login_error')}: $e', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // ── ЛОГОТИП ──
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD97706), Color(0xFFEF4444)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(
                        color: const Color(0xFFD97706).withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )],
                    ),
                    child: const Icon(Icons.storefront_rounded,
                        color: Colors.white, size: 44),
                  ),

                  const SizedBox(height: 24),

                  // ── АТАЛЫШ ──
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFD97706), Color(0xFFEF4444)],
                    ).createShader(bounds),
                    child: const Text(
                      'DD Online',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    loc.get('welcome_title'),
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.grey500),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(flex: 2),

                  // ── КИРҮҮ БАСКЫЧЫ ──
                  _buildGoogleButton(loc, isDark),

                  const SizedBox(height: 16),

                  Text(
                    loc.get('sign_in_terms'),
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.grey400),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton(AppLocalizations loc, bool isDark) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SellerLoginScreen())),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Text(loc.get('seller_login'),
                  style: AppTextStyles.headingSmall
                      .copyWith(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    final btnColor  = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final btnBorder = isDark ? const Color(0xFF3A3A3A) : AppColors.grey200;
    final textColor = isDark ? Colors.white : AppColors.black;

    return GestureDetector(
      onTap: _isLoading ? null : _handleGoogleSignIn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: btnColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: btnBorder, width: 1.5),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )],
        ),
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _GoogleLogo(),
                  const SizedBox(width: 12),
                  Text(loc.get('sign_in_google'),
                      style: AppTextStyles.headingSmall
                          .copyWith(color: textColor)),
                ],
              ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 4.0;
    final rect =
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    void drawArc(double startDeg, double sweepDeg, Color color) {
      canvas.drawArc(
        rect,
        startDeg * 3.1415926535 / 180,
        sweepDeg * 3.1415926535 / 180,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
    }

    drawArc(-90, 90, const Color(0xFF4285F4));
    drawArc(0,   90, const Color(0xFF34A853));
    drawArc(90,  90, const Color(0xFFFBBC05));
    drawArc(180, 90, const Color(0xFFEA4335));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
