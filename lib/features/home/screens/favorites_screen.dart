// lib/features/home/screens/favorites_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/utils/favorites_manager.dart';
import '../../../data/models/product_model.dart';
import '../../product_detail/screens/product_detail_screen.dart';
import '../../../core/supabase_client.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  final _fav = FavoritesManager();
  late TabController _tabController;
  late PageController _pageController;

  List<Map<String, dynamic>> _favoriteStores = [];
  bool _storesLoading = false;

  // ── Selection mode ──
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pageController = PageController();

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      _pageController.animateToPage(
        _tabController.index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      if (_tabController.index == 1 && _favoriteStores.isEmpty) {
        _loadFavoriteStores();
      }
      // Tab алмашканда selection mode өчүр
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
    });

    _fav.addListener(_onFavChanged);
  }

  void _onFavChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    _fav.removeListener(_onFavChanged);
    super.dispose();
  }

  Future<void> _loadFavoriteStores() async {
    final storeIds = _fav.favoriteStoreIds;
    if (storeIds.isEmpty) return;

    setState(() => _storesLoading = true);
    try {
      final rows = await supabase
          .from('stores')
          .select('id, store_name, market, district, owner_id')
          .inFilter('id', storeIds);

      final stores = (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();

      final ownerIds = stores
          .map((s) => s['owner_id'] as String?)
          .whereType<String>()
          .toList();

      if (ownerIds.isNotEmpty) {
        final profiles = await supabase
            .from('profiles')
            .select('id, avatar_url')
            .inFilter('id', ownerIds);

        final avatarMap = {
          for (final p in profiles as List)
            p['id'] as String: p['avatar_url'] as String?
        };

        for (final s in stores) {
          final ownerId = s['owner_id'] as String?;
          s['image_url'] = ownerId != null ? avatarMap[ownerId] : null;
        }
      }

      if (mounted) setState(() {
        _favoriteStores = stores;
        _storesLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _storesLoading = false);
    }
  }

  // ══════════════════════════════════════════════════
  // SELECTION MODE
  // ══════════════════════════════════════════════════

  void _enterSelectionMode(String productId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectionMode = true;
      _selectedIds.add(productId);
    });
  }

  void _toggleSelect(String productId) {
    setState(() {
      if (_selectedIds.contains(productId)) {
        _selectedIds.remove(productId);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(productId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds.addAll(_fav.favorites.map((p) => p.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _deleteSelected() {
    showDialog(
      context: context,
      builder: (_) {
        final loc = AppLocalizations.of(context);
        final isKy = loc.locale.languageCode == 'ky';
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text(
            isKy
                ? '${_selectedIds.length} товарды өчүрөсүзбү?'
                : 'Удалить ${_selectedIds.length} товаров?',
            style: AppTextStyles.headingSmall,
          ),
          content: Text(
            isKy
                ? 'Тандалган товарлар тандамалардан алынат.'
                : 'Выбранные товары будут удалены из избранного.',
            style: AppTextStyles.bodySmall,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isKy ? 'Жок' : 'Отмена',
                style: const TextStyle(color: AppColors.grey500),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                for (final id in _selectedIds) {
                  final product = _fav.favorites
                      .firstWhere((p) => p.id == id,
                          orElse: () => _fav.favorites.first);
                  _fav.toggle(product);
                }
                setState(() {
                  _selectionMode = false;
                  _selectedIds.clear();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isKy ? 'Өчүрүү' : 'Удалить',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isKy = loc.locale.languageCode == 'ky';

    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: _selectionMode
            ? Row(children: [
                GestureDetector(
                  onTap: _clearSelection,
                  child: const Icon(Icons.close, color: AppColors.error),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_selectedIds.length} ${isKy ? 'белгиленди' : 'выбрано'}',
                  style: AppTextStyles.headingSmall,
                ),
              ])
            : Text(
                loc.get('favorites'),
                style: AppTextStyles.headingSmall,
              ),
        actions: _selectionMode
            ? [
                // Баарын тандоо
                TextButton(
                  onPressed: _selectAll,
                  child: Text(
                    isKy ? 'Баары' : 'Все',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
                // Өчүрүү
                IconButton(
                  onPressed:
                      _selectedIds.isEmpty ? null : _deleteSelected,
                  icon: const Icon(Icons.delete_rounded,
                      color: AppColors.error),
                ),
              ]
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildTabBar(loc, isDark, cardColor),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) => _tabController.animateTo(i),
        children: [
          _buildProductsTab(loc, isDark),
          _buildStoresTab(loc, isDark, cardColor),
        ],
      ),
    );
  }

  Widget _buildTabBar(
      AppLocalizations loc, bool isDark, Color cardColor) {
    final activeColor = AppColors.primary;
    final inactiveColor =
        isDark ? const Color(0xFF888888) : AppColors.grey400;

    return Container(
      color: cardColor,
      child: TabBar(
        controller: _tabController,
        labelColor: activeColor,
        unselectedLabelColor: inactiveColor,
        indicatorColor: activeColor,
        indicatorWeight: 3,
        labelStyle: AppTextStyles.labelMedium
            .copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTextStyles.labelMedium,
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite_rounded, size: 18),
                const SizedBox(width: 6),
                Text(loc.get('fav_tab_products')),
                const SizedBox(width: 6),
                _countBadge(_fav.count, activeColor),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.store_rounded, size: 18),
                const SizedBox(width: 6),
                Text(loc.get('fav_tab_stores')),
                const SizedBox(width: 6),
                _countBadge(
                    _fav.favoriteStoreIds.length, AppColors.info),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _countBadge(int count, Color color) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // БЕТ 1: ТОВАРЛАР
  // ══════════════════════════════════════════════════

  Widget _buildProductsTab(AppLocalizations loc, bool isDark) {
    final products = _fav.favorites;

    if (products.isEmpty) {
      return _buildEmpty(
        icon: Icons.favorite_outline,
        title: loc.get('favorites_empty'),
        subtitle: loc.get('favorites_empty_desc'),
        isDark: isDark,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) {
        final product = products[i];
        final isSelected = _selectedIds.contains(product.id);
        final isDark2 =
            Theme.of(context).brightness == Brightness.dark;

        return GestureDetector(
          onTap: () {
            if (_selectionMode) {
              _toggleSelect(product.id);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ProductDetailScreen(product: product)),
              ).then((_) => setState(() {}));
            }
          },
          onLongPress: () {
            if (!_selectionMode) {
              _enterSelectionMode(product.id);
            }
          },
          child: Stack(
            children: [
              // ── Товар карточкасы ──
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected
                      ? Border.all(
                          color: AppColors.primary, width: 2.5)
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _ProductFavCard(
                    product: product,
                    isDark: isDark2,
                  ),
                ),
              ),

              // ── Белгилөө чекити ──
              if (_selectionMode)
                Positioned(
                  top: 8,
                  left: 8,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.grey300,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 16)
                        : null,
                  ),
                ),

              // ── Караңгылатуу overlay ──
              if (_selectionMode && !isSelected)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.black.withValues(alpha: 0.18),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════
  // БЕТ 2: ДҮКӨНДӨР
  // ══════════════════════════════════════════════════

  Widget _buildStoresTab(
      AppLocalizations loc, bool isDark, Color cardColor) {
    if (_storesLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    final storeIds = _fav.favoriteStoreIds;

    if (storeIds.isEmpty) {
      return _buildEmpty(
        icon: Icons.store_mall_directory_outlined,
        title: loc.get('fav_stores_empty'),
        subtitle: loc.get('fav_stores_empty_desc'),
        isDark: isDark,
      );
    }

    if (_favoriteStores.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadFavoriteStores,
          icon: const Icon(Icons.refresh),
          label: Text(loc.get('refresh')),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _favoriteStores.length,
      itemBuilder: (_, i) =>
          _buildStoreCard(_favoriteStores[i], isDark, cardColor),
    );
  }

  Widget _buildStoreCard(
      Map<String, dynamic> store, bool isDark, Color cardColor) {
    final loc = AppLocalizations.of(context);
    final name = store['store_name'] as String? ?? loc.get('shop');
    final market = store['market'] as String? ?? '';
    final district = store['district'] as String? ?? '';
    final imageUrl = store['image_url'] as String?;
    final storeId = store['id'] as String;
    final location =
        [market, district].where((s) => s.isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: imageUrl != null && imageUrl.isNotEmpty
              ? Image.network(imageUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _storePlaceholder())
              : _storePlaceholder(),
        ),
        title: Text(name,
            style: AppTextStyles.labelLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: location.isNotEmpty
            ? Text(location,
                style: AppTextStyles.labelSmall.copyWith(
                    color: isDark
                        ? AppColors.grey500
                        : AppColors.grey400))
            : null,
        trailing: GestureDetector(
          onTap: () {
            _fav.toggleStore(storeId);
            setState(() {
              _favoriteStores
                  .removeWhere((s) => s['id'] == storeId);
            });
          },
          child: const Icon(Icons.favorite_rounded,
              color: AppColors.error, size: 22),
        ),
      ),
    );
  }

  Widget _storePlaceholder() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.store_rounded,
          color: AppColors.primary, size: 26),
    );
  }

  Widget _buildEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 80,
                color:
                    isDark ? AppColors.grey600 : AppColors.grey300),
            const SizedBox(height: 16),
            Text(title,
                style: AppTextStyles.headingSmall.copyWith(
                    color: isDark
                        ? AppColors.grey500
                        : AppColors.grey400),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// Жөнөкөй товар карточкасы
// ══════════════════════════════════════════════════
class _ProductFavCard extends StatelessWidget {
  final ProductModel product;
  final bool isDark;

  const _ProductFavCard(
      {required this.product, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final imageUrl = product.imageUrl;

    return Container(
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Сүрөт
          Expanded(
         child: (imageUrl.isNotEmpty)
                ? Image.network(imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.image_not_supported,
                            color: AppColors.grey300))
                : Container(
                    color: AppColors.grey100,
                    child: const Icon(Icons.image,
                        color: AppColors.grey300, size: 40)),
          ),
          // Маалымат
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: AppTextStyles.labelMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${product.price.toStringAsFixed(0)} сом',
                    style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}