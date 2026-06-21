import 'package:shared_preferences/shared_preferences.dart';

/// Сатуучунун сессиясын (uid) телефонго сактоо.
class SellerSessionService {
  SellerSessionService._();
  static final SellerSessionService instance = SellerSessionService._();

  static const _kSellerUidKey = 'seller_session_uid';

  Future<void> saveSession(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSellerUidKey, uid);
  }

  Future<String?> getSavedUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSellerUidKey);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSellerUidKey);
  }
}