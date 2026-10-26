import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/dd_design.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/supabase_client.dart';


import '../../store/screens/store_products_screen.dart';
import '../../product_detail/screens/product_detail_screen.dart';

class _StoreLocation {
  final String id;
  final String shopName;
  final String ownerName;
  final String containerNumber;
  final double? latitude;
  final double? longitude;
  final String ownerId;
  final String? avatarUrl;

  _StoreLocation({
    required this.id,
    required this.shopName,
    required this.ownerName,
    required this.containerNumber,
    this.latitude,
    this.longitude,
    this.ownerId = '',
    this.avatarUrl,
  });

  factory _StoreLocation.fromMap(Map<String, dynamic> data) {
    final profile   = data['profiles'] as Map<String, dynamic>?;
    final container = [
      data['market']   as String? ?? '',
      data['district'] as String? ?? '',
    ].where((s) => s.isNotEmpty).join(', ');

    return _StoreLocation(
      id:              data['id']         as String? ?? '',
      shopName:        data['store_name'] as String? ?? '',
      ownerName:       profile?['full_name'] as String? ?? '',
      containerNumber: container,
      latitude:        (data['latitude']  as num?)?.toDouble(),
      longitude:       (data['longitude'] as num?)?.toDouble(),
      ownerId:         data['owner_id']   as String? ?? '',
      avatarUrl:       profile?['avatar_url'] as String?,
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<_StoreLocation> _sellers  = [];
  List<_StoreLocation> _filtered = [];
  _StoreLocation? _selectedSeller;
  bool _isLoading       = true;
  int  _noLocationCount = 0;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSellers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSellers() async {
    try {
      final data = await supabase
          .from('stores')
          .select('*, profiles!inner(full_name, seller_status, avatar_url)')
          .eq('is_active', true)
          .eq('profiles.seller_status', 'approved');

      final all = (data as List)
          .cast<Map<String, dynamic>>()
          .map((row) => _StoreLocation.fromMap(row))
          .toList();

      final withLocation =
          all.where((s) => s.latitude != null && s.longitude != null).toList();
      final noLocation =
          all.where((s) => s.latitude == null || s.longitude == null).length;

      setState(() {
        _sellers         = withLocation;
        _filtered        = withLocation;
        _noLocationCount = noLocation;
        _isLoading       = false;
      });
    } catch (e) {
      debugPrint('❌ _loadSellers: $e');
      setState(() => _isLoading = false);
    }
  }

  void _search(String query) {
    setState(() {
      _filtered = _sellers
          .where((s) =>
              s.shopName.toLowerCase().contains(query.toLowerCase()) ||
              s.containerNumber.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _open2GIS(_StoreLocation seller) async {
    final loc = AppLocalizations.of(context);
    final lat = seller.latitude!;
    final lng = seller.longitude!;

    final appUri       = Uri.parse('dgis://2gis.ru/routeSearch/rsType/pedestrian/to/$lng,$lat');
    final playStoreUri = Uri.parse('https://play.google.com/store/apps/details?id=ru.dublgis.dgismobile');
    final appStoreUri  = Uri.parse('https://apps.apple.com/app/id481627348');

    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
    } else {
      if (!mounted) return;
      final isIOS    = Theme.of(context).platform == TargetPlatform.iOS;
      final storeUri = isIOS ? appStoreUri : playStoreUri;
      showDialog(
        context: context,
        builder: (ctx) => _GlassDialog(
          isDark: Theme.of(context).brightness == Brightness.dark,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.get('2gis_not_installed'),
                  style: AppTextStyles.headingSmall),
              const SizedBox(height: 8),
              Text(loc.get('2gis_download_hint'),
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.grey500)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.grey300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(loc.get('no'),
                          style:
                              const TextStyle(color: AppColors.grey500)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        if (await canLaunchUrl(storeUri)) {
                          await launchUrl(storeUri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Text(loc.get('download'),
                          style:
                              const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }

  void _openStoreProducts(_StoreLocation seller) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreProductsScreen(
          storeId:         seller.id,
          shopName:        seller.shopName,
          containerNumber: seller.containerNumber,
          ownerName:       seller.ownerName,
          avatarUrl:       seller.avatarUrl,
          latitude:        seller.latitude,
          longitude:       seller.longitude,
          productBuilder:  (p) => ProductDetailScreen(product: p),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? DD.bgDark : DD.bgLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // ── AppBar — айнек ──
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: isDark
                    ? Colors.black.withOpacity(0.30)
                    : Colors.white.withOpacity(0.50),
                padding: EdgeInsets.fromLTRB(
                    16, MediaQuery.of(context).padding.top + 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          ' ${loc.get('map_title')}',
                          style: AppTextStyles.headingMedium.copyWith(
                            color: isDark ? Colors.white : AppColors.black,
                          ),
                        ),
                        const Spacer(),
                        if (!_isLoading)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: DD.accentGradient,
                                  borderRadius: BorderRadius.circular(DD.rPill),
                                ),
                                child: Text(
                                  '${_sellers.length} ${loc.get('map_store_count')}',
                                  style: AppTextStyles.labelSmall
                                      .copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // ── Издөө талаасы — айнек ──
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _search,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isDark ? Colors.white : AppColors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: loc.get('map_search_hint'),
                            hintStyle: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.grey400),
                            prefixIcon: const Icon(Icons.search,
                                color: DD.accent, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      _search('');
                                    },
                                    child: const Icon(Icons.close,
                                        color: AppColors.grey400, size: 18),
                                  )
                                : null,
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.white.withOpacity(0.60),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),

          // ── Тизме ──
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _filtered.isEmpty
                    ? _buildEmpty(loc, isDark)
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          16 + MediaQuery.of(context).padding.bottom + 72,
                        ),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _buildSellerCard(_filtered[i], loc, isDark),
                      ),
          ),

          // ── Статистика — айнек ──
          if (!_isLoading && _noLocationCount > 0)
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: isDark
                      ? Colors.black.withOpacity(0.25)
                      : Colors.white.withOpacity(0.40),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: AppColors.grey400),
                      const SizedBox(width: 6),
                      Text(
                        '$_noLocationCount ${loc.get('map_no_location')}',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.grey400),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations loc, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📍', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(loc.get('map_not_found'), style: AppTextStyles.headingSmall),
          const SizedBox(height: 8),
          Text(loc.get('map_try_search'),
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.grey500)),
        ],
      ),
    );
  }

  Widget _buildSellerCard(
      _StoreLocation seller, AppLocalizations loc, bool isDark) {
    final isSelected   = _selectedSeller?.id == seller.id;
    final dividerColor =
        isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: GestureDetector(
          onTap: () =>
              setState(() => _selectedSeller = isSelected ? null : seller),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? DD.accent
                    : isDark
                        ? Colors.white.withOpacity(0.10)
                        : Colors.white.withOpacity(0.80),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Лого
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: DD.accentGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          seller.shopName.isNotEmpty
                              ? seller.shopName[0].toUpperCase()
                              : '🏪',
                          style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(seller.shopName,
                              style: AppTextStyles.headingSmall.copyWith(
                                color: isDark ? Colors.white : AppColors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 13, color: DD.accent),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  seller.containerNumber.isNotEmpty
                                      ? seller.containerNumber
                                      : loc.get('location_unknown'),
                                  style: AppTextStyles.labelSmall
                                      .copyWith(color: AppColors.grey500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Бейдж
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.success.withOpacity(0.20)),
                          ),
                          child: const Text('📍'),
                        ),
                      ),
                    ),
                  ],
                ),

                if (isSelected) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: dividerColor),
                  const SizedBox(height: 12),
                  if (seller.ownerName.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 14, color: AppColors.grey400),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(seller.ownerName,
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.grey500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Товарлар
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _openStoreProducts(seller),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      DD.accent.withOpacity(0.08),
                                  side: const BorderSide(
                                      color: DD.accent, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(DD.rPill)),
                                ),
                                icon: const Icon(
                                    Icons.storefront_rounded,
                                    size: 18,
                                    color: DD.accent),
                                label: Text(
                                  loc.locale.languageCode == 'ru'
                                      ? 'Товары'
                                      : 'Товарлар',
                                  style: AppTextStyles.labelLarge
                                      .copyWith(color: DD.accent, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Маршрут
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () => _open2GIS(seller),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DD.accent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(DD.rPill)),
                            ).copyWith(
                              backgroundColor: WidgetStateProperty.all(DD.accent),
                            ),
                            icon: const Icon(Icons.navigation_rounded,
                                size: 18, color: Colors.white),
                            label: Text(
                              loc.get('open_2gis'),
                              style: AppTextStyles.labelLarge
                                  .copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// АЙНЕК ДИАЛОГ HELPER
// ══════════════════════════════════════════════════════
class _GlassDialog extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _GlassDialog({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.80),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.white.withOpacity(0.9),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}