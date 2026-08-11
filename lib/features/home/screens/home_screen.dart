import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/utils/favorites_manager.dart';
import '../../../data/models/product_model.dart';
import '../../admin/screens/admin_login_screen.dart';
import '../../chat/screens/chat_list_screen.dart';
import '../../seller/screens/seller_entrance_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../utils/product_repository.dart';
import '../widgets/category_list.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/search_bar_widget.dart';
import '../../home/widgets/app_end_drawer.dart';
import '../../map/screens/map_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../chat/services/chat_service.dart';
import '../../chat/models/chat_model.dart';
import '../../../core/supabase_client.dart';
import '../../product_detail/screens/product_detail_screen.dart';
import '../screens/favorites_screen.dart';
import '../widgets/suggestion_button.dart';
import '../widgets/product_card.dart';
import '../../../services/notification_service.dart';
import '../constants/home_colors.dart';
import '../widgets/home_bottom_nav.dart';
import '../widgets/home_background.dart';
import '../../../core/update_checker.dart';

// ══════════════════════════════════════════════════════
// TAB индекстери
// ══════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════
// COSMIC DARK — түс константалары
// ══════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ProductModel> allProducts = [];
  List<ProductModel> displayedProducts = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedCategoryId = '';
  final fav = FavoritesManager();

  int _adminTapCount = 0;
  int _currentTab = tabHome;
  DateTime? _lastTapTime;

  int _favCount = 0;
  int _totalUnreadChat = 0;
  StreamSubscription<List<ChatModel>>? _chatSub;

  int _offset = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  static const int _pageSize = ProductRepository.pageSize;

  bool _isNearbyMode = false;
  bool _hasUnread = false;
  bool _isLocating = false;
  bool _isSearchMode = false;
  Timer? _debounce;

  ProductFilterMode _filterMode = ProductFilterMode.all;

  FilterOptions _filter = FilterOptions(
    priceRange: const RangeValues(0, 100000),
    selectedSizes: [],
    sortBy: 'default',
  );

  // ── Lalafo-стиль скролл ──
  // Логотип (DD Online) жашынат/чыгат
  // Search+CategoryList дайыма туруктуу
  final ScrollController _scrollController = ScrollController();
  double _lastScrollOffset = 0;
  bool _titleVisible = true;
  bool _navVisible = true;
  double _navBottomPadding = 12;

  // DD Online блогу көрүнөбү

  // DD Online блогунун бийиктиги: toolbar(52px)
  static const double _titleBarHeight = 75.0;

  int get _filterCount {
    int c = 0;
    if (_filter.priceRange.start > 0 || _filter.priceRange.end < 100000) c++;
    if (_filter.selectedSizes.isNotEmpty) c++;
    if (_filter.sortBy != 'default') c++;
    return c;
  }

@override
void initState() {
  super.initState();
  _loadProducts();  // ← бул бар
  _favCount = fav.count;
  _checkUnread();
  fav.addListener(_onFavChanged);
  _subscribeChatUnread();

  _scrollController.addListener(_onScroll);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final bottom = MediaQuery.of(context).padding.bottom;
    setState(() => _navBottomPadding = bottom > 0 ? bottom : 12);
    NotificationService().saveMyToken();

    // ✅ МАЙ КОШУУ — товарлар жүктөлүп бүткөндөн кийин версия текшер
    _checkAppUpdate();
  });
}

// ── Жаңы метод ──
Future<void> _checkAppUpdate() async {
  final langCode = AppLocalizations.of(context).locale.languageCode;
  await UpdateChecker.check(context, langCode);
}

  // ══════════════════════════════════════════════════════
  // LALAFO SCROLL ЛОГИКАСЫ
  // Ылдый скролл → DD Online жашынат
  // Жогору скролл → DD Online кайтат
  // ══════════════════════════════════════════════════════
  void _onScroll() {
    final current = _scrollController.offset;
    final delta = current - _lastScrollOffset;
    _lastScrollOffset = current;

    // Эгер эң жогоруда болсо — логотип дайыма көрүнсүн
    if (current <= 0) {
      if (!_titleVisible) setState(() => _titleVisible = true);
      if (!_navVisible) setState(() => _navVisible = true);
      return;
    }

    if (delta > 2) {
      if (_titleVisible) setState(() => _titleVisible = false);
      if (_navVisible) setState(() => _navVisible = false);
    } else if (delta < -2) {
      if (!_titleVisible) setState(() => _titleVisible = true);
      if (!_navVisible) setState(() => _navVisible = true);
    }
  }

  void _subscribeChatUnread() {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    _chatSub = ChatService().buyerChatsStream(user.id).listen((chats) {
      if (!mounted) return;
      final total = chats.fold<int>(0, (sum, c) => sum + c.buyerUnread);
      setState(() => _totalUnreadChat = total);
    });
  }

  void _onFavChanged() {
    if (mounted) setState(() => _favCount = fav.count);
  }

  Future<void> _checkUnread() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final all = await supabase.from('admin_notifications').select('id');
      if ((all as List).isEmpty) return;
      final allIds = all.map((r) => r['id'] as String).toSet();
      final reads = await supabase
          .from('notification_reads')
          .select('notification_id')
          .eq('user_id', userId);
      final readIds =
          (reads as List).map((r) => r['notification_id'] as String).toSet();
      final hasUnread = allIds.any((id) => !readIds.contains(id));
      if (mounted) setState(() => _hasUnread = hasUnread);
    } catch (_) {}
  }

  @override
  void dispose() {
    fav.removeListener(_onFavChanged);
    _debounce?.cancel();
    _chatSub?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _switchTab(int tab) {
    if (_currentTab == tab) return;
    setState(() {
      _currentTab = tab;
      _navVisible = true;
      _titleVisible = true;
    });
  }

  Future<void> _loadProducts({bool refresh = false}) async {
    if (refresh) ProductRepository.instance.refreshSeed();
    setState(() {
      _isLoading = true;
      _isNearbyMode = false;
      _isSearchMode = false;
      _offset = 0;
      _hasMore = true;
    });
    try {
      final products = await ProductRepository.instance.fetchProducts(
        offset: 0,
        categoryId: _selectedCategoryId.isNotEmpty ? _selectedCategoryId : null,
      );
      products.shuffle();
      _hasMore = products.length == _pageSize;
      _offset = products.length;
      if (mounted) {
        setState(() {
          allProducts = List.from(products);
          displayedProducts = List.from(products);
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      debugPrint('❌ loadProducts: $e');
      if (mounted)
        setState(() {
          allProducts = [];
          displayedProducts = [];
          _isLoading = false;
        });
    }
  }

  Future<void> _loadNewest() async {
    setState(() {
      _isLoading = true;
      _isNearbyMode = false;
      _isSearchMode = false;
      _offset = 0;
      _hasMore = true;
    });
    try {
      final products = await ProductRepository.instance.fetchNewest(
        categoryId: _selectedCategoryId.isNotEmpty ? _selectedCategoryId : null,
        limit: _pageSize,
        offset: 0,
      );
      _hasMore = products.length == _pageSize;
      _offset = products.length;
      if (mounted)
        setState(() {
          allProducts = products;
          displayedProducts = List.from(products);
          _isLoading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPopular() async {
    setState(() {
      _isLoading = true;
      _isNearbyMode = false;
      _isSearchMode = false;
      _offset = 0;
      _hasMore = false;
    });
    try {
      final products = await ProductRepository.instance.fetchPopular(
        categoryId: _selectedCategoryId.isNotEmpty ? _selectedCategoryId : null,
        limit: _pageSize,
      );
      if (mounted)
        setState(() {
          allProducts = products;
          displayedProducts = List.from(products);
          _isLoading = false;
        });
    } catch (e) {
      debugPrint('❌ loadPopular: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onFilterModeChanged(ProductFilterMode mode) {
    setState(() => _filterMode = mode);
    switch (mode) {
      case ProductFilterMode.newest:
        _loadNewest();
        break;
      case ProductFilterMode.popular:
        _loadPopular();
        break;
      case ProductFilterMode.all:
        _loadProducts(refresh: true);
        break;
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore ||
        !_hasMore ||
        _isLoading ||
        _isNearbyMode ||
        _isSearchMode) return;
    _isLoadingMore = true;
    try {
      List<ProductModel> newProducts;
      if (_filterMode == ProductFilterMode.newest) {
        newProducts = await ProductRepository.instance.fetchNewest(
          categoryId:
              _selectedCategoryId.isNotEmpty ? _selectedCategoryId : null,
          limit: _pageSize,
          offset: _offset,
        );
      } else if (_filterMode == ProductFilterMode.popular) {
        newProducts = await ProductRepository.instance.fetchPopular(
          categoryId:
              _selectedCategoryId.isNotEmpty ? _selectedCategoryId : null,
          limit: _pageSize,
          offset: _offset,
        );
      } else {
        newProducts = await ProductRepository.instance.fetchProducts(
          offset: _offset,
          categoryId:
              _selectedCategoryId.isNotEmpty ? _selectedCategoryId : null,
        );
        newProducts.shuffle();
      }
      _hasMore = newProducts.length == _pageSize;
      _offset += newProducts.length;
      if (newProducts.isNotEmpty && mounted) {
        allProducts.addAll(newProducts);
        _applyFilters();
      }
    } catch (e) {
      debugPrint('loadMore KATA: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> _loadNearbyProducts() async {
    setState(() => _isLocating = true);
    final position = await ProductRepository.instance.getCurrentPosition();
    if (position == null) {
      if (mounted) {
        setState(() => _isLocating = false);
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.get('nearby_error')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    setState(() {
      _isLoading = true;
      _isNearbyMode = true;
      _isSearchMode = false;
      _hasMore = false;
      _filterMode = ProductFilterMode.all;
    });
    try {
      final products = await ProductRepository.instance.fetchProductsNearby(
        lat: position.latitude,
        lng: position.longitude,
        categoryId: _selectedCategoryId.isNotEmpty ? _selectedCategoryId : null,
      );
      setState(() {
        allProducts = products;
        displayedProducts = List.from(products);
        _isLoading = false;
        _isLocating = false;
      });
      _applyFilters();
    } catch (e) {
      debugPrint('❌ loadNearbyProducts: $e');
      setState(() {
        _isLoading = false;
        _isLocating = false;
      });
    }
  }

  void _onSearchChanged(String q) {
    _searchQuery = q;
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _isSearchMode = false);
      _loadProducts();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _isSearchMode = true;
        _isNearbyMode = false;
        _hasMore = false;
        _filterMode = ProductFilterMode.all;
      });
      try {
        final results = await ProductRepository.instance.searchProducts(
          query: q,
          categoryId:
              _selectedCategoryId.isNotEmpty ? _selectedCategoryId : null,
        );
        if (!mounted) return;
        setState(() {
          displayedProducts = results;
          _isLoading = false;
        });
      } catch (e) {
        debugPrint('❌ searchProducts: $e');
        if (!mounted) return;
        setState(() {
          displayedProducts = [];
          _isLoading = false;
        });
      }
    });
  }

  void _onSearchClear() {
    _searchQuery = '';
    _debounce?.cancel();
    setState(() => _isSearchMode = false);
    _loadProducts();
  }

  void _applyFilters() {
    if (_isSearchMode) return;
    List<ProductModel> result = List.from(allProducts);
    result = result
        .where((p) =>
            p.price >= _filter.priceRange.start &&
            p.price <= _filter.priceRange.end)
        .toList();
    switch (_filter.sortBy) {
      case 'price_asc':
        result.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        result.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'rating':
        result.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        break;
      default:
        if (_isNearbyMode)
          result.sort((a, b) => (a.distanceKm ?? double.infinity)
              .compareTo(b.distanceKm ?? double.infinity));
        break;
    }
    setState(() => displayedProducts = result);
  }

  void _resetFilters() {
    setState(() {
      _filter = FilterOptions(
          priceRange: const RangeValues(0, 100000),
          selectedSizes: [],
          sortBy: 'default');
    });
    _applyFilters();
  }

  void _openFilter() {
    FilterBottomSheet.show(context, initialOptions: _filter, onApply: (opts) {
      _filter = opts;
      _applyFilters();
    });
  }

  void _showSuggestionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SuggestionButton(),
    );
  }

  void _onTitleTap() {
    final now = DateTime.now();
    if (_lastTapTime == null ||
        now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _adminTapCount = 1;
    } else {
      _adminTapCount++;
    }
    _lastTapTime = now;
    if (_adminTapCount >= 15) {
      _adminTapCount = 0;
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
    }
  }

  String _filterModeLabel(AppLocalizations loc) {
    switch (_filterMode) {
      case ProductFilterMode.newest:
        return loc.get('newest');
      case ProductFilterMode.popular:
        return loc.get('popular');
      case ProductFilterMode.all:
        return '';
    }
  }

  Widget _glassButton({
    required Widget child,
    required VoidCallback onTap,
    bool active = false,
    Color? activeColor,
    double padding = 13,
    double radius = 14,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = activeColor ?? AppColors.primary;
    return _IosBtn(
      onTap: onTap,
      active: active,
      activeColor: color,
      padding: EdgeInsets.all(padding),
      radius: radius,
      isDark: isDark,
      child: child,
    );
  }

  // ══════════════════════════════════════════════════════
  // NAVBAR
  // ══════════════════════════════════════════════════════

  // ══════════════════════════════════════════════════════
  // HOME TAB мазмуну
  // ══════════════════════════════════════════════════════
  Widget _buildHomeTab(AppLocalizations loc, bool isDark) {
    final filterIconColor = isDark ? AppColors.grey400 : AppColors.grey600;
    final dividerColor =
        isDark ? HomeColors.cardBorder : const Color(0xFFEEEEEE);
    final appBarColor = isDark ? HomeColors.card : Colors.white;

    // ── Search + CategoryList бийиктиги (туруктуу sticky блок) ──
    // search(44+8padding) + divider(1) + pills(44) = ~97
    const double _searchCatH = 97.0;

    return _HomeBodySlider(
      onOpenPanel: () => openSidePanel(context),
      child: Stack(
        children: [
          // ════════════════════════════════════════════
          // СКРОЛЛ МАЗМУН — CustomScrollView
          // ════════════════════════════════════════════
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300)
                _loadMoreProducts();
              return false;
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Жогоруда бош орун (sticky header бийиктиги) ──
                // DD Online жашынганда: _searchCatH
                // DD Online көрүнгөндө: _titleBarHeight + _searchCatH
                SliverToBoxAdapter(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    height: _titleVisible
                        ? _titleBarHeight + _searchCatH
                        : _searchCatH,
                  ),
                ),

                // ── Баскычтар сабы ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 25, 14, 8),
                    child: Row(
                      children: [
                        if (_isSearchMode && !_isLoading)
                          Flexible(
                            child: Text(
                              '${displayedProducts.length} ${loc.get('results')}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color:
                                      isDark ? Colors.white70 : Colors.black54),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (_isNearbyMode && !_isLoading)
                          Flexible(
                            child: Text(
                              '📍 ${displayedProducts.length} ${loc.get('nearby_count')}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color:
                                      isDark ? Colors.white70 : Colors.black54),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (_filterMode != ProductFilterMode.all &&
                            !_isSearchMode &&
                            !_isNearbyMode &&
                            !_isLoading)
                          Flexible(
                            child: Text(
                              '${_filterModeLabel(loc)} · ${displayedProducts.length} шт',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color:
                                      isDark ? Colors.white70 : Colors.black54),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        if (!_isSearchMode)
                          _IosLabelBtn(
                            onTap: _showSuggestionSheet,
                            icon: Icons.chat_bubble_outline,
                            label: loc.get('suggestion'),
                            color: AppColors.primary,
                            isDark: isDark,
                          ),
                        const Spacer(),
                        if (!_isSearchMode)
                          _IosLabelBtn(
                            onTap: _isNearbyMode
                                ? _loadNearbyProducts
                                : () {
                                    switch (_filterMode) {
                                      case ProductFilterMode.newest:
                                        _loadNewest();
                                        break;
                                      case ProductFilterMode.popular:
                                        _loadPopular();
                                        break;
                                      case ProductFilterMode.all:
                                        _loadProducts(refresh: true);
                                        break;
                                    }
                                  },
                            icon: Icons.refresh,
                            label: loc.get('refresh'),
                            color: AppColors.primary,
                            isDark: isDark,
                          ),
                        if (_filterCount > 0) ...[
                          const SizedBox(width: 8),
                          _IosLabelBtn(
                            onTap: _resetFilters,
                            icon: Icons.close,
                            label: loc.get('filter_reset'),
                            color: AppColors.error,
                            isDark: isDark,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Товарлар ──
                if (_isLoading)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                              color: AppColors.primary, strokeWidth: 3),
                          const SizedBox(height: 16),
                          Text(loc.get('loading'),
                              style: const TextStyle(
                                  color: AppColors.grey500, fontSize: 14)),
                        ],
                      ),
                    ),
                  )
                else if (displayedProducts.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🔍', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text(
                            _isSearchMode
                                ? '"$_searchQuery" — ${loc.get('no_products')}'
                                : loc.get('no_products'),
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.grey500),
                            textAlign: TextAlign.center,
                          ),
                          if (_isSearchMode) ...[
                            const SizedBox(height: 8),
                            Text(loc.get('search_empty'),
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.grey400)),
                          ],
                        ],
                      ),
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.62,
                        crossAxisSpacing: 5,
                        mainAxisSpacing: 5,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = displayedProducts[index];
                          return RepaintBoundary(
                            key: ValueKey(product.id),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => ProductDetailScreen(
                                          product: product)),
                                ).then((_) => setState(() {})),
                                child: ProductCard(
                                  product: product,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => ProductDetailScreen(
                                            product: product)),
                                  ).then((_) => setState(() {})),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: displayedProducts.length,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ════════════════════════════════════════════
          // STICKY HEADER — экрандын жогору жагында туруктуу
          // ════════════════════════════════════════════
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: appBarColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── DD Online блогу — анимация менен жашынат/чыгат ──
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    height: _titleVisible ? _titleBarHeight : 0,
                    clipBehavior: Clip.hardEdge,
                    decoration: const BoxDecoration(),
                    child: SizedBox(
                      height: _titleBarHeight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Дүкөн баскычы
                            GestureDetector(
                              onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const SellerEntranceScreen()))
                                  .then((_) => setState(() {})),
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(8, 6, 4, 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 9),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF2C1A00)
                                      : Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFFD97706)
                                          .withOpacity(0.55),
                                      width: 1.2),
                                  boxShadow: isDark
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: const Color(0xFFD97706)
                                                .withOpacity(0.15),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                ),
                                child: Text(loc.get('shop'),
                                    style: const TextStyle(
                                        color: Color(0xFFD97706),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ),
                            ),
                            // DD Online логотипи
                            Expanded(
                              child: GestureDetector(
                                onTap: _onTitleTap,
                                child: Center(
                                  child: ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                      colors: [
                                        Color(0xFFD97706),
                                        Color(0xFFEF4444)
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ).createShader(bounds),
                                    child: const Text('DD Online',
                                        style: TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: 1.0)),
                                  ),
                                ),
                              ),
                            ),
                            // Коңгуроо
                            GestureDetector(
                              onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const NotificationsScreen()))
                                  .then((_) => _checkUnread()),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(Icons.notifications_outlined,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.8),
                                        size: 26),
                                    if (_hasUnread)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                              color: AppColors.error,
                                              shape: BoxShape.circle),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Search + баскычтар (дайыма туруктуу) ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: Row(
                      children: [
                        Expanded(
                            child: SearchBarWidget(
                                onChanged: _onSearchChanged,
                                onClear: _onSearchClear)),
                        const SizedBox(width: 8),
                        _glassButton(
                          active: _isNearbyMode,
                          onTap: _isLocating
                              ? () {}
                              : (_isNearbyMode
                                  ? () => _loadProducts(refresh: true)
                                  : _loadNearbyProducts),
                          child: _isLocating
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.primary))
                              : Icon(Icons.near_me_rounded,
                                  color: _isNearbyMode
                                      ? Colors.white
                                      : filterIconColor,
                                  size: 22),
                        ),
                        const SizedBox(width: 8),
                        _glassButton(
                          active: _filterCount > 0,
                          onTap: _openFilter,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(Icons.tune_rounded,
                                  color: _filterCount > 0
                                      ? Colors.white
                                      : filterIconColor,
                                  size: 22),
                              if (_filterCount > 0)
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: Container(
                                    width: 15,
                                    height: 15,
                                    decoration: const BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle),
                                    child: Center(
                                        child: Text('$_filterCount',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold))),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: dividerColor),
                  const SizedBox(height: 6),

                  // ── CategoryList (дайыма туруктуу) ──
                  CategoryList(
                    onCategorySelected: (id) {
                      setState(() => _selectedCategoryId = id);
                      if (_isSearchMode && _searchQuery.isNotEmpty) {
                        _onSearchChanged(_searchQuery);
                      } else if (_isNearbyMode) {
                        _loadNearbyProducts();
                      } else {
                        _onFilterModeChanged(_filterMode);
                      }
                    },
                    onFilterModeChanged: _onFilterModeChanged,
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (_currentTab != tabHome) {
          setState(() => _currentTab = tabHome);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
           
            
HomeBackground(isDark: isDark),
            
           

            // ── Мазмун ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: Stack(
                children: [
                  Offstage(
                    offstage: _currentTab != tabHome,
                    child: _buildHomeTab(loc, isDark),
                  ),
                  Offstage(
                    offstage: _currentTab != tabChat,
                    child: const ChatListScreen(isSeller: false),
                  ),
                  Offstage(
                    offstage: _currentTab != tabMap,
                    child: const MapScreen(),
                  ),
                  Offstage(
                    offstage: _currentTab != tabFavorites,
                    child: const FavoritesScreen(),
                  ),
                  Offstage(
                    offstage: _currentTab != tabSettings,
                    child: const SettingsScreen(),
                  ),
                ],
              ),
            ),

            // ── Калкып турган меню баскычы ──
            if (_currentTab == tabHome)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                right: 16,
                bottom: _navVisible
                    ? HomeBottomNav.navHeight + _navBottomPadding + 16
                    : 32,
                child: _MenuFab(onTap: () => openSidePanel(context)),
              ),

            // ── Navbar ──

            HomeBottomNav(
              currentTab: _currentTab,
              isVisible: _navVisible,
              totalUnreadChat: _totalUnreadChat,
              favCount: _favCount,
              bottomPadding: _navBottomPadding,
              onTabSelected: _switchTab,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// _HomeBodySlider
// ══════════════════════════════════════════════════════
class _HomeBodySlider extends StatefulWidget {
  final Widget child;
  final VoidCallback onOpenPanel;
  const _HomeBodySlider({required this.child, required this.onOpenPanel});

  @override
  State<_HomeBodySlider> createState() => _HomeBodySliderState();
}

class _HomeBodySliderState extends State<_HomeBodySlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _progress = 0.0;
  bool _isDragging = false;
  static const double _openThreshold = 0.3;
  static const double _velocityThreshold = 500.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) {
    _isDragging = true;
    _ctrl.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final sw = MediaQuery.of(context).size.width;
    if (details.delta.dx < 0) {
      setState(() {
        _progress = (_progress - details.delta.dx / sw).clamp(0.0, 1.0);
        _ctrl.value = _progress;
      });
    }
  }

  void _onDragEnd(DragEndDetails details) {
    _isDragging = false;
    final velocity = details.primaryVelocity ?? 0;
    if (_progress > _openThreshold || velocity < -_velocityThreshold) {
      _ctrl
          .animateTo(1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic)
          .then((_) {
        if (!mounted) return;
        setState(() => _progress = 0.0);
        _ctrl.value = 0.0;
        widget.onOpenPanel();
      });
    } else {
      _ctrl
          .animateTo(0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic)
          .then((_) {
        if (!mounted) return;
        setState(() => _progress = 0.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}

class RouteAwareSlide extends StatelessWidget {
  final Widget child;
  const RouteAwareSlide({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}

// ══════════════════════════════════════════════════════
// КАЛКЫП ТУРГАН МАБ БАСКЫЧ
// ══════════════════════════════════════════════════════
class _MenuFab extends StatefulWidget {
  final VoidCallback onTap;
  const _MenuFab({required this.onTap});

  @override
  State<_MenuFab> createState() => _MenuFabState();
}

class _MenuFabState extends State<_MenuFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD97706), Color(0xFFEF4444)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD97706).withOpacity(0.45),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(Icons.chevron_right_rounded,
              color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// iOS стил баскычтары
// ══════════════════════════════════════════════════════
class _IosBtn extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool active;
  final Color activeColor;
  final EdgeInsets padding;
  final double radius;
  final bool isDark;

  const _IosBtn({
    required this.child,
    required this.onTap,
    required this.active,
    required this.activeColor,
    required this.padding,
    required this.radius,
    required this.isDark,
  });

  @override
  State<_IosBtn> createState() => _IosBtnState();
}

class _IosBtnState extends State<_IosBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.active
        ? widget.activeColor
        : (widget.isDark ? HomeColors.btnBg : Colors.white);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: widget.active
                ? [
                    BoxShadow(
                        color: widget.activeColor.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        spreadRadius: -2)
                  ]
                : widget.isDark
                    ? []
                    : [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.09),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                            spreadRadius: -2),
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 3,
                            offset: const Offset(0, 1)),
                      ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _IosLabelBtn extends StatefulWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  const _IosLabelBtn({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  State<_IosLabelBtn> createState() => _IosLabelBtnState();
}

class _IosLabelBtnState extends State<_IosLabelBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? HomeColors.btnBg : Colors.white;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(45),
            boxShadow: widget.isDark
                ? [
                    BoxShadow(
                        color: HomeColors.glow1.withOpacity(0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]
                : [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.09),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        spreadRadius: -2),
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 3,
                        offset: const Offset(0, 1)),
                  ],
            border: widget.isDark
                ? Border.all(color: HomeColors.btnBorder, width: 0.8)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: widget.color, size: 14),
              const SizedBox(width: 5),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.color)),
            ],
          ),
        ),
      ),
    );
  }
}
