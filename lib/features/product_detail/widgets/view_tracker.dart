// ═══════════════════════════════════════════════════════════════
// lib/features/product_detail/widgets/view_tracker.dart
//
// ProductDetailScreen initState'инде чакырылат:
//   ViewTracker.track(productId: widget.product.id);
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import '../../../core/supabase_client.dart';

class ViewTracker {
  ViewTracker._();

  /// Товарды ачканда чакыр.
  /// Кирген колдонуучу болсо: views_count +1, ар 3де keys_count +1
  static Future<void> track({required String productId}) async {
    final user = supabase.auth.currentUser;
    if (user == null) return; // кирбеген колдонуучуга эсеп жок

    try {
      await supabase.rpc('increment_product_view', params: {
        'p_user_id':    user.id,
        'p_product_id': productId,
      });
      debugPrint('👁 ViewTracker: view tracked → $productId');
    } catch (e) {
      debugPrint('⚠️ ViewTracker ката: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// product_detail_screen.dart ичинде колдонуу:
// ═══════════════════════════════════════════════════════════════
/*
// Импорт кош:
import '../widgets/view_tracker.dart';
import '../widgets/buyer_leaderboard.dart';

// initState ичине кош:
@override
void initState() {
  super.initState();
  _product = widget.product;
  _loadFullProductData();
  // ✅ ЖАҢЫ: Көрүү санын жаңыртуу
  ViewTracker.track(productId: widget.product.id);
}

// ProductDetailScreen'де "Тизмеге кир" баскычын кош:
// Мисалы, баа бөлүмүнүн астына же AppBar actions'ка:

GestureDetector(
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BuyerLeaderboard(productId: _product.id),
    ),
  ),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8F0),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('🏆', style: TextStyle(fontSize: 16)),
      const SizedBox(width: 6),
      Text(
        'Алуучулар тизмеги',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ]),
  ),
),
*/
