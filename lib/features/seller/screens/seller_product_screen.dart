import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/supabase_client.dart';
import '../../home/models/category_model.dart';

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
  static const _cloudName    = 'dedwm4krp';
  static const _uploadPreset = 'dd-online';

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
    {'name': 'Кара',         'hex': 0xFF000000},
    {'name': 'Ак',           'hex': 0xFFFFFFFF},
    {'name': 'Кызыл',        'hex': 0xFFEF4444},
    {'name': 'Көк',          'hex': 0xFF3B82F6},
    {'name': 'Жашыл',        'hex': 0xFF22C55E},
    {'name': 'Сары',         'hex': 0xFFEAB308},
    {'name': 'Кызгылт',      'hex': 0xFFEC4899},
    {'name': 'Күрөң',        'hex': 0xFF92400E},
    {'name': 'Боз',          'hex': 0xFF6B7280},
    {'name': 'Күлгүн',       'hex': 0xFF8B5CF6},
    {'name': 'Кызгылт сары', 'hex': 0xFFF97316},
    {'name': 'Ачык көк',     'hex': 0xFF06B6D4},
    {'name': 'Бежевый',      'hex': 0xFFF5F0DC},
    {'name': 'Кремовый',     'hex': 0xFFFFFDD0},
    {'name': 'Жыгач',        'hex': 0xFF8B4513},
    {'name': 'Алтын',        'hex': 0xFFFFD700},
    {'name': 'Күмүш',        'hex': 0xFFC0C0C0},
    {'name': 'Кара жашыл',   'hex': 0xFF006400},
    {'name': 'Темно-көк',    'hex': 0xFF00008B},
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
      _products = (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      _isLoading = false;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    _showSnack('Жүктөөдө ката: $e', isError: true);
  }
}
  Future<String?> _uploadToCloudinary(Uint8List bytes) async {
    final loc = AppLocalizations.of(context);
    try {
      final uri     = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'product_${DateTime.now().millisecondsSinceEpoch}.jpg'));
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response         = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['secure_url'] as String?;
      }
      final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
      final errorMsg  = errorData?['error']?['message'] ?? loc.get('error');
      if (mounted) _showSnack('${loc.get('prod_img_upload_fail')}: $errorMsg', isError: true);
      return null;
    } catch (e) {
      if (mounted) _showSnack('${loc.get('prod_check_internet')}: $e', isError: true);
      return null;
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

  void _showDiscountSheet(Map<String, dynamic> product) {
    final loc   = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final ctrl  = TextEditingController(text: (product['discount_percent'] as num?)?.toString() ?? '');
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(loc.get('discount_title'), style: AppTextStyles.headingSmall),
                const SizedBox(height: 4),
                Text('${loc.get('discount_original_price')}: ${price.toStringAsFixed(0)} ${loc.get('currency')}',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500)),
                const SizedBox(height: 20),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  onChanged: recalc,
                  style: TextStyle(color: isDark ? Colors.white : AppColors.black),
                  decoration: InputDecoration(
                    labelText: loc.get('discount_percent_label'),
                    suffixText: '%',
                    filled: true,
                    fillColor: fieldFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2)),
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
                        Text('$percent% ${loc.get('discount_label')}',
                            style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
                        Text('${discountedPrice!.toStringAsFixed(0)} ${loc.get('currency')}',
                            style: AppTextStyles.headingSmall.copyWith(color: AppColors.error)),
                        Text('${(price - discountedPrice!).toStringAsFixed(0)} ${loc.get('discount_saved')}',
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
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
                    child: Text(loc.get('discount_add_btn'),
                        style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
                if ((product['discount_percent'] as num? ?? 0) > 0) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity, height: 44,
                    child: OutlinedButton(
                      onPressed: () async {
                        await supabase.from('products').update(
                            {'discount_percent': null, 'discounted_price': null, 'has_promotion': false})
                            .eq('id', product['id'] as String);
                        _showSnack(loc.get('discount_removed'));
                        _loadProducts();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(loc.get('discount_remove_btn'),
                          style: const TextStyle(color: AppColors.error)),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveDiscount({required String productId, required Map<String, dynamic> product, required int percent, required double discountedPrice}) async {
    final loc = AppLocalizations.of(context);
    await supabase.from('products').update(
        {'discount_percent': percent, 'discounted_price': discountedPrice, 'has_promotion': true})
        .eq('id', productId);
    _showSnack(loc.get('discount_saved_msg'));
    _loadProducts();
  }

  String _getCategoryName(String id) {
    if (id.isEmpty) return '📦 Башка';
    final parts  = id.split('_');
    final mainId = parts[0];
    try {
      final cat = _allCategories.firstWhere((c) => c.id == mainId);
      if (parts.length > 1) {
        try { final sub = cat.subcategories.firstWhere((s) => s.id == id); return '${cat.icon} ${cat.name} › ${sub.icon} ${sub.name}'; } catch (_) {}
      }
      return '${cat.icon} ${cat.name}';
    } catch (_) {}
    final legacy = _legacyCategories.firstWhere((c) => c['id'] == id, orElse: () => {'name': 'Башка', 'icon': '📦'});
    return '${legacy['icon']} ${legacy['name']}';
  }

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredProducts;
    final usedMainCatIds = _products.map((p) => (p['category_id'] as String? ?? '').split('_')[0]).toSet();

    final bgColor      = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);
    final appBarColor  = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor   = isDark ? Colors.white : AppColors.black;
    final catBarColor  = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final cardColor    = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final prodNameColor = isDark ? Colors.white : AppColors.black;
    final divColor     = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : AppColors.grey600),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(loc.get('my_products'),
              style: AppTextStyles.headingSmall.copyWith(color: titleColor)),
          Text(widget.shopName,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
        ]),
        actions: [
          IconButton(
            onPressed: _loadProducts,
            icon: Icon(Icons.refresh, color: isDark ? Colors.white70 : AppColors.grey600),
            tooltip: loc.get('refresh'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Категория фильтр ──
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

          // ── Товарлар тизмеси ──
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
                        Text(
                          _selectedCategoryId == null ? loc.get('prod_empty_hint') : loc.get('prod_empty_cat_hint'),
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500),
                          textAlign: TextAlign.center,
                        ),
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
                                // Сүрөт
                                GestureDetector(
                                  onTap: () => _showDiscountSheet(p),
                                  child: Stack(children: [
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
                                          child: Text('-${p['discount_percent']}%',
                                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                  ]),
                                ),
                                const SizedBox(width: 12),

                                // Маалымат
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(p['title'] as String? ?? '',
                                      style: AppTextStyles.labelLarge.copyWith(color: prodNameColor),
                                      maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text('${(p['price'] as num?)?.toStringAsFixed(0) ?? 0} ${loc.get('currency')}',
                                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
                                  const SizedBox(height: 2),
                                  Text(_getCategoryName(p['category_id'] as String? ?? ''),
                                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${loc.get('banner_stock_label')}: ${p['in_stock'] ?? 0} ${loc.get('pcs')}',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: (p['in_stock'] as int? ?? 0) > 0 ? AppColors.success : AppColors.error,
                                    ),
                                  ),
                                  if (colors.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(children: colors.take(5).map((name) {
                                      final c = _allColors.firstWhere((x) => x['name'] == name, orElse: () => {'hex': 0xFF888888});
                                      return Container(
                                        width: 14, height: 14,
                                        margin: const EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(color: Color(c['hex'] as int), shape: BoxShape.circle, border: Border.all(color: Colors.grey.withValues(alpha: 0.3))),
                                      );
                                    }).toList()),
                                  ],
                                  if (sizes.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${loc.get('size_label')}: ${sizes.take(3).join(', ')}${sizes.length > 3 ? ' +${sizes.length - 3}' : ''}',
                                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ])),

                                // Өзгөртүү / Өчүрүү
                                Column(children: [
                                  GestureDetector(
                                    onTap: () => _showProductDialog(existing: p),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.edit, size: 18, color: Color(0xFF0369A1)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => _deleteProduct(p['id'] as String? ?? '', p['title'] as String? ?? ''),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.delete, size: 18, color: AppColors.error),
                                    ),
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
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : unselBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(name, style: AppTextStyles.labelMedium.copyWith(
            color: isSelected ? Colors.white : unselText,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
          )),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withValues(alpha: 0.25) : AppColors.grey300,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.grey600,
            )),
          ),
        ]),
      ),
    );
  }

  Future<void> _showProductDialog({Map<String, dynamic>? existing}) async {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final nameCtrl   = TextEditingController(text: existing?['title'] ?? '');
    final priceCtrl  = TextEditingController(text: existing?['price']?.toString() ?? '');
    final descCtrl   = TextEditingController(text: existing?['description'] ?? '');
    final stockCtrl  = TextEditingController(text: existing?['in_stock']?.toString() ?? '');
    final extra1Ctrl = TextEditingController(text: existing?['extra1'] ?? '');
    final extra2Ctrl = TextEditingController(text: existing?['extra2'] ?? '');
    final extra3Ctrl = TextEditingController(text: existing?['extra3'] ?? '');

    final existingCatId      = existing?['category_id'] as String? ?? '1';
    final existingParts      = existingCatId.split('_');
    String selectedMainCatId = existingParts[0];
    String? selectedSubCatId = existingParts.length > 1 ? existingCatId : null;

    bool mainCatExists = false;
    try { _allCategories.firstWhere((c) => c.id == selectedMainCatId); mainCatExists = true; } catch (_) {}
    if (!mainCatExists) { selectedMainCatId = '1'; selectedSubCatId = null; }

    List<String> selectedColors = List<String>.from(existing?['colors'] ?? []);
    List<String> selectedSizes  = List<String>.from(existing?['sizes']  ?? []);

    Uint8List? imageBytes;
    final existingImages    = List<String>.from(existing?['images'] as List? ?? []);
    String existingImageUrl = existingImages.isNotEmpty ? existingImages.first : '';
    bool isUploading   = false;
    bool isLoading     = false;
    String uploadStatus = '';

    // ── Диалог түстөрү ──
    final dialogBg  = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fieldFill = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7);
    final textColor = isDark ? Colors.white : AppColors.black;
    final labelClr  = isDark ? const Color(0xFFCCCCCC) : AppColors.grey600;
    final hintClr   = isDark ? const Color(0xFF666666) : AppColors.grey400;
    final dropBg    = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7);

    List<String> sizesForCategory(String mainId, [String? subId]) {
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

    String sizeLabelForCategory(String mainId, [String? subId]) {
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

    bool hasSizes(String mainId)       => ['1', '2', '14'].contains(mainId);
    bool hasColors(String mainId)      => ['1', '2', '3', '7', '8', '9', '14'].contains(mainId);
    bool hasTechFields(String mainId)  => ['4', '6'].contains(mainId);
    bool hasBeautyFields(String mainId)=> ['9', '10'].contains(mainId);
    bool hasAutoFields(String mainId)  => mainId == '12';

    Future<void> pickImage(StateSetter setD) async {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: dialogBg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2))),
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
        ])),
      );
      if (source == null) return;
      try {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: source);
        if (picked != null) { final bytes = await picked.readAsBytes(); setD(() => imageBytes = bytes); }
      } catch (e) {
        _showSnack('${loc.get('prod_img_pick_error')}: $e', isError: true);
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) {
          CategoryModel mainCat = _allCategories.firstWhere((c) => c.id == selectedMainCatId, orElse: () => _allCategories.first);
          final effectiveCatId  = selectedSubCatId ?? selectedMainCatId;

          Widget labelW(String text) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(text, style: AppTextStyles.labelMedium.copyWith(color: labelClr)),
          );

          Widget fieldW(TextEditingController ctrl, String hint, {TextInputType type = TextInputType.text}) =>
              TextField(
                controller: ctrl, keyboardType: type,
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: hintClr),
                  filled: true, fillColor: fieldFill,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
              );

          return Dialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92, maxWidth: 520),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // ── Башлык ──
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

                // ── Форма ──
                Flexible(child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // 1. СҮРӨТ
                    labelW(loc.get('prod_field_image')),
                    GestureDetector(
                      onTap: () => pickImage(setD),
                      child: Container(
                        width: double.infinity, height: 160,
                        decoration: BoxDecoration(
                          color: fieldFill,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: imageBytes != null || existingImageUrl.isNotEmpty ? AppColors.primary : AppColors.grey300,
                            width: 1.5,
                          ),
                        ),
                        child: imageBytes != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.memory(imageBytes!, fit: BoxFit.cover))
                            : existingImageUrl.isNotEmpty
                                ? ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.network(existingImageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _uploadPlaceholder(loc)))
                                : _uploadPlaceholder(loc),
                      ),
                    ),
                    if (isUploading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 4),
                      Text(uploadStatus, style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
                    ],
                    const SizedBox(height: 14),

                    // 2. АТЫ
                    labelW(loc.get('prod_field_name')),
                    fieldW(nameCtrl, loc.get('prod_hint_name')),
                    const SizedBox(height: 14),

                    // 3. БААСЫ
                    labelW(loc.get('prod_field_price')),
                    fieldW(priceCtrl, loc.get('prod_hint_price'), type: TextInputType.number),
                    const SizedBox(height: 14),

                    // 4. НЕГИЗГИ КАТЕГОРИЯ
                    labelW(loc.get('prod_field_main_cat')),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(color: dropBg, borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                        value: selectedMainCatId, isExpanded: true,
                        dropdownColor: dropBg,
                        style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                        items: _allCategories.map((c) => DropdownMenuItem(value: c.id,
                            child: Text('${c.icon}  ${c.name}', style: AppTextStyles.bodyMedium.copyWith(color: textColor)))).toList(),
                        onChanged: (val) {
                          if (val != null) setD(() { selectedMainCatId = val; selectedSubCatId = null; selectedColors = []; selectedSizes = []; });
                        },
                      )),
                    ),
                    const SizedBox(height: 14),

                    // 5. КИЧИ КАТЕГОРИЯ
                    labelW(loc.get('prod_field_sub_cat')),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(color: dropBg, borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(child: DropdownButton<String?>(
                        value: selectedSubCatId, isExpanded: true,
                        dropdownColor: dropBg,
                        style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                        hint: Text('— ${loc.get('prod_sub_cat_general')} (${mainCat.name}) —',
                            style: AppTextStyles.bodyMedium.copyWith(color: hintClr)),
                        items: [
                          DropdownMenuItem<String?>(value: null, child: Text('— ${loc.get('prod_sub_cat_general')} (${mainCat.name}) —',
                              style: AppTextStyles.bodyMedium.copyWith(color: hintClr))),
                          ...mainCat.subcategories.map((sub) => DropdownMenuItem<String?>(value: sub.id,
                              child: Text('${sub.icon}  ${sub.name}', style: AppTextStyles.bodyMedium.copyWith(color: textColor)))),
                        ],
                        onChanged: (val) => setD(() => selectedSubCatId = val),
                      )),
                    ),
                    const SizedBox(height: 6),
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
                      _colorPicker(selectedColors, setD, isDark),
                      const SizedBox(height: 14),
                    ],

                    if (hasSizes(selectedMainCatId)) ...[
                      labelW(sizeLabelForCategory(selectedMainCatId, selectedSubCatId)),
                      _sizePicker(sizesForCategory(selectedMainCatId, selectedSubCatId), selectedSizes, setD, isDark),
                      const SizedBox(height: 14),
                    ],

                    if (hasTechFields(selectedMainCatId)) ...[
                      labelW(loc.get('prod_field_brand')), fieldW(extra1Ctrl, loc.get('prod_hint_brand_tech')), const SizedBox(height: 14),
                      labelW(loc.get('prod_field_model')), fieldW(extra2Ctrl, loc.get('prod_hint_model')), const SizedBox(height: 14),
                      labelW(loc.get('prod_field_spec')),  fieldW(extra3Ctrl, loc.get('prod_hint_spec')),  const SizedBox(height: 14),
                    ],
                    if (hasBeautyFields(selectedMainCatId)) ...[
                      labelW(loc.get('prod_field_brand')),  fieldW(extra1Ctrl, loc.get('prod_hint_brand_beauty')), const SizedBox(height: 14),
                      labelW(loc.get('prod_field_volume')), fieldW(extra2Ctrl, loc.get('prod_hint_volume')),       const SizedBox(height: 14),
                    ],
                    if (hasAutoFields(selectedMainCatId)) ...[
                      labelW(loc.get('prod_field_brand')),       fieldW(extra1Ctrl, loc.get('prod_hint_brand_auto')),  const SizedBox(height: 14),
                      labelW(loc.get('prod_field_car_compat')),  fieldW(extra2Ctrl, loc.get('prod_hint_car_compat')), const SizedBox(height: 14),
                    ],

                    labelW(loc.get('prod_field_stock')),
                    fieldW(stockCtrl, loc.get('prod_hint_stock'), type: TextInputType.number),
                    const SizedBox(height: 14),

                    labelW(loc.get('prod_field_desc')),
                    TextField(controller: descCtrl, maxLines: 3,
                        style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                        decoration: InputDecoration(
                          hintText: loc.get('prod_hint_desc'),
                          hintStyle: AppTextStyles.bodyMedium.copyWith(color: hintClr),
                          filled: true, fillColor: fieldFill,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        )),

                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2B1E0A) : const Color(0xFFFFF8F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Text('ℹ️', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(loc.get('prod_required_note'),
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500))),
                      ]),
                    ),
                    const SizedBox(height: 18),

                    // ── САКТОО ──
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () async {
                          final name  = nameCtrl.text.trim();
                          final price = double.tryParse(priceCtrl.text.trim());
                          if (name.isEmpty)                              { _showSnack(loc.get('prod_err_name'),  isError: true); return; }
                          if (price == null || price <= 0)               { _showSnack(loc.get('prod_err_price'), isError: true); return; }
                          if (imageBytes == null && existingImageUrl.isEmpty) { _showSnack(loc.get('prod_err_image'), isError: true); return; }

                          setD(() { isLoading = true; uploadStatus = ''; });
                          try {
                            String imageUrl = existingImageUrl;
                            if (imageBytes != null) {
                              setD(() { isUploading = true; uploadStatus = loc.get('prod_uploading'); });
                              final compressed = await compressImage(imageBytes!);
                              final uploaded   = await _uploadToCloudinary(compressed);
                              if (uploaded == null) { setD(() { isLoading = false; isUploading = false; uploadStatus = ''; }); return; }
                              imageUrl = uploaded;
                              setD(() { isUploading = false; uploadStatus = loc.get('prod_uploaded'); });
                            }
                            setD(() => uploadStatus = loc.get('prod_saving'));

                            final storeId    = await _getOrCreateStoreId();
                            final finalCatId = selectedSubCatId ?? selectedMainCatId;
                            final data = {
                              'title': name, 'price': price, 'category_id': finalCatId, 'store_id': storeId,
                              'images': [imageUrl], 'in_stock': int.tryParse(stockCtrl.text.trim()) ?? 0,
                              'description': descCtrl.text.trim(), 'colors': selectedColors, 'sizes': selectedSizes,
                              'extra1': extra1Ctrl.text.trim(), 'extra2': extra2Ctrl.text.trim(), 'extra3': extra3Ctrl.text.trim(),
                              'rating': existing?['rating'] ?? 0.0,
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

  Widget _noImage(bool isDark) => Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(child: Text('📦', style: TextStyle(fontSize: 28))),
      );

  Widget _uploadPlaceholder(AppLocalizations loc) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.grey400),
          const SizedBox(height: 8),
          Text(loc.get('prod_img_tap'), style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey400)),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.camera_alt_outlined, size: 14, color: AppColors.grey300),
            const SizedBox(width: 4),
            Text(loc.get('prod_img_camera'), style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey300)),
            const SizedBox(width: 10),
            const Icon(Icons.photo_library_outlined, size: 14, color: AppColors.grey300),
            const SizedBox(width: 4),
            Text(loc.get('prod_img_gallery'), style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey300)),
          ]),
        ],
      );

  Widget _colorPicker(List<String> selected, StateSetter setD, bool isDark) {
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
              Container(width: 14, height: 14, decoration: BoxDecoration(color: Color(c['hex'] as int), shape: BoxShape.circle, border: Border.all(color: Colors.grey.withValues(alpha: 0.3)))),
              const SizedBox(width: 6),
              Text(c['name'] as String, style: AppTextStyles.labelSmall.copyWith(
                  color: isSelected ? AppColors.primary : unselText,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
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
            child: Text(s, style: AppTextStyles.labelMedium.copyWith(
                color: isSelected ? Colors.white : unselText,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          ),
        );
      }).toList(),
    );
  }
}
