import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../config/theme/dd_design.dart';
import '../../../core/app_localizations.dart';
import '../../../core/supabase_client.dart';
import '../../../data/models/product_model.dart';
import '../../product_detail/screens/product_detail_screen.dart';


class PromotionScreen extends StatefulWidget {
  const PromotionScreen({super.key});

  @override
  State<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends State<PromotionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _allProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPromos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPromos() async {
    setState(() => _isLoading = true);
    try {
      final rows = await supabase
          .from('products')
          .select('*, stores(store_name, owner_id)')
          .eq('has_promotion', true);
      setState(() {
        _allProducts = (rows as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _allProducts;
    return _allProducts
        .where((p) => (p['title'] as String? ?? '')
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);
    final inputBg = isDark ? const Color(0xFF2C2C2C) : AppColors.grey100;
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: (isDark ? DD.bgDark : Colors.white).withValues(alpha: isDark ? 0.75 : 0.85),
                border: Border(
                  bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFEDEDF0)),
                ),
              ),
            ),
          ),
        ),
        leading: IconButton(
          icon: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFEDEDF0)),
              boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.black, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                gradient: DD.accentGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: DD.accent.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              loc.get('promo_title'),
              style: AppTextStyles.headingMedium.copyWith(
                color: isDark ? Colors.white : AppColors.black,
                fontSize: 17,
              ),
            ),
          ],
        ),
        foregroundColor: isDark ? Colors.white : AppColors.black,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Search Bar ──
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: loc.get('promo_search_hint'),
                hintStyle: AppTextStyles.bodyMedium,
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.grey400),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const Icon(Icons.close_rounded,
                            color: AppColors.grey400),
                      )
                    : null,
                filled: true,
                fillColor: inputBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2)),
              ),
            ),
          ),

          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${filtered.length} ${loc.get('promo_found')}',
                    style: AppTextStyles.bodySmall),
              ),
            ),

          const SizedBox(height: 8),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('😔', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(
                              _allProducts.isEmpty
                                  ? loc.get('promo_empty')
                                  : loc.get('promo_not_found'),
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPromos,
                        color: AppColors.primary,
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.68,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) =>
                              _PromoCard(product: filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _PromoCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cur = loc.get('currency');
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final discounted =
        (product['discounted_price'] as num?)?.toDouble() ?? price;
    final percent = (product['discount_percent'] as num?)?.toInt() ?? 0;
    final name = product['title'] as String? ?? '';
    final images = List<String>.from(product['images'] as List? ?? []);
    final imageUrl = images.isNotEmpty ? images.first : '';
    final store = product['stores'] as Map<String, dynamic>?;
    final shopName = store?['store_name'] as String? ?? '';

    final productModel = ProductModel.fromMap(product).copyWith(
      discountedPrice: discounted,
      hasPromotion: true,
    );

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: productModel))),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? DD.accent.withOpacity(0.20)
                  : Colors.black.withOpacity(0.07),
              blurRadius: 18,
              offset: const Offset(0, 6),
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // ── Карточка фону ──
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0E0A07) : Colors.white,
                  border: Border.all(
                    color: isDark
                        ? DD.accent.withOpacity(0.22)
                        : const Color(0xFFF0F0F2),
                    width: 1.2,
                  ),
                ),
              ),
              // ── Фон жарык (dark режим) ──
              if (isDark)
                Positioned(
                  top: -20, left: -20,
                  child: Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        DD.accent2.withOpacity(0.15),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Сүрөт + Badge ──
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 150,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: isDark
                                        ? [const Color(0xFF1A0E07), const Color(0xFF120A04)]
                                        : [AppColors.grey100, AppColors.grey200]),
                                  ),
                                  child: const Center(child: Icon(Icons.image_not_supported_outlined, color: AppColors.grey400)),
                                ),
                              )
                            : Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: isDark
                                      ? [const Color(0xFF1A0E07), const Color(0xFF120A04)]
                                      : [AppColors.grey100, AppColors.grey200]),
                                ),
                                child: const Center(child: Icon(Icons.image_outlined, color: AppColors.grey400)),
                              ),
                      ),
                      // ── Фото үстүнө градиент ──
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          height: 55,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      if (percent > 0)
                        Positioned(
                          top: 8, left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: DD.accentGradient,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: [BoxShadow(color: DD.accent.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Text('-$percent%',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      // ── "Аксия" белгиси ──
                      Positioned(
                        bottom: 8, right: 8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.50),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withOpacity(0.15)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_offer_rounded, color: Colors.white70, size: 10),
                                  SizedBox(width: 3),
                                  Text('Аксия', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // ── Маалымат ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: isDark ? Colors.white.withOpacity(0.90) : AppColors.black,
                              fontSize: 13, height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        if (shopName.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.store_rounded, size: 10, color: isDark ? Colors.white30 : AppColors.grey400),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(shopName,
                                    style: AppTextStyles.bodySmall.copyWith(color: isDark ? Colors.white30 : AppColors.grey500),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 7),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${discounted.toStringAsFixed(0)} $cur',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF4ADE80) : AppColors.success,
                                fontSize: 16, fontWeight: FontWeight.w800,
                                shadows: isDark ? [const Shadow(color: Color(0x404ADE80), blurRadius: 8)] : [],
                              ),
                            ),
                            if (percent > 0) ...[
                              const SizedBox(width: 5),
                              Text(
                                '${price.toStringAsFixed(0)}',
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.grey400,
                                    fontSize: 10,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: AppColors.grey400),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}