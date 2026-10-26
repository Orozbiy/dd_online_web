import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/utils/favorites_manager.dart';
import '../../../data/models/product_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'negotiation_badge.dart';

// Cosmic Dark
class _CardC {
  static const card       = Color(0xFF14162A);
  static const cardBorder = Color(0xFF2A2560);
  static const favBg      = Color(0xFF1C1E38);
  static const shimmer    = Color(0xFF1E2040);
}

class ProductCard extends StatefulWidget {
  final ProductModel product;
  final VoidCallback onTap;
  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard>
    with TickerProviderStateMixin {
  final _favorites = FavoritesManager();
  late AnimationController _heartController;
  late Animation<double>   _heartAnim;

  // ── Скидка белгиси: чексиз чоңоюп-кичирейип пульсациялайт ──
  late AnimationController _badgePulseController;
  late Animation<double>   _badgePulseAnim;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartAnim = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.elasticOut),
    );

    _badgePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _badgePulseAnim = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _badgePulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    _badgePulseController.dispose();
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
    final isFav       = _favorites.isFavorite(widget.product.id);
    final rating      = widget.product.rating ?? 0.0;
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final textColor   = isDark ? Colors.white           : Colors.black87;
    final subColor    = isDark ? Colors.white60         : Colors.black54;
    final shimmerColor = isDark ? _CardC.shimmer        : const Color(0xFFE8E8E8);

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
      child: Container(
        // ── Карта мазмунуна жараша авто бийиктик ──
        // Эч кандай fixed height жок → mainAxisSize.min аркылуу авто кыскарат
        decoration: BoxDecoration(
          color: isDark ? _CardC.card : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isDark
              ? Border.all(color: _CardC.cardBorder, width: 0.8)
              : null,
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: const Color(0xFF3D2080).withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
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
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            // max: катардагы узун картага чейин созулат (фон толот)
            mainAxisSize: MainAxisSize.max,
            children: [

              // ══════════════════════════════
              // СҮРӨТ — квадрат (1:1)
              // ══════════════════════════════
              AspectRatio(
                aspectRatio: 1.0,
                child: LayoutBuilder(
                  builder: (context, cardConstraints) {
                    // ── Карта туурасы 2/3/4/5 колонкага жараша өзгөрөт —
                    // скидка/"Жаңы" белгиси ошого пропорционалдуу
                    // чоңоюп/кичирейип турушу үчүн масштаб эсептелет ──
                    final double badgeScale = (cardConstraints.maxWidth / 170)
                        .clamp(0.78, 1.25)
                        .toDouble();
                    final badgeFontSize = 14.0 * badgeScale;
                    final badgePadH = 7.0 * badgeScale;
                    final badgePadV = 3.0 * badgeScale;
                    final badgeRadius = 8.0 * badgeScale;

                    return Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: shimmerColor),
                    CachedNetworkImage(
                      imageUrl: _thumbUrl(widget.product.imageUrl),
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 120),
                      memCacheWidth: 300,
                      placeholder: (_, __) => const SizedBox.shrink(),
                      errorWidget: (_, __, ___) => Container(
                        color: shimmerColor,
                        child: Icon(Icons.image_not_supported_outlined,
                            color: isDark ? Colors.white24 : AppColors.grey300,
                            size: 32),
                      ),
                    ),

                    // Скидка badge — чексиз пульсация менен чоңоюп-кичирейет
                    if (hasDiscount)
                      Positioned(
                        top: 8, left: 8,
                        child: ScaleTransition(
                          scale: _badgePulseAnim,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: badgePadH, vertical: badgePadV),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(badgeRadius),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error.withValues(alpha: 0.45),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text('-$discountPct%',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: badgeFontSize,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),

                    // Жаңы badge
                    if (isNew && !hasDiscount)
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: badgePadH, vertical: badgePadV),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(badgeRadius),
                          ),
                          child: Text('Жаңы',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: badgeFontSize,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),

                    // Жүрөк баскычы
                    Positioned(
                      top: 6, right: 6,
                      child: GestureDetector(
                        onTap: _toggleFavorite,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? _CardC.favBg : Colors.white,
                            shape: BoxShape.circle,
                            border: isDark
                                ? Border.all(
                                    color: _CardC.cardBorder, width: 0.8)
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ScaleTransition(
                            scale: _heartAnim,
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? Colors.red : AppColors.grey400,
                              size: 17,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                    );
                  },
                ),
              ),

              // ══════════════════════════════
              // МААЛЫМАТ — авто бийиктик
              // ══════════════════════════════
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // Товар аты — max 2 сап, кыска болсо 1 сапта бітет
                    Text(
                      widget.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,   // ат
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 5),

                    // Баа же Келишим
                    Builder(builder: (context) {
                      final loc = AppLocalizations.of(context);
                      final isWholesale = widget.product.pricingType == 'wholesale';
                      final isNegotiation = isWholesale && widget.product.wholesaleMode == 'negotiation';

                      // Negotiation: баа жок — "Келишим түрүндө  Оптом"
                      if (isNegotiation) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              loc.get('prod_price_negotiation'),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              loc.get('prod_badge_wholesale'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF7C3AED),
                                height: 1.1,
                              ),
                            ),
                          ],
                        );
                      }

                      final pricingLabel = isWholesale
                          ? loc.get('prod_badge_wholesale')
                          : loc.get('prod_badge_retail');
                      final pricingColor = isWholesale
                          ? const Color(0xFF7C3AED)
                          : AppColors.primary;

                      if (hasDiscount) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.product.price.toStringAsFixed(0)} сом',
                              style: TextStyle(
                                fontSize: 15,
                                color: subColor,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: subColor,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${widget.product.discountedPrice!.toStringAsFixed(0)} сом',
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.error,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(pricingLabel,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: pricingColor, height: 1.1)),
                              ],
                            ),
                          ],
                        );
                      } else {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${widget.product.price.toStringAsFixed(0)} сом',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: pricingColor,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(pricingLabel,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: pricingColor, height: 1.1)),
                          ],
                        );
                      }
                    }),

                    // Рейтинг — болгондо гана
                    if (rating > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.star_rounded,
                              size: 16, color: Colors.amber[600]),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.1,
                              color: subColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Торг белгиси — болгондо гана
                    if (widget.product.hasNegotiation) ...[
                      const SizedBox(height: 4),
                      const NegotiationBadgeSmall(),
                    ],
                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}