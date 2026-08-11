import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/theme/app_theme.dart';
import 'core/supabase_client.dart';
import 'core/utils/favorites_manager.dart';
import 'core/active_status_tracker.dart';
import 'core/locale_provider.dart';
import 'core/app_localizations.dart';
import 'core/theme_provider.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/cart/utils/cart_manager.dart';
import 'features/home/screens/home_screen.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

import 'core/update_checker_stub.dart'
    if (dart.library.html) 'core/update_checker_stub.dart' as update_checker;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('🔔 Фондо: ${message.notification?.title}');
}

// ──────────────────────────────────────────────────────
// MAIN
// ──────────────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 MAIN (веб: $kIsWeb)');

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // ✅ Supabase — дайыма күтөбүз (тез)
  await SupabaseInit.init();

  if (kIsWeb) {
    // ✅ ВЕБ: Firebase'ди ФОНДО иштет — загрузканы токтотпойт
    _initFirebase().catchError((e) => debugPrint('⚠️ Firebase web: $e'));
  } else {
    // ✅ МОБИЛ: Firebase'ди күтөбүз — push notification үчүн керек
    await _initFirebase();
    await NotificationService().handleInitialMessage();
  }

  await CartManager.instance.loadFromPrefs();
  await FavoritesManager().loadFromPrefs();

  unawaited(NotificationService().saveMyToken());

  runApp(const ActiveStatusTracker(child: DDOnlineApp()));
}

Future<void> _initFirebase() async {
  try {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {}
    await NotificationService().init();
  } catch (e) {
    debugPrint('⚠️ Firebase init ката: $e');
  }
}

void unawaited(Future<void> future) {
  future.catchError((e) => debugPrint('⚠️ $e'));
}

// ══════════════════════════════════════════════════════
// APP
// ══════════════════════════════════════════════════════
class DDOnlineApp extends StatefulWidget {
  const DDOnlineApp({super.key});
  @override
  State<DDOnlineApp> createState() => _DDOnlineAppState();
}

class _DDOnlineAppState extends State<DDOnlineApp> {
  final _localeProvider = LocaleProvider();
  final _themeProvider  = ThemeProvider();

  @override
  void initState() {
    super.initState();
    _localeProvider.loadSavedLocale();
    _localeProvider.addListener(() => setState(() {}));
    _themeProvider.loadSavedTheme();
    _themeProvider.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _localeProvider.removeListener(() => setState(() {}));
    _localeProvider.dispose();
    _themeProvider.removeListener(() => setState(() {}));
    _themeProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      provider: _themeProvider,
      isDark:   _themeProvider.isDark,
      child: LocaleScope(
        provider: _localeProvider,
        locale: _localeProvider.locale,
        child: MaterialApp(
          title:                      'DD Online',
          debugShowCheckedModeBanner:  false,
          theme:                       AppTheme.lightTheme,
          darkTheme:                   AppTheme.darkTheme,
          themeMode:                   _themeProvider.themeMode,
          navigatorKey:                navigatorKey,
          locale:                      _localeProvider.locale,
          supportedLocales: const     [Locale('ky'), Locale('ru')],
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashRouter(),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// THEME SCOPE
// ══════════════════════════════════════════════════════
class ThemeScope extends InheritedWidget {
  final ThemeProvider provider;
  final bool isDark;
  const ThemeScope({
    super.key,
    required this.provider,
    required this.isDark,
    required super.child,
  });
  static ThemeProvider of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()!.provider;
  @override
  bool updateShouldNotify(ThemeScope old) => old.isDark != isDark;
}

// ══════════════════════════════════════════════════════
// LOCALE SCOPE
// ══════════════════════════════════════════════════════
class LocaleScope extends InheritedWidget {
  final LocaleProvider provider;
  final Locale locale;
  const LocaleScope({
    super.key,
    required this.provider,
    required this.locale,
    required super.child,
  });
  static LocaleProvider of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()!.provider;
  @override
  bool updateShouldNotify(LocaleScope old) => old.locale != locale;
}

// ══════════════════════════════════════════════════════
// SPLASH ROUTER
// ══════════════════════════════════════════════════════
class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});
  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  bool    _checking     = true;
  Widget? _targetScreen;

  @override
  void initState() {
    super.initState();
    _determineScreen();
    if (kIsWeb) {
      _handleWebUrl();
    }
  }

  void _handleWebUrl() {
    try {
      final uri      = Uri.base;
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments[0] == 'product') {
        NotificationService.pendingProductId = segments[1];
      }
      final chatId = uri.queryParameters['chat'];
      if (chatId != null && chatId.isNotEmpty) {
        NotificationService.pendingChatId = chatId;
      }
    } catch (e) {
      debugPrint('⚠️ Web URL parse ката: $e');
    }
  }

  Future<void> _determineScreen() async {
    final prefs    = await SharedPreferences.getInstance();
    final langCode = prefs.getString('app_locale') ?? 'ky';

    _targetScreen = await _getTargetScreen();
    if (mounted) setState(() => _checking = false);

    // ── Pending chat ──
    final pendingChat = NotificationService.pendingChatId;
    if (pendingChat != null) {
      NotificationService.pendingChatId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 600));
        NotificationService().navigateToChatPublic(pendingChat);
      });
    }

    // ── Pending product ──
    final pendingProduct = NotificationService.pendingProductId;
    if (pendingProduct != null) {
      NotificationService.pendingProductId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 600));
        NotificationService().navigateToProductPublic(pendingProduct);
      });
    }

    // ── Update checker — мобайл гана ──
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 300));
        final ctx = navigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) return;
        await update_checker.check(ctx, langCode);
      });
    }
  }

  Future<Widget> _getTargetScreen() async {
    final user = supabase.auth.currentSession?.user;
    if (user != null) {
      unawaited(NotificationService().saveMyToken());
      return const HomeScreen();
    }
    return const WelcomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const _SplashScreen();
    return AnimatedSwitcher(
      duration:          const Duration(milliseconds: 300),
      switchInCurve:     Curves.easeOut,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _targetScreen!,
    );
  }
}

// ══════════════════════════════════════════════════════
// SPLASH SCREEN
// ══════════════════════════════════════════════════════
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scaleAnim;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD97706), Color(0xFFEF4444)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      color: Colors.white, size: 52),
                ),
                const SizedBox(height: 20),
                const Text(
                  'DD Online',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Дордойдун онлайн базары',
                  style: TextStyle(color: Color(0xFF888888), fontSize: 13),
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(
                    color: Color(0xFFD97706),
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}