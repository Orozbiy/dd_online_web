// ═══════════════════════════════════════════════════════════════
// lib/services/price_watch_service.dart
// Баа өзгөргөндө price_watch тизмесиндеги колдонуучуларга
// FCM notification жиберет.
//
// ЧАКЫРУУ ЖЕРИ:
// create_promotion_screen.dart → _savePromotion() ичинде,
// суpabase update'тен КИЙИН:
//   await PriceWatchService().notifyWatchers(
//     productId: _selected!['id'] as String,
//     productName: _selected!['title'] as String,
//     oldPrice: (_selected!['price'] as num).toDouble(),
//     newPrice: _discountedPrice!,
//   );
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import '../core/supabase_client.dart';

class PriceWatchService {
  static final PriceWatchService _i = PriceWatchService._();
  factory PriceWatchService() => _i;
  PriceWatchService._();

  static const _projectId = 'dd-online-web';
  static const _fcmUrl =
      'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

  // ─────────────────────────────────────────────────────────────
  // Баа түшкөндө price_watch тизмесиндеги
  // баардык колдонуучуларга notification жиберет
  // ─────────────────────────────────────────────────────────────
  Future<void> notifyWatchers({
    required String productId,
    required String productName,
    required double oldPrice,
    required double newPrice,
  }) async {
    try {
      // 1. price_watch тизмесинен колдонуучуларды алуу
      final rows = await supabase
          .from('price_watch')
          .select('user_id')
          .eq('product_id', productId);

      if ((rows as List).isEmpty) {
        debugPrint('ℹ️ price_watch: күтүүдөгү колдонуучу жок → $productId');
        return;
      }

      final userIds = rows.map((r) => r['user_id'] as String).toList();
      debugPrint('🔔 price_watch: ${userIds.length} колдонуучуга кабарлама жиберилет');

      // 2. FCM токендерин алуу
      final tokenRows = await supabase
          .from('push_tokens')
          .select('user_id, token')
          .inFilter('user_id', userIds);

      if ((tokenRows as List).isEmpty) return;

      // 3. Access token алуу
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        debugPrint('⚠️ PriceWatchService: Access Token алынбады');
        return;
      }

      // 4. Notification тексти
      final saved   = (oldPrice - newPrice).toStringAsFixed(0);
      final title   = '🏷️ Баа түштү! — $productName';
      final body    = '${newPrice.toStringAsFixed(0)} сом (${oldPrice.toStringAsFixed(0)} сомдон), $saved сомго арзандады!';

      // 5. Ар бир колдонуучуга жиберүү
      for (final row in tokenRows) {
        final token = row['token'] as String?;
        if (token == null || token.isEmpty) continue;

        await _sendFcm(
          token:       token,
          title:       title,
          body:        body,
          productId:   productId,
          accessToken: accessToken,
        );
      }

      debugPrint('✅ PriceWatchService: баардыгына кабарлама жиберилди');
    } catch (e) {
      debugPrint('❌ PriceWatchService.notifyWatchers ката: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // FCM жиберүү
  // ─────────────────────────────────────────────────────────────
  Future<void> _sendFcm({
    required String token,
    required String title,
    required String body,
    required String productId,
    required String accessToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_fcmUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': {
            'token': token,
            'notification': {'title': title, 'body': body},
            'android': {
              'priority': 'high',
              'notification': {
                'channel_id': 'chat_messages',
                'sound': 'default',
                'notification_priority': 'PRIORITY_MAX',
              },
            },
            'apns': {
              'payload': {
                'aps': {'sound': 'default', 'badge': 1},
              },
              'headers': {'apns-priority': '10'},
            },
            'data': {
              'type':      'price_drop',
              'productId': productId,
              'title':     title,
              'body':      body,
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM жиберилди → $token');
      } else {
        debugPrint('❌ FCM ката ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ _sendFcm ката: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Google Service Account → Access Token
  // (notification_service.dart'тагы менен бирдей)
  // ─────────────────────────────────────────────────────────────
  Future<String?> _getAccessToken() async {
    try {
      final jsonString = await rootBundle.loadString('service_account.json');
      final json = jsonDecode(jsonString);
      final creds  = ServiceAccountCredentials.fromJson(json);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await clientViaServiceAccount(creds, scopes);
      final token  = client.credentials.accessToken.data;
      client.close();
      return token;
    } catch (e) {
      debugPrint('❌ Access Token ката: $e');
      return null;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// create_promotion_screen.dart ичине кошуу:
// ═══════════════════════════════════════════════════════════════
/*
// Импорт кош:
import '../../../services/price_watch_service.dart';

// _savePromotion() функциясында, суpabase.update'тен КИЙИН:
Future<void> _savePromotion() async {
  final pct = double.tryParse(_discountCtrl.text);
  if (_selected == null || pct == null || pct <= 0 || pct >= 100) return;
  setState(() => _saving = true);
  try {
    await supabase.from('products').update({
      'discount_percent':  pct,
      'discounted_price':  _discountedPrice,
      'has_promotion':     true,
    }).eq('id', _selected!['id']);

    // ✅ ЖАңы: баа күтүп жаткандарга кабарлама
    await PriceWatchService().notifyWatchers(
      productId:   _selected!['id'] as String,
      productName: _selected!['title'] as String,
      oldPrice:    (_selected!['price'] as num).toDouble(),
      newPrice:    _discountedPrice!,
    );

    // ... калган код ...
  } catch (e) {
    // ...
  }
}
*/
