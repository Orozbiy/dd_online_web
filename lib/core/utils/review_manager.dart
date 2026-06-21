import '../../core/supabase_client.dart';

/// Supabase аркылуу рейтингдерди башкаруу
class ReviewManager {
  static ReviewManager? _instance;
  static ReviewManager get instance {
    _instance ??= ReviewManager._internal();
    return _instance!;
  }
  ReviewManager._internal();

  static const _table = 'reviews';

  // ── Жылдыз сактоо ─────────────────────────────────────────────────────────
  Future<void> submitRating({
    required String productId,
    required int rating,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // 1) reviews таблицасына сактоо (ар бир колдонуучу 1 рейтинг — upsert)
    await supabase.from(_table).upsert({
      'product_id': productId,
      'user_id': user.id,
      'rating': rating,
    }, onConflict: 'product_id,user_id');

    // 2) Орточо рейтингди эсептеп products'та жаңыртуу
    await _updateProductRating(productId);
  }

  Future<void> _updateProductRating(String productId) async {
    try {
      final rows = await supabase
          .from(_table)
          .select('rating')
          .eq('product_id', productId);

      final list = rows as List;
      if (list.isEmpty) return;

      final total = list.fold<double>(
        0,
        (sum, row) => sum + ((row['rating'] as num?)?.toDouble() ?? 0),
      );
      final avg = total / list.length;

      await supabase.from('products').update({
        'rating': double.parse(avg.toStringAsFixed(1)),
        'rating_count': list.length,
      }).eq('id', productId);
    } catch (e) {
      // ignore
    }
  }

  // ── Учурдагы колдонуучунун рейтингин алуу ─────────────────────────────────
  Future<int?> getUserRating(String productId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await supabase
          .from(_table)
          .select('rating')
          .eq('product_id', productId)
          .eq('user_id', user.id)
          .maybeSingle();
      if (row == null) return null;
      return (row['rating'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  // ── Реалдуу убакытта рейтинг стримы ───────────────────────────────────────
  Stream<Map<String, dynamic>> getRatingStream(String productId) {
    return supabase
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('product_id', productId)
        .map((rows) {
      if (rows.isEmpty) return {'avg': 0.0, 'count': 0};
      final total = rows.fold<double>(
        0,
        (sum, row) => sum + ((row['rating'] as num?)?.toDouble() ?? 0),
      );
      final avg = total / rows.length;
      return {
        'avg': double.parse(avg.toStringAsFixed(1)),
        'count': rows.length,
      };
    });
  }
}