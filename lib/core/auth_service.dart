import 'package:flutter/foundation.dart'; // kIsWeb үчүн
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';
import '../services/notification_service.dart';

/// Google Sign-In аркылуу Supabase Auth'ка кирүү/чыгуу логикасы.
///
/// Браузер (Custom Tab) аркылуу Google account picker ачылат,
/// андан кийин deep link менен колдонмого кайтарылып, Supabase
/// сессиясы автоматтык түзүлөт.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Колдонмонун deep link redirect URL'и.
  /// AndroidManifest.xml'деги intent-filter жана Supabase Dashboard'дагы
  /// Redirect URLs менен так дал келиши керек.
  static const String _redirectUrl = 'io.supabase.ddonline://login-callback/';

  /// Веб үчүн redirect URL.
static const String _webRedirectUrl = 'https://dd-online-web.web.app/auth/callback';

  /// Учурдагы Supabase колдонуучусу (же null).
  User? get currentUser => supabase.auth.currentUser;

  /// Колдонуучу кирген-кирбегенин текшерүү.
  bool get isSignedIn => currentUser != null;

  /// Колдонуучунун auth абалынын өзгөрүүлөрүн угуу
  /// (мис. OAuth callback аркылуу кирген учурда).
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  /// Google аккаунту аркылуу Supabase'ге кирүү.
  ///
  /// Системалык браузерде Google account picker ачылат.
  /// Натыйжа [authStateChanges] аркылуу [AuthChangeEvent.signedIn]
  /// окуясы катары келет.
  Future<void> signInWithGoogle() async {
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? _webRedirectUrl : _redirectUrl,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        queryParams: const {'prompt': 'select_account'},
      );
    } catch (e) {
      throw AuthException('Кирүүдө ката кетти: $e');
    }
  }

  /// Колдонуучу кирген соң профилди акыркы Google маалыматтары
  /// менен синхрондоо (аты, сүрөтү, email).
  ///
  /// [authStateChanges] боюнча signedIn окуясынан кийин чакыруу керек.
  Future<void> syncProfile() async {
    final user = currentUser;
    if (user == null) return;

    final identity =
        user.identities?.where((i) => i.provider == 'google').firstOrNull;
    final data = identity?.identityData;

    try {
      await supabase.from('profiles').update({
        'full_name': data?['full_name'] ?? data?['name'],
        'avatar_url': data?['avatar_url'] ?? data?['picture'],
        'email': user.email,
        'last_active_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    } catch (_) {
      // Профиль табылбаса (trigger кечиксе), унчукпайбыз —
      // кийинки кирүүдө синхрондолот.
    }

    // ✅ ОҢДОО: Google менен кирген соң FCM токенди сакта
    // Бул болбосо сатуучу жооп жазганда алуучуга уведомления жетпейт
    if (!kIsWeb) {
      await NotificationService().saveMyToken();
    }
  }

  /// Колдонуучунун ролун (customer/seller/admin) алуу.
  Future<String> getUserRole() async {
    final user = currentUser;
    if (user == null) return 'customer';

    try {
      final data = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();
      return data['role'] as String? ?? 'customer';
    } catch (_) {
      return 'customer';
    }
  }

  /// Тиркемеден чыгуу.
  ///
  /// Чыгаар алдында FCM push токенди 'push_tokens' таблицасынан
  /// өчүрөт, антпесе эски колдонуучунун токенине жаны колдонуучунун
  /// push-билдирүүлөрү жетип кетет.
  Future<void> signOut() async {
    if (!kIsWeb) {
      await NotificationService().clearMyToken();
    }
    await supabase.auth.signOut();
  }
}