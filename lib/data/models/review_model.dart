/// Оценка моделі
class ReviewModel {
  final String userId;
  final String userName;
  final int rating;       // 1-5 жылдыз
  final String comment;
  final DateTime date;

  ReviewModel({
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.date,
  });

  String get formattedDate {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Бүгүн';
    if (diff.inDays == 1) return 'Кечээ';
    if (diff.inDays < 7) return '${diff.inDays} күн мурун';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} жума мурун';
    return '${(diff.inDays / 30).floor()} ай мурун';
  }
}
