
import '../../../core/supabase_client.dart';
import '../models/seller_model.dart';

class SellerService {
  static final SellerService _instance = SellerService._internal();
  factory SellerService() => _instance;
  SellerService._internal();

  final _table = 'profiles';

  // ── SHA-256 хэш ──

  // ── Паролдун талаптарын текшерет ──
  static String? validatePassword(String password) {
    if (password.length < 8) return 'Пароль кеминде 8 символ болушу керек';
    if (!password.contains(RegExp(r'[A-Z]'))) return 'Кеминде 1 баш тамга болушу керек (A-Z)';
    if (!password.contains(RegExp(r'[a-z]'))) return 'Кеминде 1 кичи тамга болушу керек (a-z)';
    if (!password.contains(RegExp(r'[0-9]'))) return 'Кеминде 1 сан болушу керек (0-9)';
    if (!password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-=+\[\]]'))) {
      return 'Кеминде 1 атайын символ болушу керек (!@#\$%...)';
    }
    return null;
  }

  // ── Admin тарабынан сатуучунун паролун жаңылоо ──
 // ── Admin тарабынан сатуучунун паролун жаңылоо ──
 // ── Admin тарабынан сатуучунун паролун жаңылоо ──
  Future<bool> resetPassword({
    required String uid,
    required String newPassword,
  }) async {
    try {
      final passError = validatePassword(newPassword);
      if (passError != null) return false;

      final response = await supabase.functions.invoke(
        'admin-reset-password',
        body: {
          'uid': uid,
          'newPassword': newPassword,
          'adminPassword': 'sara_2005',
        },
      );

      print('resetPassword status: ${response.status}, data: ${response.data}');

      if (response.status != 200) return false;

      await supabase.from(_table).update({
        'password': newPassword,
      }).eq('id', uid);

      return true;
    } catch (e) {
      print('resetPassword error: $e');
      return false;
    }
  }
  // ═══════════════════════════════════════
  
  // ═══════════════════════════════════════
  /// uid (= profiles.id, = auth.uid()) боюнча сатуучу маалыматын алуу.
  Future<SellerModel?> getSellerByUid(String uid) async {
    try {
      final row = await supabase
          .from(_table)
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (row == null) return null;
      return SellerModel.fromJson(row);
    } catch (e) {
      return null;
    }
  }

  /// Эски колдонуу (телефон боюнча) — Google Auth'тон кийин телефон
  /// profiles'те сакталган болсо ушуну менен табылат.
  Future<SellerModel?> getSellerByPhone(String phone) async {
    try {
      final row = await supabase
          .from(_table)
          .select()
          .eq('phone', phone)
          .maybeSingle();
      if (row == null) return null;
      return SellerModel.fromJson(row);
    } catch (e) {
      return null;
    }
  }

  Future<SellerStatus?> checkStatus(String uid) async {
    final seller = await getSellerByUid(uid);
    return seller?.status;
  }

  // ═══════════════════════════════════════
  // ADMIN — SELLER БАШКАРУУ
  // ═══════════════════════════════════════

  Future<List<SellerModel>> getAllSellers() async {
  try {
    final rows = await supabase
        .from(_table)
        .select()
        .not('seller_status', 'is', null)   // NULL эмес болсун
        .neq('seller_status', '')            // бош эмес болсун
        .order('created_at', ascending: false);


      return (rows as List)
          .map((r) => SellerModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<SellerModel>> getPendingSellers() async {
    try {
      final rows = await supabase
          .from(_table)
          .select()
          .eq('seller_status', 'pending')
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => SellerModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<SellerModel>> getApprovedSellers() async {
    try {
      final rows = await supabase
          .from(_table)
          .select()
          .eq('seller_status', 'approved')
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => SellerModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> approveSeller(String uid) async {
    await supabase.from(_table).update({'seller_status': 'approved'}).eq('id', uid);
  }

  Future<void> rejectSeller(String uid) async {
    await supabase.from(_table).update({'seller_status': 'rejected'}).eq('id', uid);
  }

  Future<void> blockSeller(String uid) async {
    await supabase.from(_table).update({'seller_status': 'blocked'}).eq('id', uid);
  }

  Future<void> unblockSeller(String uid) async {
    await supabase.from(_table).update({'seller_status': 'approved'}).eq('id', uid);
  }

 Future<void> deleteSeller(String uid) async {
  await supabase.from(_table).update({
    'seller_status': 'rejected',
    'shop_name': '',
    'phone': null,
  }).eq('id', uid);
}

  Future<void> updatePhone(String uid, String newPhone) async {
    await supabase.from(_table).update({'phone': newPhone}).eq('id', uid);
  }

  Future<void> updateContainer(String uid, String containerNumber) async {
    await supabase
        .from(_table)
        .update({'container_number': containerNumber}).eq('id', uid);
  }

  // ═══════════════════════════════════════
  // ЛОКАЦИЯ БАШКАРУУ
  // ═══════════════════════════════════════

 Future<void> updateLocation(String uid, double lat, double lng) async {
    await supabase.from(_table).update({
      'latitude': lat,
      'longitude': lng,
    }).eq('id', uid);

    // stores таблицасына да синхрондоо (product detail/навигация ушундан окуйт)
    await supabase.from('stores').update({
      'latitude': lat,
      'longitude': lng,
    }).eq('owner_id', uid);
  }

  Future<void> removeLocation(String uid) async {
    await supabase.from(_table).update({
      'latitude': null,
      'longitude': null,
    }).eq('id', uid);

    await supabase.from('stores').update({
      'latitude': null,
      'longitude': null,
    }).eq('owner_id', uid);
  }

  // ═══════════════════════════════════════
  // ADMIN — ТӨЛӨМ БАШКАРУУ
  // ═══════════════════════════════════════

  Future<void> markAsPaid({
    required String uid,
    required String month,
    required double amount,
  }) async {
    final seller = await getSellerByUid(uid);
    if (seller == null) return;

    final payments = List<PaymentModel>.from(seller.payments);
    final index = payments.indexWhere((p) => p.month == month);
    final payment = PaymentModel(month: month, paid: true, paidAt: DateTime.now(), amount: amount);

    if (index >= 0) {
      payments[index] = payment;
    } else {
      payments.add(payment);
    }

    await supabase.from(_table).update({
      'payments': payments.map((p) => p.toJson()).toList(),
    }).eq('id', uid);
  }

  Future<void> markAsUnpaid({
    required String uid,
    required String month,
    required double amount,
  }) async {
    final seller = await getSellerByUid(uid);
    if (seller == null) return;

    final payments = List<PaymentModel>.from(seller.payments);
    final index = payments.indexWhere((p) => p.month == month);
    final payment = PaymentModel(month: month, paid: false, paidAt: null, amount: amount);

    if (index >= 0) {
      payments[index] = payment;
    } else {
      payments.add(payment);
    }

    await supabase.from(_table).update({
      'payments': payments.map((p) => p.toJson()).toList(),
    }).eq('id', uid);
  }

  Future<void> addCurrentMonthPayment({required double amount}) async {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final sellers = await getApprovedSellers();
    for (final seller in sellers) {
      final alreadyAdded = seller.payments.any((p) => p.month == month);
      if (!alreadyAdded) {
        await markAsUnpaid(uid: seller.uid, month: month, amount: amount);
      }
    }
  }
}
