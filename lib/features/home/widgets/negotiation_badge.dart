// ═══════════════════════════════════════════════════════════════
// lib/features/home/widgets/negotiation_badge.dart
// ProductCard жана ProductDetailScreen'ге кошулат
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../config/theme/app_text_styles.dart';

/// Товар картасына кичинекей белги (compact)
class NegotiationBadgeSmall extends StatelessWidget {
  const NegotiationBadgeSmall({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),        // жашыл фон
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF66BB6A).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🤝', style: TextStyle(fontSize: 10)),
          const SizedBox(width: 3),
          Text(
            'Соодалашуу',
            style: AppTextStyles.labelSmall.copyWith(
              color: const Color(0xFF2E7D32),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// ProductDetail экранына чоңураак белги
class NegotiationBadgeLarge extends StatelessWidget {
  const NegotiationBadgeLarge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF66BB6A).withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Text('🤝', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Соодалашуу бар',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: const Color(0xFF2E7D32),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Сатуучу менен баа боюнча макулдашса болот',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: const Color(0xFF388E3C),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// КОЛДОНУУ МИСАЛДАРЫ
// ═══════════════════════════════════════════════════════════════

/*
─────────────────────────────────────────
1. ProductModel'ге талаа кошуу:
─────────────────────────────────────────
// lib/data/models/product_model.dart ичинде:

class ProductModel {
  // ... бардык учурдагы талаалар ...
  final bool hasNegotiation;   // ← жаңы

  ProductModel({
    // ... учурдагы параметрлер ...
    this.hasNegotiation = false,   // ← жаңы
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final store = json['stores'] as Map<String, dynamic>?;
    return ProductModel(
      // ... учурдагы талаалар ...
      hasNegotiation: (store?['has_negotiation'] as bool?) ?? false,  // ← жаңы
    );
  }
}

─────────────────────────────────────────
2. product_repository.dart — stores select'ке кошуу:
─────────────────────────────────────────
// Учурдагы:
.select('*, stores(store_name, owner_id)')

// Өзгөртүлгөн:
.select('*, stores(store_name, owner_id, has_negotiation)')

─────────────────────────────────────────
3. ProductCard'га кошуу (product_card.dart):
─────────────────────────────────────────
// Баанын астына:
if (widget.product.hasNegotiation)
  const Padding(
    padding: EdgeInsets.only(top: 4),
    child: NegotiationBadgeSmall(),
  ),

─────────────────────────────────────────
4. ProductDetailScreen'ге кошуу:
─────────────────────────────────────────
// _buildPriceSection() же дүкөн маалымат блогунун ичинде:
if (_product.hasNegotiation)
  const Padding(
    padding: EdgeInsets.only(top: 12, bottom: 4),
    child: NegotiationBadgeLarge(),
  ),

─────────────────────────────────────────
5. SellerDashboardScreen'ге NegotiationToggle кошуу:
─────────────────────────────────────────
// _buildMenuItem(...) тизмесинен кийин:
NegotiationToggle(ownerUid: widget.uid),
const SizedBox(height: 12),
*/
