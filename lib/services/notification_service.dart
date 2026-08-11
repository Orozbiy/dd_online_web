import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import '../core/supabase_client.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/product_detail/screens/product_detail_screen.dart';
import '../data/models/product_model.dart';

// ─────────────────────────────────────────────────────────────
// GLOBAL NAVIGATOR KEY — MaterialApp'ка берилет
// ─────────────────────────────────────────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static String? pendingChatId;
  static String? pendingProductId;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'chat_messages',
    'Чат билдирүүлөрү',
    description: 'DD Online чат билдирүүлөрү',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  // ─────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────
  Future<void> init() async {
    debugPrint('🚀 NotificationService.init() башталды');

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _localNotif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload ?? '';
        debugPrint('🔔 [Foreground tap] payload=$payload');
        if (payload.isEmpty) return;

        if (payload.startsWith('chat:')) {
          final chatId = payload.substring(5);
          if (chatId.isNotEmpty) _navigateToChat(chatId);
        } else if (payload.startsWith('product:')) {
          final productId = payload.substring(8);
          if (productId.isNotEmpty) navigateToProductPublic(productId);
        } else {
          _navigateToChat(payload);
        }
      },
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 onMessage келди: ${message.data}');

      final chatId    = message.data['chatId']    as String?;
      final productId = message.data['productId'] as String?;
      final type      = message.data['type']      as String? ?? 'chat_message';

      final notification = message.notification;
      final title = notification?.title ?? message.data['senderName'] ?? 'DD Online';
      final body  = notification?.body  ?? message.data['body']       ?? 'Жаңы билдирүү';

      String payload = '';
      if (type == 'chat_message' && chatId != null && chatId.isNotEmpty) {
        payload = 'chat:$chatId';
      } else if (type == 'price_drop' && productId != null && productId.isNotEmpty) {
        payload = 'product:$productId';
      } else if (chatId != null && chatId.isNotEmpty) {
        payload = 'chat:$chatId';
      }

      _localNotif.show(
        message.messageId.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            channelShowBadge: true,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      debugPrint('🔔 [Background→Foreground tap] data=${message.data}');

      final chatId    = message.data['chatId']    as String?;
      final productId = message.data['productId'] as String?;
      final type      = message.data['type']      as String? ?? 'chat_message';

      await Future.delayed(const Duration(milliseconds: 800));

      if (type == 'chat_message' && chatId != null && chatId.isNotEmpty) {
        await _navigateToChat(chatId);
      } else if (type == 'price_drop' && productId != null && productId.isNotEmpty) {
        await navigateToProductPublic(productId);
      } else if (chatId != null && chatId.isNotEmpty) {
        await _navigateToChat(chatId);
      }
    });

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('✅ NotificationService даяр');
  }

  // ─────────────────────────────────────────────────────────────
  // TERMINATED STATE
  // ─────────────────────────────────────────────────────────────
  Future<void> handleInitialMessage() async {
    try {
      final message = await _messaging.getInitialMessage();
      if (message == null) {
        debugPrint('🔔 [Terminated] getInitialMessage: null');
        return;
      }

      final chatId    = message.data['chatId']    as String?;
      final productId = message.data['productId'] as String?;
      final type      = message.data['type']      as String? ?? 'chat_message';

      debugPrint('🔔 [Terminated→Open] type=$type chatId=$chatId productId=$productId');

      if (type == 'chat_message' && chatId != null && chatId.isNotEmpty) {
        NotificationService.pendingChatId = chatId;
      } else if (type == 'price_drop' && productId != null && productId.isNotEmpty) {
        NotificationService.pendingProductId = productId;
      } else if (chatId != null && chatId.isNotEmpty) {
        NotificationService.pendingChatId = chatId;
      }
    } catch (e) {
      debugPrint('❌ handleInitialMessage ката: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PUBLIC WRAPPERS
  // ─────────────────────────────────────────────────────────────
  Future<void> navigateToChatPublic(String chatId) => _navigateToChat(chatId);
  Future<void> navigateToProductPublic(String productId) => _navigateToProduct(productId);

  // ─────────────────────────────────────────────────────────────
  // NAVIGATE TO CHAT
  // ─────────────────────────────────────────────────────────────
  Future<void> _navigateToChat(String chatId) async {
    debugPrint('🧭 _navigateToChat chatId=$chatId');

    BuildContext? context;
    for (int i = 0; i < 20; i++) {
      context = navigatorKey.currentContext;
      if (context != null) break;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (context == null) {
      debugPrint('⚠️ navigatorKey null — pendingChatId катары сактайбыз');
      NotificationService.pendingChatId = chatId;
      return;
    }

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        NotificationService.pendingChatId = chatId;
        return;
      }

      final row = await supabase
          .from('chats')
          .select('id, seller_id, buyer_id, product_id, seller_name')
          .eq('id', chatId)
          .maybeSingle();

      if (row == null) return;

      final isSeller = row['seller_id'] == user.id;

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
            productName = product['title'] as String? ?? '';
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
          : row['seller_id'] as String? ?? '';
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
            chatId:       chatId,
            sellerName:   row['seller_name'] as String? ?? 'Сатуучу',
            productName:  productName,
            productImage: productImage,
            isSeller:     isSeller,
            buyerId:      row['buyer_id']  as String? ?? '',
            sellerId:     row['seller_id'] as String? ?? '',
            otherAvatarUrl: otherAvatarUrl,
          ),
        ),
      );

      debugPrint('✅ ChatScreen navigate болду → isSeller=$isSeller');
    } catch (e) {
      debugPrint('❌ _navigateToChat катасы: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // NAVIGATE TO PRODUCT
  // ─────────────────────────────────────────────────────────────
  Future<void> _navigateToProduct(String productId) async {
    debugPrint('🧭 _navigateToProduct productId=$productId');

    BuildContext? context;
    for (int i = 0; i < 15; i++) {
      context = navigatorKey.currentContext;
      if (context != null) break;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (context == null) {
      debugPrint('⚠️ navigatorKey null — pendingProductId катары сактайбыз');
      NotificationService.pendingProductId = productId;
      return;
    }

    try {
      final data = await supabase
          .from('products')
          .select('*, stores(*)')
          .eq('id', productId)
          .maybeSingle();

      if (data == null) {
        debugPrint('⚠️ Product табылбады: productId=$productId');
        return;
      }

      final product = ProductModel.fromMap(data);

      context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
      );

      debugPrint('✅ ProductDetailScreen\'ге navigate болду → productId=$productId');
    } catch (e) {
      debugPrint('❌ _navigateToProduct катасы: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SEND CHAT NOTIFICATION — FCM v1 API
  // ─────────────────────────────────────────────────────────────
  Future<void> sendChatNotification({
    required String receiverUid,
    required String senderName,
    required String messageText,
    required String chatId,
  }) async {
    debugPrint('📤 sendChatNotification → receiverUid=$receiverUid');
    try {
      final tokenRow = await supabase
          .from('push_tokens')
          .select('token')
          .eq('user_id', receiverUid)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final fcmToken = tokenRow?['token'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('⚠️ FCM токен табылбады, receiverUid=$receiverUid');
        return;
      }

      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        debugPrint('⚠️ Access Token алынбады');
        return;
      }

      const projectId = 'dd-online-web';
      const url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {
              'title': senderName,
              'body':  messageText,
            },
            'android': {
              'priority': 'high',
              'notification': {
                'channel_id':             'chat_messages',
                'sound':                  'default',
                'default_vibrate_timings': true,
                'notification_priority':  'PRIORITY_MAX',
                'visibility':             'PUBLIC',
                'click_action':           'FLUTTER_NOTIFICATION_CLICK',
              },
            },
            'apns': {
              'payload': {
                'aps': {
                  'sound':             'default',
                  'badge':              1,
                  'content-available':  1,
                },
              },
              'headers': {'apns-priority': '10'},
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

      if (response.statusCode == 200) {
        debugPrint('✅ Notification жиберилди → $senderName: $messageText');
      } else {
        debugPrint('❌ FCM ката: ${response.statusCode} — ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Notification жибере алган жок: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // БААРДЫГЫНА БИЛДИРҮҮ — Админ үчүн (push_tokens бардык токен)
  // ─────────────────────────────────────────────────────────────
  Future<int> sendBroadcastNotification({
    required String title,
    required String body,
  }) async {
    debugPrint('📢 sendBroadcastNotification башталды');
    try {
      final rows = await supabase.from('push_tokens').select('token');

      final tokens = (rows as List)
          .map((r) => r['token'] as String?)
          .whereType<String>()
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList();

      if (tokens.isEmpty) {
        debugPrint('⚠️ Токендер жок');
        return 0;
      }

      debugPrint('📢 Жалпы токен саны: ${tokens.length}');

      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        debugPrint('⚠️ Access Token алынбады');
        return 0;
      }

      const projectId = 'dd-online-web';
      const url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      int successCount = 0;

      for (final token in tokens) {
        try {
          final response = await http.post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'message': {
                'token': token,
                'notification': {
                  'title': title,
                  'body':  body,
                },
                'android': {
                  'priority': 'high',
                  'notification': {
                    'channel_id':             'chat_messages',
                    'sound':                  'default',
                    'notification_priority':  'PRIORITY_MAX',
                    'default_vibrate_timings': true,
                  },
                },
                'apns': {
                  'payload': {
                    'aps': {'sound': 'default', 'badge': 1},
                  },
                  'headers': {'apns-priority': '10'},
                },
                'data': {
                  'type':  'admin_broadcast',
                  'title': title,
                  'body':  body,
                },
              },
            }),
          );

          if (response.statusCode == 200) {
            successCount++;
          } else {
            // Эски/жараксыз токенди базадан өчүр
            if (response.statusCode == 404 ||
                response.body.contains('UNREGISTERED') ||
                response.body.contains('INVALID_ARGUMENT')) {
              await supabase.from('push_tokens').delete().eq('token', token);
              debugPrint('🗑️ Эски токен өчүрүлдү');
            }
          }
        } catch (e) {
          debugPrint('❌ Token жөнөтүүдө ката: $e');
        }
      }

      debugPrint('✅ Broadcast аяктады: $successCount/${tokens.length} жеткирилди');
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
    await _localNotif.show(
      999,
      'DD Online 🛍️',
      'Уведомления иштеп жатат!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FCM TOKEN — Supabase'ка сактоо / өчүрүү
  // ─────────────────────────────────────────────────────────────
  Future<void> saveMyToken() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token == null) return;

      debugPrint('💾 FCM Token сакталууда...');

      await supabase.from('push_tokens').delete().eq('user_id', user.id);
      await supabase.from('push_tokens').insert({
        'user_id':    user.id,
        'token':      token,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ FCM Token сакталды: ${token.substring(0, 20)}...');

      _messaging.onTokenRefresh.listen((newToken) async {
        await supabase.from('push_tokens').delete().eq('user_id', user.id);
        await supabase.from('push_tokens').insert({
          'user_id':    user.id,
          'token':      newToken,
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ FCM Token жаңырды');
      });
    } catch (e) {
      debugPrint('❌ Token сактоо катасы: $e');
    }
  }

  Future<void> clearMyToken() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      await supabase.from('push_tokens').delete().eq('user_id', user.id);
      debugPrint('🗑️ FCM Token өчүрүлдү (user_id=${user.id})');
    } catch (e) {
      debugPrint('❌ Token өчүрүү катасы: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ACCESS TOKEN (Google Service Account)
  // ─────────────────────────────────────────────────────────────
  Future<String?> _getAccessToken() async {
    try {
      final jsonString = await rootBundle.loadString('service_account.json');
      final json = jsonDecode(jsonString);
      final accountCredentials = ServiceAccountCredentials.fromJson(json);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await clientViaServiceAccount(accountCredentials, scopes);
      final token = client.credentials.accessToken.data;
      client.close();
      return token;
    } catch (e) {
      debugPrint('❌ Access Token ката: $e');
      return null;
    }
  }

} // ← NotificationService классы бул жерде ЖАБЫЛАТ

// ─────────────────────────────────────────────────────────────
// _ChatScreenProxy — circular import'тан качуу үчүн
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