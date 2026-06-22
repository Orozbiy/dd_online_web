import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';
import '../../../data/models/product_model.dart';
import '../../home/widgets/product_grid.dart';
import '../../product_detail/screens/product_detail_screen.dart';

class FeaturedScreen extends StatefulWidget {
  const FeaturedScreen({super.key});

  @override
  State<FeaturedScreen> createState() => _FeaturedScreenState();
}

class _FeaturedScreenState extends State<FeaturedScreen> {
  List<ProductModel> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFeaturedProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeaturedProducts() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('products')
          .select('*, stores(store_name, owner_id)')
          .eq('is_featured', true)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final list = (data as List)
          .cast<Map<String, dynamic>>()
          .map((row) => ProductModel.fromMap(row))
          .toList();

      if (mounted) {
        setState(() {
          _products = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ FeaturedScreen loadProducts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ProductModel> get _filtered {
    if (_searchQuery.trim().isEmpty) return _products;
   
    return _products
     
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
  

    final bgColor    = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);
    final cardColor  = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final divColor   = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);
    final inputFill  = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0);
    final titleColor = isDark ? Colors.white : AppColors.black;

    final filtered = _filtered;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Өзгөчө товарлар',
          style: AppTextStyles.headingMedium.copyWith(color: titleColor),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: isDark ? Colors.white70 : AppColors.grey600),
            onPressed: _loadFeaturedProducts,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: divColor),
        ),
      ),
      body: Column(
        children: [
          // ── Издөө ──
          Container(
            color: cardColor,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? Colors.white : AppColors.black),
              decoration: InputDecoration(
                hintText: 'Товар издөө...',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.grey400),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.grey400),
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
                fillColor: inputFill,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 2)),
              ),
            ),
          ),

          // ── Табылган саны ──
          if (!_isLoading && _searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${filtered.length} товар табылды',
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.grey500),
                ),
              ),
            ),

          const SizedBox(height: 4),

          // ── Товарлар ──
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : filtered.isEmpty
                    ? _buildEmpty(isDark)
                    : RefreshIndicator(
                        onRefresh: _loadFeaturedProducts,
                        color: AppColors.primary,
                        child: ProductGrid(
                          products: filtered,
                          onProductTap: (product) => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductDetailScreen(product: product),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'Өзгөчө товар жок',
            style: AppTextStyles.headingSmall.copyWith(
                color: isDark ? Colors.white70 : AppColors.black),
          ),
          const SizedBox(height: 8),
          Text(
            'Сатуучулар азырынча өзгөчө\nтовар белгилеген жок',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.grey500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
