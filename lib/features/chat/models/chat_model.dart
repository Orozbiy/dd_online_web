// lib/features/chat/models/chat_model.dart

import 'package:flutter/material.dart';
import '../../../core/app_localizations.dart';

class ChatModel {
  final String id;
  final String sellerId;
  final String sellerName;
  final String sellerAvatar;
  final String buyerId;
  final String buyerName;   // ← ЖАЦ: Google аты
  final String buyerAvatar;
  final String? productId;
  final String? productName;
  final String? productImage;
  final String lastMessage;
  final DateTime lastTime;
  final int unreadCount;
  final int sellerUnread;
  final int buyerUnread;
  final bool isOnline;
  final String lastSeen;

  ChatModel({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.sellerAvatar,
    required this.buyerId,
    this.buyerName   = '',
    this.buyerAvatar = '',
    this.productId,
    this.productName,
    this.productImage,
    required this.lastMessage,
    required this.lastTime,
    this.unreadCount  = 0,
    this.sellerUnread = 0,
    this.buyerUnread  = 0,
    this.isOnline     = false,
    this.lastSeen     = '',
  });

  // ── Supabase raw row'дон түзүү ──────────────────────
  factory ChatModel.fromMap(
    Map<String, dynamic> data, {
    required bool isSeller,
  }) {
    final productData  = data['products'] as Map<String, dynamic>?;
    final images       = productData?['images'] as List?;
    final sellerUnread = data['seller_unread'] as int? ?? 0;
    final buyerUnread  = data['buyer_unread']  as int? ?? 0;

    return ChatModel(
      id:           data['id']             as String? ?? '',
      sellerId:     data['seller_id']      as String? ?? '',
      sellerName:   data['seller_name']    as String? ?? '',
      sellerAvatar: data['seller_avatar']  as String? ?? '',
      buyerId:      data['buyer_id']       as String? ?? '',
      buyerName:    data['buyer_name']     as String? ?? '',  // ← Google аты
      buyerAvatar:  data['buyer_avatar']   as String? ?? '',
      productId:    data['product_id']     as String?,
      productName:  productData?['title']  as String?
                    ?? data['product_name'] as String?,
      productImage: (images != null && images.isNotEmpty)
          ? images.first as String
          : data['product_image'] as String?,
      lastMessage:  data['last_message']   as String? ?? '',
      lastTime: data['last_message_at'] != null
          ? DateTime.parse(data['last_message_at'] as String).toLocal()
          : DateTime.now(),
      unreadCount:  isSeller ? sellerUnread : buyerUnread,
      sellerUnread: sellerUnread,
      buyerUnread:  buyerUnread,
      isOnline:     false,
      lastSeen:     '',
    );
  }

  // ── SharedPreferences кэш үчүн ──────────────────────
  Map<String, dynamic> toJson() => {
    'id':              id,
    'seller_id':       sellerId,
    'seller_name':     sellerName,
    'seller_avatar':   sellerAvatar,
    'buyer_id':        buyerId,
    'buyer_name':      buyerName,
    'buyer_avatar':    buyerAvatar,
    'product_id':      productId,
    'product_name':    productName,
    'product_image':   productImage,
    'last_message':    lastMessage,
    'last_message_at': lastTime.toIso8601String(),
    'seller_unread':   sellerUnread,
    'buyer_unread':    buyerUnread,
  };

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    final sellerUnread = json['seller_unread'] as int? ?? 0;
    final buyerUnread  = json['buyer_unread']  as int? ?? 0;
    return ChatModel(
      id:           json['id']            as String? ?? '',
      sellerId:     json['seller_id']     as String? ?? '',
      sellerName:   json['seller_name']   as String? ?? '',
      sellerAvatar: json['seller_avatar'] as String? ?? '',
      buyerId:      json['buyer_id']      as String? ?? '',
      buyerName:    json['buyer_name']    as String? ?? '',
      buyerAvatar:  json['buyer_avatar']  as String? ?? '',
      productId:    json['product_id']    as String?,
      productName:  json['product_name']  as String?,
      productImage: json['product_image'] as String?,
      lastMessage:  json['last_message']  as String? ?? '',
      lastTime: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String).toLocal()
          : DateTime.now(),
      unreadCount:  sellerUnread, // кэш — isSeller жок, жалпы
      sellerUnread: sellerUnread,
      buyerUnread:  buyerUnread,
    );
  }

  // ── Убакытты форматтоо ───────────────────────────────

  /// Тилге жараша убакыт (context керек)
  String formattedTimeLocalized(BuildContext context) {
    final loc  = AppLocalizations.of(context);
    final now  = DateTime.now();
    final diff = now.difference(lastTime);

    // Бүгүн болсо — саат:мүнөт
    if (lastTime.year == now.year &&
        lastTime.month == now.month &&
        lastTime.day == now.day) {
      final h = lastTime.hour.toString().padLeft(2, '0');
      final m = lastTime.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    if (diff.inMinutes < 1)  return loc.get('time_now');
    if (diff.inMinutes < 60) return '${diff.inMinutes} ${loc.get('time_min')}';
    if (diff.inHours   < 24) return '${diff.inHours} ${loc.get('time_hour')}';
    return '${diff.inDays} ${loc.get('time_day')}';
  }

  /// Контексссиз (кыргызча)
  String get formattedTime {
    final now  = DateTime.now();
    final diff = now.difference(lastTime);

    if (lastTime.year == now.year &&
        lastTime.month == now.month &&
        lastTime.day == now.day) {
      final h = lastTime.hour.toString().padLeft(2, '0');
      final m = lastTime.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    if (diff.inMinutes < 1)  return 'Азыр';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин';
    if (diff.inHours   < 24) return '${diff.inHours} саат';
    return '${diff.inDays} күн';
  }
}