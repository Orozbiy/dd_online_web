import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class PayboxService {
  // ── PayBox merchant маалыматтары ──
  // paybox.money → Личный кабинет → Магазины → API ачкычтары
  static const String merchantId = 'СЕНИН_MERCHANT_ID'; // ← өзгөрт
  static const String secretKey = 'СЕНИН_SECRET_KEY';   // ← өзгөрт
  static const String currency = 'KGS';
  static const double monthlyFee = 2000.0;

  // ── PayBox тест / продакшн URL ──
  static const String _baseUrl = 'https://api.paybox.money';
  // Тест режими үчүн: 'https://api.paybox.money' (sandbox)
  // Продакшн үчүн дагы ошол, бирок тест merchant колдонбо

  // ══════════════════════════════════════════════════════
  // КАРТА БАЙЛОО ҮЧҮН PAYMENT URL ТҮЗҮҮ
  // ══════════════════════════════════════════════════════

  /// Seller картасын байлоо үчүн PayBox payment URL түзөт.
  /// [sellerUid] — Firestore seller ID
  /// [sellerPhone] — seller телефону
  /// Кайтарат: payment URL (WebView ичинде ачылат)
  String buildPaymentUrl({
    required String sellerUid,
    required String sellerPhone,
  }) {
    final orderId = _generateOrderId();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // PayBox параметрлери
    final params = {
      'pg_merchant_id': merchantId,
      'pg_amount': monthlyFee.toStringAsFixed(2),
      'pg_currency': currency,
      'pg_order_id': orderId,
      'pg_description': 'DD Online айлык жазылуу',
      'pg_user_phone': sellerPhone,
      'pg_user_id': sellerUid,
      // Карта токенин сактоо үчүн
      'pg_save_card': '1',
      'pg_recurring_start': '1',
      // Натыйжа кайра жөнөтүлүүчү URL (Cloud Function)
      'pg_result_url': 'https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/payboxResult',
      'pg_success_url': 'https://ddonline.app/success',
      'pg_failure_url': 'https://ddonline.app/failure',
      'pg_salt': _generateSalt(),
      'pg_timestamp': now.toString(),
      'pg_testing_mode': '1', // ← Продакшнда '0' кыл
    };

    // MD5 подпись
    final sig = _generateSignature('init_payment.php', params);
    params['pg_sig'] = sig;

    // URL параметрлери
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$_baseUrl/init_payment.php?$query';
  }

  // ══════════════════════════════════════════════════════
  // ПОДПИСЬ ТҮЗҮҮ (MD5)
  // ══════════════════════════════════════════════════════

  String _generateSignature(
      String scriptName, Map<String, String> params) {
    // PayBox подпись алгоритми:
    // script_name;param1;param2;...;secret_key → MD5
    final sorted = Map.fromEntries(
      params.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    );

    final values = [scriptName, ...sorted.values, secretKey];
    final raw = values.join(';');
    return md5.convert(utf8.encode(raw)).toString();
  }

  // ══════════════════════════════════════════════════════
  // ЖАРДАМЧЫЛАР
  // ══════════════════════════════════════════════════════

  String _generateOrderId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'DD_$now';
  }

  String _generateSalt() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(16, (_) => chars[rand.nextInt(chars.length)])
        .join();
  }

  // ══════════════════════════════════════════════════════
  // SUCCESS URL'ди ТЕКШЕРҮҮ
  // WebView ичинде URL өзгөргөндө чакырылат
  // ══════════════════════════════════════════════════════

  /// URL success же failure экенин текшерет.
  /// Кайтарат: 'success' | 'failure' | null
  String? checkRedirectUrl(String url) {
    if (url.contains('ddonline.app/success')) return 'success';
    if (url.contains('ddonline.app/failure')) return 'failure';
    return null;
  }
}