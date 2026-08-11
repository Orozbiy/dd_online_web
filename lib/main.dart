import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/theme/app_theme.dart';
import 'core/supabase_client.dart';
import 'core/utils/favorites_manager.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/cart/utils/cart_manager.dart';
import 'features/home/screens/home_screen.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'core/active_status_tracker.dart';
import 'package:flutter/foundation.dart';
import 'core/locale_provider.dart';
import 'core/app_localizations.dart';
import 'core/theme_provider.dart';
import 'core/update_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (defaultTargetPlatform == TargetPlatform.windows) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('🔔 Фондо билдирүү: ${message.notification?.title} — ${message.notification?.body}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 MAIN БАШТАЛДЫ');

  if (defaultTargetPlatform != TargetPlatform.windows) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  debugPrint('🚀 Supabase init...');
  await SupabaseInit.init();

  debugPrint('🚀 Firebase init...');
  await _initFirebase();

  debugPrint('🚀 handleInitialMessage...');
  await NotificationService().handleInitialMessage();

  debugPrint('🚀 Cart & Favorites...');
  await CartManager.instance.loadFromPrefs();
  await FavoritesManager().loadFromPrefs();

  debugPrint('🚀 saveMyToken...');
  unawaited(NotificationService().saveMyToken());

  debugPrint('🚀 runApp...');
  runApp(const ActiveStatusTracker(child: DDOnlineApp()));
}

Future<void> _initFirebase() async {
  try {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('🔥 Firebase мурда init болгон, улантабыз');
    }
    await NotificationService().init();
  } catch (e) {
    debugPrint('⚠️ Firebase init ката: $e');
  }
}

void unawaited(Future<void> future) {
  future.catchError((e) => debugPrint('⚠️ Untracked error: $e'));
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
        locale:   _localeProvider.locale,
        child: MaterialApp(
          title:                     'DD Online',
          debugShowCheckedModeBanner: false,
          theme:                     AppTheme.lightTheme,
          darkTheme:                 AppTheme.darkTheme,
          themeMode:                 _themeProvider.themeMode,
          navigatorKey:              navigatorKey,
          locale:                    _localeProvider.locale,
          supportedLocales: const   [Locale('ky'), Locale('ru')],
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

  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _determineScreen();
    _listenDeepLinks();
  }

  void _listenDeepLinks() {
    _appLinks.uriLinkStream.listen((uri) {
      debugPrint('🔗 Deep link келди: $uri');
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'product') {
      final productId = uri.pathSegments[1];
      debugPrint('🔗 Product deep link: $productId');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService().navigateToProductPublic(productId);
      });
    }
  }

  Future<void> _determineScreen() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('🔗 Initial deep link: $initialUri');
        if (initialUri.pathSegments.length >= 2 &&
            initialUri.pathSegments[0] == 'product') {
          NotificationService.pendingProductId = initialUri.pathSegments[1];
        }
      }
    } catch (_) {}

    // ✅ prefs'ти МУРДА окуйбуз
    final prefs = await SharedPreferences.getInstance();
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

    // ✅ версия текшерүү
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      await UpdateChecker.check(ctx, langCode);
    });
  }
Future<Widget> _getTargetScreen() async {
  final user = supabase.auth.currentSession?.user;
  if (user != null) {
    // ✅ Колдонуучу кирип турса — токенди дайыма жаңырт
    // (колдонмо өчүп-күйгөндө, токен эскирип же жок болуп калышы мүмкүн)
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
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width:  96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD97706), Color(0xFFEF4444)],
                          begin:  Alignment.topLeft,
                          end:    Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size:  46,
                      ),
                    ),
                    Positioned(
                      bottom: -10,
                      right:  -10,
                      child: Container(
                        width:  34,
                        height: 34,
                        decoration: BoxDecoration(
                          color:        const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFD97706),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          color: Color(0xFFD97706),
                          size:  18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Text(
                  'DD Online',
                  style: TextStyle(
                    color:         Colors.white,
                    fontSize:      28,
                    fontWeight:    FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Дордой базары',
                  style: TextStyle(
                    color:    Color(0xFF888888),
                    fontSize: 14,
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