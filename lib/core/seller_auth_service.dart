import '../features/seller/models/seller_model.dart';
import '../services/notification_service.dart';
import 'supabase_client.dart';
import 'package:flutter/foundation.dart';

class SellerAuthService {
  SellerAuthService._();
  static final SellerAuthService instance = SellerAuthService._();

  static const String _table = 'profiles';
  static const String _phonePrefix = '+996';
  static const String _emailDomain = '@dd-online-seller.local';

  static String formatPhone(String localPart) {
    final digits = localPart.replaceAll(RegExp(r'[^0-9]'), '');
    return '$_phonePrefix$digits';
  }

  static String _fakeEmail(String phone) => '$phone$_emailDomain';

  Future<SellerModel> register({
    required String phone,
    required String password,
    required String fullName,
    required int age,
    required String containerNumber,
    required String shopName,
    String storeType = 'market',
    String? marketName,
  }) async {
    final exists = await phoneExists(phone);
    if (exists) {
      throw const SellerPhoneTakenException();
    }

    final email = _fakeEmail(phone);

    final res = await supabase.auth.signUp(
      email: email,
      password: password,
    );

    final user = res.user;
    if (user == null) {
      throw const SellerInvalidCredentialsException();
    }

   final row = await supabase
    .from(_table)
    .update({
      'phone':            phone,
      'full_name':        fullName,
      'age':              age,
      'container_number': containerNumber,
      'store_type':       storeType,
      'market_name':      marketName,
      'shop_name':        shopName.isNotEmpty ? shopName : containerNumber,
      'seller_status':    'pending',
      'role':             'seller',          // ← кош
      'avatar_url':       null,              // ← кош (баш тамга көрсөтүлөт)
      'email':            email,             // ← кош
    })
    .eq('id', user.id)
    .select()
    .single();

    // ✅ FCM токенди сакта
    await NotificationService().saveMyToken();

    // ✅ Adminге Telegram билдирүү жөнөт
   try {
  debugPrint('📤 Telegram notify жөнөтүлүүдө...');
  final response = await supabase.functions.invoke(
    'notify-admin',
    body: {
      'sellerName': fullName,
      'phone': phone,
      'shopName': shopName.isNotEmpty ? shopName : containerNumber,
      'container': containerNumber,
      'sellerId': user.id,
    },
  );
  debugPrint('✅ Telegram notify жооп: ${response.data}');
} catch (e) {
  debugPrint('❌ Telegram notify ката: $e');
}

    return SellerModel.fromJson(row);
  }



  Future<SellerModel> login({
    required String phone,
    required String password,
  }) async {
    final email = _fakeEmail(phone);

    final res = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = res.user;
    if (user == null) {
      throw const SellerInvalidCredentialsException();
    }

    final row = await supabase
        .from(_table)
        .select()
        .eq('id', user.id)
        .single();

    final status = row['seller_status'] as String? ?? 'pending';

    // ✅ Статусту текшер
    if (status == 'pending') {
      await supabase.auth.signOut();
      throw const SellerPendingException();
    }

    if (status == 'rejected') {
      await supabase.auth.signOut();
      throw const SellerRejectedException();
    }

    await NotificationService().saveMyToken();

    return SellerModel.fromJson(row);
  }

  Future<bool> phoneExists(String phone) async {
    final row = await supabase
        .from(_table)
        .select('id')
        .eq('phone', phone)
        .maybeSingle();
    return row != null;
  }
}

class SellerPhoneTakenException implements Exception {
  const SellerPhoneTakenException();
  @override
  String toString() => 'Бул телефон номери менен сатуучу мурда катталган';
}

class SellerInvalidCredentialsException implements Exception {
  const SellerInvalidCredentialsException();
  @override
  String toString() => 'Телефон же пароль туура эмес';
}
/// Заявка каралууда
class SellerPendingException implements Exception {
  const SellerPendingException();
  @override
  String toString() => 'Сиздин заявкаңыз каралууда. Күтүңүз.';
}

/// Заявка четке кагылды
class SellerRejectedException implements Exception {
  const SellerRejectedException();
  @override
  String toString() => 'Сиздин заявкаңыз четке кагылды.';
}