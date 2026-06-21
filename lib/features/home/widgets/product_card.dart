import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../core/utils/favorites_manager.dart';
import '../../../data/models/product_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'negotiation_badge.dart';

class ProductCard extends StatefulWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard>
    with SingleTickerProviderStateMixin {
  final _favorites = FavoritesManager();
  late AnimationController _heartController;
  late Animation<double> _heartAnim;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 30),
    );
    _heartAnim = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _toggleFavorite() {
    _favorites.toggle(widget.product);
    _heartController.forward().then((_) => _heartController.reverse());
    setState(() {});
  }

  String _thumbUrl(String url) {
    if (url.contains('res.cloudinary.com') && url.contains('/upload/')) {
      return url.replaceFirst('/upload/', '/upload/w_400,q_auto,f_auto/');
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final isFav      = _favorites.isFavorite(widget.product.id);
    final rating     = widget.product.rating ?? 0.0;
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final cardColor  = isDark ? const Color(0xFF1E1E1E) : AppColors.white;
    final textColor  = isDark ? Colors.white : Colors.black87;
    final ratingColor = isDark ? Colors.white60 : Colors.black54;
    final shimmerColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);
    final favBgColor = isDark
        ? Colors.black.withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.85);

    final hasDiscount = widget.product.hasPromotion &&
        widget.product.discountedPrice != null &&
        widget.product.discountedPrice! < widget.product.price;
    final discountPct = hasDiscount
        ? ((1 - widget.product.discountedPrice! / widget.product.price) * 100).round()
        : 0;
    final isNew = widget.product.isNew;

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth  = constraints.maxWidth;
            final cardHeight = constraints.maxHeight;
            const infoReserved = 112.0;
            final imgHeight = (cardHeight - infoReserved).clamp(80.0, cardHeight * 0.78);

            return Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  // ── Сүрөт ──
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: SizedBox(
                      width: cardWidth,
                      height: imgHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: shimmerColor),

                          CachedNetworkImage(
                            imageUrl: _thumbUrl(widget.product.imageUrl),
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 250),
                            placeholder: (_, __) => const SizedBox.shrink(),
                            errorWidget: (_, __, ___) => Container(
                              color: shimmerColor,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: isDark ? AppColors.grey600 : AppColors.grey300,
                                size: 32,
                              ),
                            ),
                          ),

                          // Discount badge
                          if (hasDiscount)
                            Positioned(
                              top: 8, left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '-$discountPct%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                          // New badge
                          if (isNew && !hasDiscount)
                            Positioned(
                              top: 8, left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Жаңы',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                          // Favorite button
                          Positioned(
                            top: 6, right: 6,
                            child: GestureDetector(
                              onTap: _toggleFavorite,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: favBgColor,
                                  shape: BoxShape.circle,
                                ),
                                child: ScaleTransition(
                                  scale: _heartAnim,
                                  child: Icon(
                                    isFav ? Icons.favorite : Icons.favorite_border,
                                    color: isFav ? Colors.red : AppColors.grey400,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Маалымат бөлүмү ──
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Аты
                          Text(
                            widget.product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Баа
                          if (hasDiscount) ...[
                            Text(
                              '${widget.product.discountedPrice!.toStringAsFixed(0)} сом',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: AppColors.error,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${widget.product.price.toStringAsFixed(0)} сом',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppColors.grey400,
                                decoration: TextDecoration.lineThrough,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ] else
                            Text(
                              '${widget.product.price.toStringAsFixed(0)} сом',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                          // ✅ Соодалашуу белгиси
                          if (widget.product.hasNegotiation)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: NegotiationBadgeSmall(),
                            ),

                          // Rating
                          if (rating > 0) ...[
                            const SizedBox(height: 3),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 15),
                                const SizedBox(width: 3),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: ratingColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}