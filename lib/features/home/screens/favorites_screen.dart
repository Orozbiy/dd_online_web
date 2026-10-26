// lib/features/home/screens/favorites_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/image_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/dd_design.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/utils/favorites_manager.dart';
import '../../../data/models/product_model.dart';
import '../../product_detail/screens/product_detail_screen.dart';
import '../../store/screens/store_products_screen.dart';
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
                  final product = _fav.favorites.firstWhere(
                    (p) => p.id == id,
                    orElse: () => _fav.favorites.first,
                  );
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

    final bgColor = isDark ? DD.bgDark : DD.bgLight;
    final cardColor = isDark ? const Color(0xFF15120F) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 48),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AppBar(
        backgroundColor: isDark
            ? Colors.black.withOpacity(0.55)
            : Colors.white.withOpacity(0.65),
        elevation: 0,
        automaticallyImplyLeading: false,
        foregroundColor: isDark ? Colors.white : AppColors.black,
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
                style: AppTextStyles.headingMedium.copyWith(
                  color: isDark ? Colors.white : AppColors.black,
                ),
              ),
        actions: _selectionMode
            ? [
                TextButton(
                  onPressed: _selectAll,
                  child: Text(
                    isKy ? 'Баары' : 'Все',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
                IconButton(
                  onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                  icon: const Icon(Icons.delete_rounded, color: AppColors.error),
                ),
              ]
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildTabBar(loc, isDark, cardColor),
        ),
      ),
          ),  // ← BackdropFilter
        ),    // ← ClipRect
      ),      // ← PreferredSize
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

  Widget _buildTabBar(AppLocalizations loc, bool isDark, Color cardColor) {
    final activeColor = DD.accent;
    final inactiveColor = isDark ? const Color(0xFF888888) : AppColors.grey400;

    return Container(
      color: Colors.transparent,
      child: TabBar(
        controller: _tabController,
        labelColor: activeColor,
        unselectedLabelColor: inactiveColor,
        indicatorColor: activeColor,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w600),
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
                _countBadge(_fav.favoriteStoreIds.length, AppColors.info),
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
        borderRadius: BorderRadius.circular(DD.rPill),
      ),
      child: Text(
        '$count',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
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

    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight + 48 + 12;
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(8, topPadding, 8, 24),
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
        final isDark2 = Theme.of(context).brightness == Brightness.dark;

        return GestureDetector(
          onTap: () {
            if (_selectionMode) {
              _toggleSelect(product.id);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: product)),
              ).then((_) => setState(() {}));
            }
          },
          onLongPress: () {
            if (!_selectionMode) _enterSelectionMode(product.id);
          },
          child: Stack(
            children: [
              // ── Товар карточкасы ──
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected
                      ? Border.all(color: AppColors.primary, width: 2.5)
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _ProductFavCard(product: product, isDark: isDark2),
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
                          : (isDark2
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.08)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark2 ? AppColors.grey400 : AppColors.grey500),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
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

  Widget _buildStoresTab(AppLocalizations loc, bool isDark, Color cardColor) {
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

    final topPadding2 = MediaQuery.of(context).padding.top + kToolbarHeight + 48 + 12;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, topPadding2, 16, 24),
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
    final location = [market, district].where((s) => s.isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(DD.rCard),
        border: Border.all(
            color: isDark
                ? DD.accent2.withValues(alpha: 0.14)
                : const Color(0xFFF0F0F2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoreProductsScreen(
                storeId: storeId,
                shopName: name,
                containerNumber: '',
                ownerName: name,
                avatarUrl: imageUrl,
              ),
            ),
          );
        },
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          // ── CachedNetworkImage менен алмаштырылды ──
          child: imageUrl != null && imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  memCacheWidth: 104,
                  fadeInDuration: const Duration(milliseconds: 100),
                  placeholder: (_, __) => _storePlaceholder(),
                  errorWidget: (_, __, ___) => _storePlaceholder(),
                )
              : _storePlaceholder(),
        ),
        title: Text(name,
            style: AppTextStyles.labelLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: location.isNotEmpty
            ? Text(location,
                style: AppTextStyles.labelSmall.copyWith(
                    color: isDark ? AppColors.grey500 : AppColors.grey400))
            : null,
        trailing: GestureDetector(
          onTap: () {
            _fav.toggleStore(storeId);
            setState(() {
              _favoriteStores.removeWhere((s) => s['id'] == storeId);
            });
          },
          child: const Icon(Icons.favorite_rounded,
              color: Color(0xFFEF4444), size: 22),
        ),
      ),
    );
  }

  Widget _storePlaceholder() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: DD.accentGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.store_rounded,
          color: Colors.white, size: 26),
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
                color: isDark ? AppColors.grey600 : AppColors.grey300),
            const SizedBox(height: 16),
            Text(title,
                style: AppTextStyles.headingSmall.copyWith(
                    color: isDark ? AppColors.grey500 : AppColors.grey400),
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
// Товар карточкасы — CachedNetworkImage + Cloudinary
// ══════════════════════════════════════════════════
class _ProductFavCard extends StatelessWidget {
  final ProductModel product;
  final bool isDark;

  const _ProductFavCard({required this.product, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final shimmerColor = isDark ? const Color(0xFF2C2C2C) : AppColors.grey100;
    final thumbUrl = toCloudinaryThumb(product.imageUrl, width: 400);

    return Container(
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Сүрөт ──
          Expanded(
            child: product.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: thumbUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    fadeInDuration: const Duration(milliseconds: 150),
                    placeholder: (_, __) => Container(color: shimmerColor),
                    errorWidget: (_, __, ___) => Container(
                      color: shimmerColor,
                      child: const Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            color: AppColors.grey400, size: 32),
                      ),
                    ),
                  )
                : Container(
                    color: shimmerColor,
                    child: const Center(
                      child: Icon(Icons.image,
                          color: AppColors.grey300, size: 40),
                    ),
                  ),
          ),

          // ── Маалымат ──
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isDark ? Colors.white : AppColors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.price.toStringAsFixed(0)} сом',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}