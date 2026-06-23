import '../features/seller/models/seller_model.dart';
import '../services/notification_service.dart';
import 'supabase_client.dart';

/// Сатуучулар үчүн телефон номери + пароль аркылуу кирүү/каттоо.
///
/// Supabase Auth (email/password) колдонулат. Телефон номери
/// "+996700123456@dd-online-seller.local" түрүндөгү жасалма email'ге
/// айлантылып, signUp/signInWithPassword аркылуу чыныгы auth.uid()
/// алынат — бул RLS policy'лер (chats, push_tokens, ж.б.) туура иштеши үчүн.
class SellerAuthService {
  SellerAuthService._();
  static final SellerAuthService instance = SellerAuthService._();

  static const String _table = 'profiles';
  static const String _phonePrefix = '+996';
  static const String _emailDomain = '@dd-online-seller.local';

  /// +996 префиксин кошуп, толук телефон номерин кайтарат.
  /// [localPart] — колдонуучу терген 9 орундуу номер (мис. 700123456).
  static String formatPhone(String localPart) {
    final digits = localPart.replaceAll(RegExp(r'[^0-9]'), '');
    return '$_phonePrefix$digits';
  }

  static String _fakeEmail(String phone) => '$phone$_emailDomain';

  /// Жаңы сатуучуну каттоо.
  ///
  /// [phone] — толук формада +996XXXXXXXXX.
  /// Телефон мурда катталган болсо [SellerPhoneTakenException] кетет.
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

    // handle_new_user() триггери profiles(id, email, full_name, avatar_url)
    // катарын автоматтык түзөт. Калган талааларды UPDATE менен толтурабыз.
    final row = await supabase
        .from(_table)
        .update({
          'phone': phone,
          'full_name': fullName,
          'age': age,
          'container_number': containerNumber,
          'store_type': storeType,
          'market_name': marketName,
          'shop_name': shopName.isNotEmpty ? shopName : containerNumber,
          'seller_status': 'pending',
        })
        .eq('id', user.id)
        .select()
        .single();

    // ✅ Катталган соң FCM токенди сакта
    await NotificationService().saveMyToken();

    return SellerModel.fromJson(row);
  }

  /// Телефон + пароль менен кирүү.
  /// Дал келбесе [SellerInvalidCredentialsException] кетет.
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

    // ✅ Кирген соң FCM токенди сакта — уведомления иштеши үчүн
    await NotificationService().saveMyToken();

    return SellerModel.fromJson(row);
  }

  /// Телефон номери боюнча катталган-катталбаганын текшерүү.
  Future<bool> phoneExists(String phone) async {
    final row = await supabase
        .from(_table)
        .select('id')
        .eq('phone', phone)
        .maybeSingle();
    return row != null;
  }
}

/// Бул телефон номери менен сатуучу мурда катталган.
class SellerPhoneTakenException implements Exception {
  const SellerPhoneTakenException();
  @override
  String toString() => 'Бул телефон номери менен сатуучу мурда катталган';
}

/// Телефон же пароль туура эмес.
class SellerInvalidCredentialsException implements Exception {
  const SellerInvalidCredentialsException();
  @override
  String toString() => 'Телефон же пароль туура эмес';
}