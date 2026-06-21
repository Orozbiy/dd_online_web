import 'package:flutter/foundation.dart';
import '../../../core/supabase_client.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

/// Optimized ChatService
/// - Batch запростор (N чат = 4 запрос, эмес 4N)
/// - Параллел Future.wait()
/// - Сессия кэши (кайра жүктөбөйт)
/// - Buyer Google атын туура алат
class ChatService {
  // ── Сессия кэши ────────────────────────────────────────
  final Map<String, Map<String, dynamic>> _productCache = {};
  final Map<String, String>  _storeCache  = {}; // owner_id → store_name
  final Map<String, String?> _nameCache   = {}; // user_id  → full_name
  final Map<String, String?> _avatarCache = {}; // user_id  → avatar_url

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
  }) async {
    await supabase.from('messages').insert({
      'chat_id':        chatId,
      'sender_id':      senderId,
      'text':           text,
      'image_url':      imageUrl,
      'audio_url':      audioUrl,
      'audio_duration': audioDuration,
      'is_read':        false,
      if (replyToId   != null) 'reply_to_id':   replyToId,
      if (replyToText != null) 'reply_to_text': replyToText,
    });
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

    // ── 1. Кэште жок же null болгон ID'лерди чогулт ──
    final missingProductIds = <String>{};
    final missingSellerIds  = <String>{};
    final missingUserIds    = <String>{};

    for (final row in rows) {
      // Продукт
      final pid = row['product_id'] as String?;
      if (pid != null && !_productCache.containsKey(pid)) {
        missingProductIds.add(pid);
      }

      // Дүкөн аты
      final sid = row['seller_id'] as String? ?? '';
      if ((row['seller_name'] as String? ?? '').isEmpty &&
          !_storeCache.containsKey(sid)) {
        missingSellerIds.add(sid);
      }

      final buyId = row['buyer_id']  as String? ?? '';
      final selId = row['seller_id'] as String? ?? '';

      // ✅ ОҢДОО: null болсо да кайра суранат
      // Мурда: containsKey(buyId) → null болсо да өтпөй калчу
      // Азыр: мааниси null же жок болсо — кайра запрос жасайт
      final buyerNameMissing   = !_nameCache.containsKey(buyId)   || _nameCache[buyId] == null;
      final buyerAvatarMissing = !_avatarCache.containsKey(buyId) || _avatarCache[buyId] == null;
      final sellerAvatarMissing= !_avatarCache.containsKey(selId) || _avatarCache[selId] == null;

      if (buyerNameMissing || buyerAvatarMissing) missingUserIds.add(buyId);
      if (sellerAvatarMissing) missingUserIds.add(selId);
    }

    // ── 2. Параллел batch запростор ───────────────────
    await Future.wait([

      // Продукттар
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

      // Дүкөн аттары
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

      // ✅ ОҢДОО: profiles'тен buyer аты + аватары алынат
      // null болгон жазуулар да кайра суралат
      if (missingUserIds.isNotEmpty)
        supabase
            .from('profiles')
            .select('id, full_name, avatar_url')
            .inFilter('id', missingUserIds.toList())
            .then((list) {
              debugPrint('👤 profiles жүктөлдү: ${list.length} колдонуучу');
              for (final p in list) {
                final uid    = p['id']         as String;
                final name   = p['full_name']  as String?;
                final avatar = p['avatar_url'] as String?;
                _nameCache[uid]   = name;
                _avatarCache[uid] = avatar;
                debugPrint('  → $uid: name=$name, avatar=${avatar != null ? "бар" : "жок"}');
              }
              // Базада таптакыр жок болсо гана null деп белгиле
              // (жогоруда мааниси bar болсо эч качан жазылбайт)
              for (final uid in missingUserIds) {
                if (!_nameCache.containsKey(uid))   _nameCache[uid]   = null;
                if (!_avatarCache.containsKey(uid)) _avatarCache[uid] = null;
              }
            }).catchError((e) {
              debugPrint('❌ profiles batch ката: $e');
            }),
    ]);

    // ── 3. Кэштен ChatModel түзүү ─────────────────────
    final result = <ChatModel>[];

    for (final row in rows) {
      final enriched = Map<String, dynamic>.from(row);

      // Продукт
      final pid = row['product_id'] as String?;
      if (pid != null && _productCache.containsKey(pid)) {
        enriched['products'] = _productCache[pid];
      }

      // Дүкөн аты
      final sid = row['seller_id'] as String? ?? '';
      if ((row['seller_name'] as String? ?? '').isEmpty &&
          _storeCache.containsKey(sid)) {
        enriched['seller_name'] = _storeCache[sid];
      }

      // ✅ Buyer Google аты — null болбосо гана жазат
      final buyId = row['buyer_id'] as String? ?? '';
      final buyerName = _nameCache[buyId];
      if (buyerName != null && buyerName.isNotEmpty) {
        enriched['buyer_name'] = buyerName;
        debugPrint('✅ buyer_name коюлду: $buyerName (buyId=$buyId)');
      } else {
        debugPrint('⚠️ buyer_name жок: buyId=$buyId, cache=${_nameCache[buyId]}');
      }

      // Аватарлар
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
  // КЭШТИ ТАЗАЛОО  (logout болгондо чакыр)
  // ════════════════════════════════════════════════════

  void clearCache() {
    _productCache.clear();
    _storeCache.clear();
    _nameCache.clear();
    _avatarCache.clear();
    debugPrint('🧹 ChatService кэш тазаланды');
  }
}