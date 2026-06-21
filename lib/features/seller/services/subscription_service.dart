import '../../../core/supabase_client.dart';
import '../models/seller_model.dart';

class SubscriptionService {
  static const _table = 'profiles';
  static const double monthlyFee = 2000;

  // ═══════════════════════════════════════
  // КАРТАНЫ САКТОО
  // ═══════════════════════════════════════

  Future<void> saveCard({
    required String uid,
    required String cardToken,
    required String cardMasked,
  }) async {
    await supabase.from(_table).update({
      'card_token': cardToken,
      'card_masked': cardMasked,
      'auto_pay_enabled': true,
      'next_pay_date': _nextMonthDate().toIso8601String(),
    }).eq('id', uid);
  }

  // ═══════════════════════════════════════
  // АВТО ТӨЛӨМДҮ ТОКТОТУУ
  // ═══════════════════════════════════════

  Future<void> cancelAutoPayment(String uid) async {
    await supabase.from(_table).update({
      'auto_pay_enabled': false,
    }).eq('id', uid);
  }

  // ═══════════════════════════════════════
  // АВТО ТӨЛӨМДҮ КАЙРА ИШТЕТҮҮ
  // ═══════════════════════════════════════

  Future<void> enableAutoPayment(String uid) async {
    await supabase.from(_table).update({
      'auto_pay_enabled': true,
      'next_pay_date': _nextMonthDate().toIso8601String(),
    }).eq('id', uid);
  }

  // ═══════════════════════════════════════
  // КАРТАНЫ ӨЧҮРүҮ
  // ═══════════════════════════════════════

  Future<void> removeCard(String uid) async {
    await supabase.from(_table).update({
      'auto_pay_enabled': false,
      'card_token': null,
      'card_masked': null,
      'next_pay_date': null,
    }).eq('id', uid);
  }

  // ═══════════════════════════════════════
  // АВТО ТӨЛӨМ ЖҮРГҮЗҮҮ
  // PayBox API менен интеграция болгондо
  // ушул методду Edge Function чакырат
  // ═══════════════════════════════════════

  Future<bool> chargeCard({
    required String uid,
    required String cardToken,
  }) async {
    try {
      // TODO: PayBox API чалуу
      // POST https://api.paybox.money/v1/payments
      // { amount: 2000, currency: 'KGS', token: cardToken }

      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final row = await supabase
          .from(_table)
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (row == null) return false;

      final seller = SellerModel.fromJson(row);
      final payments = List<PaymentModel>.from(seller.payments);
      final index = payments.indexWhere((p) => p.month == month);

      final payment = PaymentModel(
        month: month,
        paid: true,
        paidAt: now,
        amount: monthlyFee,
        method: 'auto_card',
      );

      if (index >= 0) {
        payments[index] = payment;
      } else {
        payments.add(payment);
      }

      await supabase.from(_table).update({
        'payments': payments.map((p) => p.toJson()).toList(),
        'next_pay_date': _nextMonthDate().toIso8601String(),
      }).eq('id', uid);

      return true;
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════
  // HELPER
  // ═══════════════════════════════════════

  DateTime _nextMonthDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 1);
  }
}