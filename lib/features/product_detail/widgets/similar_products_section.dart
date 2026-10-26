import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/supabase_client.dart';
import '../../../data/models/product_model.dart';
// Cloudinary URL — сапаты 80%, кичине размер
String _thumbUrl(String url, {int width = 280}) {
  if (url.isEmpty) return url;
  if (!url.contains('cloudinary')) return url;
  return url.replaceFirst(
    '/upload/',
    '/upload/w_$width,q_80,f_auto/',
  );
}

class SimilarProductsSection extends StatefulWidget {
  final List<ProductModel> initialProducts;
  final String currentProductId;
  final String? categoryId;
  final Widget Function(ProductModel product)? productBuilder;

  const SimilarProductsSection({
    super.key,
    required this.initialProducts,
    required this.currentProductId,
    this.categoryId,
    this.productBuilder,
  });

  @override
  State<SimilarProductsSection> createState() => _SimilarProductsSectionState();
}

class _SimilarProductsSectionState extends State<SimilarProductsSection> {
  final List<ProductModel> _products = [];
  bool _loading = false;
  // ── Мурда "акырына жакындаганда дагы жүктөө" логикасы бар эле, бирок
  // GridView.builder shrinkWrap:true менен бардык элементти дароо
  // курат, андыктан шарт кайра-кайра туура келип, чексиз/кайталанган
  // сурам чынжырын жаратчу. Эми бир жолу гана, чектелген санда
  // жүктөйбүз — "чексиз жүктөлүп туруу" багы жоюлат. ──
  static const int _maxItems = 20;

  @override
  void initState() {
    super.initState();
    _products.addAll(widget.initialProducts.take(_maxItems));
    if (_products.length < 4) {
      _load();
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final existingIds = [
        widget.currentProductId,
        ..._products.map((p) => p.id),
      ];

      List<dynamic> data = [];

      // 1. Алгач окшош категориядагы товарлар
      if (widget.categoryId != null && widget.categoryId!.isNotEmpty) {
        data = await supabase
            .from('products')
            .select('*, stores(store_name)')
            .eq('category_id', widget.categoryId!)
            .eq('is_active', true)
            .not('id', 'in', '(${existingIds.join(',')})')
            .limit(_maxItems);
      }

      // 2. Окшош товар жок же аз болсо — башка каалаган товарлар
      if (data.length < _maxItems) {
        final extra = await supabase
            .from('products')
            .select('*, stores(store_name)')
            .eq('is_active', true)
            .not('id', 'in', '(${existingIds.join(',')})')
            .order('views_count', ascending: false)
            .limit(_maxItems - data.length);
        data = [...data, ...extra];
      }

      final newItems = (data)
          .cast<Map<String, dynamic>>()
          .map((row) => ProductModel.fromMap(row))
          .toList();

      if (mounted) {
        setState(() {
          _products.addAll(newItems);
        });
      }
    } catch (e) {
      debugPrint('SimilarProductsSection _load: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_products.isEmpty && !_loading) return const SizedBox.shrink();

    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Аталыш ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            loc.locale.languageCode == 'ru' ? 'Похожие товары' : 'Окшош товарлар',
            style: AppTextStyles.headingMedium,
          ),
        ),

        // ── 2 колонкалуу GRID ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (context, i) => _SimilarProductCard(
              product: _products[i],
              isDark: isDark,
              cur: loc.get('currency'),
              productBuilder: widget.productBuilder,
            ),
          ),
        ),

        // ── Жүктөлүп жатат индикатор ──
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),

        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Жеке карточка ──
class _SimilarProductCard extends StatelessWidget {
  final ProductModel product;
  final bool isDark;
  final String cur;
  final Widget Function(ProductModel)? productBuilder;

  const _SimilarProductCard({
    required this.product,
    required this.isDark,
    required this.cur,
    this.productBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.hasPromotion &&
        product.discountedPrice != null &&
        product.discountedPrice! < product.price;

    final cardColor = isDark ? const Color(0xFF1A1C2E) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A2C3E) : const Color(0xFFE5E7EB);
    final placeholderColor =
        isDark ? const Color(0xFF23253A) : const Color(0xFFF3F4F6);

    return GestureDetector(
      onTap: () {
        final screen = productBuilder?.call(product);
        if (screen != null) {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => screen),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Сүрөт ──
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: _thumbUrl(product.imageUrl),
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 120),
                    placeholder: (_, __) =>
                        Container(color: placeholderColor),
                    errorWidget: (_, __, ___) => Container(
                      color: placeholderColor,
                      child: const Icon(Icons.image_not_supported_outlined,
                          color: AppColors.grey300),
                    ),
                  ),
                  // Скидка badge
                  if (hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '-${((1 - product.discountedPrice! / product.price) * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Маалымат ──
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMedium
                        .copyWith(height: 1.3, fontSize: 15),
                  ),
                  const SizedBox(height: 5),
                  if (hasDiscount) ...[
                    Text(
                      '${product.discountedPrice!.toStringAsFixed(0)} $cur',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      '${product.price.toStringAsFixed(0)} $cur',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.grey400,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: AppColors.grey400,
                      ),
                    ),
                  ] else
                    Text(
                      '${product.price.toStringAsFixed(0)} $cur',
                      style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primary, fontSize: 17),
                    ),
                  if ((product.rating ?? 0) > 0) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 13),
                      const SizedBox(width: 2),
                      Text(
                        product.rating!.toStringAsFixed(1),
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.grey500, fontSize: 16),
                      ),
                      if ((product.ratingCount ?? 0) > 0)
                        Text(
                          ' (${product.ratingCount})',
                          style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.grey400, fontSize: 16),
                        ),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}