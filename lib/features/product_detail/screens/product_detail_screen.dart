import 'dart:ui';
import 'package:flutter/rendering.dart' show ScrollDirection;
import '../widgets/similar_products_section.dart';
import '../widgets/recommended_products_section.dart';
import '../widgets/detail_buttons.dart';
import '../widgets/navigation_guide_sheet.dart';
import '../widgets/fullscreen_image_screen.dart';
import '../widgets/complaint_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../config/theme/dd_design.dart';
import '../../../core/app_localizations.dart';
import '../../../core/supabase_client.dart';
import '../../../core/utils/favorites_manager.dart';
import '../../../core/utils/image_utils.dart';
import '../../../data/models/product_model.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/services/chat_service.dart';
import '../../store/screens/store_products_screen.dart';
import '../widgets/review_section.dart';
import '../widgets/pulse_box.dart';
import '../widgets/share_widget.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with WidgetsBindingObserver {
  final _fav = FavoritesManager();
  final _chatService = ChatService();
  // Тизмеден келген product маалыматы (аты, баасы, сүрөттөрү, ж.б.) толук
  // экранды дароо көрсөтүү үчүн жетиштүү — андыктан баштапкы мааниси false:
  // колдонуучу ачылганда спиннерге күтпөй, товарды дароо көрөт.
  bool _dataLoading = false;
  // Дүкөн/сатуучу маалыматы (chat/маршрут үчүн керек) фондо жүктөлөт
  bool _sellerInfoLoading = true;
  bool _navGuideOpen = false;
  // Колдонуучу геолокация/жайгашкан жер жөндөөлөрүнө жөнөтүлгөн —
  // тиркемеге кайра кайтканда (app resumed) геолокация жанык болсо,
  // кайра баскыч басылбай эле автоматтык түрдө 2ГИС'ке өтөт
  bool _waitingForLocationSettings = false;
  bool _isChatLoading = false;
  String selectedSize = '';
  int _currentImageIndex = 0;
  late PageController _imagePageController;

  late ProductModel _product;
  String? _sellerUid;
  String? _storeId;
  String _storeType = 'market';
  String _marketName = '';
  String _sellerName = '';
  String _shopName = '';
  String _containerNumber = '';
  String _workStart = '';
  String _workEnd = '';
  String _workDays = '';
  String? _avatarUrl;
  // Дүкөндүн координаттары (stores таблицасынан). null/0 болсо — локация коюлган эмес
  double? _storeLat;
  double? _storeLng;

  bool get _hasStoreLocation =>
      _storeLat != null &&
      _storeLng != null &&
      !(_storeLat == 0 && _storeLng == 0);

  // ── Төмөнкү баскычтар: ылдый жылдырганда жашырынат, жогору
  // жылдырганда же токтогондо кайра чыгат ──
  final ValueNotifier<bool> _buttonsVisible = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _product = widget.product;
    _imagePageController = PageController();
    // shopId дароо белгилүү болсо — storeId'ти алдын ала коюп коюу
    if (widget.product.shopId.isNotEmpty) {
      _storeId = widget.product.shopId;
    }
    // Экран дароо көрүнөт (жогорудагы _product менен); калган маалымат
    // фондо жүктөлөт. "Окшош товарлар" өзүнчө виджет катары өзү жүктөйт.
    _loadFullProductData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Колдонуучу геолокация/жайгашкан жер жөндөөлөрүнөн кайтты —
    // геолокация жанык болсо, баскычты кайра баспай эле 2ГИС'ке өтөбүз
    if (state == AppLifecycleState.resumed && _waitingForLocationSettings) {
      _waitingForLocationSettings = false;
      _openMapNavigation();
    }
  }

  Future<void> _loadFullProductData() async {
    try {
      final data = await supabase
          .from('products')
          .select('*, stores(*)')
          .eq('id', widget.product.id)
          .single();
      if (!mounted) return;
      setState(() => _product = ProductModel.fromMap(data));
      final storeData = data['stores'] as Map<String, dynamic>?;
      if (storeData != null) {
        setState(() {
          _storeId = storeData['id'] as String?;
          _sellerUid = storeData['owner_id'] as String?;
          _shopName = storeData['store_name'] as String? ?? '';
          _containerNumber = [
            storeData['market'] as String? ?? '',
            storeData['district'] as String? ?? ''
          ].where((s) => s.isNotEmpty).join(', ');
          _workStart = storeData['work_start'] as String? ?? '';
          _workEnd = storeData['work_end'] as String? ?? '';
          _workDays = storeData['work_days'] as String? ?? '';
          _storeLat = (storeData['latitude'] as num?)?.toDouble();
          _storeLng = (storeData['longitude'] as num?)?.toDouble();
        });
        if (_sellerUid != null) {
          // Сатуучунун профилин да фондо, күттүрбөй жүктөйбүз
          supabase
              .from('profiles')
              .select('full_name, store_type, market_name, avatar_url')
              .eq('id', _sellerUid!)
              .single()
              .then((profile) {
            if (mounted) {
              setState(() {
                _sellerName = profile['full_name'] as String? ?? '';
                _storeType = profile['store_type'] as String? ?? 'market';
                _marketName = profile['market_name'] as String? ?? '';
                _avatarUrl = profile['avatar_url'] as String?;
              });
            }
          }).catchError((_) {});
        }
      }

      supabase.rpc('increment_product_views', params: {
        'product_id': widget.product.id,
      }).then((_) {
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
      if (mounted) setState(() => _sellerInfoLoading = false);
    }
  }

  Future<void> _openMapNavigation() async {
    // Баскычты бир нече жолу катар бассаңыз да, бир гана жолу иштейт —
    // "маршрут түзүү" экрандары катмарланып чыкпайт
    if (_navGuideOpen) return;
    _navGuideOpen = true;
    try {
      await _openMapNavigationInner();
    } finally {
      if (mounted) _navGuideOpen = false;
    }
  }

  Future<void> _openMapNavigationInner() async {
    final loc = AppLocalizations.of(context);

    // ── 1) АЛДЫ МЕНЕН сатуучу локация койгонбу — текшеребиз.
    // Койбосо маршрут иштебейт (GPS/уруксат да сурабайбыз). ──
    double? sellerLat = _storeLat;
    double? sellerLng = _storeLng;

    if (sellerLat == null || sellerLng == null) {
      // Дүкөн маалыматы али жүктөлө элек болушу мүмкүн — stores'тан алабыз
      String? storeId = _storeId;
      if (storeId == null) {
        try {
          final row = await supabase
              .from('products')
              .select('store_id')
              .eq('id', _product.id)
              .single();
          storeId = row['store_id'] as String?;
        } catch (e) {
          debugPrint('❌ store_id алуу: $e');
        }
      }
      if (storeId != null) {
        try {
          final store = await supabase
              .from('stores')
              .select('latitude, longitude')
              .eq('id', storeId)
              .single();
          sellerLat = (store['latitude'] as num?)?.toDouble();
          sellerLng = (store['longitude'] as num?)?.toDouble();
          if (mounted) {
            setState(() {
              _storeLat = sellerLat;
              _storeLng = sellerLng;
            });
          }
        } catch (e) {
          debugPrint('❌ stores lat/lng: $e');
        }
      }
    }

    if (sellerLat == null ||
        sellerLng == null ||
        (sellerLat == 0 && sellerLng == 0)) {
      if (mounted) _showSnack(loc.get('location_unknown'));
      return;
    }

    // ── 2) Колдонуучунун GPS уруксаттары ──
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) _showSnack(loc.get('location_denied'));
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        // Жөндөөлөрдөн кайтканда (уруксат берилсе) автоматтык улантуу
        _waitingForLocationSettings = true;
        await Geolocator.openAppSettings();
      }
      return;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Жайгашкан жер (GPS) жөндөөлөрүнөн кайтканда, жанык болсо,
      // баскычты кайра баспай эле автоматтык түрдө 2ГИС'ке өтөбүз
      _waitingForLocationSettings = true;
      await Geolocator.openLocationSettings();
      return;
    }
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => NavigationGuideSheet(
          shopName: _shopName,
          containerNumber: _containerNumber,
          sellerLat: sellerLat!,
          sellerLng: sellerLng!),
    );
  }

  Future<void> _openChat() async {
    if (_isChatLoading) return;
    final loc = AppLocalizations.of(context);
    if (_sellerInfoLoading) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(loc.get('loading')),
        duration: const Duration(seconds: 1),
        backgroundColor: DD.accent,
      ));
      return;
    }
    setState(() => _isChatLoading = true);
    if (_sellerUid == null || _sellerUid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.get('seller_no_info')),
          backgroundColor: AppColors.warning));
      return;
    }
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.get('chat_login_required')),
          backgroundColor: AppColors.warning));
      return;
    }
    if (user.id == _sellerUid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.get('own_product')),
          backgroundColor: AppColors.warning));
      return;
    }
    try {
      final chatId = await _chatService.getOrCreateChat(
          buyerId: user.id, sellerId: _sellerUid!, productId: _product.id);
      if (!mounted) return;
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ChatScreen(
                    chatId: chatId,
                    sellerName: _shopName.isNotEmpty ? _shopName : _sellerName,
                    productId: _product.id,
                    productName: _product.name,
                    productImage: _product.imageUrl,
                    isSeller: false,
                    buyerId: user.id,
                    sellerId: _sellerUid!,
                  )));
    } catch (e) {
      debugPrint('❌ _openChat: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${loc.get('error')}: $e'),
          backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isChatLoading = false);
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

  void _showComplaintSheet(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isRu = loc.locale.languageCode == 'ru';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ComplaintSheet(
        productId: _product.id,
        productName: _product.name,
        isRu: isRu,
        storeId: _storeId,
        sellerId: _sellerUid,
        shopName: _shopName,
        sellerName: _sellerName,
        containerNumber: _containerNumber,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _imagePageController.dispose();
    _buttonsVisible.dispose();
    super.dispose();
  }

  bool _isOpenNow() {
    if (_workStart.isEmpty || _workEnd.isEmpty) return false;
    final now = TimeOfDay.now();
    TimeOfDay parse(String t) {
      final p = t.split(':');
      return TimeOfDay(
          hour: int.tryParse(p[0]) ?? 0, minute: int.tryParse(p[1]) ?? 0);
    }

    final s = parse(_workStart);
    final e = parse(_workEnd);
    final nowMin = now.hour * 60 + now.minute;
    return nowMin >= s.hour * 60 + s.minute && nowMin < e.hour * 60 + e.minute;
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}к';
    return count.toString();
  }

  // ── Сүрөт галереясы (слайдер + thumbnail strip) ──
  Widget _buildImageGallery() {
    final allImages = _product.images.isNotEmpty
        ? _product.images
        : (_product.imageUrl.isNotEmpty ? [_product.imageUrl] : <String>[]);

    if (allImages.isEmpty) {
      return Container(
        color: AppColors.grey100,
        child: const Icon(Icons.image, size: 80, color: AppColors.grey300),
      );
    }

    return Stack(
      children: [
        // ── Сүрөттөр PageView ──
        PageView.builder(
          controller: _imagePageController,
          itemCount: allImages.length,
          onPageChanged: (i) => setState(() => _currentImageIndex = i),
          itemBuilder: (context, index) {
            final url = allImages[index];
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  opaque: false,
                  barrierColor: Colors.black,
                  transitionDuration: const Duration(milliseconds: 250),
                  pageBuilder: (_, __, ___) => FullscreenImageScreen(
                    images: allImages,
                    initialIndex: index,
                    heroTag: 'product_image_${_product.id}_$index',
                  ),
                ),
              ),
              child: Hero(
                tag: 'product_image_${_product.id}_$index',
                child: CachedNetworkImage(
                  imageUrl: toCloudinaryThumb(url, width: 800),
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (_, __) => Container(color: AppColors.grey100),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.grey100,
                    child: const Icon(Icons.image_not_supported,
                        size: 80, color: AppColors.grey300),
                  ),
                ),
              ),
            );
          },
        ),

        // ── Thumbnail strip (болгону 2+ сүрөт болсо) ──
        if (allImages.length > 1)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.55),
                  ],
                ),
              ),
              // Align + оңго түздөгөн Row: аз сүрөт болсо оң четке
              // жыйналат, көп болсо горизонталдык scroll иштейт
              child: Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(allImages.length, (i) {
                      final isActive = i == _currentImageIndex;
                      return GestureDetector(
                        onTap: () {
                          _imagePageController.animateToPage(
                            i,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(left: 8),
                          width: isActive ? 54 : 46,
                          height: isActive ? 54 : 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isActive ? DD.accent : Colors.white54,
                              width: isActive ? 2.5 : 1.5,
                            ),
                            boxShadow: isActive
                                ? [BoxShadow(color: DD.accent.withOpacity(0.5), blurRadius: 8)]
                                : [],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: toCloudinaryThumb(allImages[i], width: 120),
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: Colors.white12),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.white12,
                                child: const Icon(Icons.image, size: 18, color: Colors.white38),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),

        // ── Санагыч "2 / 3" ──
        if (allImages.length > 1)
          Positioned(
            // ← Асты-сол жакка жылдырылды: үстүнкү жүрөк/бөлүшүү
            // баскычтарына жакын болбошу үчүн
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentImageIndex + 1} / ${allImages.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Жардамчы: блокту blur менен ороо ──
  Widget _blurBlock(Widget child, Color cardColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: DD.card(isDark),
      child: child,
    );
  }


  // ── Секция аталышы: кызгылт сары сызык + иконка ──
  Widget _sectionTitle(String text, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: DD.accentGradient,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: DD.accent.withValues(alpha: 0.30),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: AppTextStyles.headingSmall.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : DD.ink,
          ),
        ),
      ]),
    );
  }

  Widget _subLabel(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 15, color: DD.accent),
          const SizedBox(width: 6),
          Text(text,
              style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.grey500, fontWeight: FontWeight.w600)),
        ]),
      );

  // ── Кичинекей маалымат "таблетка" (рейтинг, көрүү, лайк, аралык) ──
  Widget _metaPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DD.rPill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(text,
            style: AppTextStyles.labelSmall
                .copyWith(color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _buildPriceSection(AppLocalizations loc) {
    final cur = loc.get('currency');
    final hasDiscount = _product.discountedPrice != null &&
        _product.discountedPrice! < _product.price;
    if (hasDiscount) {
      final discounted = _product.discountedPrice!;
      final pct = ((1 - discounted / _product.price) * 100).round();
      final saved = (_product.price - discounted).toStringAsFixed(0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('${discounted.toStringAsFixed(0)} $cur',
                style: AppTextStyles.headingLarge.copyWith(
                    color: DD.accent, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: DD.accent,
                  borderRadius: BorderRadius.circular(DD.rBadge)),
              child: Text('-$pct%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text('${_product.price.toStringAsFixed(0)} $cur',
                style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.grey400,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: AppColors.grey400,
                    decorationThickness: 1.5)),
            const SizedBox(width: 8),
            Text('$saved ${loc.get('price_saved')}',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.success)),
          ]),
        ],
      );
    }
    final isWholesale = _product.pricingType == 'wholesale';
    final isNegotiation = isWholesale && _product.wholesaleMode == 'negotiation';
    final hasWholesalePrice = isWholesale && !isNegotiation && _product.wholesalePrice != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Negotiation: баа жок — текст гана
        if (isNegotiation)
          Text(
            loc.get('prod_price_negotiation'),
            style: AppTextStyles.headingLarge.copyWith(
                color: const Color(0xFF059669), fontWeight: FontWeight.w800, letterSpacing: -0.5),
          )
        else
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text('${_product.price.toStringAsFixed(0)} $cur',
                style: AppTextStyles.headingLarge.copyWith(
                    color: isWholesale ? const Color(0xFF7C3AED) : DD.accent,
                    fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(width: 10),
            Text(
              isWholesale ? loc.get('prod_badge_wholesale') : loc.get('prod_badge_retail'),
              style: TextStyle(
                color: isWholesale ? const Color(0xFF7C3AED) : DD.accent,
                fontSize: 13, fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        // Оптом маалыматы
        if (isWholesale) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isNegotiation
                  ? const Color(0xFF059669).withValues(alpha: 0.08)
                  : const Color(0xFF7C3AED).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isNegotiation
                    ? const Color(0xFF059669).withValues(alpha: 0.35)
                    : const Color(0xFF7C3AED).withValues(alpha: 0.35),
              ),
            ),
            child: Row(children: [
              Icon(isNegotiation ? Icons.handshake_outlined : Icons.price_change_outlined,
                  color: isNegotiation ? const Color(0xFF059669) : const Color(0xFF7C3AED),
                  size: 18),
              const SizedBox(width: 10),
              Expanded(child: isNegotiation
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(loc.get('prod_detail_negotiation_title'),
                          style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(loc.get('prod_detail_negotiation_sub'),
                          style: TextStyle(color: const Color(0xFF059669).withValues(alpha: 0.75), fontSize: 12)),
                    ])
                  : hasWholesalePrice
                      ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(loc.get('prod_detail_wholesale_price_label'),
                              style: TextStyle(color: const Color(0xFF7C3AED).withValues(alpha: 0.75), fontSize: 12)),
                          Text('${_product.wholesalePrice!.toStringAsFixed(0)} $cur',
                              style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w800, fontSize: 16)),
                        ])
                      : Text(loc.get('prod_detail_wholesale_contact'),
                          style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 12))),
            ]),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isFav = _fav.isFavorite(_product.id);
    loc.get('currency');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = Colors.transparent;
    final chipColor =
        isDark ? const Color(0xFF1F1A16) : const Color(0xFFF7F7F9);
    final chipBorder =
        isDark ? const Color(0xFF3A2E26) : const Color(0xFFECECF0);
    final appBarBg = isDark
        ? Colors.black.withOpacity(0.65)
        : Colors.white.withOpacity(0.80);
    final btnBg = isDark
        ? Colors.black.withOpacity(0.70)
        : Colors.white.withOpacity(0.85);

    // ── Арткы фон: dark → синий градиент (HomeBackground), light → ак ──
    final scaffoldBg = isDark
        ? DD.bgDark
        : DD.bgLight; // light ак фон

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: NotificationListener<UserScrollNotification>(
        onNotification: (n) {
          // ValueNotifier'ге setState эмес, түз мааниси коюлат — ошондуктан
          // бул бүт 1500 саптык build()ди эмес, баскыч тилкесин гана
          // кайра курат (scroll учурундагы jank четтетилет)
          if (n.direction == ScrollDirection.reverse &&
              _buttonsVisible.value) {
            // ылдый жылдырып жатат (мазмун жогору жылат) → жашыр
            _buttonsVisible.value = false;
          } else if (n.direction != ScrollDirection.reverse &&
              !_buttonsVisible.value) {
            // жогору жылдырды же токтоду → кайра көрсөт
            _buttonsVisible.value = true;
          }
          return false;
        },
        child: Stack(
        children: [
          // ── Figma фон: кара/ак + кызгылт сары жарык такталары ──
          Positioned.fill(child: _DDGlow(isDark: isDark)),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: appBarBg,
                leading: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration:
                        BoxDecoration(color: btnBg, shape: BoxShape.circle),
                    child: Icon(Icons.arrow_back,
                        color: theme.colorScheme.onSurface),
                  ),
                ),
                actions: [
                  GestureDetector(
                    onTap: () {
                      _fav.toggle(_product);
                      setState(() {});
                    },
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration:
                          BoxDecoration(color: btnBg, shape: BoxShape.circle),
                      child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? Colors.red : AppColors.grey600)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ShareWidget.show(context, _product),
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration:
                          BoxDecoration(color: btnBg, shape: BoxShape.circle),
                      child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.share_outlined,
                              color: AppColors.grey600)),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(28)),
                    child: _buildImageGallery(),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _dataLoading
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: DD.accent)))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Баа + аты ──
                          _blurBlock(
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildPriceSection(loc),
                                  const SizedBox(height: 10),
                                  Text(_product.name,
                                      style: AppTextStyles.headingMedium
                                          .copyWith(
                                          fontSize: 22,
                                          height: 1.25,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.4)),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if ((_product.rating ?? 0) > 0)
                                        _metaPill(
                                          Icons.star_rounded,
                                          _product.rating!.toStringAsFixed(1) +
                                              ((_product.ratingCount ?? 0) > 0
                                                  ? ' (${_product.ratingCount})'
                                                  : ''),
                                          const Color(0xFFF59E0B),
                                        ),
                                      _metaPill(
                                        Icons.remove_red_eye_rounded,
                                        _formatCount(_product.viewsCount),
                                        const Color(0xFF6B7280),
                                      ),
                                      _metaPill(
                                        Icons.favorite_rounded,
                                        _formatCount(_product.likesCount),
                                        const Color(0xFFEC4899),
                                      ),
                                      if (_product.distanceFormatted.isNotEmpty)
                                        _metaPill(
                                          Icons.location_on_rounded,
                                          _product.distanceFormatted,
                                          DD.accent,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            cardColor,
                          ),
                          const SizedBox(height: 8),

                          // ── Характеристикалар ──
                          _buildCharacteristics(
                              loc, cardColor, chipColor, chipBorder),
                          const SizedBox(height: 8),

                          // ── Сүрөттөмө ──
                          if (_product.description != null &&
                              _product.description!.isNotEmpty) ...[
                            _blurBlock(
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _sectionTitle(loc.get('description'), Icons.notes_rounded),
                                    const SizedBox(height: 10),
                                    Text(_product.description!,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(height: 1.55)),
                                  ],
                                ),
                              ),
                              cardColor,
                            ),
                            const SizedBox(height: 8),
                          ],

                          // ── Размер тандоо ──
                          if (_product.sizes.isNotEmpty) ...[
                            _blurBlock(
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _sectionTitle(loc.get('select_size'), Icons.straighten_rounded),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _product.sizes.map((size) {
                                        final isSel = selectedSize == size;
                                        return GestureDetector(
                                          onTap: () => setState(
                                              () => selectedSize = size),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: isSel
                                                  ? DD.accent
                                                  : chipColor,
                                              borderRadius:
                                                  BorderRadius.circular(DD.rPill),
                                              border: Border.all(
                                                  color: isSel
                                                      ? DD.accent
                                                      : chipBorder),
                                            ),
                                            child: Text(size,
                                                style: AppTextStyles.labelLarge
                                                    .copyWith(
                                                        color: isSel
                                                            ? Colors.white
                                                            : theme.colorScheme
                                                                .onSurface)),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              cardColor,
                            ),
                            const SizedBox(height: 8),
                          ],

                          // ── Сатуучу маалыматы (жаңы дизайн) ──
                          _blurBlock(
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionTitle(loc.get('seller'), Icons.storefront_rounded),
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // ── СОЛ: Айлана аватар + Кирүү баскычы ──
                                      Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: const BoxDecoration(
                                              gradient: DD.accentGradient,
                                              shape: BoxShape.circle,
                                            ),
                                            child: CircleAvatar(
                                            radius: 30,
                                            backgroundColor: DD.accent,
                                            backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                                ? CachedNetworkImageProvider(_avatarUrl!)
                                                : null,
                                            child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                                                ? const Icon(
                                                    Icons.store_rounded,
                                                    size: 32,
                                                    color: Colors.white,
                                                  )
                                                : null,
                                          )),
                                          const SizedBox(height: 8),
                                          PulseBox(
                                              child: GestureDetector(
                                            onTap: () {
                                              if (_storeId != null) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => StoreProductsScreen(
                                                      storeId: _storeId!,
                                                      shopName: _shopName,
                                                      containerNumber: _containerNumber,
                                                      ownerName: _sellerName,
                                                      avatarUrl: _avatarUrl,
                                                      latitude: _storeLat,
                                                      longitude: _storeLng,
                                                      productBuilder: (p) => ProductDetailScreen(product: p),
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 5),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF10B981),
                                                    Color(0xFF059669)
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(DD.rPill),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFF10B981)
                                                        .withValues(alpha: 0.40),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 3),
                                                    spreadRadius: -2,
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                loc.locale.languageCode == 'ru'
                                                    ? 'Войти'
                                                    : 'Кирүү',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          )),
                                        ],
                                      ),
                                      const SizedBox(width: 14),
                                      // ── ОҢ: Маалыматтар ──
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (_shopName.isNotEmpty) ...[
                                              Text(
                                                loc.get('shop'),
                                                style: AppTextStyles.labelSmall
                                                    .copyWith(
                                                        color:
                                                            AppColors.grey500),
                                              ),
                                              Text(
                                                _shopName,
                                                style: AppTextStyles.labelLarge
                                                    .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                            ],
                                            if (_sellerName.isNotEmpty) ...[
                                              Text(
                                                loc.get('seller'),
                                                style: AppTextStyles.labelSmall
                                                    .copyWith(
                                                        color:
                                                            AppColors.grey500),
                                              ),
                                              Text(
                                                _sellerName,
                                                style: AppTextStyles.labelLarge
                                                    .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                            ],
                                            // ── Тип badge ──
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _storeType == 'market'
                                                    ? DD.accent
                                                        .withValues(alpha: 0.1)
                                                    : const Color(0xFF10B981)
                                                        .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: _storeType == 'market'
                                                      ? DD.accent
                                                          .withValues(
                                                              alpha: 0.4)
                                                      : const Color(0xFF10B981)
                                                          .withValues(
                                                              alpha: 0.4),
                                                ),
                                              ),
                                              child: Text(
                                                _storeType == 'market' &&
                                                        _marketName.isNotEmpty
                                                    ? '🏪 $_marketName'
                                                    : '🏬 Жеке менчик дүкөн',
                                                style: AppTextStyles.labelSmall
                                                    .copyWith(
                                                  color: _storeType == 'market'
                                                      ? DD.accent
                                                      : const Color(0xFF10B981),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            // ── Иштөө убактысы ──
                                            if (_workStart.isNotEmpty &&
                                                _workEnd.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Row(children: [
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: _isOpenNow()
                                                        ? const Color(
                                                            0xFF10B981)
                                                        : const Color(
                                                            0xFFF87171),
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: (_isOpenNow()
                                                                ? const Color(0xFF10B981)
                                                                : const Color(0xFFF87171))
                                                            .withValues(alpha: 0.6),
                                                        blurRadius: 6,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    '${_isOpenNow() ? loc.get('open') : loc.get('closed')}  ·  ${_workDays.isNotEmpty ? "$_workDays  " : ""}$_workStart — $_workEnd',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? AppColors.grey400
                                                          : const Color(
                                                              0xFF6B7280),
                                                    ),
                                                  ),
                                                ),
                                              ]),
                                            ],
                                            if (_shopName.isEmpty &&
                                                _sellerName.isEmpty)
                                              Text(loc.get('no_info'),
                                                  style: AppTextStyles
                                                      .bodyMedium
                                                      .copyWith(
                                                          color: AppColors
                                                              .grey500)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  // ── Арыздануу баскычы ──
                                  const SizedBox(height: 14),
                                  Divider(
                                      height: 1,
                                      color: isDark
                                          ? Colors.white.withOpacity(0.08)
                                          : const Color(0xFFEDEDF0)),
                                  const SizedBox(height: 12),
                                  GestureDetector(
                                    onTap: () => _showComplaintSheet(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444)
                                            .withValues(alpha: 0.08),
                                        borderRadius:
                                            BorderRadius.circular(DD.rPill),
                                        border: Border.all(
                                            color: const Color(0xFFEF4444)
                                                .withValues(alpha: 0.35)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.flag_outlined,
                                              color: Color(0xFFEF4444),
                                              size: 16),
                                          const SizedBox(width: 6),
                                          Text(
                                            loc.locale.languageCode == 'ru'
                                                ? 'Пожаловаться'
                                                : 'Арыздануу',
                                            style: const TextStyle(
                                              color: Color(0xFFEF4444),
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            cardColor,
                          ),
                          const SizedBox(height: 8),

                          // ── Бөлүшүү кнопкасы ──
                          Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [DD.accent2, DD.accent],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(DD.rPill),
                              boxShadow: [
                                BoxShadow(
                                  color: DD.accent
                                      .withValues(alpha: isDark ? 0.25 : 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () =>
                                    ShareWidget.show(context, _product),
                                borderRadius: BorderRadius.circular(DD.rPill),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.share_rounded,
                                          color: Colors.white, size: 22),
                                      const SizedBox(width: 10),
                                      Text(
                                        loc.locale.languageCode == 'ru'
                                            ? 'Поделиться'
                                            : 'Бөлүшүү',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: ReviewSection(productId: _product.id)),
                          SimilarProductsSection(
                            initialProducts: const [],
                            currentProductId: _product.id,
                            categoryId: _product.category,
                            productBuilder: (p) => ProductDetailScreen(product: p),
                          ),
                          // ── "Окшош товарлар" бүткөндөн кийин — бардык
                          // товарлардан аралаштырылган чексиз тасма ──
                          RecommendedProductsSection(
                            currentProductId: _product.id,
                            productBuilder: (p) => ProductDetailScreen(product: p),
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
              ),
            ],
          ),
          // ── Төмөнкү баскычтар: Positioned — артында кара фон жок,
          // товарлар ылдыйда көрүнүп турат ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            // ── ValueListenableBuilder: _buttonsVisible өзгөргөндө
            // бул кичине тилке гана кайра курулат, бүт экран эмес ──
            child: ValueListenableBuilder<bool>(
              valueListenable: _buttonsVisible,
              builder: (context, buttonsVisible, _) => Container(
              padding: EdgeInsets.fromLTRB(
                  16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
              color: Colors.transparent,
              child: Row(
          children: [
            // ── Чат баскычы: ылдый жылдырганда АСТЫГА жашырынат ──
            Expanded(
              flex: 2,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                offset: buttonsVisible ? Offset.zero : const Offset(0, 2),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: buttonsVisible ? 1 : 0,
                  // ── GradientButton: Маршрут баскычындагыдай эле
                  // басканда кичирейип-жарчыйт (AnimatedScale) ──
                  child: GradientButton(
                    height: 52,
                    borderRadius: DD.rPill,
                    colors: const [Color(0xFF10B981), Color(0xFF059669)],
                    pressedColors: const [Color(0xFF059669), Color(0xFF047857)],
                    shadowColor: const Color(0xFF10B981),
                    onTap: _isChatLoading
                        ? null
                        : () async {
                            if (_isChatLoading) return;
                            await _openChat();
                          },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          right: -8,
                          bottom: -12,
                          child: Icon(Icons.shopping_bag_rounded,
                              size: 48,
                              color: Colors.white.withValues(alpha: 0.16)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat_bubble_rounded,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Чат',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // ── Эки баскычты ачык ажыратуу үчүн кеңейтилген боштук ──
            const SizedBox(width: 18),
            // ── Маршрут баскычы: ылдый жылдырганда АСТЫГА жашырынат ──
            Expanded(
              flex: 3,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                offset: buttonsVisible ? Offset.zero : const Offset(0, 2),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: buttonsVisible ? 1 : 0,
                  child: GradientButton(
                    height: 52,
                    borderRadius: DD.rPill,
                    colors: (!_sellerInfoLoading && !_hasStoreLocation)
                        ? const [Color(0xFF9CA3AF), Color(0xFF6B7280)]
                        : const [DD.accent2, DD.accent],
                    pressedColors: (!_sellerInfoLoading && !_hasStoreLocation)
                        ? const [Color(0xFF6B7280), Color(0xFF4B5563)]
                        : const [DD.accent, Color(0xFFC2371E)],
                    shadowColor: (!_sellerInfoLoading && !_hasStoreLocation)
                        ? const Color(0xFF6B7280)
                        : DD.accent,
                    onTap: _openMapNavigation,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          right: -8,
                          bottom: -12,
                          child: Icon(Icons.map_rounded,
                              size: 48,
                              color: Colors.white.withValues(alpha: 0.16)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.near_me_rounded,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                loc.get('route'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
              ],
              ),
            ),
            ), // ← ValueListenableBuilder
          ),
        ], // ← Stack children
        ), // ← Stack
      ), // ← NotificationListener
    );
  }

  Widget _buildCharacteristics(AppLocalizations loc, Color cardColor,
      Color chipColor, Color chipBorder) {
    final hasColors = _product.colors.isNotEmpty;
    final hasSizes = _product.sizes.isNotEmpty;
    final hasStock = _product.inStock != null;
    if (!hasColors && !hasSizes && !hasStock) return const SizedBox.shrink();

    return _blurBlock(
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(loc.get('characteristics'), Icons.tune_rounded),
            const SizedBox(height: 10),
            if (hasStock) ...[
              Builder(builder: (_) {
                final ok = (_product.inStock ?? 0) > 0;
                final c = ok ? AppColors.success : AppColors.error;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(DD.rPill),
                    border: Border.all(color: c.withValues(alpha: 0.35)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        ok
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 16,
                        color: c),
                    const SizedBox(width: 6),
                    Text(
                      ok
                          ? '${loc.get('in_stock')}: ${_product.inStock} ${loc.get('pcs')}'
                          : loc.get('out_of_stock'),
                      style: AppTextStyles.labelMedium
                          .copyWith(color: c, fontWeight: FontWeight.w700),
                    ),
                  ]),
                );
              }),
              const SizedBox(height: 14),
            ],
            if (hasColors) ...[
              _subLabel(Icons.palette_outlined, loc.get('colors')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _product.colors.map((c) {
                  const legacyToKy = {
                    'color_white': 'Ак',
                    'color_black': 'Кара',
                    'color_red': 'Кызыл',
                    'color_blue': 'Көк',
                    'color_green': 'Жашыл',
                    'color_yellow': 'Сары',
                    'color_pink': 'Кызгылт',
                    'color_brown': 'Күрөң',
                    'color_grey': 'Боз',
                    'color_gray': 'Боз',
                    'color_purple': 'Күлгүн',
                    'color_orange': 'Кызгылт сары',
                    'color_lightblue': 'Ачык көк',
                    'color_beige': 'Бежевый',
                    'color_cream': 'Кремовый',
                    'color_gold': 'Алтын',
                    'color_silver': 'Күмүш',
                    'color_darkgreen': 'Кара жашыл',
                    'color_darkblue': 'Темно-көк',
                  };
                  const kyToRu = {
                    'Кара': 'Чёрный',
                    'Ак': 'Белый',
                    'Кызыл': 'Красный',
                    'Көк': 'Синий',
                    'Жашыл': 'Зелёный',
                    'Сары': 'Жёлтый',
                    'Кызгылт': 'Розовый',
                    'Күрөң': 'Коричневый',
                    'Боз': 'Серый',
                    'Күлгүн': 'Фиолетовый',
                    'Кызгылт сары': 'Оранжевый',
                    'Ачык көк': 'Голубой',
                    'Бежевый': 'Бежевый',
                    'Кремовый': 'Кремовый',
                    'Жыгач': 'Деревянный',
                    'Алтын': 'Золотой',
                    'Күмүш': 'Серебряный',
                    'Кара жашыл': 'Тёмно-зелёный',
                    'Темно-көк': 'Тёмно-синий',
                  };
                  const colorHexMap = {
                    'Кара': 0xFF1C1C1C,
                    'Ак': 0xFFEEEEEE,
                    'Кызыл': 0xFFEF4444,
                    'Көк': 0xFF3B82F6,
                    'Жашыл': 0xFF22C55E,
                    'Сары': 0xFFEAB308,
                    'Кызгылт': 0xFFEC4899,
                    'Күрөң': 0xFF92400E,
                    'Боз': 0xFF6B7280,
                    'Күлгүн': 0xFF8B5CF6,
                    'Кызгылт сары': 0xFFF97316,
                    'Ачык көк': 0xFF06B6D4,
                    'Бежевый': 0xFFF5F0DC,
                    'Кремовый': 0xFFFFFDD0,
                    'Жыгач': 0xFF8B4513,
                    'Алтын': 0xFFFFD700,
                    'Күмүш': 0xFFC0C0C0,
                    'Кара жашыл': 0xFF006400,
                    'Темно-көк': 0xFF00008B,
                  };
                  final ky = legacyToKy[c] ?? c;
                  final display =
                      loc.locale.languageCode == 'ru' ? (kyToRu[ky] ?? ky) : ky;
                  final hex = colorHexMap[ky];
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: chipColor,
                      borderRadius: BorderRadius.circular(DD.rPill),
                      border: Border.all(color: chipBorder),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (hex != null) ...[
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Color(hex),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.4)),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(display, style: AppTextStyles.labelSmall),
                    ]),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],
            if (hasSizes) ...[
              _subLabel(Icons.straighten_rounded, loc.get('sizes')),
              const SizedBox(height: 8),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _product.sizes
                      .map((s) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: chipColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: chipBorder)),
                            child: Text(s, style: AppTextStyles.labelSmall),
                          ))
                      .toList()),
            ],
          ],
        ),
      ),
      cardColor,
    );
  }

}

// ══════════════════════════════════════════════════════
// ФОН — Figma "blur gradient": кара/ак + кызгылт сары жарык
// ══════════════════════════════════════════════════════
class _DDGlow extends StatelessWidget {
  final bool isDark;
  const _DDGlow({required this.isDark});

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: CustomPaint(painter: _DDGlowPainter(isDark)));
}

class _DDGlowPainter extends CustomPainter {
  final bool isDark;
  _DDGlowPainter(this.isDark);

  void _blob(Canvas c, Offset o, double r, Color color) {
    final paint = Paint();
    paint.shader = RadialGradient(colors: [color, color.withOpacity(0)])
        .createShader(Rect.fromCircle(center: o, radius: r));
    c.drawCircle(o, r, paint);
  }

  @override
  void paint(Canvas canvas, Size s) {
    if (isDark) {
      final bgPaint = Paint();
      bgPaint.shader = const LinearGradient(
        colors: [Color(0xFF000000), Color(0xFF0E0604), Color(0xFF000000)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & s);
      canvas.drawRect(Offset.zero & s, bgPaint);
      _blob(canvas, Offset(s.width * 0.1, s.height * 0.38), s.width * 0.85,
          DD.accent2.withOpacity(0.20));
      _blob(canvas, Offset(s.width * 0.95, s.height * 0.78), s.width * 0.95,
          DD.accent.withOpacity(0.18));
    } else {
      _blob(canvas, Offset(s.width * 0.2, s.height * 0.36), s.width * 0.8,
          DD.accent2.withOpacity(0.10));
      _blob(canvas, Offset(s.width * 0.95, s.height * 0.72), s.width * 0.9,
          DD.accent.withOpacity(0.08));
    }
  }

  @override
  bool shouldRepaint(_DDGlowPainter o) => o.isDark != isDark;
}