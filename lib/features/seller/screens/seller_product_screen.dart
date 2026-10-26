import 'dart:async';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/supabase_client.dart';
import '../../home/models/category_model.dart';

import '../../../core/services/yandex_storage_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SellerProductScreen extends StatefulWidget {
  final String sellerUid;
  final String shopName;

  const SellerProductScreen({
    super.key,
    required this.sellerUid,
    required this.shopName,
  });

  @override
  State<SellerProductScreen> createState() => _SellerProductScreenState();
}

class _SellerProductScreenState extends State<SellerProductScreen> {

  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String? _selectedCategoryId;
  String? _storeId;

  late final List<CategoryModel> _allCategories;

  List<Map<String, dynamic>> get _filteredProducts {
    if (_selectedCategoryId == null) return _products;
    return _products
        .where((p) => (p['category_id'] as String? ?? '').startsWith(_selectedCategoryId!))
        .toList();
  }

  final List<Map<String, String>> _legacyCategories = [
    {'id': '1',  'name': 'Кийим-кече',           'icon': '👕'},
    {'id': '2',  'name': 'Эркектер кийими',       'icon': '👔'},
    {'id': '3',  'name': 'Аялдар кийими',         'icon': '👗'},
    {'id': '4',  'name': 'Балдар кийими',         'icon': '🧒'},
    {'id': '5',  'name': 'Мектеп формасы',        'icon': '🏫'},
    {'id': '6',  'name': 'Кышкы кийим',           'icon': '🧥'},
    {'id': '7',  'name': 'Жайкы кийим',           'icon': '☀️'},
    {'id': '8',  'name': 'Күзгү / Жазгы кийим',  'icon': '🍂'},
    {'id': '9',  'name': 'Спорт кийими',          'icon': '🏋️'},
    {'id': '10', 'name': 'Бут кийим',             'icon': '👟'},
    {'id': '11', 'name': 'Аксессуарлар',          'icon': '👜'},
    {'id': '12', 'name': 'Сумкалар',              'icon': '🎒'},
    {'id': '13', 'name': 'Кол / Баш кийим',       'icon': '🧤'},
    {'id': '14', 'name': 'Зергерчилик',           'icon': '💍'},
    {'id': '15', 'name': 'Кездеме / Мата',        'icon': '🧵'},
    {'id': '16', 'name': 'Электроника',           'icon': '📱'},
    {'id': '17', 'name': 'Муздаткыч / Техника',   'icon': '❄️'},
    {'id': '18', 'name': 'Кир жуучу машина',      'icon': '🫧'},
    {'id': '19', 'name': 'Куралдар / Инструмент', 'icon': '🔧'},
    {'id': '20', 'name': 'Үй буюмдар',            'icon': '🏠'},
    {'id': '21', 'name': 'Үй өсүмдүктөрү',       'icon': '🪴'},
    {'id': '22', 'name': 'Дүкөн буюмдары',        'icon': '🏪'},
    {'id': '23', 'name': 'Спорт',                 'icon': '⚽'},
    {'id': '24', 'name': 'Балдар оюнчуктары',     'icon': '🧸'},
    {'id': '25', 'name': 'Сулуулук / Косметика',  'icon': '💄'},
    {'id': '26', 'name': 'Жеке гигиена',          'icon': '🧴'},
    {'id': '27', 'name': 'Азык-түлүк',            'icon': '🛒'},
    {'id': '28', 'name': 'Автотовар',             'icon': '🚗'},
    {'id': '29', 'name': 'Китептер / Канцтовар',  'icon': '📚'},
    {'id': '30', 'name': 'Оюнчуктар',             'icon': '🎮'},
  ];

  static const _allClothSizes    = ['86 см','92 см','98 см','104 см','110 см','116 см','122 см','128 см','134 см','140 см','146 см','152 см','158 см','164 см','XS','S','M','L','XL','XXL','3XL','4XL','5XL'];
  static const _menClothSizes    = ['S','M','L','XL','XXL','3XL','4XL','5XL','44','46','48','50','52','54','56','58','60'];
  static const _womenClothSizes  = ['XS (36)','S (38)','M (40)','L (42)','XL (44)','XXL (46)','3XL (48)','4XL (50)','5XL (52)'];
  static const _kidsClothSizes   = ['0-1 жаш (56-62 см)','1-2 жаш (80-86 см)','2-3 жаш (92-98 см)','3-4 жаш (98-104 см)','4-5 жаш (104-110 см)','5-6 жаш (110-116 см)','6-7 жаш (116-122 см)','7-8 жаш (122-128 см)','8-9 жаш (128-134 см)','9-10 жаш (134-140 см)','10-11 жаш (140-146 см)','11-12 жаш (146-152 см)','12-13 жаш (152-158 см)','13-14 жаш (158-164 см)'];
  static const _schoolSizes      = ['110 см (4-5 жаш)','116 см (5-6 жаш)','122 см (6-7 жаш)','128 см (7-8 жаш)','134 см (8-9 жаш)','140 см (9-10 жаш)','146 см (10-11 жаш)','152 см (11-12 жаш)','158 см (12-13 жаш)','164 см (13-14 жаш)','170 см (14-15 жаш)','176 см (15-16 жаш)'];
  static const _seasonClothSizes = ['86 см','92 см','98 см','104 см','110 см','116 см','122 см','128 см','134 см','140 см','146 см','152 см','158 см','164 см','XS','S','M','L','XL','XXL','3XL','4XL','5XL'];
  static const _allShoesSizes    = ['16','17','18','19','20','21','22','23','24','25','26','27','28','29','30','31','32','33','34','35','36','37','38','39','40','41','42','43','44','45','46','47'];
  static const _fabricSizes      = ['0.5 м','1 м','1.5 м','2 м','2.5 м','3 м','4 м','5 м','10 м','20 м','50 м'];

  final List<Map<String, dynamic>> _allColors = [
    {'name': 'Кара',         'nameRu': 'Чёрный',       'hex': 0xFF000000},
    {'name': 'Ак',           'nameRu': 'Белый',         'hex': 0xFFFFFFFF},
    {'name': 'Кызыл',        'nameRu': 'Красный',       'hex': 0xFFEF4444},
    {'name': 'Көк',          'nameRu': 'Синий',         'hex': 0xFF3B82F6},
    {'name': 'Жашыл',        'nameRu': 'Зелёный',       'hex': 0xFF22C55E},
    {'name': 'Сары',         'nameRu': 'Жёлтый',        'hex': 0xFFEAB308},
    {'name': 'Кызгылт',      'nameRu': 'Розовый',       'hex': 0xFFEC4899},
    {'name': 'Күрөң',        'nameRu': 'Коричневый',    'hex': 0xFF92400E},
    {'name': 'Боз',          'nameRu': 'Серый',         'hex': 0xFF6B7280},
    {'name': 'Күлгүн',       'nameRu': 'Фиолетовый',   'hex': 0xFF8B5CF6},
    {'name': 'Кызгылт сары', 'nameRu': 'Оранжевый',    'hex': 0xFFF97316},
    {'name': 'Ачык көк',     'nameRu': 'Голубой',       'hex': 0xFF06B6D4},
    {'name': 'Бежевый',      'nameRu': 'Бежевый',       'hex': 0xFFF5F0DC},
    {'name': 'Кремовый',     'nameRu': 'Кремовый',      'hex': 0xFFFFFDD0},
    {'name': 'Жыгач',        'nameRu': 'Деревянный',    'hex': 0xFF8B4513},
    {'name': 'Алтын',        'nameRu': 'Золотой',       'hex': 0xFFFFD700},
    {'name': 'Күмүш',        'nameRu': 'Серебряный',    'hex': 0xFFC0C0C0},
    {'name': 'Кара жашыл',   'nameRu': 'Тёмно-зелёный','hex': 0xFF006400},
    {'name': 'Темно-көк',    'nameRu': 'Тёмно-синий',  'hex': 0xFF00008B},
  ];

  @override
  void initState() {
    super.initState();
    _allCategories = CategoryModel.getCategories();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProducts();
    });
  }

  Future<String> _getOrCreateStoreId() async {
    if (_storeId != null) return _storeId!;
    final uid      = widget.sellerUid;
    final existing = await supabase.from('stores').select('id').eq('owner_id', uid).maybeSingle();
    if (existing != null) { _storeId = existing['id'] as String; return _storeId!; }
    final inserted = await supabase.from('stores').insert({'owner_id': uid, 'store_name': widget.shopName}).select('id').single();
    _storeId = inserted['id'] as String;
    return _storeId!;
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final storeId = await _getOrCreateStoreId();
      if (!mounted) return;
      final rows = await supabase
          .from('products')
          .select()
          .eq('store_id', storeId)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _products  = (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Жүктөөдө ката: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _deleteProduct(String id, String name) async {
    final loc     = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(loc.get('prod_delete_title'), style: AppTextStyles.headingSmall),
        content: Text('"$name" ${loc.get('prod_delete_confirm')}', style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(loc.get('no'))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text(loc.get('prod_delete_yes'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await supabase.from('products').delete().eq('id', id);
      _showSnack(loc.get('prod_deleted'));
      _loadProducts();
    } catch (e) {
      _showSnack('${loc.get('prod_delete_error')}: $e', isError: true);
    }
  }

  Future<void> _toggleFeatured(Map<String, dynamic> product) async {
    final id         = product['id'] as String;
    final isFeatured = product['is_featured'] == true;
    final newValue   = !isFeatured;
    try {
      await supabase.from('products').update({'is_featured': newValue}).eq('id', id);
      setState(() {
        final idx = _products.indexWhere((p) => p['id'] == id);
        if (idx != -1) _products[idx]['is_featured'] = newValue;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newValue ? '⭐ Өзгөчө товарларга кошулду!' : '✖ Өзгөчө товарлардан алынды'),
          backgroundColor: newValue ? const Color(0xFF7C3AED) : AppColors.grey500,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ката чыкты: $e'), backgroundColor: AppColors.error));
    }
  }

  // ── Акция: товар тандоо sheet ─────────────────────────────────────────────
  void _showProductPickerForDiscount() {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDark ? Colors.white : AppColors.black;
    String query = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => StatefulBuilder(builder: (ctx, setSheet) {
          final filtered = _products.where((p) =>
              ((p['title'] as String?) ?? '').toLowerCase().contains(query.toLowerCase().trim())).toList();
          return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_offer_rounded, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Акция кошуу', style: AppTextStyles.headingSmall.copyWith(color: titleColor)),
                    Text('Товарды тандаңыз', style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                onChanged: (v) => setSheet(() => query = v),
                decoration: InputDecoration(
                  hintText: 'Товар издөө...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE)),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('📦', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text('Товарлар жок', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500)),
                      ]),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final p = filtered[i];
                        final images = List<String>.from(p['images'] as List? ?? []);
                        final imageUrl = images.isNotEmpty ? images.first : '';
                        final hasDiscount = (p['discount_percent'] as num? ?? 0) > 0;
                        final discPct = p['discount_percent'];

                        return InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _showDiscountSheet(p);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 56, height: 56,
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(imageUrl, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0),
                                            child: const Center(child: Text('📦', style: TextStyle(fontSize: 22))),
                                          ))
                                      : Container(
                                          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0),
                                          child: const Center(child: Text('📦', style: TextStyle(fontSize: 22))),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(p['title'] as String? ?? '',
                                    style: AppTextStyles.labelLarge.copyWith(color: titleColor),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Text('${(p['price'] as num?)?.toStringAsFixed(0) ?? 0} с',
                                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
                                  if (hasDiscount) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.error,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('-$discPct%',
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ]),
                              ])),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  hasDiscount ? 'Өзгөртүү' : '+ Кошуу',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: Colors.orange, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ],
          );
        }),
      ),
    );
  }

  void _showDiscountSheet(Map<String, dynamic> product) {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final price  = (product['price'] as num?)?.toDouble() ?? 0;
    final ctrl   = TextEditingController(text: (product['discount_percent'] as num?)?.toString() ?? '');
    double? discountedPrice;
    int percent = int.tryParse(ctrl.text) ?? 0;
    final sheetBg   = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fieldFill = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          void recalc(String v) {
            final p = int.tryParse(v) ?? 0;
            setS(() { percent = p.clamp(0, 100); discountedPrice = price - (price * percent / 100); });
          }
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(loc.get('discount_title'), style: AppTextStyles.headingSmall),
              const SizedBox(height: 4),
              Text('${loc.get('discount_original_price')}: ${price.toStringAsFixed(0)} ${loc.get('currency')}',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500)),
              const SizedBox(height: 20),
              TextField(
                controller: ctrl, keyboardType: TextInputType.number, onChanged: recalc,
                style: TextStyle(color: isDark ? Colors.white : AppColors.black),
                decoration: InputDecoration(
                  labelText: loc.get('discount_percent_label'), suffixText: '%',
                  filled: true, fillColor: fieldFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                ),
              ),
              if (percent > 0 && discountedPrice != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2B1E0A) : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary, width: 1),
                  ),
                  child: Row(children: [
                    const Text('🔥', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$percent% ${loc.get('discount_label')}', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
                      Text('${discountedPrice!.toStringAsFixed(0)} ${loc.get('currency')}', style: AppTextStyles.headingSmall.copyWith(color: AppColors.error)),
                      Text('${(price - discountedPrice!).toStringAsFixed(0)} ${loc.get('discount_saved')}', style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
                    ]),
                  ]),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: percent < 1 ? null : () async {
                    await _saveDiscount(productId: product['id'] as String, product: product, percent: percent, discountedPrice: discountedPrice!);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(loc.get('discount_add_btn'), style: const TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              if ((product['discount_percent'] as num? ?? 0) > 0) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity, height: 44,
                  child: OutlinedButton(
                    onPressed: () async {
                      await supabase.from('products').update({'discount_percent': null, 'discounted_price': null, 'has_promotion': false}).eq('id', product['id'] as String);
                      _showSnack(loc.get('discount_removed'));
                      _loadProducts();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: Text(loc.get('discount_remove_btn'), style: const TextStyle(color: AppColors.error)),
                  ),
                ),
              ],
            ]),
          );
        },
      ),
    );
  }

  Future<void> _saveDiscount({required String productId, required Map<String, dynamic> product, required int percent, required double discountedPrice}) async {
    final loc = AppLocalizations.of(context);
    await supabase.from('products').update({'discount_percent': percent, 'discounted_price': discountedPrice, 'has_promotion': true}).eq('id', productId);
    _showSnack(loc.get('discount_saved_msg'));
    _loadProducts();
  }

  String _getCategoryName(String id) {
    if (id.isEmpty) return '📦 Башка';
    final parts  = id.split('_');
    final mainId = parts[0];
    try {
      final cat = _allCategories.firstWhere((c) => c.id == mainId);
      if (parts.length >= 3) {
        final subId  = '${parts[0]}_${parts[1]}';
        final itemId = id;
        try {
          final sub  = cat.subcategories.firstWhere((s) => s.id == subId);
          final item = sub.subItems.firstWhere((i) => i.id == itemId);
          return '${cat.icon} ${cat.name} › ${sub.icon} ${sub.name} › ${item.icon} ${item.name}';
        } catch (_) {}
      }
      if (parts.length == 2) {
        try {
          final sub = cat.subcategories.firstWhere((s) => s.id == id);
          return '${cat.icon} ${cat.name} › ${sub.icon} ${sub.name}';
        } catch (_) {}
      }
      return '${cat.icon} ${cat.name}';
    } catch (_) {}
    final legacy = _legacyCategories.firstWhere((c) => c['id'] == id, orElse: () => {'name': 'Башка', 'icon': '📦'});
    return '${legacy['icon']} ${legacy['name']}';
  }

  @override
  Widget build(BuildContext context) {
    final loc      = AppLocalizations.of(context);
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredProducts;
    final usedMainCatIds = _products.map((p) => (p['category_id'] as String? ?? '').split('_')[0]).toSet();

    final bgColor       = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);
    final appBarColor   = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor    = isDark ? Colors.white : AppColors.black;
    final catBarColor   = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final cardColor     = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final prodNameColor = isDark ? Colors.white : AppColors.black;
    final divColor      = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: isDark ? Colors.white : AppColors.grey600),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(loc.get('my_products'), style: AppTextStyles.headingSmall.copyWith(color: titleColor)),
          Text(widget.shopName, style: AppTextStyles.labelSmall.copyWith(color: isDark ? Colors.white60 : AppColors.grey500)),
        ]),
        actions: [
          // ── Акция кнопкасы ──
          GestureDetector(
            onTap: () => _showProductPickerForDiscount(),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange, width: 1.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_offer_rounded, color: Colors.orange, size: 14),
                  const SizedBox(width: 4),
                  Text('Акция', style: AppTextStyles.labelSmall.copyWith(color: Colors.orange, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          // ── Убактылуу акция кнопкасы ──
          GestureDetector(
            onTap: () async {
              final sid = await _getOrCreateStoreId();
              if (!mounted) return;
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => SellerFlashSaleScreen(storeId: sid),
              ));
            },
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text('Вр. акция', style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          // ── Жаңыртуу ──
          IconButton(
            onPressed: _loadProducts,
            icon: Icon(Icons.refresh, color: isDark ? Colors.white70 : AppColors.grey600),
            tooltip: loc.get('refresh'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: catBarColor,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                _categoryChip(id: null, icon: '📦', name: loc.get('prod_all'), count: _products.length, isDark: isDark),
                const SizedBox(width: 8),
                ..._allCategories.where((cat) => usedMainCatIds.contains(cat.id)).map((cat) {
                  final count = _products.where((p) => (p['category_id'] as String? ?? '').startsWith(cat.id)).length;
                  return Padding(padding: const EdgeInsets.only(right: 8),
                      child: _categoryChip(id: cat.id, icon: cat.icon, name: cat.name, count: count, isDark: isDark));
                }),
                ..._legacyCategories.where((cat) {
                  final id = cat['id']!;
                  if (usedMainCatIds.contains(id)) return false;
                  try { _allCategories.firstWhere((c) => c.id == id); return false; } catch (_) {}
                  return _products.any((p) => p['category_id'] == id);
                }).map((cat) {
                  final count = _products.where((p) => p['category_id'] == cat['id']).length;
                  return Padding(padding: const EdgeInsets.only(right: 8),
                      child: _categoryChip(id: cat['id'], icon: cat['icon']!, name: cat['name']!, count: count, isDark: isDark));
                }),
              ]),
            ),
          ),
          Divider(height: 1, color: divColor),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : filtered.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('📦', style: TextStyle(fontSize: 64)),
                        const SizedBox(height: 16),
                        Text(_selectedCategoryId == null ? loc.get('prod_empty') : loc.get('prod_empty_cat'),
                            style: AppTextStyles.headingSmall.copyWith(color: titleColor)),
                        const SizedBox(height: 8),
                        Text(_selectedCategoryId == null ? loc.get('prod_empty_hint') : loc.get('prod_empty_cat_hint'),
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500), textAlign: TextAlign.center),
                      ]))
                    : RefreshIndicator(
                        onRefresh: _loadProducts,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final p      = filtered[index];
                            final colors = List<String>.from(p['colors'] as List? ?? []);
                            final sizes  = List<String>.from(p['sizes']  as List? ?? []);
                            final images = List<String>.from(p['images'] as List? ?? []);
                            final imageUrl = images.isNotEmpty ? images.first : '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                              ),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Stack(children: [
                                  SizedBox(
                                    width: 80, height: 80,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: imageUrl.isNotEmpty
                                          ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _noImage(isDark))
                                          : _noImage(isDark),
                                    ),
                                  ),
                                  if ((p['discount_percent'] as num? ?? 0) > 0)
                                    Positioned(top: 2, left: 2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(6)),
                                        child: Text('-${p['discount_percent']}%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                ]),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(p['title'] as String? ?? '', style: AppTextStyles.labelLarge.copyWith(color: prodNameColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Text('${(p['price'] as num?)?.toStringAsFixed(0) ?? 0} ${loc.get('currency')}',
                                        style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
                                    const SizedBox(width: 6),
                                    _pricingBadge(p, loc, isDark),
                                  ]),
                                  const SizedBox(height: 2),
                                  Text(_getCategoryName(p['category_id'] as String? ?? ''),
                                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
                                  const SizedBox(height: 2),
                                  Text('${loc.get('banner_stock_label')}: ${p['in_stock'] ?? 0} ${loc.get('pcs')}',
                                      style: AppTextStyles.labelSmall.copyWith(color: (p['in_stock'] as int? ?? 0) > 0 ? AppColors.success : AppColors.error)),
                                  if (colors.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(children: colors.take(5).map((name) {
                                      final c = _allColors.firstWhere((x) => x['name'] == name, orElse: () => {'hex': 0xFF888888});
                                      return Container(width: 14, height: 14, margin: const EdgeInsets.only(right: 4),
                                          decoration: BoxDecoration(color: Color(c['hex'] as int), shape: BoxShape.circle, border: Border.all(color: Colors.grey.withValues(alpha: 0.3))));
                                    }).toList()),
                                  ],
                                  if (sizes.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text('${loc.get('size_label')}: ${sizes.take(3).join(', ')}${sizes.length > 3 ? ' +${sizes.length - 3}' : ''}',
                                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ])),
                                Column(children: [
                                  GestureDetector(
                                    onTap: () => _showProductDialog(existing: p),
                                    child: Container(padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(8)),
                                        child: const Icon(Icons.edit, size: 18, color: Color(0xFF0369A1))),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => _toggleFeatured(p),
                                    child: Container(padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                            color: p['is_featured'] == true ? const Color(0xFFF3E8FF) : const Color(0xFFF5F5F5),
                                            borderRadius: BorderRadius.circular(8)),
                                        child: Icon(p['is_featured'] == true ? Icons.star_rounded : Icons.star_outline_rounded,
                                            size: 18, color: p['is_featured'] == true ? const Color(0xFF7C3AED) : AppColors.grey400)),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => _deleteProduct(p['id'] as String? ?? '', p['title'] as String? ?? ''),
                                    child: Container(padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(8)),
                                        child: const Icon(Icons.delete, size: 18, color: AppColors.error)),
                                  ),
                                ]),
                              ]),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(loc.get('add_product'), style: AppTextStyles.labelMedium.copyWith(color: Colors.white)),
      ),
    );
  }

  Widget _categoryChip({required String? id, required String icon, required String name, required int count, required bool isDark}) {
    final isSelected = _selectedCategoryId == id;
    final unselBg    = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0);
    final unselText  = isDark ? Colors.white70 : AppColors.grey600;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryId = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? AppColors.primary : unselBg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(name, style: AppTextStyles.labelMedium.copyWith(color: isSelected ? Colors.white : unselText, fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: isSelected ? Colors.white.withValues(alpha: 0.25) : AppColors.grey300, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppColors.grey600)),
          ),
        ]),
      ),
    );
  }

  Future<void> _showProductDialog({Map<String, dynamic>? existing}) async {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final nameCtrl         = TextEditingController(text: existing?['title'] ?? '');
    final priceCtrl        = TextEditingController(text: existing?['price']?.toString() ?? '');
    final wholesalePriceCtrl = TextEditingController(text: existing?['wholesale_price']?.toString() ?? '');
    final descCtrl         = TextEditingController(text: existing?['description'] ?? '');
    final stockCtrl        = TextEditingController(text: existing?['in_stock']?.toString() ?? '');
    final extra1Ctrl       = TextEditingController(text: existing?['extra1'] ?? '');
    final extra2Ctrl       = TextEditingController(text: existing?['extra2'] ?? '');
    final extra3Ctrl       = TextEditingController(text: existing?['extra3'] ?? '');

    // ── Баа тиби state ──
    String pricingType    = existing?['pricing_type'] as String? ?? 'retail';
    String wholesaleMode  = existing?['wholesale_mode'] as String? ?? 'price';

    final existingCatId = existing?['category_id'] as String? ?? '1';
    final existingParts = existingCatId.split('_');

    String  selectedMainCatId  = existingParts[0];
    String? selectedSubCatId;
    String? selectedSubItemId;

    bool mainCatExists = false;
    try { _allCategories.firstWhere((c) => c.id == selectedMainCatId); mainCatExists = true; } catch (_) {}
    if (!mainCatExists) { selectedMainCatId = '1'; }

    if (existingParts.length >= 3) {
      selectedSubCatId  = '${existingParts[0]}_${existingParts[1]}';
      selectedSubItemId = existingCatId;
    } else if (existingParts.length == 2) {
      selectedSubCatId = existingCatId;
    }

    List<String> selectedColors = List<String>.from(existing?['colors'] ?? []);
    List<String> selectedSizes  = List<String>.from(existing?['sizes']  ?? []);

    // ── ӨЗГӨРТҮҮ 1: 3 сүрөт слоту үчүн state ──
    final existingImages = List<String>.from(existing?['images'] as List? ?? []);
    while (existingImages.length < 3) existingImages.add('');
    final List<Uint8List?> newImageBytes = [null, null, null];
    bool isUploading  = false;
    bool isLoading    = false;
    String uploadStatus = '';

    final dialogBg  = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fieldFill = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7);
    final textColor = isDark ? Colors.white : AppColors.black;
    final labelClr  = isDark ? const Color(0xFFCCCCCC) : AppColors.grey600;
    final hintClr   = isDark ? const Color(0xFF666666) : AppColors.grey400;
    final dropBg    = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7);

    List<String> sizesForCategory(String mainId, [String? subId, String? subItemId]) {
      if (subId != null) {
        switch (subId) {
          case '1_2': return _menClothSizes;
          case '1_3': return _womenClothSizes;
          case '1_4': return _kidsClothSizes;
          case '1_5': return _schoolSizes;
          case '1_6': case '1_7': case '1_8': return _seasonClothSizes;
        }
      }
      switch (mainId) {
        case '1':  return _allClothSizes;
        case '2':  return _allShoesSizes;
        case '14': return _fabricSizes;
        default:   return [];
      }
    }

    String sizeLabelForCategory(String mainId, [String? subId, String? subItemId]) {
      if (subId != null) {
        switch (subId) {
          case '1_2': return loc.get('prod_size_men');
          case '1_3': return loc.get('prod_size_women');
          case '1_4': return loc.get('prod_size_kids');
          case '1_5': return loc.get('prod_size_school');
        }
      }
      switch (mainId) {
        case '2':  return loc.get('prod_size_shoes');
        case '14': return loc.get('prod_size_fabric');
        default:   return loc.get('prod_size_default');
      }
    }

    bool hasSizes(String mainId)        => ['1', '2', '14'].contains(mainId);
    bool hasColors(String mainId)       => ['1', '2', '3', '7', '8', '9', '14'].contains(mainId);
    bool hasTechFields(String mainId)   => ['4', '6'].contains(mainId);
    bool hasBeautyFields(String mainId) => ['9', '10'].contains(mainId);
    bool hasAutoFields(String mainId)   => mainId == '12';

    // ── ӨЗГӨРТҮҮ 2: pickImage — idx параметри менен ──
    Future<void> pickImage(int idx, StateSetter setD) async {
      if (kIsWeb) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(16),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: Text('📷  ${loc.get('prod_img_camera')}',
                    style: AppTextStyles.labelLarge.copyWith(color: textColor)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.camera,
                      maxWidth: 1200, maxHeight: 1200, imageQuality: 85,
                    );
                    if (picked == null) return;
                    final bytes = await picked.readAsBytes();
                    if (bytes.isNotEmpty) setD(() => newImageBytes[idx] = bytes);
                  } catch (e) {
                    _showSnack('${loc.get('prod_img_pick_error')}: $e', isError: true);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: Text('🖼️  ${loc.get('prod_img_gallery')}',
                    style: AppTextStyles.labelLarge.copyWith(color: textColor)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1200, maxHeight: 1200, imageQuality: 85,
                    );
                    if (picked == null) return;
                    final bytes = await picked.readAsBytes();
                    if (bytes.isNotEmpty) setD(() => newImageBytes[idx] = bytes);
                  } catch (e) {
                    _showSnack('${loc.get('prod_img_pick_error')}: $e', isError: true);
                  }
                },
              ),
            ]),
          ),
        );
        return;
      }

      // МОБАЙЛ
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: dialogBg,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: Text('📷  ${loc.get('prod_img_camera')}',
                  style: AppTextStyles.labelLarge.copyWith(color: textColor)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: Text('🖼️  ${loc.get('prod_img_gallery')}',
                  style: AppTextStyles.labelLarge.copyWith(color: textColor)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      );
      if (source == null) return;
      try {
        final picked = await ImagePicker().pickImage(
          source: source,
          maxWidth: 1200, maxHeight: 1200, imageQuality: 85,
        );
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          if (bytes.isNotEmpty) setD(() => newImageBytes[idx] = bytes);
        }
      } catch (e) {
        _showSnack('${loc.get('prod_img_pick_error')}: $e', isError: true);
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) {
          final mainCat      = _allCategories.firstWhere((c) => c.id == selectedMainCatId, orElse: () => _allCategories.first);
          final selectedSub  = selectedSubCatId != null
              ? mainCat.subcategories.where((s) => s.id == selectedSubCatId).firstOrNull
              : null;
          final effectiveCatId = selectedSubItemId ?? selectedSubCatId ?? selectedMainCatId;

          Widget labelW(String text) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(text, style: AppTextStyles.labelMedium.copyWith(color: labelClr)),
          );

          Widget fieldW(TextEditingController ctrl, String hint, {TextInputType type = TextInputType.text}) =>
              TextField(
                controller: ctrl, keyboardType: type,
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                decoration: InputDecoration(
                  hintText: hint, hintStyle: AppTextStyles.bodyMedium.copyWith(color: hintClr),
                  filled: true, fillColor: fieldFill,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
              );

          Widget dropdownW({required String? value, required List<DropdownMenuItem<String?>> items, required ValueChanged<String?> onChanged, required String hint}) =>
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(color: dropBg, borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(child: DropdownButton<String?>(
                  value: value, isExpanded: true, dropdownColor: dropBg,
                  style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                  hint: Text(hint, style: AppTextStyles.bodyMedium.copyWith(color: hintClr)),
                  items: items,
                  onChanged: onChanged,
                )),
              );

          return Dialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92, maxWidth: 520),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFFD97706), Color(0xFFEF4444)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(children: [
                    const Text('📦', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Text(existing == null ? loc.get('prod_dialog_add') : loc.get('prod_dialog_edit'),
                        style: AppTextStyles.headingSmall.copyWith(color: Colors.white)),
                    const Spacer(),
                    GestureDetector(onTap: () { if (!isLoading) Navigator.pop(ctx); }, child: const Icon(Icons.close, color: Colors.white)),
                  ]),
                ),

                Flexible(child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // ── ӨЗГӨРТҮҮ 3: 3 сүрөт слоту UI ──
                   labelW(loc.get('prod_field_image')),
const SizedBox(height: 6),
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: List.generate(3, (i) {
    final hasNew      = newImageBytes[i] != null;
    final hasExisting = existingImages[i].isNotEmpty;
    final isFirst     = i == 0;
    final borderClr   = hasNew || hasExisting
        ? AppColors.primary
        : (isFirst
            ? const Color(0xFFEF4444).withValues(alpha: 0.5)
            : AppColors.grey300);

    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: i < 2 ? 8.0 : 0.0),
        child: GestureDetector(
          onTap: () => pickImage(i, setD),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: double.infinity,   // ← бүтүн туурасы
                height: 110,
                child: Container(
                  decoration: BoxDecoration(
                    color: fieldFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderClr, width: 1.5),
                  ),
                  child: hasNew
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.memory(newImageBytes[i]!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity),
                        )
                      : hasExisting
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.network(existingImages[i],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (_, __, ___) =>
                                      _miniPlaceholder(isFirst)),
                            )
                          : _miniPlaceholder(isFirst),
                ),
              ),
              // Номер белгиси
              Positioned(
                top: 5, left: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: (hasNew || hasExisting)
                        ? AppColors.primary
                        : (isFirst ? const Color(0xFFEF4444) : AppColors.grey400),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    isFirst ? '1 *' : '${i + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              // Жок кылуу баскычы
              if (hasNew || hasExisting)
                Positioned(
                  top: 4, right: 4,
                  child: GestureDetector(
                    onTap: () => setD(() {
                      newImageBytes[i] = null;
                      existingImages[i] = '';
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          size: 12, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }),
),
                    if (isUploading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 4),
                      Text(uploadStatus, style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
                    ],
                    const SizedBox(height: 14),

                    labelW(loc.get('prod_field_name')),
                    fieldW(nameCtrl, loc.get('prod_hint_name')),
                    const SizedBox(height: 14),

                    // ── PRICING TYPE SELECTOR ──
                    labelW(loc.get('pricing_type_label')),
                    Row(children: [
                      Expanded(child: GestureDetector(
                        onTap: () => setD(() => pricingType = 'retail'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: pricingType == 'retail'
                                ? AppColors.primary
                                : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: pricingType == 'retail' ? AppColors.primary : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(children: [
                            Icon(Icons.person_rounded,
                                color: pricingType == 'retail' ? Colors.white : (isDark ? Colors.white60 : AppColors.grey500),
                                size: 20),
                            const SizedBox(height: 4),
                            Text(loc.get('pricing_retail'),
                                style: TextStyle(
                                  color: pricingType == 'retail' ? Colors.white : (isDark ? Colors.white60 : AppColors.grey600),
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          ]),
                        ),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: GestureDetector(
                        onTap: () => setD(() => pricingType = 'wholesale'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: pricingType == 'wholesale'
                                ? const Color(0xFF7C3AED)
                                : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: pricingType == 'wholesale' ? const Color(0xFF7C3AED) : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(children: [
                            Icon(Icons.store_rounded,
                                color: pricingType == 'wholesale' ? Colors.white : (isDark ? Colors.white60 : AppColors.grey500),
                                size: 20),
                            const SizedBox(height: 4),
                            Text(loc.get('pricing_wholesale'),
                                style: TextStyle(
                                  color: pricingType == 'wholesale' ? Colors.white : (isDark ? Colors.white60 : AppColors.grey600),
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          ]),
                        ),
                      )),
                    ]),
                    const SizedBox(height: 14),

                    // ── RETAIL: баасын жаз ──
                    if (pricingType == 'retail') ...[
                      labelW(loc.get('pricing_retail_price_label')),
                      fieldW(priceCtrl, loc.get('pricing_hint_retail'), type: TextInputType.number),
                      const SizedBox(height: 14),
                    ],

                    // ── WHOLESALE: Kelishim же Baasy ──
                    if (pricingType == 'wholesale') ...[
                      labelW(loc.get('pricing_wholesale_mode_label')),
                      Row(children: [
                        Expanded(child: GestureDetector(
                          onTap: () => setD(() => wholesaleMode = 'price'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: wholesaleMode == 'price'
                                  ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                                  : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: wholesaleMode == 'price' ? const Color(0xFF7C3AED) : (isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0)),
                                width: 1.5,
                              ),
                            ),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.price_change_outlined,
                                  color: wholesaleMode == 'price' ? const Color(0xFF7C3AED) : (isDark ? Colors.white54 : AppColors.grey500),
                                  size: 16),
                              const SizedBox(width: 6),
                              Text(loc.get('pricing_wholesale_by_price'),
                                  style: TextStyle(
                                    color: wholesaleMode == 'price' ? const Color(0xFF7C3AED) : (isDark ? Colors.white60 : AppColors.grey600),
                                    fontWeight: FontWeight.w600, fontSize: 12)),
                            ]),
                          ),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: GestureDetector(
                          onTap: () => setD(() => wholesaleMode = 'negotiation'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: wholesaleMode == 'negotiation'
                                  ? const Color(0xFF059669).withValues(alpha: 0.12)
                                  : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: wholesaleMode == 'negotiation' ? const Color(0xFF059669) : (isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0)),
                                width: 1.5,
                              ),
                            ),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.handshake_outlined,
                                  color: wholesaleMode == 'negotiation' ? const Color(0xFF059669) : (isDark ? Colors.white54 : AppColors.grey500),
                                  size: 16),
                              const SizedBox(width: 6),
                              Text(loc.get('pricing_wholesale_by_negotiation'),
                                  style: TextStyle(
                                    color: wholesaleMode == 'negotiation' ? const Color(0xFF059669) : (isDark ? Colors.white60 : AppColors.grey600),
                                    fontWeight: FontWeight.w600, fontSize: 12)),
                            ]),
                          ),
                        )),
                      ]),
                      const SizedBox(height: 12),

                      // Базалык баа — negotiation болсо жашырылат
                      if (wholesaleMode != 'negotiation') ...[
                        labelW(loc.get('pricing_retail_price_label')),
                        fieldW(priceCtrl, loc.get('pricing_hint_retail'), type: TextInputType.number),
                        const SizedBox(height: 10),
                      ],

                      if (wholesaleMode == 'price') ...[
                        labelW(loc.get('pricing_wholesale_price_label')),
                        fieldW(wholesalePriceCtrl, loc.get('pricing_hint_wholesale'), type: TextInputType.number),
                        const SizedBox(height: 10),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0D1F18) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.handshake_outlined, color: Color(0xFF059669), size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(loc.get('pricing_negotiation_hint'),
                                style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF059669)))),
                          ]),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],

                    labelW(loc.get('prod_field_main_cat')),
                    dropdownW(
                      value: selectedMainCatId,
                      hint: '— ${loc.get('cat_label')} —',
                      items: _allCategories.map((c) => DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text('${c.icon}  ${c.name}', style: AppTextStyles.bodyMedium.copyWith(color: textColor)),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) setD(() {
                          selectedMainCatId = val;
                          selectedSubCatId  = null;
                          selectedSubItemId = null;
                          selectedColors    = [];
                          selectedSizes     = [];
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    if (mainCat.subcategories.isNotEmpty) ...[
                      labelW(loc.get('prod_field_sub_cat')),
                      dropdownW(
                        value: selectedSubCatId,
                        hint: '— ${loc.get('prod_sub_cat_general')} (${mainCat.name}) —',
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('— ${loc.get('prod_sub_cat_general')} (${mainCat.name}) —',
                                style: AppTextStyles.bodyMedium.copyWith(color: hintClr)),
                          ),
                          ...mainCat.subcategories.map((sub) => DropdownMenuItem<String?>(
                            value: sub.id,
                            child: Row(children: [
                              Text(sub.icon, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Text(sub.name, style: AppTextStyles.bodyMedium.copyWith(color: textColor)),
                              if (sub.hasSubItems) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right, size: 16, color: AppColors.grey400),
                              ],
                            ]),
                          )),
                        ],
                        onChanged: (val) => setD(() {
                          selectedSubCatId  = val;
                          selectedSubItemId = null;
                          selectedSizes     = [];
                        }),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (selectedSub != null && selectedSub.hasSubItems) ...[
                      labelW('${selectedSub.icon} ${selectedSub.name} — ${loc.locale.languageCode == 'ru' ? 'Раздел' : 'Бөлүм'}'),
                      dropdownW(
                        value: selectedSubItemId,
                        hint: '— ${loc.get('prod_sub_cat_general')} (${selectedSub.name}) —',
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('— ${loc.get('prod_sub_cat_general')} (${selectedSub.name}) —',
                                style: AppTextStyles.bodyMedium.copyWith(color: hintClr)),
                          ),
                          ...selectedSub.subItems.map((item) => DropdownMenuItem<String?>(
                            value: item.id,
                            child: Row(children: [
                              Text(item.icon, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Text(item.name, style: AppTextStyles.bodyMedium.copyWith(color: textColor)),
                            ]),
                          )),
                        ],
                        onChanged: (val) => setD(() => selectedSubItemId = val),
                      ),
                      const SizedBox(height: 14),
                    ],

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        const Icon(Icons.label_outline, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_getCategoryName(effectiveCatId),
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary))),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    if (hasColors(selectedMainCatId)) ...[
                      labelW(loc.get('prod_field_colors')),
                      _colorPicker(selectedColors, setD, isDark, loc),
                      const SizedBox(height: 14),
                    ],

                    if (hasSizes(selectedMainCatId)) ...[
                      labelW(sizeLabelForCategory(selectedMainCatId, selectedSubCatId, selectedSubItemId)),
                      _sizePicker(sizesForCategory(selectedMainCatId, selectedSubCatId, selectedSubItemId), selectedSizes, setD, isDark),
                      const SizedBox(height: 14),
                    ],

                    if (hasTechFields(selectedMainCatId)) ...[
                      labelW(loc.get('prod_field_brand')), fieldW(extra1Ctrl, loc.get('prod_hint_brand_tech')), const SizedBox(height: 14),
                      labelW(loc.get('prod_field_model')), fieldW(extra2Ctrl, loc.get('prod_hint_model')),      const SizedBox(height: 14),
                      labelW(loc.get('prod_field_spec')),  fieldW(extra3Ctrl, loc.get('prod_hint_spec')),       const SizedBox(height: 14),
                    ],

                    if (hasBeautyFields(selectedMainCatId)) ...[
                      labelW(loc.get('prod_field_brand')),  fieldW(extra1Ctrl, loc.get('prod_hint_brand_beauty')), const SizedBox(height: 14),
                      labelW(loc.get('prod_field_volume')), fieldW(extra2Ctrl, loc.get('prod_hint_volume')),       const SizedBox(height: 14),
                    ],

                    if (hasAutoFields(selectedMainCatId)) ...[
                      labelW(loc.get('prod_field_brand')),      fieldW(extra1Ctrl, loc.get('prod_hint_brand_auto')),  const SizedBox(height: 14),
                      labelW(loc.get('prod_field_car_compat')), fieldW(extra2Ctrl, loc.get('prod_hint_car_compat')), const SizedBox(height: 14),
                    ],

                    labelW(loc.get('prod_field_stock')),
                    fieldW(stockCtrl, loc.get('prod_hint_stock'), type: TextInputType.number),
                    const SizedBox(height: 14),

                    labelW(loc.get('prod_field_desc')),
                    TextField(
                      controller: descCtrl, maxLines: 3,
                      style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                      decoration: InputDecoration(
                        hintText: loc.get('prod_hint_desc'), hintStyle: AppTextStyles.bodyMedium.copyWith(color: hintClr),
                        filled: true, fillColor: fieldFill,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF2B1E0A) : const Color(0xFFFFF8F0), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Text('ℹ️', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(loc.get('prod_required_note'), style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500))),
                      ]),
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () async {
                          final name  = nameCtrl.text.trim();
                          final price = double.tryParse(priceCtrl.text.trim());
                          if (name.isEmpty) { _showSnack(loc.get('prod_err_name'), isError: true); return; }
                          // negotiation болгондо баа талап кылынбайт
                          final needsPrice = !(pricingType == 'wholesale' && wholesaleMode == 'negotiation');
                          if (needsPrice && (price == null || price <= 0)) { _showSnack(loc.get('prod_err_retail_price'), isError: true); return; }
                          final wholesalePr = pricingType == 'wholesale' && wholesaleMode == 'price'
                              ? double.tryParse(wholesalePriceCtrl.text.trim())
                              : null;

                          // ── ӨЗГӨРТҮҮ 4а: Валидация — 1-сүрөт міндеттүү ──
                          if (newImageBytes[0] == null && existingImages[0].isEmpty) {
                            _showSnack(loc.get('prod_err_image'), isError: true);
                            return;
                          }

                          setD(() { isLoading = true; uploadStatus = ''; });
                          try {
                            // ── ӨЗГӨРТҮҮ 4б: 3 сүрөттү жүктөө ──
                            setD(() { isUploading = true; uploadStatus = loc.get('prod_uploading'); });
                            final List<String> finalImageUrls = [];
                            bool anyUploadFailed = false;

                            for (int i = 0; i < 3; i++) {
                              if (newImageBytes[i] != null) {
                                final Uint8List uploadBytes;
                                if (kIsWeb) {
                                  uploadBytes = newImageBytes[i]!;
                                } else {
                                  final compressed = await compressImage(newImageBytes[i]!);
                                  uploadBytes      = await addWatermark(compressed);
                                }
                                final uploaded = await YandexStorageService.instance.uploadImage(
                                  uploadBytes, folder: 'products',
                                );
                                if (uploaded == null) { anyUploadFailed = true; break; }
                                finalImageUrls.add(uploaded);
                              } else if (existingImages[i].isNotEmpty) {
                                finalImageUrls.add(existingImages[i]);
                              }
                            }

                            if (anyUploadFailed) {
                              setD(() { isLoading = false; isUploading = false; uploadStatus = ''; });
                              return;
                            }
                            setD(() { isUploading = false; uploadStatus = loc.get('prod_uploaded'); });

                            setD(() => uploadStatus = loc.get('prod_saving'));
                            final storeId    = await _getOrCreateStoreId();
                            final finalCatId = selectedSubItemId ?? selectedSubCatId ?? selectedMainCatId;
                            // negotiation болгондо баа 0 болот
                            final finalPrice = (pricingType == 'wholesale' && wholesaleMode == 'negotiation')
                                ? 0.0
                                : (price ?? 0.0);
                            final data = {
                              'title': name, 'price': finalPrice, 'category_id': finalCatId, 'store_id': storeId,
                              'images': finalImageUrls,   // ← 3 сүрөткө чейин
                              'in_stock': int.tryParse(stockCtrl.text.trim()) ?? 0,
                              'description': descCtrl.text.trim(), 'colors': selectedColors, 'sizes': selectedSizes,
                              'extra1': extra1Ctrl.text.trim(), 'extra2': extra2Ctrl.text.trim(), 'extra3': extra3Ctrl.text.trim(),
                              'rating': existing?['rating'] ?? 0.0,
                              // ── Баа тиби ──
                              'pricing_type': pricingType,
                              'wholesale_mode': wholesaleMode,
                              'wholesale_price': wholesalePr,
                            };
                            if (existing != null) {
                              await supabase.from('products').update(data).eq('id', existing['id'] as String);
                            } else {
                              await supabase.from('products').insert(data);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showSnack(existing == null ? loc.get('prod_added') : loc.get('prod_updated'));
                            _loadProducts();
                          } catch (e) {
                            setD(() { isLoading = false; isUploading = false; uploadStatus = ''; });
                            _showSnack('${loc.get('prod_save_error')}: $e', isError: true);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(existing == null ? loc.get('prod_btn_save') : loc.get('prod_btn_update'),
                                style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
                      ),
                    ),
                  ]),
                )),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _pricingBadge(Map<String, dynamic> p, AppLocalizations loc, bool isDark) {
    final type = p['pricing_type'] as String? ?? 'retail';
    if (type == 'wholesale') {
      final mode = p['wholesale_mode'] as String? ?? 'price';
      if (mode == 'negotiation') {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.handshake_outlined, color: Color(0xFF059669), size: 10),
            const SizedBox(width: 3),
            Text(loc.get('prod_badge_negotiation'),
                style: const TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.store_rounded, color: Color(0xFF7C3AED), size: 10),
          const SizedBox(width: 3),
          Text(loc.get('prod_badge_wholesale'),
              style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.person_rounded, color: AppColors.primary, size: 10),
        const SizedBox(width: 3),
        Text(loc.get('prod_badge_retail'),
            style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _noImage(bool isDark) => Container(
        width: 80, height: 80,
        decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(10)),
        child: const Center(child: Text('📦', style: TextStyle(fontSize: 28))),
      );

  // ── ӨЗГӨРТҮҮ 5: Жаңы _miniPlaceholder widget ──
  Widget _miniPlaceholder(bool isRequired) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 26,
            color: isRequired ? AppColors.primary.withValues(alpha: 0.7) : AppColors.grey400,
          ),
          const SizedBox(height: 4),
          Text(
            isRequired ? 'Сүрөт\nкошуу *' : '+',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isRequired ? AppColors.primary.withValues(alpha: 0.7) : AppColors.grey400,
            ),
          ),
        ],
      );


  Widget _colorPicker(List<String> selected, StateSetter setD, bool isDark, AppLocalizations loc) {
    final unselBg   = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7);
    final unselText = isDark ? Colors.white70 : AppColors.grey600;
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _allColors.map((c) {
        final isSelected = selected.contains(c['name']);
        return GestureDetector(
          onTap: () => setD(() { if (isSelected) selected.remove(c['name']); else selected.add(c['name'] as String); }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : unselBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 14, height: 14,
                  decoration: BoxDecoration(color: Color(c['hex'] as int), shape: BoxShape.circle, border: Border.all(color: Colors.grey.withValues(alpha: 0.3)))),
              const SizedBox(width: 6),
              Text(
                loc.locale.languageCode == 'ru' ? (c['nameRu'] as String? ?? c['name'] as String) : c['name'] as String,
                style: AppTextStyles.labelSmall.copyWith(color: isSelected ? AppColors.primary : unselText, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
              ),
              if (isSelected) ...[const SizedBox(width: 4), const Icon(Icons.check, size: 12, color: AppColors.primary)],
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _sizePicker(List<String> sizes, List<String> selected, StateSetter setD, bool isDark) {
    final unselBg   = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7);
    final unselText = isDark ? Colors.white70 : AppColors.grey600;
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: sizes.map((s) {
        final isSelected = selected.contains(s);
        return GestureDetector(
          onTap: () => setD(() { if (isSelected) selected.remove(s); else selected.add(s); }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : unselBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
            ),
            child: Text(s, style: AppTextStyles.labelMedium.copyWith(color: isSelected ? Colors.white : unselText, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          ),
        );
      }).toList(),
    );
  }
}

// ══════════ Сатуучунун убактылуу акция экраны ══════════
class SellerFlashSaleScreen extends StatefulWidget {
  final String storeId;
  const SellerFlashSaleScreen({super.key, required this.storeId});

  @override
  State<SellerFlashSaleScreen> createState() => _SellerFlashSaleScreenState();
}

class _SellerFlashSaleScreenState extends State<SellerFlashSaleScreen> {
  List<Map<String, dynamic>> _flashProducts = [];
  bool _loading = true;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  DateTime? _nearestEnd;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final rows = await supabase
          .from('products')
          .select('id, title, images, price, flash_sale_price, flash_end_time')
          .eq('store_id', widget.storeId)
          .eq('is_flash_sale', true)
          .eq('is_active', true)
          .gt('flash_end_time', now)
          .order('flash_end_time', ascending: true);

      final items = (rows as List).cast<Map<String, dynamic>>();
      DateTime? nearest;
      for (final item in items) {
        final t = _parseEnd(item);
        if (t != null && (nearest == null || t.isBefore(nearest))) nearest = t;
      }
      if (mounted) {
        setState(() { _flashProducts = items; _nearestEnd = nearest; _loading = false; });
        _startTimer();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _parseEnd(Map<String, dynamic> item) {
    final s = item['flash_end_time'] as String?;
    return s != null ? DateTime.parse(s).toLocal() : null;
  }

  void _startTimer() {
    _timer?.cancel();
    if (_nearestEnd == null) return;
    _remaining = _nearestEnd!.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final r = _nearestEnd!.difference(DateTime.now());
      if (r.isNegative) { _timer?.cancel(); _load(); return; }
      setState(() => _remaining = r);
    });
  }

  Future<void> _removeFromFlash(String productId) async {
    await supabase.from('products').update({
      'is_flash_sale': false,
      'flash_sale_price': null,
      'flash_end_time': null,
    }).eq('id', productId);
    _load();
  }

  void _showAddBottomSheet() async {
    // Сатуучунун флеш сатуудагысыз товарларын жүктө
    DateTime.now().toUtc().toIso8601String();
    final rows = await supabase
        .from('products')
        .select('id, title, images, price')
        .eq('store_id', widget.storeId)
        .eq('is_active', true)
        .or('is_flash_sale.is.null,is_flash_sale.eq.false')
        .order('title');

    final available = (rows as List).cast<Map<String, dynamic>>();
    if (!mounted) return;

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Кошуу үчүн товар жок'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFlashSheet(
        products: available,
        onAdd: (productId, flashPrice, hours) async {
          final endTime = DateTime.now().toUtc().add(Duration(hours: hours));
          await supabase.from('products').update({
            'is_flash_sale': true,
            'flash_sale_price': flashPrice,
            'flash_end_time': endTime.toIso8601String(),
          }).eq('id', productId);
          if (mounted) {
            Navigator.pop(context);
            _load();
          }
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFFDC2626),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '⚡ Убактылуу акция',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: _showAddBottomSheet,
            tooltip: 'Товар кош',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBottomSheet,
        backgroundColor: const Color(0xFFDC2626),
        icon: const Icon(Icons.bolt_rounded, color: Colors.white),
        label: const Text('Товар кош', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.error))
          : _flashProducts.isEmpty
              ? _EmptyState(onAdd: _showAddBottomSheet)
              : Column(
                  children: [
                    // Таймер
                    _MiniTimer(remaining: _remaining),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.error,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                          itemCount: _flashProducts.length,
                          itemBuilder: (_, i) => _FlashProductTile(
                            item: _flashProducts[i],
                            isDark: isDark,
                            onRemove: () => _removeFromFlash(_flashProducts[i]['id'] as String),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ── Кичи таймер ──
class _MiniTimer extends StatelessWidget {
  final Duration remaining;
  const _MiniTimer({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Text(
            'Эң жакын акция бүтөт: $h:$m:$s',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ── Товар тизме карточкасы ──
class _FlashProductTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDark;
  final VoidCallback onRemove;
  const _FlashProductTile({required this.item, required this.isDark, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final name       = item['title'] as String? ?? '';
    final images     = List<String>.from(item['images'] as List? ?? []);
    final imageUrl   = images.isNotEmpty ? images.first : '';
    final origPrice  = (item['price'] as num?)?.toDouble() ?? 0;
    final flashPrice = (item['flash_sale_price'] as num?)?.toDouble() ?? origPrice;
    final discPct    = origPrice > 0 ? ((origPrice - flashPrice) / origPrice * 100).round() : 0;
    final endStr     = item['flash_end_time'] as String?;
    final endTime    = endStr != null ? DateTime.parse(endStr).toLocal() : null;
    final timeLeft   = endTime != null ? endTime.difference(DateTime.now()) : Duration.zero;
    final h = timeLeft.inHours.toString().padLeft(2, '0');
    final mn = (timeLeft.inMinutes % 60).toString().padLeft(2, '0');

    final cardBg = isDark ? const Color(0xFF1C1C1C) : Colors.white;
    final border = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.25)),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Сүрөт
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(imageUrl: imageUrl, width: 80, height: 80, fit: BoxFit.cover)
                : Container(width: 80, height: 80, color: border, child: const Icon(Icons.image_outlined, color: AppColors.grey400)),
          ),
          const SizedBox(width: 12),
          // Маалымат
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('${flashPrice.toStringAsFixed(0)} с',
                        style: const TextStyle(color: AppColors.error, fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    if (discPct > 0)
                      Text('${origPrice.toStringAsFixed(0)} с',
                          style: TextStyle(color: isDark ? Colors.white38 : AppColors.grey400, fontSize: 11,
                              decoration: TextDecoration.lineThrough, decorationColor: isDark ? Colors.white38 : AppColors.grey400)),
                    if (discPct > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(4)),
                        child: Text('-$discPct%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.timer_outlined, size: 12, color: AppColors.error),
                    const SizedBox(width: 3),
                    Text('$h саат $mn мин калды', style: const TextStyle(color: AppColors.error, fontSize: 11)),
                  ]),
                ],
              ),
            ),
          ),
          // Жок кылуу
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 20),
            onPressed: onRemove,
            tooltip: 'Акциядан алып салуу',
          ),
        ],
      ),
    );
  }
}

// ── Товар кошуу bottom sheet ──
class _AddFlashSheet extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final Future<void> Function(String productId, double flashPrice, int hours) onAdd;
  const _AddFlashSheet({required this.products, required this.onAdd});

  @override
  State<_AddFlashSheet> createState() => _AddFlashSheetState();
}

class _AddFlashSheetState extends State<_AddFlashSheet> {
  Map<String, dynamic>? _selected;
  final _priceCtrl = TextEditingController();
  int _hours = 24;
  bool _saving = false;
  String _query = '';

  List<Map<String, dynamic>> get _filteredProducts => widget.products
      .where((p) => ((p['title'] as String?) ?? '')
          .toLowerCase()
          .contains(_query.toLowerCase().trim()))
      .toList();

  @override
  void dispose() { _priceCtrl.dispose(); super.dispose(); }

  double get _origPrice => (_selected?['price'] as num?)?.toDouble() ?? 0;
  double get _flashPrice => double.tryParse(_priceCtrl.text) ?? 0;
  int get _discPct => _origPrice > 0 && _flashPrice > 0
      ? ((_origPrice - _flashPrice) / _origPrice * 100).round() : 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final subColor = isDark ? Colors.white70 : const Color(0xFF555555);

    final filtered = _filteredProducts;
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Center(child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(2)),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(children: [
                const Icon(Icons.bolt_rounded, color: AppColors.error, size: 22),
                const SizedBox(width: 8),
                Text('Убактылуу акцияга кош',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
              ]),
            ),

            // ── Товар тизмеси ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Товарды тандаңыз', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subColor)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Товар издөө...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            SizedBox(
              height: 120,
              child: filtered.isEmpty
                  ? Center(child: Text('Товар табылган жок', style: TextStyle(color: subColor)))
                  : ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final p = filtered[i];
                  final imgs = List<String>.from(p['images'] as List? ?? []);
                  final img = imgs.isNotEmpty ? imgs.first : '';
                  final isSelected = _selected?['id'] == p['id'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selected = p;
                        _priceCtrl.text = ((p['price'] as num?)?.toDouble() ?? 0)
                            .toStringAsFixed(0);
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 10),
                      width: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.error : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: img.isNotEmpty
                                ? CachedNetworkImage(imageUrl: img, width: 70, height: 70, fit: BoxFit.cover)
                                : Container(width: 70, height: 70, color: Colors.grey.withOpacity(0.2)),
                          ),
                          const SizedBox(height: 2),
                          Text(p['title'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 9, color: subColor)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_selected != null) ...[
              const SizedBox(height: 16),

              // ── Акция баасы ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Акция баасы (с)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subColor)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Акция бааны киргиз',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      if (_discPct > 0) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('-$_discPct%',
                              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w800, fontSize: 18)),
                        ),
                      ],
                    ]),
                    if (_origPrice > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Баштапкы баа: ${_origPrice.toStringAsFixed(0)} с',
                            style: TextStyle(fontSize: 11, color: subColor)),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Убакыт ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Убакыт', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subColor)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [3, 6, 12, 24, 48, 72].map((h) {
                        final isActive = _hours == h;
                        return GestureDetector(
                          onTap: () => setState(() => _hours = h),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.error : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              h < 24 ? '$h саат' : '${h ~/ 24} күн',
                              style: TextStyle(
                                color: isActive ? Colors.white : subColor,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Кош баскычы ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_saving || _flashPrice <= 0 || _flashPrice >= _origPrice)
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            await widget.onAdd(_selected!['id'] as String, _flashPrice, _hours);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.bolt_rounded, color: Colors.white),
                            const SizedBox(width: 8),
                            Text('Акцияга кош ($_hours ${_hours < 24 ? 'саат' : 'саат'})',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                          ]),
                  ),
                ),
              ),
            ] else
              const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Бош абал ──
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⚡', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('Убактылуу акция жок',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Товарга убакыт менен арзандатуу кош',
              style: TextStyle(color: AppColors.grey400, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('Товар кош'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}