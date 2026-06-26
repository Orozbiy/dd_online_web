// lib/features/chat/models/message_model.dart
// ✅ message_type кошулду: 'text' | 'image' | 'audio' | 'call_request'

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
  final String  messageType; // ✅ ЖАҢЫ: 'text' | 'image' | 'audio' | 'call_request'
  final String? callStatus;  // ✅ ЖАҢЫ: 'pending' | 'accepted' | 'declined'

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
    this.messageType = 'text',
    this.callStatus,
  });

  bool get isCallRequest => messageType == 'call_request';
  bool get isCallPending  => isCallRequest && (callStatus == 'pending' || callStatus == null);
  bool get isCallAccepted => isCallRequest && callStatus == 'accepted';
  bool get isCallDeclined => isCallRequest && callStatus == 'declined';

  factory MessageModel.fromMap(Map<String, dynamic> data) {
    return MessageModel(
      id:            data['id']             as String? ?? '',
      senderId:      data['sender_id']      as String? ?? '',
      text:          data['text']           as String? ?? '',
      imageUrl:      data['image_url']      as String?,
      audioUrl:      data['audio_url']      as String?,
      audioDuration: (data['audio_duration'] as num?)?.toInt(),
      timestamp: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String).toLocal()
          : DateTime.now(),
      isRead:        data['is_read']        as bool? ?? false,
      replyToId:     data['reply_to_id']    as String?,
      replyToText:   data['reply_to_text']  as String?,
      messageType:   data['message_type']   as String? ?? 'text', // ✅
      callStatus:    data['call_status']    as String?,           // ✅
    );
  }

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
    String?   messageType,
    String?   callStatus,
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
      messageType:   messageType   ?? this.messageType,
      callStatus:    callStatus    ?? this.callStatus,
    );
  }
}
