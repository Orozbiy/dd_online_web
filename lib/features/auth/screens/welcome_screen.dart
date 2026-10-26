import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/auth_service.dart';
import '../../home/screens/home_screen.dart';
import '../../seller/screens/seller_entrance_screen.dart';
import '../../seller/screens/seller_login_screen.dart';
import '../../../core/supabase_client.dart';
import '../../../services/notification_service.dart';

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
  bool _navigated = false;
  StreamSubscription<AuthState>? _authSub;
  Timer? _loadingTimeoutTimer;

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
        if (!mounted || _navigated) return;
        _navigated = true;
        _loadingTimeoutTimer?.cancel();

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );

        final user = AuthService.instance.currentUser;
        if (user != null) {
          // ВЕБ: push токен уруксат берилгенден кийин (Орнотуулар → Билдирүүлөр)
          if (!kIsWeb) NotificationService().saveMyToken();
          AuthService.instance.syncProfile();
          _checkAndFixSellerStatus(user.id);
        }
      } else if (data.event == AuthChangeEvent.signedOut) {
        if (mounted) {
          _loadingTimeoutTimer?.cancel();
          setState(() {
            _isLoading = false;
            _navigated = false;
          });
        }
      }
    });
  }

  Future<void> _checkAndFixSellerStatus(String userId) async {
    try {
      final profile = await supabase
          .from('profiles')
          .select('role, seller_status')
          .eq('id', userId)
          .maybeSingle();
      final role = profile?['role'] as String?;
      final sellerStatus = profile?['seller_status'] as String?;
      if (role != 'seller' && sellerStatus != null) {
        await supabase
            .from('profiles')
            .update({'seller_status': null}).eq('id', userId);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _loadingTimeoutTimer?.cancel();
    _controller.dispose();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _navigated = false;
    });

    _loadingTimeoutTimer?.cancel();

    // Веб жагында браузер redirect болот — 60 сек таймер мобил үчүн гана
    if (!kIsWeb) {
      _loadingTimeoutTimer = Timer(const Duration(seconds: 60), () {
        if (mounted && _isLoading) {
          setState(() => _isLoading = false);
          _showSnack(
            '${AppLocalizations.of(context).get('login_error')}: '
            'Убакыт бүттү. Кайра аракет кылыңыз.',
            isError: true,
          );
        }
      });
    }

    try {
      await AuthService.instance.signInWithGoogle();
      // Веб: бул жерге жетпейт (redirect). Мобил: _authSub HomeScreen'га багыттайт
    } catch (e) {
      _loadingTimeoutTimer?.cancel();
      if (mounted) {
        setState(() => _isLoading = false);
        final loc = AppLocalizations.of(context);
        _showSnack('${loc.get('login_error')}: $e', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
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
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── СУЛУУ ФОНДУК ГРАДИЕНТ ──
          const Positioned.fill(child: _AnimatedBackground()),

          // ── КОНТЕНТ ──
          SafeArea(
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
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD97706), Color(0xFFEF4444)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD97706).withValues(alpha: 0.45),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.storefront_rounded,
                            color: Colors.white, size: 50),
                      ),

                      const SizedBox(height: 28),

                      // ── АТАЛЫШ ──
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFFFB347), Color(0xFFFF4444)],
                        ).createShader(bounds),
                        child: const Text(
                          'DD Online',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Subtitle — жарым өткөрүмдүү
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.20),
                              ),
                            ),
                            child: Text(
                              loc.get('welcome_title'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),

                      const Spacer(flex: 2),

                      // ── GOOGLE КИРҮҮ БАСКЫЧЫ (GLASSMORPHISM) ──
                      _buildGoogleButton(loc),

                      const SizedBox(height: 16),

                      // Веб: Google барагына багыттоо убагында түшүндүрмө
                      if (_isLoading && kIsWeb)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Google барагы ачылды, аккаунтту тандаңыз...',
                            style: TextStyle(color: Colors.white60, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // Terms жазуу
                      Text(
                        loc.get('sign_in_terms'),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      // ── САТУУЧУ КИРҮҮСҮ (веб: кирбей туруп эле сатуучуга өтүү) ──
                      if (kIsWeb) ...[
                        const SizedBox(height: 16),
                        _buildSellerButton(loc),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerButton(AppLocalizations loc) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SellerEntranceScreen()),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.storefront_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text(loc.get('seller_login'),
                    style: AppTextStyles.headingSmall
                        .copyWith(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton(AppLocalizations loc) {
    // Windows — сатуучу логин
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SellerLoginScreen())),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.5,
                ),
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
          ),
        ),
      );
    }

    // ── Google баскычы — GLASSMORPHISM ──
    return GestureDetector(
      onTap: _isLoading ? null : _handleGoogleSignIn,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _isLoading ? 0.10 : 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.40),
                width: 1.5,
              ),
            ),
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _GoogleLogo(),
                      const SizedBox(width: 12),
                      Text(
                        loc.get('sign_in_google'),
                        style: AppTextStyles.headingSmall
                            .copyWith(color: Colors.white),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// АНИМАЦИЯЛАНГАН ФОНДУК ГРАДИЕНТ
// ══════════════════════════════════════════════════════
class _AnimatedBackground extends StatefulWidget {
  const _AnimatedBackground();

  @override
  State<_AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final t = _anim.value;
        return CustomPaint(
          painter: _BgPainter(t),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Негизги кара-күрөң фон ──
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D0F1A),
            Color(0xFF12103A),
            Color(0xFF0D1525),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // ── Жылып жаткан жарык тегерек 1 (кызгылт-сары) ──
    final cx1 = w * (0.15 + 0.20 * math.sin(t * math.pi));
    final cy1 = h * (0.20 + 0.15 * math.cos(t * math.pi * 1.3));
    canvas.drawCircle(
      Offset(cx1, cy1),
      w * 0.55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFD97706).withValues(alpha: 0.35),
            const Color(0xFFD97706).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(
            center: Offset(cx1, cy1), radius: w * 0.55)),
      );

    // ── Жылып жаткан жарык тегерек 2 (кызыл) ──
    final cx2 = w * (0.75 + 0.15 * math.cos(t * math.pi * 0.9));
    final cy2 = h * (0.65 + 0.20 * math.sin(t * math.pi * 1.1));
    canvas.drawCircle(
      Offset(cx2, cy2),
      w * 0.50,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFEF4444).withValues(alpha: 0.28),
            const Color(0xFFEF4444).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(
            center: Offset(cx2, cy2), radius: w * 0.50)),
    );

    // ── Жылып жаткан жарык тегерек 3 (кок) ──
    final cx3 = w * (0.50 + 0.10 * math.sin(t * math.pi * 1.7));
    final cy3 = h * (0.45 + 0.10 * math.cos(t * math.pi * 0.8));
    canvas.drawCircle(
      Offset(cx3, cy3),
      w * 0.40,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF3D2080).withValues(alpha: 0.30),
            const Color(0xFF3D2080).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(
            center: Offset(cx3, cy3), radius: w * 0.40)),
    );

    // ── Майда жылдыздар ──
    final rng = math.Random(42);
    for (int i = 0; i < 55; i++) {
      final sx = rng.nextDouble() * w;
      final sy = rng.nextDouble() * h;
      final sr = rng.nextDouble() * 1.2 + 0.3;
      // жылдыз жаркылдоо
      final blink = (math.sin(t * math.pi * 2 + i * 1.3) + 1) / 2;
      canvas.drawCircle(
        Offset(sx, sy),
        sr,
        Paint()..color = Colors.white.withValues(alpha: 0.20 + blink * 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

// ══════════════════════════════════════════════════════
// GOOGLE ЛОГО
// ══════════════════════════════════════════════════════
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

    // Google түстөрү ак фонго ылайыкталган жарык версия
    drawArc(-90, 90,  const Color(0xFF6EA8FE)); // көк
    drawArc(0,   90,  const Color(0xFF57D079)); // жашыл
    drawArc(90,  90,  const Color(0xFFFFDA6A)); // сары
    drawArc(180, 90,  const Color(0xFFFF7F7F)); // кызыл
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}