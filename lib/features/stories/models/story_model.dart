class StoryModel {
  final String id;
  final String mediaUrl;
  final String mediaType;
  final int likesCount;
  final bool isActive;
  final DateTime createdAt;
  final bool isLikedByMe;
  final bool isViewed; // ← ЖАҢЫ

  const StoryModel({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    required this.likesCount,
    required this.isActive,
    required this.createdAt,
    this.isLikedByMe = false,
    this.isViewed = false, // ← ЖАҢЫ
  });

  factory StoryModel.fromMap(Map<String, dynamic> map) {
    return StoryModel(
      id:         map['id']         as String,
      mediaUrl:   map['media_url']  as String,
      mediaType:  map['media_type'] as String? ?? 'image',
      likesCount: (map['likes_count'] as num?)?.toInt() ?? 0,
      isActive:   map['is_active']  as bool? ?? true,
      createdAt:  DateTime.parse(map['created_at'] as String),
      // isViewed SharedPreferences'тен келет, fromMap'та жок
    );
  }

  Map<String, dynamic> toMap() => {
    'media_url':   mediaUrl,
    'media_type':  mediaType,
    'likes_count': likesCount,
    'is_active':   isActive,
  };

  StoryModel copyWith({
    String?   id,
    String?   mediaUrl,
    String?   mediaType,
    int?      likesCount,
    bool?     isActive,
    DateTime? createdAt,
    bool?     isLikedByMe,
    bool?     isViewed, // ← ЖАҢЫ
  }) {
    return StoryModel(
      id:          id          ?? this.id,
      mediaUrl:    mediaUrl    ?? this.mediaUrl,
      mediaType:   mediaType   ?? this.mediaType,
      likesCount:  likesCount  ?? this.likesCount,
      isActive:    isActive    ?? this.isActive,
      createdAt:   createdAt   ?? this.createdAt,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isViewed:    isViewed    ?? this.isViewed, // ← ЖАҢЫ
    );
  }

  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';
}