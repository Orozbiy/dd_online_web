import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import '../core/supabase_client.dart';
import '../core/services/in_app_notification_banner.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/product_detail/screens/product_detail_screen.dart';
import '../data/models/product_model.dart';
import '../features/notifications/screens/notifications_screen.dart';

// ─────────────────────────────────────────────────────────────
// GLOBAL NAVIGATOR KEY — MaterialApp'ка берилет
// ─────────────────────────────────────────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ─────────────────────────────────────────────────────────────
// NOTIFICATION SERVICE
// ─────────────────────────────────────────────────────────────
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static String? pendingChatId;
  static String? pendingProductId;
  static bool pendingNotifications = false;

  // Lazy getter: NotificationService() Firebase init болгонго чейин чакырылса да кулабайт
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  // ─────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────
  Future<void> init() async {
    debugPrint('🚀 NotificationService.init() (веб: $kIsWeb)');

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // ── Foreground message ──
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final chatId    = message.data['chatId']    as String?;
      final productId = message.data['productId'] as String?;
      final type      = message.data['type']      as String? ?? 'chat_message';

      final title = message.notification?.title
          ?? message.data['senderName']
          ?? 'DD Online';
      final body  = message.notification?.body
          ?? message.data['body']
          ?? 'Жаңы билдирүү';

      String payload = '';
      if (type == 'admin_broadcast') {
        payload = 'notifications';
      } else if (type == 'chat_message' && chatId != null && chatId.isNotEmpty) {
        payload = 'chat:$chatId';
      } else if (type == 'price_drop' && productId != null && productId.isNotEmpty) {
        payload = 'product:$productId';
      } else if (chatId != null && chatId.isNotEmpty) {
        payload = 'chat:$chatId';
      }

      // ✅ Веб — дайыма SnackBar
      _showWebSnackbar(title, body, payload);
    });

    // ── Background → Foreground tap ──
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      final chatId    = message.data['chatId']    as String?;
      final productId = message.data['productId'] as String?;
      final type      = message.data['type']      as String? ?? 'chat_message';

      await Future.delayed(const Duration(milliseconds: 800));

      if (type == 'admin_broadcast') {
        _openNotifications();
      } else if (type == 'chat_message' && chatId != null && chatId.isNotEmpty) {
        await _navigateToChat(chatId);
      } else if (type == 'price_drop' && productId != null && productId.isNotEmpty) {
        await navigateToProductPublic(productId);
      } else if (chatId != null && chatId.isNotEmpty) {
        await _navigateToChat(chatId);
      }
    });

    debugPrint('✅ NotificationService даяр');
  }

  // ─────────────────────────────────────────────────────────────
  // TERMINATED STATE — веб'де колдонулбайт, бош калтырылат
  // ─────────────────────────────────────────────────────────────
  Future<void> handleInitialMessage() async {
    // Веб'де terminated state жок
  }

  // ─────────────────────────────────────────────────────────────
  // ВЕБ: SnackBar аркылуу notification
  // ─────────────────────────────────────────────────────────────
  void _showWebSnackbar(String title, String body, String payload) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // app'тагыдай айнек banner; Overlay табылбаса — SnackBar'га түшөт
    try {
      InAppNotificationBanner.show(
        context: context,
        title: title,
        body: body,
        avatarText: title,
        onTap: () => _handlePayload(payload),
      );
      return;
    } catch (e) {
      debugPrint('⚠️ Banner көрсөтүлгөн жок, SnackBar колдонулат: $e');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            Text(body,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        action: payload.isNotEmpty
            ? SnackBarAction(
                label: 'Ачуу',
                textColor: const Color(0xFF4895EF),
                onPressed: () => _handlePayload(payload),
              )
            : null,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PAYLOAD HANDLER
  // ─────────────────────────────────────────────────────────────
  void _handlePayload(String payload) {
    if (payload.isEmpty) return;
    if (payload == 'notifications') {
      _openNotifications();
    } else if (payload.startsWith('chat:')) {
      final chatId = payload.substring(5);
      if (chatId.isNotEmpty) _navigateToChat(chatId);
    } else if (payload.startsWith('product:')) {
      final productId = payload.substring(8);
      if (productId.isNotEmpty) navigateToProductPublic(productId);
    } else {
      _navigateToChat(payload);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // АДМИН БИЛДИРҮҮЛӨР ЭКРАНЫН АЧУУ
  // ─────────────────────────────────────────────────────────────
  void _openNotifications() {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      NotificationService.pendingNotifications = true;
      return;
    }
    Navigator.of(ctx).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PUBLIC WRAPPERS
  // ─────────────────────────────────────────────────────────────
  Future<void> navigateToChatPublic(String chatId) => _navigateToChat(chatId);
  Future<void> navigateToProductPublic(String productId) =>
      _navigateToProduct(productId);

  // ─────────────────────────────────────────────────────────────
  // NAVIGATE TO CHAT
  // ─────────────────────────────────────────────────────────────
  Future<void> _navigateToChat(String chatId) async {
  BuildContext? context;
  for (int i = 0; i < 20; i++) {
    context = navigatorKey.currentContext;
    if (context != null) break;
    await Future.delayed(const Duration(milliseconds: 200));
  }

  if (context == null) {
    NotificationService.pendingChatId = chatId;
    return;
  }

  try {
    final user = supabase.auth.currentUser;
    if (user == null) {
      NotificationService.pendingChatId = chatId;
      return;
    }

    // ✅ seller_name жок — stores'тен алабыз
    final row = await supabase
        .from('chats')
        .select('id, seller_id, buyer_id, product_id')
        .eq('id', chatId)
        .maybeSingle();

    if (row == null) return;

    final isSeller  = row['seller_id'] == user.id;
    final sellerId  = row['seller_id'] as String? ?? '';

    // ✅ seller_name — stores таблицасынан
    String sellerName = 'Сатуучу';
    try {
      final store = await supabase
          .from('stores')
          .select('store_name')
          .eq('owner_id', sellerId)
          .maybeSingle();
      sellerName = store?['store_name'] as String? ?? 'Сатуучу';
    } catch (_) {}

    String productName  = '';
    String productImage = '';
    final productId = row['product_id'] as String?;
    if (productId != null) {
      try {
        final product = await supabase
            .from('products')
            .select('title, images')
            .eq('id', productId)
            .maybeSingle();
        if (product != null) {
          productName  = product['title'] as String? ?? '';
          final images = product['images'] as List?;
          productImage = (images != null && images.isNotEmpty)
              ? images.first as String
              : '';
        }
      } catch (_) {}
    }

    String otherAvatarUrl = '';
    final otherUserId = isSeller
        ? row['buyer_id']  as String? ?? ''
        : sellerId;
    try {
      final profile = await supabase
          .from('profiles')
          .select('avatar_url')
          .eq('id', otherUserId)
          .maybeSingle();
      otherAvatarUrl = profile?['avatar_url'] as String? ?? '';
    } catch (_) {}

    context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => _ChatScreenProxy(
          chatId:         chatId,
          sellerName:     sellerName,
          productName:    productName,
          productImage:   productImage,
          isSeller:       isSeller,
          buyerId:        row['buyer_id']  as String? ?? '',
          sellerId:       sellerId,
          otherAvatarUrl: otherAvatarUrl,
        ),
      ),
    );
  } catch (e) {
    debugPrint('❌ _navigateToChat ката: $e');
  }
}

  // ─────────────────────────────────────────────────────────────
  // NAVIGATE TO PRODUCT
  // ─────────────────────────────────────────────────────────────
  Future<void> _navigateToProduct(String productId) async {
    BuildContext? context;
    for (int i = 0; i < 15; i++) {
      context = navigatorKey.currentContext;
      if (context != null) break;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (context == null) {
      NotificationService.pendingProductId = productId;
      return;
    }

    try {
      final data = await supabase
          .from('products')
          .select('*, stores(*)')
          .eq('id', productId)
          .maybeSingle();

      if (data == null) return;

      final product = ProductModel.fromMap(data);

      context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
      );
    } catch (e) {
      debugPrint('❌ _navigateToProduct ката: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SEND CHAT NOTIFICATION — FCM v1
  // ─────────────────────────────────────────────────────────────
  Future<void> sendChatNotification({
    required String receiverUid,
    required String senderName,
    required String messageText,
    required String chatId,
  }) async {
    try {
      final tokenRow = await supabase
          .from('push_tokens')
          .select('token')
          .eq('user_id', receiverUid)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final fcmToken = tokenRow?['token'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) return;

      final accessToken = await _getAccessToken();
      if (accessToken == null) return;

      const projectId = 'dd-online-web';
      const url =
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {'title': senderName, 'body': messageText},
            'webpush': {
              'notification': {
                'title': senderName,
                'body':  messageText,
                'icon':  '/icons/Icon-192.png',
              },
              'fcm_options': {'link': '/'},
            },
            'data': {
              'chatId':     chatId,
              'type':       'chat_message',
              'senderName': senderName,
              'title':      senderName,
              'body':       messageText,
            },
          },
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ FCM ката: ${response.statusCode} — ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ sendChatNotification ката: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BROADCAST
  // ─────────────────────────────────────────────────────────────
  Future<int> sendBroadcastNotification({
    required String title,
    required String body,
  }) async {
    try {
      final rows = await supabase.from('push_tokens').select('token');
      final tokens = (rows as List)
          .map((r) => r['token'] as String?)
          .whereType<String>()
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList();

      if (tokens.isEmpty) return 0;

      final accessToken = await _getAccessToken();
      if (accessToken == null) return 0;

      const projectId = 'dd-online-web';
      const url =
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      int successCount = 0;
      for (final token in tokens) {
        try {
          final response = await http.post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type':  'application/json',
            },
            body: jsonEncode({
              'message': {
                'token': token,
                'notification': {'title': title, 'body': body},
                'webpush': {
                  'notification': {
                    'title': title,
                    'body':  body,
                    'icon':  '/icons/Icon-192.png',
                  },
                },
                'data': {'type': 'admin_broadcast', 'title': title, 'body': body},
              },
            }),
          );
          if (response.statusCode == 200) {
            successCount++;
          } else if (response.statusCode == 404 ||
              response.body.contains('UNREGISTERED') ||
              response.body.contains('INVALID_ARGUMENT')) {
            await supabase.from('push_tokens').delete().eq('token', token);
          }
        } catch (_) {}
      }
      return successCount;
    } catch (e) {
      debugPrint('❌ sendBroadcastNotification ката: $e');
      return 0;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // TEST NOTIFICATION
  // ─────────────────────────────────────────────────────────────
  Future<void> showTestNotification() async {
    _showWebSnackbar('DD Online 🛍️', 'Уведомления иштеп жатат!', '');
  }

  // ─────────────────────────────────────────────────────────────
  // FCM TOKEN
  // ─────────────────────────────────────────────────────────────
  Future<void> saveMyToken() async {
  try {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    String? token;

    if (kIsWeb) {
      // ВЕБ үчүн VAPID ачкычы керек
      token = await _messaging.getToken(
        vapidKey: 'BDpKYBHjHAilY1jGXlduqw1eJ6lSsmxwkJ8dIgag-2svdBpjn_QsiN2BrSbBboBNmVh2ZI-AQqZe3zaOjFsdXL0',
      );
    } else {
      token = await _messaging.getToken();
    }

    if (token == null) return;

    debugPrint('💾 FCM Token сакталууда...');

    await supabase.from('push_tokens').upsert(
      {
        'user_id':    user.id,
        'token':      token,
        'platform':   kIsWeb ? 'web' : 'mobile',
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id',
    );

    debugPrint('✅ FCM Token сакталды: ${token.substring(0, 20)}...');
  } catch (e) {
    debugPrint('❌ saveMyToken ката: $e');
  }
}

  Future<void> clearMyToken() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      await supabase.from('push_tokens').delete().eq('user_id', user.id);
    } catch (e) {
      debugPrint('❌ clearMyToken ката: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ACCESS TOKEN
  // ─────────────────────────────────────────────────────────────
  Future<String?> _getAccessToken() async {
    try {
      final jsonString = await rootBundle.loadString('service_account.json');
      final json       = jsonDecode(jsonString);
      final creds      = ServiceAccountCredentials.fromJson(json);
      final scopes     = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client     = await clientViaServiceAccount(creds, scopes);
      final token      = client.credentials.accessToken.data;
      client.close();
      return token;
    } catch (e) {
      debugPrint('❌ _getAccessToken ката: $e');
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// _ChatScreenProxy
// ─────────────────────────────────────────────────────────────
class _ChatScreenProxy extends StatelessWidget {
  final String chatId;
  final String sellerName;
  final String productName;
  final String productImage;
  final bool   isSeller;
  final String buyerId;
  final String sellerId;
  final String otherAvatarUrl;

  const _ChatScreenProxy({
    required this.chatId,
    required this.sellerName,
    required this.productName,
    required this.productImage,
    required this.isSeller,
    required this.buyerId,
    required this.sellerId,
    required this.otherAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ChatScreen(
      chatId:         chatId,
      sellerName:     sellerName,
      productName:    productName,
      productImage:   productImage,
      isSeller:       isSeller,
      buyerId:        buyerId,
      sellerId:       sellerId,
      otherAvatarUrl: otherAvatarUrl,
    );
  }
}