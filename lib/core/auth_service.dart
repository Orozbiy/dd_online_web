import 'package:dd_online/features/admin/widgets/admin_notification_sender.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

/// Google Sign-In аркылуу Supabase Auth'ка кирүү/чыгуу логикасы.
///
/// Нативдүү Google account picker ачылат (браузер эмес),
/// андан кийин Supabase сессиясы түзүлөт.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Учурдагы Supabase колдонуучусу (же null).
  User? get currentUser => supabase.auth.currentUser;

  /// Колдонуучу кирген-кирбегенин текшерүү.
  bool get isSignedIn => currentUser != null;

  /// Колдонуучунун auth абалынын өзгөрүүлөрүн угуу.
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  /// Google аккаунту аркылуу Supabase'ге кирүү.
  ///
  /// Нативдүү Google account picker ачылат — Android да, iOS до.
  /// Браузерге өтпөйт, сразу телефондогу аккаунттар чыгат.
  Future<void> signInWithGoogle() async {
    try {
      // 1. Нативдүү Google Sign-In picker ачуу
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: '1069640136187-3bsq97dd1fn7ln7l8vi6emjpgueiuei5.apps.googleusercontent.com',
      );

      // Мурунку сессияны тазалоо (таза picker чыгуу үчүн)
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // Колдонуучу picker жапты
        return;
      }

      // 2. Google токендерди алуу
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw AuthException('Google ID токен алынган жок');
      }

      // 3. Supabase'ге Google токен менен кирүү
      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      throw AuthException('Кирүүдө ката кетти: $e');
    }
  }

  /// Колдонуучу кирген соң профилди Google маалыматтары менен синхрондоо.
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

    // FCM токенди сактоо
    NotificationService().saveMyToken();
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
  Future<void> signOut() async {
    await NotificationService().clearMyToken();
    // Google сессиясын да тазалоо
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await supabase.auth.signOut();
  }
}