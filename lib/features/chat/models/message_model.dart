// lib/features/chat/models/message_model.dart

class MessageModel {
  final String  id;
  final String  senderId;
  final String  text;
  final String? imageUrl;
  final String? audioUrl;
  final int?    audioDuration;
  final DateTime timestamp;
  final bool    isRead;
  final String? replyToId;
  final String? replyToText;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    this.imageUrl,
    this.audioUrl,
    this.audioDuration,
    required this.timestamp,
    required this.isRead,
    this.replyToId,
    this.replyToText,
  });

  factory MessageModel.fromMap(Map<String, dynamic> data) {
    return MessageModel(
      id:            data['id']             as String? ?? '',
      senderId:      data['sender_id']      as String? ?? '',
      text:          data['text']           as String? ?? '',
      imageUrl:      data['image_url']      as String?,
      audioUrl:      data['audio_url']      as String?,
      audioDuration: (data['audio_duration'] as num?)?.toInt(),
      // ✅ .toLocal() — UTC → жергиликтүү убакыт (туура убакыт)
      timestamp: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String).toLocal()
          : DateTime.now(),
      isRead:        data['is_read']        as bool? ?? false,
      replyToId:     data['reply_to_id']    as String?,
      replyToText:   data['reply_to_text']  as String?,
    );
  }

  /// WhatsApp стилинде: саат:мүнөт (жергиликтүү убакыт)
  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  MessageModel copyWith({
    String?   id,
    String?   senderId,
    String?   text,
    String?   imageUrl,
    String?   audioUrl,
    int?      audioDuration,
    DateTime? timestamp,
    bool?     isRead,
    String?   replyToId,
    String?   replyToText,
  }) {
    return MessageModel(
      id:            id            ?? this.id,
      senderId:      senderId      ?? this.senderId,
      text:          text          ?? this.text,
      imageUrl:      imageUrl      ?? this.imageUrl,
      audioUrl:      audioUrl      ?? this.audioUrl,
      audioDuration: audioDuration ?? this.audioDuration,
      timestamp:     timestamp     ?? this.timestamp,
      isRead:        isRead        ?? this.isRead,
      replyToId:     replyToId     ?? this.replyToId,
      replyToText:   replyToText   ?? this.replyToText,
    );
  }
}