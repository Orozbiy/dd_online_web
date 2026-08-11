import 'package:dd_online/features/admin/widgets/admin_notification_sender.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  User? get currentUser => supabase.auth.currentUser;
  bool get isSignedIn => currentUser != null;
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // ВЕБ: браузер redirect аркылуу — эч кандай return жок,
        // браузер автоматтык redirect болот
        await supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'https://dd-online-web.web.app',
          authScreenLaunchMode: LaunchMode.externalApplication, 
        );
        // Бул жерге эч качан жетпейт — браузер redirect болот
      } else {
        // МОБИЛ: нативдүү Google Sign-In picker
        final GoogleSignIn googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
          serverClientId:
              '1069640136187-3bsq97dd1fn7ln7l8vi6emjpgueiuei5.apps.googleusercontent.com',
        );

        await googleSignIn.signOut();

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) return;

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final idToken = googleAuth.idToken;
        final accessToken = googleAuth.accessToken;

        if (idToken == null) {
          throw Exception('Google ID токен алынган жок');
        }

        await supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
      }
    } catch (e) {
      throw Exception('Кирүүдө ката кетти: $e');
    }
  }

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
    } catch (_) {}

    try {
      NotificationService().saveMyToken();
    } catch (_) {}
  }

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

  Future<void> signOut() async {
    try {
      await NotificationService().clearMyToken();
    } catch (_) {}
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
    await supabase.auth.signOut();
  }
}