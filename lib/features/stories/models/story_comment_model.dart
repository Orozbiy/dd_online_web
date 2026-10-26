class StoryCommentModel {
  final String id;
  final String storyId;
  final String userId;
  final String userName;
  final String? avatarUrl;
  final String text;
  final DateTime createdAt;

  const StoryCommentModel({
    required this.id,
    required this.storyId,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.text,
    required this.createdAt,
  });

  factory StoryCommentModel.fromMap(Map<String, dynamic> m) => StoryCommentModel(
        id: m['id'] as String,
        storyId: m['story_id'] as String,
        userId: m['user_id'] as String,
        userName: (m['user_name'] as String?)?.trim().isNotEmpty == true
            ? m['user_name'] as String
            : 'Колдонуучу',
        avatarUrl: m['avatar_url'] as String?,
        text: m['text'] as String? ?? '',
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}
