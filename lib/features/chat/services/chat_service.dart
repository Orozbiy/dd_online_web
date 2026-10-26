import 'package:flutter/foundation.dart';
import '../../../core/supabase_client.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
class ChatService {
  final Map<String, Map<String, dynamic>> _productCache = {};
  final Map<String, String> _storeCache = {};
  final Map<String, String?> _nameCache = {};
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
        .eq('buyer_id', buyerId)
        .eq('seller_id', sellerId)
        .eq('product_id', productId)
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    // Сатуучунун дүкөн атын ал
    String sellerName = '';
    try {
      final store = await supabase
          .from('stores')
          .select('store_name')
          .eq('owner_id', sellerId)
          .maybeSingle();
      sellerName = store?['store_name'] as String? ?? '';
    } catch (_) {}

    final inserted = await supabase
        .from('chats')
        .insert({
          'buyer_id': buyerId,
          'seller_id': sellerId,
          'product_id': productId,
          'last_message': '',
          'seller_name': sellerName, // ← кош
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
  int? audioDuration,
  String? replyToId,
  String? replyToText,
  required bool senderIsBuyer,
}) async {
  final messageText = text ?? (imageUrl != null ? '🖼️ Сүрөт' : '🎵 Үн');
  final unreadField = senderIsBuyer ? 'seller_unread' : 'buyer_unread';

  // Алуучу мурун чатты өз тарабынан "өчүрсө" (soft-delete), жаны билдирүү
  // келгенде анын тарабынан чат кайра көрүнсүн — тарыхы серверде бузулбай сакталат.
  final recipientDeletedField =
      senderIsBuyer ? 'deleted_for_seller' : 'deleted_for_buyer';

  await Future.wait([
   supabase.from('messages').insert({
  'chat_id':        chatId,
  'sender_id':      senderId,
  'text':           text,
  'image_url':      imageUrl,
  'audio_url':      audioUrl,
  'audio_duration': audioDuration,
  'is_read':        false,
  'is_delivered':   false,  // ← false, алуучу алганда true болот
  if (replyToId != null)   'reply_to_id':   replyToId,
  if (replyToText != null) 'reply_to_text': replyToText,
}),
    supabase.rpc('increment_unread', params: {
      'chat_id':    chatId,
      'unread_field': unreadField,
    }),
    supabase.from('chats').update({
      'last_message':    messageText,
      'last_message_at': DateTime.now().toUtc().toIso8601String(),
      recipientDeletedField: false,
    }).eq('id', chatId),
  ]);
}

  // ════════════════════════════════════════════════════
  // ОКУЛДУ ДЕГЕН БЕЛГИЛӨӨ
  // ════════════════════════════════════════════════════

  Future<void> markAsRead({
    required String chatId,
    required String myUserId,
    required bool readerIsBuyer,
  }) async {
    try {
      await Future.wait([
        supabase.from('chats').update({
          if (readerIsBuyer) 'buyer_unread': 0,
          if (!readerIsBuyer) 'seller_unread': 0,
        }).eq('id', chatId),
        supabase
            .from('messages')
            .update({'is_read': true})
            .eq('chat_id', chatId)
            .eq('is_read', false)
            .neq('sender_id', myUserId),
      ]);
    } catch (e) {
      debugPrint('❌ markAsRead ката: $e');
    }
  }

  // ════════════════════════════════════════════════════
  // SOFT-DELETE — бир тараптык өчүрүү
  // ════════════════════════════════════════════════════
  //
  // МААНИЛҮҮ: мурда бул метод 'messages' жана 'chats' сапта тарын
  // ЭКИ ТАРАПТАН ТЕН биротоло өчүрүп жиберчү — демек экинчи колдонуучу
  // да өз тарабынан чатты жоготуп коёт эле (realtime DELETE аркылуу).
  // Азыр чат ЖАЛГЫЗ ошол колдонуучунун тизмесинен жашырылат
  // (deleted_for_buyer / deleted_for_seller = true), ал эми серверде
  // бардык билдирүүлөр бузулбай сакталат — экинчи тарап өз тарабынан
  // толук тарыхты көрө алат. Эгер экинчи тарап кайра жазса, sendMessage()
  // ичинде бул флаг автоматтык түрдө false кылынып, чат кайра тизмеге чыгат.
  Future<void> deleteChat(String chatId, {required bool isSeller}) async {
    try {
      await supabase.from('chats').update({
        if (isSeller) 'deleted_for_seller': true,
        if (!isSeller) 'deleted_for_buyer': true,
      }).eq('id', chatId);
    } catch (e) {
      debugPrint('❌ deleteChat ката: $e');
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════
  // ТАНДАЛГАН БИЛДИРҮҮЛӨРДҮ ӨЧҮРҮҮ (ЭСКИ — эки тараптан өчүрөт)
  // ════════════════════════════════════════════════════
  //
  // ЭСКЕРТҮҮ: бул метод серверден биротоло өчүрөт — демек экинчи
  // колдонуучунун чатынан да ошол билдирүү жоголот. Азыр колдонмо
  // билдирүү деңгээлиндеги "өчүрүүнү" ChatScreen ичинде ЛОКАЛДУУ
  // (ар колдонуучу үчүн өзүнчө жашыруу) жасайт, бул метод чакырылбайт.
  // Эски чалуулар үчүн гана калтырылды.
  @Deprecated('Экинчи тарапта да өчүрүп жиберет. Ордуна ChatScreen ичиндеги '
      'локалдык жашыруу (_hideMessagesLocally) колдонулат.')
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
        'text': newText,
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

 Stream<List<MessageModel>> messagesStream(String chatId, {int limit = 80}) {
  StreamController<List<MessageModel>>? controller;

  Future<void> fetch() async {
    try {
      // Чат ачылганда БААРЫН эмес, акыркы [limit] билдирүүнү гана алабыз —
      // телефондогу локалдуу кэш баары бир толук тарыхты көрсөтүп турат,
      // бул жерде тек гана жаны/өзгөргөн билдирүүлөрдү дал кылуу үчүн
      // интернеттен алынуучу маалымат көлөмү чектелет.
      final rows = await supabase
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .order('created_at', ascending: false)
          .limit(limit);
      final msgs = (rows as List)
          .map((r) => MessageModel.fromMap(r as Map<String, dynamic>))
          .toList()
          .reversed
          .toList();
      if (controller != null && !controller!.isClosed) {
        controller!.add(msgs);
      }
    } catch (e) {
      debugPrint('❌ messagesStream fetch ката: $e');
    }
  }

  RealtimeChannel? channel;

  controller = StreamController<List<MessageModel>>(
    onListen: () {
      fetch();
      channel = supabase
          .channel('messages_$chatId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'chat_id',
              value: chatId,
            ),
            callback: (_) => fetch(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'chat_id',
              value: chatId,
            ),
            callback: (_) => fetch(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'chat_id',
              value: chatId,
            ),
            callback: (_) => fetch(),
          )
          .subscribe();
    },
    onCancel: () {
      if (channel != null) supabase.removeChannel(channel!);
      controller?.close();
      controller = null;
    },
  );

  return controller!.stream;
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
          final f = rows.where((r) => r['deleted_for_seller'] != true)
          .where((r) => r['product_id'] != null).toList();
          
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
    final missingSellerIds = <String>{};
    final missingUserIds = <String>{};

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

      final buyId = row['buyer_id'] as String? ?? '';
      final selId = row['seller_id'] as String? ?? '';

      final buyerNameMissing = !_nameCache.containsKey(buyId);
      final buyerAvatarMissing = !_avatarCache.containsKey(buyId);
      final sellerAvatarMissing = !_avatarCache.containsKey(selId);

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
            final uid = p['id'] as String;
            final name = p['full_name'] as String?;
            final avatar = p['avatar_url'] as String?;
            _nameCache[uid] = name;
            _avatarCache[uid] = avatar;
          }
          for (final uid in missingUserIds) {
            if (!_nameCache.containsKey(uid)) _nameCache[uid] = null;
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
      final buyerAvatar = _avatarCache[buyId];
      final sellerAvatar = _avatarCache[selId];
      if (buyerAvatar != null) enriched['buyer_avatar'] = buyerAvatar;
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