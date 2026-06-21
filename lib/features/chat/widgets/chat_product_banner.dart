import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/supabase_client.dart';
import '../../../core/utils/image_utils.dart';

class ChatProductBanner extends StatefulWidget {
  final String? productId;
  final String? productName;
  final String? productImage;

  const ChatProductBanner({
    super.key,
    required this.productId,
    this.productName,
    this.productImage,
  });

  @override
  State<ChatProductBanner> createState() => _ChatProductBannerState();
}

class _ChatProductBannerState extends State<ChatProductBanner> {
  Map<String, dynamic>? _product;
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.productId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final row = await supabase
          .from('products')
          .select(
              'id, title, price, discounted_price, images, description, colors, sizes, in_stock, category_id')
          .eq('id', widget.productId!)
          .maybeSingle();
      if (mounted) setState(() {
        _product = row;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _product == null && (widget.productName?.isEmpty ?? true)) {
      return const SizedBox.shrink();
    }

    final loc = AppLocalizations.of(context);

    final name = (_product?['title'] as String?) ?? widget.productName ?? '';
    final images = List<String>.from(_product?['images'] as List? ?? []);
    final imageUrl =
        images.isNotEmpty ? images.first : (widget.productImage ?? '');
    final price = (_product?['price'] as num?)?.toDouble();
    final discounted = (_product?['discounted_price'] as num?)?.toDouble();
    final description = _product?['description'] as String?;
    final colors = List<String>.from(_product?['colors'] as List? ?? []);
    final sizes = List<String>.from(_product?['sizes'] as List? ?? []);
    final inStock = (_product?['in_stock'] as num?)?.toInt();

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFE0B2), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Башкы сап ──
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: toCloudinaryThumb(imageUrl, width: 150),
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                  width: 52,
                                  height: 52,
                                  color: AppColors.grey100),
                              errorWidget: (_, __, ___) => _noImage(),
                            )
                          : _noImage(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Баш белги + складдагы абал
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFD97706),
                                      Color(0xFFEF4444)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  loc.get('banner_product_label'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (inStock != null)
                                Text(
                                  inStock > 0
                                      ? loc.get('in_stock')
                                      : loc.get('out_of_stock'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: inStock > 0
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Аты
                          Text(
                            name,
                            style: AppTextStyles.labelLarge,
                            maxLines: _expanded ? 3 : 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // Баасы
                          if (price != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (discounted != null &&
                                    discounted < price) ...[
                                  Text(
                                    '${discounted.toStringAsFixed(0)} ${loc.get('currency')}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${price.toStringAsFixed(0)} ${loc.get('currency')}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.grey400,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ] else
                                  Text(
                                    '${price.toStringAsFixed(0)} ${loc.get('currency')}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.grey400,
                    ),
                  ],
                ),
              ),
            ),

            // ── Кеңейтилген маалымат ──
            if (_expanded) ...[
              const Divider(height: 1, color: Color(0xFFFFE0B2)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description != null && description.isNotEmpty) ...[
                      _infoRow('📄', loc.get('description'), description),
                      const SizedBox(height: 6),
                    ],
                    if (sizes.isNotEmpty) ...[
                      _infoRow('📏', loc.get('sizes'), sizes.join(' · ')),
                      const SizedBox(height: 6),
                    ],
                    if (colors.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🎨  ',
                              style: TextStyle(fontSize: 13)),
                          Text(
                            '${loc.get('colors')}:  ',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.grey500),
                          ),
                          Expanded(
                            child: Text(
                              colors.join(', '),
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.black),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (inStock != null)
                      _infoRow(
                        '📦',
                        loc.get('banner_stock_label'),
                        '$inStock ${loc.get('pcs')}',
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String emoji, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$emoji  ', style: const TextStyle(fontSize: 13)),
        Text(
          '$label:  ',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.black),
          ),
        ),
      ],
    );
  }

  Widget _noImage() {
    return Container(
      width: 52,
      height: 52,
      color: AppColors.grey100,
      child: const Icon(Icons.image_outlined,
          color: AppColors.grey300, size: 26),
    );
  }
}
