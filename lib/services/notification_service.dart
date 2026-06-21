import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import '../core/supabase_client.dart';
import '../features/chat/screens/chat_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static String? pendingChatId;

  Future<void> init() async {
    debugPrint('✅ NotificationService (веб) даяр');
  }

  Future<void> handleInitialMessage() async {}

  Future<void> saveMyToken() async {}

  Future<void> clearMyToken() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      await supabase.from('push_tokens').delete().eq('user_id', user.id);
    } catch (e) {
      debugPrint('❌ Token өчүрүү катасы: $e');
    }
  }

  Future<void> navigateToChatPublic(String chatId) => _navigateToChat(chatId);

  Future<void> _navigateToChat(String chatId) async {
    BuildContext? context;
    for (int i = 0; i < 15; i++) {
      context = navigatorKey.currentContext;
      if (context != null) break;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (context == null) return;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final row = await supabase
          .from('chats')
          .select('id, seller_id, buyer_id, product_id, seller_name')
          .eq('id', chatId)
          .maybeSingle();
      if (row == null) return;

      final isSeller = row['seller_id'] == user.id;

      String productName = '';
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
          ? row['buyer_id'] as String? ?? ''
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

      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _buildChatScreen(
          chatId: chatId,
          sellerName: row['seller_name'] as String? ?? 'Сатуучу',
          productName: productName,
          productImage: productImage,
          isSeller: isSeller,
          buyerId: row['buyer_id'] as String? ?? '',
          sellerId: row['seller_id'] as String? ?? '',
          otherAvatarUrl: otherAvatarUrl,
        ),
      ));
    } catch (e) {
      debugPrint('❌ _navigateToChat катасы: $e');
    }
  }

  Widget _buildChatScreen({
    required String chatId,
    required String sellerName,
    required String productName,
    required String productImage,
    required bool isSeller,
    required String buyerId,
    required String sellerId,
    required String otherAvatarUrl,
  }) {
    return _ChatScreenProxy(
      chatId: chatId,
      sellerName: sellerName,
      productName: productName,
      productImage: productImage,
      isSeller: isSeller,
      buyerId: buyerId,
      sellerId: sellerId,
      otherAvatarUrl: otherAvatarUrl,
    );
  }

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
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {'title': senderName, 'body': messageText},
            'data': {
              'chatId': chatId,
              'type': 'chat_message',
              'senderName': senderName,
              'body': messageText,
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Notification жиберилди');
      } else {
        debugPrint('❌ FCM ката: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ sendChatNotification ката: $e');
    }
  }
}

class _ChatScreenProxy extends StatelessWidget {
  final String chatId;
  final String sellerName;
  final String productName;
  final String productImage;
  final bool isSeller;
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
      chatId: chatId,
      sellerName: sellerName,
      productName: productName,
      productImage: productImage,
      isSeller: isSeller,
      buyerId: buyerId,
      sellerId: sellerId,
      otherAvatarUrl: otherAvatarUrl,
    );
  }
}