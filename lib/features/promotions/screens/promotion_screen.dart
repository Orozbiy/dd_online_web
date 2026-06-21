import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
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
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final inputBg = isDark ? const Color(0xFF2C2C2C) : AppColors.grey100;
    final dividerColor =
        isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(loc.get('promo_title')),
        backgroundColor: cardColor,
        foregroundColor: isDark ? Colors.white : AppColors.black,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.headingMedium,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: dividerColor),
        ),
      ),
      body: Column(
        children: [
          // ── Search Bar ──
          Container(
            color: cardColor,
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
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
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
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Сүрөт + Badge ──
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    imageUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 150,
                      color: AppColors.grey100,
                      child: const Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              color: AppColors.grey400)),
                    ),
                  ),
                ),
                if (percent > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('-$percent%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            // ── Маалымат ──
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: AppTextStyles.labelLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  if (shopName.isNotEmpty)
                    Text(shopName,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.grey500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(
                    '${discounted.toStringAsFixed(0)} $cur',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.success),
                  ),
                  Text(
                    '${price.toStringAsFixed(0)} $cur',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.grey400,
                        decoration: TextDecoration.lineThrough),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
