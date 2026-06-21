import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatManager {
  static ChatManager? _instance;
  static ChatManager get instance {
    _instance ??= ChatManager._internal();
    return _instance!;
  }
  ChatManager._internal();

  final Map<String, List<MessageModel>> _messages = {};
  final List<ChatModel> _chats = [];

  List<ChatModel> getChats() => List.from(_chats);

  List<MessageModel> getMessages(String chatId) =>
      List.from(_messages[chatId] ?? []);

  void sendMessage(String chatId, String text, String senderId) {
    _messages[chatId] ??= [];
    _messages[chatId]!.add(MessageModel(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
      isRead: false,
    ));
  }

  ChatModel startChat({
    required String sellerId,
    required String sellerName,
    required String productId,
    required String productName,
    required String productImage,
  }) {
    final existing = _chats.firstWhere(
      (c) => c.sellerId == sellerId && c.productId == productId,
      orElse: () => ChatModel(
        id: 'chat_${DateTime.now().millisecondsSinceEpoch}',
        sellerId: sellerId,
        sellerName: sellerName,
        sellerAvatar: '',
        buyerId: 'current_user',
        productId: productId,
        productName: productName,
        productImage: productImage,
        lastMessage: '',
        lastTime: DateTime.now(),
        isOnline: true,
        lastSeen: 'Онлайн',
      ),
    );
    if (!_chats.any((c) => c.id == existing.id)) {
      _chats.insert(0, existing);
    }
    return existing;
  }

  int get totalUnread => _chats.fold(0, (sum, c) => sum + c.unreadCount);
}
