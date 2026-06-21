import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';
import '../../../services/price_watch_service.dart';


class CreatePromotionScreen extends StatefulWidget {
  const CreatePromotionScreen({super.key});

  @override
  State<CreatePromotionScreen> createState() => _CreatePromotionScreenState();
}

class _CreatePromotionScreenState extends State<CreatePromotionScreen> {
  final _searchCtrl   = TextEditingController();
  final _discountCtrl = TextEditingController();

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filtered    = [];
  Map<String, dynamic>? _selected;
  double? _discountedPrice;
  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final stores   = await supabase.from('stores').select('id').eq('owner_id', uid);
    final storeIds = (stores as List).map((s) => s['id'] as String).toList();
    if (storeIds.isEmpty) { setState(() { _allProducts = []; _filtered = []; _loading = false; }); return; }
    final rows     = await supabase.from('products').select().inFilter('store_id', storeIds);
    final products = (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    setState(() { _allProducts = products; _filtered = products; _loading = false; });
  }

  void _onSearch(String q) {
    setState(() {
      _filtered = q.isEmpty
          ? _allProducts
          : _allProducts.where((p) => (p['title'] as String? ?? '').toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  void _selectProduct(Map<String, dynamic> product) {
    _discountCtrl.clear();
    setState(() { _selected = product; _discountedPrice = null; });
  }

  void _onDiscountChanged(String val) {
    final pct   = double.tryParse(val);
    final price = (_selected?['price'] as num?)?.toDouble();
    if (pct != null && price != null && pct > 0 && pct < 100) {
      setState(() => _discountedPrice = price * (1 - pct / 100));
    } else {
      setState(() => _discountedPrice = null);
    }
  }

  Future<void> _savePromotion() async {
    final pct = double.tryParse(_discountCtrl.text);
    if (_selected == null || pct == null || pct <= 0 || pct >= 100) return;
    setState(() => _saving = true);
    try {
 await PriceWatchService().notifyWatchers(
  productId:   _selected!['id'] as String,
  productName: _selected!['title'] as String? ?? '',
  oldPrice:    (_selected!['price'] as num).toDouble(),
  newPrice:    _discountedPrice!,
);
     await supabase.from('products').update({'discount_percent': pct, 'discounted_price': _discountedPrice, 'has_promotion': true}).eq('id', _selected!['id']);

await PriceWatchService().notifyWatchers(
  productId:   _selected!['id'] as String,
  productName: _selected!['title'] as String,
  oldPrice:    (_selected!['price'] as num).toDouble(),
  newPrice:    _discountedPrice!,
);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Акция ийгилүү кошулду ✅'), backgroundColor: AppColors.success));
        setState(() {
          final idx = _allProducts.indexWhere((p) => p['id'] == _selected!['id']);
          if (idx != -1) { _allProducts[idx]['discount_percent'] = pct; _allProducts[idx]['discounted_price'] = _discountedPrice; _allProducts[idx]['has_promotion'] = true; _selected = _allProducts[idx]; }
          _discountCtrl.clear(); _discountedPrice = null;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ката: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deletePromotion() async {
    if (_selected == null) return;
    setState(() => _saving = true);
    try {
      await supabase.from('products').update({'discount_percent': null, 'discounted_price': null, 'has_promotion': false}).eq('id', _selected!['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Акция жок кылынды 🗑️'), backgroundColor: AppColors.warning));
        setState(() {
          final idx = _allProducts.indexWhere((p) => p['id'] == _selected!['id']);
          if (idx != -1) { _allProducts[idx]['discount_percent'] = null; _allProducts[idx]['discounted_price'] = null; _allProducts[idx]['has_promotion'] = false; _selected = _allProducts[idx]; }
          _discountCtrl.clear(); _discountedPrice = null;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ката: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _hasActivePromotion => _selected != null && (_selected!['has_promotion'] == true);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor    = isDark ? const Color(0xFF121212) : AppColors.grey50;
    final appBarColor = isDark ? const Color(0xFF1E1E1E) : AppColors.white;
    final titleColor  = isDark ? Colors.white : AppColors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Акция башкаруу', style: TextStyle(color: titleColor)),
        backgroundColor: appBarColor,
        foregroundColor: isDark ? Colors.white : AppColors.black,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(children: [
              _SearchBar(controller: _searchCtrl, onChanged: _onSearch),
              if (_selected != null) _SelectedProductPanel(
                product: _selected!,
                discountCtrl: _discountCtrl,
                discountedPrice: _discountedPrice,
                hasPromotion: _hasActivePromotion,
                onDiscountChanged: _onDiscountChanged,
                onDelete: _deletePromotion,
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(child: Text('Товар табылган жок', style: AppTextStyles.bodyMedium.copyWith(color: isDark ? Colors.white70 : AppColors.black)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final p          = _filtered[i];
                          final isSelected = _selected?['id'] == p['id'];
                          return _ProductListTile(product: p, isSelected: isSelected, onTap: () => _selectProduct(p));
                        },
                      ),
              ),
              _BottomSaveButton(
                enabled: _selected != null && _discountedPrice != null && !_saving,
                loading: _saving,
                onTap: _savePromotion,
              ),
            ]),
    );
  }
}

// ─────────────────────────────────────────────
// SEARCH BAR
// ─────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final barColor  = isDark ? const Color(0xFF1E1E1E) : AppColors.white;
    final fillColor = isDark ? const Color(0xFF2C2C2C) : AppColors.grey100;
    final textColor = isDark ? Colors.white : AppColors.black;

    return Container(
      color: barColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.bodyMedium.copyWith(color: textColor),
        decoration: InputDecoration(
          hintText: 'Товар издөө...',
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400),
          prefixIcon: const Icon(Icons.search, color: AppColors.grey400),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.grey400),
                  onPressed: () { controller.clear(); onChanged(''); })
              : null,
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SELECTED PRODUCT PANEL
// ─────────────────────────────────────────────
class _SelectedProductPanel extends StatelessWidget {
  final Map<String, dynamic> product;
  final TextEditingController discountCtrl;
  final double? discountedPrice;
  final bool hasPromotion;
  final ValueChanged<String> onDiscountChanged;
  final VoidCallback onDelete;

  const _SelectedProductPanel({
    required this.product, required this.discountCtrl, required this.discountedPrice,
    required this.hasPromotion, required this.onDiscountChanged, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark         = Theme.of(context).brightness == Brightness.dark;
    final originalPrice  = (product['price'] as num?)?.toDouble() ?? 0;
    final name           = product['title'] as String? ?? '';
    final images         = product['images'] as List<dynamic>? ?? [];
    final imageUrl       = images.isNotEmpty ? images.first as String : '';

    final cardColor  = isDark ? const Color(0xFF1E1E1E) : AppColors.white;
    final fieldFill  = isDark ? const Color(0xFF2C2C2C) : AppColors.grey100;
    final textColor  = isDark ? Colors.white : AppColors.black;
    final namColor   = isDark ? Colors.white : AppColors.black;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 60, height: 60, color: AppColors.grey100, child: const Icon(Icons.image_not_supported, color: AppColors.grey400))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: AppTextStyles.labelLarge.copyWith(color: namColor), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('${originalPrice.toStringAsFixed(0)} сом', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary)),
            ])),
            if (hasPromotion)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('-${(product['discount_percent'] as num?)?.toStringAsFixed(0)}%',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.error)),
              ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: discountCtrl,
            onChanged: onDiscountChanged,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}\.?\d{0,1}'))],
            style: AppTextStyles.bodyMedium.copyWith(color: textColor),
            decoration: InputDecoration(
              hintText: 'Чегерим пайызын киргизиңиз (мис: 15)',
              hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.grey400),
              suffixText: '%',
              suffixStyle: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
              filled: true,
              fillColor: fieldFill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),
          if (discountedPrice != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Text('${originalPrice.toStringAsFixed(0)} сом',
                    style: AppTextStyles.bodySmall.copyWith(decoration: TextDecoration.lineThrough, decorationColor: AppColors.grey400, color: AppColors.grey400)),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward, size: 14, color: AppColors.success),
                const SizedBox(width: 10),
                Text('${discountedPrice!.toStringAsFixed(0)} сом',
                    style: AppTextStyles.headingSmall.copyWith(color: AppColors.success)),
              ]),
            ),
          ],
          if (hasPromotion) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                label: const Text('Акцияны жок кылуу'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PRODUCT LIST TILE
// ─────────────────────────────────────────────
class _ProductListTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProductListTile({required this.product, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final name     = product['title'] as String? ?? '';
    final price    = (product['price'] as num?)?.toDouble() ?? 0;
    final images   = product['images'] as List<dynamic>? ?? [];
    final imageUrl = images.isNotEmpty ? images.first as String : '';
    final hasPromo = product['has_promotion'] == true;

    final unselBg     = isDark ? const Color(0xFF1E1E1E) : AppColors.white;
    final selBg       = AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.06);
    final unselBorder = isDark ? const Color(0xFF2C2C2C) : AppColors.grey200;
    final nameColor   = isDark ? Colors.white : AppColors.black;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? selBg : unselBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.primary : unselBorder, width: isSelected ? 1.5 : 1),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(imageUrl, width: 48, height: 48, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: AppColors.grey100, child: const Icon(Icons.image, color: AppColors.grey400, size: 20))),
          ),
          title: Text(name, style: AppTextStyles.labelLarge.copyWith(color: nameColor), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${price.toStringAsFixed(0)} сом', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
          trailing: hasPromo
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(6)),
                  child: Text('-${(product['discount_percent'] as num?)?.toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              : isSelected ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20) : null,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BOTTOM SAVE BUTTON
// ─────────────────────────────────────────────
class _BottomSaveButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _BottomSaveButton({required this.enabled, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final barColor  = isDark ? const Color(0xFF1E1E1E) : AppColors.white;
    final divColor  = isDark ? const Color(0xFF2C2C2C) : AppColors.grey200;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(color: barColor, border: Border(top: BorderSide(color: divColor))),
      child: SizedBox(
        width: double.infinity, height: 52,
        child: ElevatedButton(
          onPressed: enabled ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.grey200,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text('Акцияны сактоо', style: AppTextStyles.headingSmall.copyWith(color: AppColors.white)),
        ),
      ),
    );
  }
}