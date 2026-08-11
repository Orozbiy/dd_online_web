import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../core/utils/favorites_manager.dart';
import '../../../data/models/product_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'negotiation_badge.dart';

// Cosmic Dark
class _CardC {
  static const card = Color(0xFF14162A);
  static const cardBorder = Color(0xFF2A2560);
  static const favBg = Color(0xFF1C1E38);
  static const shimmer = Color(0xFF1E2040);
}

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
      return url.replaceFirst('/upload/', '/upload/w_300,q_auto,f_auto/');
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final isFav = _favorites.isFavorite(widget.product.id);
    final rating = widget.product.rating ?? 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final ratingColor = isDark ? Colors.white60 : Colors.black54;
    final shimmerColor = isDark ? _CardC.shimmer : const Color(0xFFE8E8E8);

    final hasDiscount = widget.product.hasPromotion &&
        widget.product.discountedPrice != null &&
        widget.product.discountedPrice! < widget.product.price;
    final discountPct = hasDiscount
        ? ((1 - widget.product.discountedPrice! / widget.product.price) * 100)
            .round()
        : 0;
    final isNew = widget.product.isNew;

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth;
            final cardHeight = constraints.maxHeight;
            const infoReserved = 112.0;
            final imgHeight =
                (cardHeight - infoReserved).clamp(80.0, cardHeight * 0.78);

            return Container(
              decoration: BoxDecoration(
                color: isDark ? _CardC.card : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: isDark
                    ? Border.all(color: _CardC.cardBorder, width: 0.8)
                    : null,
                boxShadow: isDark
                    ? [
                        BoxShadow(
                            color:
                                const Color(0xFF3D2080).withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                          spreadRadius: -3,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // ── Сүрөт ──
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(18)),
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
                              fadeInDuration: const Duration(milliseconds: 100),
                              memCacheWidth: 300,
                              placeholder: (_, __) => const SizedBox.shrink(),
                              errorWidget: (_, __, ___) => Container(
                                color: shimmerColor,
                                child: Icon(Icons.image_not_supported_outlined,
                                    color: isDark
                                        ? Colors.white24
                                        : AppColors.grey300,
                                    size: 32),
                              ),
                            ),

                            // Discount badge
                            if (hasDiscount)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('-$discountPct%',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),

                            // New badge
                            if (isNew && !hasDiscount)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Жаңы',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),

                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: _toggleFavorite,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isDark ? _CardC.favBg : Colors.white,
                                    shape: BoxShape.circle,
                                    border: isDark
                                        ? Border.all(
                                            color: _CardC.cardBorder,
                                            width: 0.8)
                                        : null,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.10),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                        spreadRadius: -1,
                                      ),
                                    ],
                                  ),
                                  child: ScaleTransition(
                                    scale: _heartAnim,
                                    child: Icon(
                                      isFav
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isFav
                                          ? Colors.red
                                          : AppColors.grey400,
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
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (hasDiscount) ...[
                              Text(
                                '${widget.product.price.toStringAsFixed(0)} сом',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: ratingColor,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: ratingColor,
                                ),
                              ),
                              Text(
                                '${widget.product.discountedPrice!.toStringAsFixed(0)} сом',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.error, // ← кызыл болду
                                ),
                              ),
                            ] else ...[
                              Text(
                                '${widget.product.price.toStringAsFixed(0)} сом',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                            const Spacer(),
                            Row(
                              children: [
                                if (rating > 0) ...[
                                  Icon(Icons.star_rounded,
                                      size: 13, color: Colors.amber[600]),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: ratingColor,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (widget.product.hasNegotiation)
                                  const NegotiationBadgeSmall(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ), // ← Column жабылат
              ), // ← Column жабылат
            );
          },
        ),
      ),
    );
  }
}
