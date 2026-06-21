import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/supabase_client.dart';
import '../../../core/utils/favorites_manager.dart';
import '../../../data/models/product_model.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/services/chat_service.dart';
import '../widgets/review_section.dart';
import '../widgets/share_widget.dart';
import '../../cart/screens/cart_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/image_utils.dart';


class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _fav = FavoritesManager();
  final _chatService = ChatService();

  bool _chatLoading = false;
  bool _dataLoading = true;
  String selectedSize = '';

  late ProductModel _product;
  String? _sellerUid;
  String? _storeId;
  String _sellerName = '';
  String _shopName = '';
  String _containerNumber = '';
  String _workStart = '';
  String _workEnd = '';
  String _workDays = '';
  List<ProductModel> _similarProducts = [];

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _loadFullProductData();
  }

  Future<void> _loadFullProductData() async {
    try {
      final data = await supabase.from('products').select('*, stores(*)').eq('id', widget.product.id).single();
      if (mounted) {
        setState(() => _product = ProductModel.fromMap(data));
        final storeData = data['stores'] as Map<String, dynamic>?;
        if (storeData != null) {
          setState(() {
            _storeId         = storeData['id'] as String?;
            _sellerUid       = storeData['owner_id'] as String?;
            _shopName        = storeData['store_name'] as String? ?? '';
            _containerNumber = [storeData['market'] as String? ?? '', storeData['district'] as String? ?? ''].where((s) => s.isNotEmpty).join(', ');
            _workStart       = storeData['work_start'] as String? ?? '';
            _workEnd         = storeData['work_end'] as String? ?? '';
            _workDays        = storeData['work_days'] as String? ?? '';
          });
          if (_sellerUid != null) {
            try {
              final profile = await supabase.from('profiles').select('full_name').eq('id', _sellerUid!).single();
              if (mounted) setState(() => _sellerName = profile['full_name'] as String? ?? '');
            } catch (_) {}
          }
        }
      }

      // ✅ View +1 жазуу
      supabase.rpc('increment_product_views', params: {
        'product_id': widget.product.id,
      }).then((_) {
        // views_count экранда жаңыртуу
        if (mounted) {
          setState(() {
            _product = _product.copyWith(viewsCount: _product.viewsCount + 1);
          });
        }
      }).catchError((e) {
        debugPrint('⚠️ increment_product_views: $e');
      });

    } catch (e) {
      debugPrint('❌ _loadFullProductData: $e');
    } finally {
      await _loadSimilarProducts();
      if (mounted) setState(() => _dataLoading = false);
    }
  }

  Future<void> _loadSimilarProducts() async {
    if (_product.category == null || _product.category!.isEmpty) return;
    try {
      final data = await supabase.from('products').select('*, stores(store_name, owner_id)').eq('category_id', _product.category!).eq('is_active', true).limit(10);
      final list = (data as List).cast<Map<String, dynamic>>().where((row) => row['id'] != _product.id).map((row) => ProductModel.fromMap(row)).toList();
      if (mounted) setState(() => _similarProducts = list);
    } catch (e) {
      debugPrint('_loadSimilarProducts: $e');
    }
  }

  Future<void> _openMapNavigation() async {
    final loc = AppLocalizations.of(context);
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) _showSnack(loc.get('location_denied'));
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) await Geolocator.openAppSettings();
      return;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) { await Geolocator.openLocationSettings(); return; }

    double? sellerLat = _product.latitude;
    double? sellerLng = _product.longitude;

    if (sellerLat == null || sellerLng == null) {
      String? storeId = _storeId;
      if (storeId == null) {
        try {
          final row = await supabase.from('products').select('store_id').eq('id', _product.id).single();
          storeId = row['store_id'] as String?;
        } catch (e) { debugPrint('❌ store_id алуу: $e'); }
      }
      if (storeId != null) {
        setState(() => _dataLoading = true);
        try {
          final store = await supabase.from('stores').select('latitude, longitude').eq('id', storeId).single();
          sellerLat = (store['latitude'] as num?)?.toDouble();
          sellerLng = (store['longitude'] as num?)?.toDouble();
        } catch (e) { debugPrint('❌ stores lat/lng: $e'); }
        if (!mounted) return;
        setState(() => _dataLoading = false);
      }
    }

    if (sellerLat == null || sellerLng == null) {
      if (mounted) _showSnack(loc.get('location_unknown'));
      return;
    }

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _NavigationGuideSheet(shopName: _shopName, containerNumber: _containerNumber, sellerLat: sellerLat!, sellerLng: sellerLng!),
    );
  }

  Future<void> _openChat() async {
    final loc = AppLocalizations.of(context);
    if (_sellerUid == null || _sellerUid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.get('seller_no_info')), backgroundColor: AppColors.warning));
      return;
    }
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.get('chat_login_required')), backgroundColor: AppColors.warning));
      return;
    }
    if (user.id == _sellerUid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.get('own_product')), backgroundColor: AppColors.warning));
      return;
    }
    setState(() => _chatLoading = true);
    try {
      final chatId = await _chatService.getOrCreateChat(buyerId: user.id, sellerId: _sellerUid!, productId: _product.id);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
        chatId:       chatId,
        sellerName:   _shopName.isNotEmpty ? _shopName : _sellerName,
        productId:    _product.id,
        productName:  _product.name,
        productImage: _product.imageUrl,
        isSeller:     false,
        buyerId:      user.id,
        sellerId:     _sellerUid!,
      )));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).get('error')}: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _chatLoading = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  bool _isOpenNow() {
    if (_workStart.isEmpty || _workEnd.isEmpty) return false;
    final now = TimeOfDay.now();
    TimeOfDay parse(String t) {
      final p = t.split(':');
      return TimeOfDay(hour: int.tryParse(p[0]) ?? 0, minute: int.tryParse(p[1]) ?? 0);
    }
    final s = parse(_workStart);
    final e = parse(_workEnd);
    final nowMin = now.hour * 60 + now.minute;
    return nowMin >= s.hour * 60 + s.minute && nowMin < e.hour * 60 + e.minute;
  }

  // ✅ ЖАҢЫ: санды форматтоо (1200 → 1.2к)
  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}к';
    return count.toString();
  }

  Widget _buildPriceSection(AppLocalizations loc) {
    final cur = loc.get('currency');
    final hasDiscount = _product.discountedPrice != null && _product.discountedPrice! < _product.price;
    if (hasDiscount) {
      final discounted = _product.discountedPrice!;
      final pct   = ((1 - discounted / _product.price) * 100).round();
      final saved = (_product.price - discounted).toStringAsFixed(0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('${discounted.toStringAsFixed(0)} $cur', style: AppTextStyles.headingLarge.copyWith(color: AppColors.error, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(6)),
              child: Text('-$pct%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text('${_product.price.toStringAsFixed(0)} $cur', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400, decoration: TextDecoration.lineThrough, decorationColor: AppColors.grey400, decorationThickness: 1.5)),
            const SizedBox(width: 8),
            Text('$saved ${loc.get('price_saved')}', style: AppTextStyles.labelSmall.copyWith(color: AppColors.success)),
          ]),
        ],
      );
    }
    return Text('${_product.price.toStringAsFixed(0)} $cur', style: AppTextStyles.headingLarge.copyWith(color: AppColors.primary));
  }

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final isFav  = _fav.isFavorite(_product.id);
    final cur    = loc.get('currency');
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor   = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final chipColor = isDark ? const Color(0xFF2C2C2C) : AppColors.grey50;
    final chipBorder = isDark ? const Color(0xFF3A3A3A) : AppColors.grey200;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: cardColor,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: cardColor.withValues(alpha: 0.9), shape: BoxShape.circle),
                child: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
              ),
            ),
            actions: [
              GestureDetector(
                onTap: () { _fav.toggle(_product); setState(() {}); },
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: cardColor.withValues(alpha: 0.9), shape: BoxShape.circle),
                  child: Padding(padding: const EdgeInsets.all(8), child: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : AppColors.grey600)),
                ),
              ),
              GestureDetector(
                onTap: () => ShareWidget.show(context, _product),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: cardColor.withValues(alpha: 0.9), shape: BoxShape.circle),
                  child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.share_outlined, color: AppColors.grey600)),
                ),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _product.imageUrl.isNotEmpty
                  ? GestureDetector(
                      onTap: () => Navigator.push(context, PageRouteBuilder(
                        opaque: false,
                        barrierColor: Colors.black,
                        transitionDuration: const Duration(milliseconds: 250),
                        pageBuilder: (_, __, ___) => _FullscreenImageScreen(imageUrl: _product.imageUrl, heroTag: 'product_image_${_product.id}'),
                      )),
                      child: Hero(
                        tag: 'product_image_${_product.id}',
                        child: CachedNetworkImage(
                          imageUrl: toCloudinaryThumb(_product.imageUrl, width: 800),
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 150),
                          placeholder: (_, __) => Container(color: AppColors.grey100),
                          errorWidget: (_, __, ___) => Container(color: AppColors.grey100, child: const Icon(Icons.image_not_supported, size: 80, color: AppColors.grey300)),
                        ),
                      ),
                    )
                  : Container(color: AppColors.grey100, child: const Icon(Icons.image, size: 80, color: AppColors.grey300)),
            ),
          ),
          SliverToBoxAdapter(
            child: _dataLoading
                ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Баа + аты ──
                      Container(
                        color: cardColor,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [


                       _buildPriceSection(loc),
const SizedBox(height: 8),

const SizedBox(height: 8),
Text(_product.name, style: AppTextStyles.headingMedium.copyWith(fontSize: 24)),

                            const SizedBox(height: 8),
                            Row(children: [
                              // ── Рейтинг ──
                              if ((_product.rating ?? 0) > 0) ...[
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 2),
                                Text(_product.rating!.toStringAsFixed(1), style: AppTextStyles.labelMedium.copyWith(fontSize: 16)),
                                if ((_product.ratingCount ?? 0) > 0)
                                  Text(' (${_product.ratingCount})', style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey400)),
                              ],
                              const Spacer(),

                              // ✅ ЖАҢЫ: Көрүлгөн саны
                              Icon(Icons.remove_red_eye_outlined, size: 14, color: AppColors.grey400),
                              const SizedBox(width: 3),
                              Text(
                                _formatCount(_product.viewsCount),
                                style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey400),
                              ),
                              const SizedBox(width: 10),

                              // ✅ ЖАҢЫ: Жактырылган саны
                              Icon(Icons.favorite_outline, size: 14, color: Colors.pinkAccent.withValues(alpha: 0.8)),
                              const SizedBox(width: 3),
                              Text(
                                _formatCount(_product.likesCount),
                                style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey400),
                              ),

                              // ── Distance ──
                              if (_product.distanceFormatted.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(_product.distanceFormatted, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
                                  ]),
                                ),
                              ],
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildCharacteristics(loc, cardColor, chipColor, chipBorder),
                      const SizedBox(height: 8),

                      // ── Сүрөттөмө ──
                      if (_product.description != null && _product.description!.isNotEmpty) ...[
                        Container(
                          color: cardColor,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loc.get('description'), style: AppTextStyles.headingSmall),
                              const SizedBox(height: 8),
                              Text(_product.description!, style: AppTextStyles.bodyMedium),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // ── Размер тандоо ──
                      if (_product.sizes.isNotEmpty) ...[
                        Container(
                          color: cardColor,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loc.get('select_size'), style: AppTextStyles.headingSmall),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _product.sizes.map((size) {
                                  final isSel = selectedSize == size;
                                  return GestureDetector(
                                    onTap: () => setState(() => selectedSize = size),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSel ? AppColors.primary : chipColor,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: isSel ? AppColors.primary : chipBorder),
                                      ),
                                      child: Text(size, style: AppTextStyles.labelLarge.copyWith(color: isSel ? Colors.white : theme.colorScheme.onSurface)),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // ── Сатуучу маалыматы ──
                      Container(
                        color: cardColor,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.get('seller'), style: AppTextStyles.headingSmall),
                            const SizedBox(height: 12),
                            if (_shopName.isNotEmpty) ...[
                              _infoRow(Icons.store_outlined, loc.get('shop'), _shopName),
                              const SizedBox(height: 8),
                            ],
                            if (_sellerName.isNotEmpty) ...[
                              _infoRow(Icons.person_outline, loc.get('seller'), _sellerName),
                              const SizedBox(height: 8),
                            ],
                            if (_containerNumber.isNotEmpty) ...[
                              _infoRow(Icons.location_on_outlined, loc.get('container'), _containerNumber, valueColor: AppColors.primary),
                            ],
                            if (_workStart.isNotEmpty && _workEnd.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    color: _isOpenNow() ? const Color(0xFF10B981) : const Color(0xFFF87171),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isOpenNow() ? loc.get('open') : loc.get('closed'),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _isOpenNow() ? const Color(0xFF10B981) : const Color(0xFFF87171)),
                                ),
                                const SizedBox(width: 8),
                                Text('·  ${_workDays.isNotEmpty ? "$_workDays  " : ""}$_workStart — $_workEnd',
                                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.grey400 : const Color(0xFF6B7280))),
                              ]),
                            ],
                            if (_shopName.isEmpty && _sellerName.isEmpty)
                              Text(loc.get('no_info'), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Сатуучуга жазуу ──
                      if (_sellerUid != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _chatLoading ? null : _openChat,
                              icon: _chatLoading
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                                  : const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                              label: Text(loc.get('write_seller'), style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),

                      // ── Окшош товарлар ──
                      if (_similarProducts.isNotEmpty)
                        Container(
                          color: cardColor,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loc.get('similar'), style: AppTextStyles.headingSmall),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 220,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _similarProducts.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                                  itemBuilder: (context, i) {
                                    final p = _similarProducts[i];
                                    final pHasDiscount = p.hasPromotion && p.discountedPrice != null && p.discountedPrice! < p.price;
                                    return GestureDetector(
                                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p))),
                                      child: SizedBox(
                                        width: 140,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: CachedNetworkImage(
                                                imageUrl: toCloudinaryThumb(p.imageUrl, width: 300),
                                                height: 140, width: 140, fit: BoxFit.cover,
                                                fadeInDuration: const Duration(milliseconds: 150),
                                                placeholder: (_, __) => Container(height: 140, width: 140, color: AppColors.grey100),
                                                errorWidget: (_, __, ___) => Container(height: 140, color: AppColors.grey100, child: const Icon(Icons.image_not_supported)),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.labelMedium),
                                            const SizedBox(height: 4),
                                            if (pHasDiscount) ...[
                                              Text('${p.discountedPrice!.toStringAsFixed(0)} $cur', style: AppTextStyles.labelLarge.copyWith(color: AppColors.error, fontWeight: FontWeight.bold)),
                                              Text('${p.price.toStringAsFixed(0)} $cur', style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey400, decoration: TextDecoration.lineThrough)),
                                            ] else
                                              Text('${p.price.toStringAsFixed(0)} $cur', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ReviewSection(productId: _product.id)),
                      const SizedBox(height: 100),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: cardColor,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -3))],
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
              icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.primary),
              tooltip: loc.get('cart'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _openMapNavigation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.navigation_rounded, color: Colors.white),
                label: Text(loc.get('route'), style: AppTextStyles.headingSmall.copyWith(color: Colors.white)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCharacteristics(AppLocalizations loc, Color cardColor, Color chipColor, Color chipBorder) {
    final hasColors = _product.colors.isNotEmpty;
    final hasSizes  = _product.sizes.isNotEmpty;
    final hasStock  = _product.inStock != null;
    if (!hasColors && !hasSizes && !hasStock) return const SizedBox.shrink();

    return Container(
      color: cardColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.get('characteristics'), style: AppTextStyles.headingSmall),
          const SizedBox(height: 12),
          if (hasStock) ...[
            Row(children: [
              Icon((_product.inStock ?? 0) > 0 ? Icons.check_circle_outline : Icons.cancel_outlined,
                  size: 16, color: (_product.inStock ?? 0) > 0 ? AppColors.success : AppColors.error),
              const SizedBox(width: 6),
              Text(
                (_product.inStock ?? 0) > 0
                    ? '${loc.get('in_stock')}: ${_product.inStock} ${loc.get('pcs')}'
                    : loc.get('out_of_stock'),
                style: AppTextStyles.labelMedium.copyWith(color: (_product.inStock ?? 0) > 0 ? AppColors.success : AppColors.error),
              ),
            ]),
            const SizedBox(height: 10),
          ],
          if (hasColors) ...[
            Text('🎨 ${loc.get('colors')}', style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey500)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _product.colors.map((c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: chipBorder)),
              child: Text(c, style: AppTextStyles.labelSmall),
            )).toList()),
            const SizedBox(height: 10),
          ],
          if (hasSizes) ...[
            Text('📐 ${loc.get('sizes')}', style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey500)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _product.sizes.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: chipBorder)),
              child: Text(s, style: AppTextStyles.labelSmall),
            )).toList()),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? valueColor}) {
    final theme = Theme.of(context);
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.grey500),
      const SizedBox(width: 8),
      Text('$label: ', style: AppTextStyles.labelMedium),
      Expanded(child: Text(value, style: AppTextStyles.bodyMedium.copyWith(color: valueColor ?? theme.colorScheme.onSurface, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
    ]);
  }
}

// ══════════════════════════════════════════════════════
// 2ГИС НАВИГАЦИЯ BOTTOM SHEET
// ══════════════════════════════════════════════════════
class _NavigationGuideSheet extends StatefulWidget {
  final String shopName;
  final String containerNumber;
  final double sellerLat;
  final double sellerLng;

  const _NavigationGuideSheet({required this.shopName, required this.containerNumber, required this.sellerLat, required this.sellerLng});

  @override
  State<_NavigationGuideSheet> createState() => _NavigationGuideSheetState();
}

class _NavigationGuideSheetState extends State<_NavigationGuideSheet> {
  Future<void> _open2GIS() async {
    final loc = AppLocalizations.of(context);
    final appUri       = Uri.parse('dgis://2gis.ru/routeSearch/rsType/pedestrian/to/${widget.sellerLng},${widget.sellerLat}');
    final webUri       = Uri.parse('https://2gis.kg/bishkek/geo/${widget.sellerLng},${widget.sellerLat}');
    final playStoreUri = Uri.parse('https://play.google.com/store/apps/details?id=ru.dublgis.dgismobile');
    final appStoreUri  = Uri.parse('https://apps.apple.com/app/id481627348');

    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
    } else if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(loc.get('2gis_not_installed')),
          content: Text(loc.get('2gis_download_hint')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.get('no'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
              onPressed: () async {
                Navigator.pop(ctx);
                final isIOS    = Theme.of(context).platform == TargetPlatform.iOS;
                final storeUri = isIOS ? appStoreUri : playStoreUri;
                if (await canLaunchUrl(storeUri)) await launchUrl(storeUri, mode: LaunchMode.externalApplication);
              },
              child: Text(loc.get('download'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg     = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final stepBg      = isDark ? const Color(0xFF2C2C2C) : Colors.grey[50]!;
    final stepBorder  = isDark ? const Color(0xFF3A3A3A) : Colors.grey[200]!;
    final handleColor = isDark ? const Color(0xFF3A3A3A) : Colors.grey[300]!;

    return Container(
      color: sheetBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: handleColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.navigation_rounded, color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 16),
            Text(widget.shopName.isNotEmpty ? widget.shopName : loc.get('shop'), style: AppTextStyles.headingSmall, textAlign: TextAlign.center),
            if (widget.containerNumber.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('📍 ${widget.containerNumber}', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: stepBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: stepBorder)),
              child: Column(children: [
                _step('1', loc.get('nav_step1')),
                const SizedBox(height: 10),
                _step('2', loc.get('nav_step2')),
                const SizedBox(height: 10),
                _step('3', loc.get('nav_step3')),
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _open2GIS,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                icon: const Icon(Icons.map_rounded, color: Colors.white),
                label: Text(loc.get('open_2gis'), style: AppTextStyles.headingSmall.copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(String num, String text) {
    return Row(children: [
      Container(width: 24, height: 24, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), alignment: Alignment.center,
        child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
    ]);
  }
}

// ══════════════════════════════════════════════════════
// FULLSCREEN IMAGE
// ══════════════════════════════════════════════════════
class _FullscreenImageScreen extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  const _FullscreenImageScreen({required this.imageUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        SizedBox(
          width: screenSize.width, height: screenSize.height,
          child: InteractiveViewer(
            minScale: 0.8, maxScale: 5.0,
            child: Hero(
              tag: heroTag,
              child: CachedNetworkImage(
                imageUrl: imageUrl, width: screenSize.width, height: screenSize.height, fit: BoxFit.contain,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.white54, size: 64)),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
