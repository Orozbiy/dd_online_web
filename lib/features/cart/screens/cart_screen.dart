import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../utils/cart_manager.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cart = CartManager.instance;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final items = _cart.items;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: AppColors.black),
        ),
        title: Text(loc.get('cart'), style: AppTextStyles.headingMedium),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(loc.get('cart_clear_title'), style: AppTextStyles.headingSmall),
                    content: Text(loc.get('cart_clear_confirm'), style: AppTextStyles.bodyMedium),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(loc.get('no'), style: const TextStyle(color: AppColors.grey500)),
                      ),
                      TextButton(
                        onPressed: () {
                          _cart.clear();
                          setState(() {});
                          Navigator.pop(context);
                        },
                        child: Text(loc.get('yes'), style: const TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
              },
              child: Text(loc.get('filter_reset'), style: AppTextStyles.labelMedium.copyWith(color: AppColors.error)),
            ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 80, color: AppColors.grey300),
                  const SizedBox(height: 16),
                  Text(loc.get('cart_empty'), style: AppTextStyles.headingSmall.copyWith(color: AppColors.grey400)),
                  const SizedBox(height: 8),
                  Text(loc.get('cart_empty_desc'), style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(loc.get('back_to_products'), style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                item.product.imageUrl,
                                width: 80, height: 80, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 80, height: 80,
                                  color: AppColors.grey100,
                                  child: const Icon(Icons.image_not_supported_outlined, color: AppColors.grey300),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name, style: AppTextStyles.labelLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  if (item.selectedSize != null)
                                    Text('${loc.get('size_label')}: ${item.selectedSize}', style: AppTextStyles.bodySmall),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(item.product.priceFormatted, style: AppTextStyles.headingSmall.copyWith(color: AppColors.primary)),
                                      const Spacer(),
                                      Container(
                                        decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(8)),
                                        child: Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () { _cart.decreaseQuantity(item); setState(() {}); },
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                child: Icon(
                                                  item.quantity == 1 ? Icons.delete_outline : Icons.remove,
                                                  size: 18,
                                                  color: item.quantity == 1 ? AppColors.error : AppColors.grey600,
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              child: Text('${item.quantity}', style: AppTextStyles.headingSmall),
                                            ),
                                            GestureDetector(
                                              onTap: () { _cart.increaseQuantity(item); setState(() {}); },
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                child: const Icon(Icons.add, size: 18, color: AppColors.primary),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(loc.get('items_count'), style: AppTextStyles.bodyMedium),
                          Text('${_cart.totalCount} ${loc.get('pcs')}', style: AppTextStyles.labelLarge),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(loc.get('total_price'), style: AppTextStyles.headingSmall),
                          Text(
                            '${_cart.totalPrice.toStringAsFixed(0)} с',
                            style: AppTextStyles.headingMedium.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Row(children: [
                                const Text('🎉 ', style: TextStyle(fontSize: 24)),
                                Text(loc.get('order_placed'), style: AppTextStyles.headingSmall),
                              ]),
                              content: Text(loc.get('order_placed_desc'), style: AppTextStyles.bodyMedium),
                              actions: [
                                ElevatedButton(
                                  onPressed: () {
                                    _cart.clear();
                                    setState(() {});
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                  child: Text(loc.get('great'), style: const TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(loc.get('checkout'), style: AppTextStyles.headingSmall.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
