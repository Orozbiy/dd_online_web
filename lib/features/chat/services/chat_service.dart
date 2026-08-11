import 'package:flutter/foundation.dart';
import '../../../core/supabase_client.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatService {
  final Map<String, Map<String, dynamic>> _productCache = {};
  final Map<String, String>  _storeCache  = {};
  final Map<String, String?> _nameCache   = {};
  final Map<String, String?> _avatarCache = {};

  // ════════════════════════════════════════════════════
  // ЧАТ ТАБУУ / ТҮЗҮҮ
  // ════════════════════════════════════════════════════

  Future<String> getOrCreateChat({
    required String buyerId,
    required String sellerId,
    required String productId,
  }) async {
    final existing = await supabase
        .from('chats')
        .select('id')
        .eq('buyer_id',   buyerId)
        .eq('seller_id',  sellerId)
        .eq('product_id', productId)
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    final inserted = await supabase
        .from('chats')
        .insert({
          'buyer_id':     buyerId,
          'seller_id':    sellerId,
          'product_id':   productId,
          'last_message': '',
        })
        .select('id')
        .single();

    return inserted['id'] as String;
  }

  // ════════════════════════════════════════════════════
  // БИЛДИРҮҮ ЖӨНӨТҮҮ
  // ════════════════════════════════════════════════════

 Future<void> sendMessage({
  required String chatId,
  required String senderId,
  String? text,
  String? imageUrl,
  String? audioUrl,
  int?    audioDuration,
  String? replyToId,
  String? replyToText,
  required bool senderIsBuyer,
}) async {
  final messageText = text ?? (imageUrl != null ? '🖼️ Сүрөт' : '🎵 Үн');
  final unreadCol   = senderIsBuyer ? 'seller_unread' : 'buyer_unread';

  await Future.wait([
    supabase.from('messages').insert({
      'chat_id':        chatId,
      'sender_id':      senderId,
      'text':           text,
      'image_url':      imageUrl,
      'audio_url':      audioUrl,
      'audio_duration': audioDuration,
      'is_read':        false,
      if (replyToId   != null) 'reply_to_id':   replyToId,
      if (replyToText != null) 'reply_to_text': replyToText,
    }),
    supabase.from('chats').update({
      'last_message':    messageText,
      'last_message_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', chatId),
    supabase.rpc('increment_chat_unread', params: {
      'p_chat_id': chatId,
      'p_column':  unreadCol,
    }),
  ]);
}

  // ════════════════════════════════════════════════════
  // ОКУЛДУ ДЕГЕН БЕЛГИЛӨӨ
  // ════════════════════════════════════════════════════

  Future<void> markAsRead({
    required String chatId,
    required String myUserId,
    required bool   readerIsBuyer,
  }) async {
    try {
      await Future.wait([
        supabase.from('chats').update({
          if (readerIsBuyer)  'buyer_unread':  0,
          if (!readerIsBuyer) 'seller_unread': 0,
        }).eq('id', chatId),
        supabase.from('messages')
            .update({'is_read': true})
            .eq('chat_id',    chatId)
            .eq('is_read',    false)
            .neq('sender_id', myUserId),
      ]);
    } catch (e) {
      debugPrint('❌ markAsRead ката: $e');
    }
  }

  // ════════════════════════════════════════════════════
  // SOFT-DELETE
  // ════════════════════════════════════════════════════

  Future<void> deleteChat(String chatId, {required bool isSeller}) async {
    try {
      final field = isSeller ? 'deleted_for_seller' : 'deleted_for_buyer';
      await supabase.from('chats').update({field: true}).eq('id', chatId);
    } catch (e) {
      debugPrint('❌ deleteChat ката: $e');
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════
  // ТАНДАЛГАН БИЛДИРҮҮЛӨРДҮ ӨЧҮРҮҮ
  // ════════════════════════════════════════════════════

  Future<void> deleteMessages(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    await supabase.from('messages').delete().inFilter('id', messageIds);
  }

  // ════════════════════════════════════════════════════
  // БИЛДИРҮҮНҮ ӨЗГӨРТҮҮ ✅ ЖАЙ
  // ════════════════════════════════════════════════════

  Future<void> editMessage({
    required String messageId,
    required String newText,
  }) async {
    try {
      await supabase.from('messages').update({
        'text':      newText,
        'is_edited': true,
        'edited_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', messageId);
    } catch (e) {
      debugPrint('❌ editMessage ката: $e');
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════
  // БИЛДИРҮҮЛӨР СТРИМУ
  // ════════════════════════════════════════════════════

  Stream<List<MessageModel>> messagesStream(String chatId) {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map((r) => MessageModel.fromMap(r)).toList());
  }

  // ════════════════════════════════════════════════════
  // ЧАТТАР СТРИМДЕРИ
  // ════════════════════════════════════════════════════

  Stream<List<ChatModel>> buyerChatsStream(String buyerId) {
    return supabase
        .from('chats')
        .stream(primaryKey: ['id'])
        .eq('buyer_id', buyerId)
        .order('last_message_at', ascending: false)
        .asyncMap((rows) {
          final f = rows.where((r) => r['deleted_for_buyer'] != true).toList();
          return _enrichChats(f, isSeller: false);
        });
  }

  Stream<List<ChatModel>> sellerChatsStream(String sellerId) {
    return supabase
        .from('chats')
        .stream(primaryKey: ['id'])
        .eq('seller_id', sellerId)
        .order('last_message_at', ascending: false)
        .asyncMap((rows) {
          final f = rows.where((r) => r['deleted_for_seller'] != true).toList();
          return _enrichChats(f, isSeller: true);
        });
  }

  // ════════════════════════════════════════════════════
  // BATCH ENRICH
  // ════════════════════════════════════════════════════

  Future<List<ChatModel>> _enrichChats(
    List<Map<String, dynamic>> rows, {
    required bool isSeller,
  }) async {
    if (rows.isEmpty) return [];

    final missingProductIds = <String>{};
    final missingSellerIds  = <String>{};
    final missingUserIds    = <String>{};

    for (final row in rows) {
      final pid = row['product_id'] as String?;
      if (pid != null && !_productCache.containsKey(pid)) {
        missingProductIds.add(pid);
      }

      final sid = row['seller_id'] as String? ?? '';
      if ((row['seller_name'] as String? ?? '').isEmpty &&
          !_storeCache.containsKey(sid)) {
        missingSellerIds.add(sid);
      }

      final buyId = row['buyer_id']  as String? ?? '';
      final selId = row['seller_id'] as String? ?? '';

      final buyerNameMissing   = !_nameCache.containsKey(buyId)   || _nameCache[buyId] == null;
      final buyerAvatarMissing = !_avatarCache.containsKey(buyId) || _avatarCache[buyId] == null;
      final sellerAvatarMissing= !_avatarCache.containsKey(selId) || _avatarCache[selId] == null;

      if (buyerNameMissing || buyerAvatarMissing) missingUserIds.add(buyId);
      if (sellerAvatarMissing) missingUserIds.add(selId);
    }

    await Future.wait([
      if (missingProductIds.isNotEmpty)
        supabase
            .from('products')
            .select('id, title, images')
            .inFilter('id', missingProductIds.toList())
            .then((list) {
              for (final p in list) {
                _productCache[p['id'] as String] = p;
              }
            }).catchError((e) {
              debugPrint('❌ products batch ката: $e');
            }),

      if (missingSellerIds.isNotEmpty)
        supabase
            .from('stores')
            .select('owner_id, store_name')
            .inFilter('owner_id', missingSellerIds.toList())
            .then((list) {
              for (final s in list) {
                _storeCache[s['owner_id'] as String] =
                    s['store_name'] as String? ?? '';
              }
              for (final id in missingSellerIds) {
                _storeCache.putIfAbsent(id, () => '');
              }
            }).catchError((e) {
              debugPrint('❌ stores batch ката: $e');
            }),

      if (missingUserIds.isNotEmpty)
        supabase
            .from('profiles')
            .select('id, full_name, avatar_url')
            .inFilter('id', missingUserIds.toList())
            .then((list) {
              for (final p in list) {
                final uid    = p['id']         as String;
                final name   = p['full_name']  as String?;
                final avatar = p['avatar_url'] as String?;
                _nameCache[uid]   = name;
                _avatarCache[uid] = avatar;
              }
              for (final uid in missingUserIds) {
                if (!_nameCache.containsKey(uid))   _nameCache[uid]   = null;
                if (!_avatarCache.containsKey(uid)) _avatarCache[uid] = null;
              }
            }).catchError((e) {
              debugPrint('❌ profiles batch ката: $e');
            }),
    ]);

    final result = <ChatModel>[];

    for (final row in rows) {
      final enriched = Map<String, dynamic>.from(row);

      final pid = row['product_id'] as String?;
      if (pid != null && _productCache.containsKey(pid)) {
        enriched['products'] = _productCache[pid];
      }

      final sid = row['seller_id'] as String? ?? '';
      if ((row['seller_name'] as String? ?? '').isEmpty &&
          _storeCache.containsKey(sid)) {
        enriched['seller_name'] = _storeCache[sid];
      }

      final buyId = row['buyer_id'] as String? ?? '';
      final buyerName = _nameCache[buyId];
      if (buyerName != null && buyerName.isNotEmpty) {
        enriched['buyer_name'] = buyerName;
      }

      final selId = row['seller_id'] as String? ?? '';
      final buyerAvatar  = _avatarCache[buyId];
      final sellerAvatar = _avatarCache[selId];
      if (buyerAvatar  != null) enriched['buyer_avatar']  = buyerAvatar;
      if (sellerAvatar != null) enriched['seller_avatar'] = sellerAvatar;

      result.add(ChatModel.fromMap(enriched, isSeller: isSeller));
    }

    return result;
  }

  // ════════════════════════════════════════════════════
  // КЭШТИ ТАЗАЛОО
  // ════════════════════════════════════════════════════

  void clearCache() {
    _productCache.clear();
    _storeCache.clear();
    _nameCache.clear();
    _avatarCache.clear();
    debugPrint('🧹 ChatService кэш тазаланды');
  }
}