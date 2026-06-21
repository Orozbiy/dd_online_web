import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';
import 'seller_login_screen.dart';

class SellerCloseAccountScreen extends StatefulWidget {
  final String sellerUid;
  const SellerCloseAccountScreen({super.key, required this.sellerUid});

  @override
  State<SellerCloseAccountScreen> createState() => _SellerCloseAccountScreenState();
}

class _SellerCloseAccountScreenState extends State<SellerCloseAccountScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading  = true;
  bool _isDeleting = false;
  final Set<String> _selectedIds = {};
  String? _storeId;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final store = await supabase.from('stores').select('id').eq('owner_id', widget.sellerUid).maybeSingle();
      if (store == null) { setState(() { _products = []; _isLoading = false; }); return; }
      _storeId = store['id'] as String;
      final rows = await supabase.from('products').select().eq('store_id', _storeId!).order('created_at', ascending: false);
      setState(() {
        _products  = (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _showSnack('Жүктөөдө ката: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ));
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) { _selectedIds.remove(id); } else { _selectedIds.add(id); }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _products.length) {
        _selectedIds.clear();
      } else {
        _selectedIds..clear()..addAll(_products.map((p) => p['id'] as String));
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Товарларды өчүрүү', style: AppTextStyles.headingSmall),
        content: Text('${_selectedIds.length} товар толугу менен өчүрүлөт. Бул кайтарылгыс. Улантасызбы?', style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Жок', style: TextStyle(color: AppColors.grey500))),
          TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Ооба, өчүрүү', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isDeleting = true);
    try {
      await supabase.from('products').delete().inFilter('id', _selectedIds.toList());
      setState(() { _products.removeWhere((p) => _selectedIds.contains(p['id'])); _selectedIds.clear(); _isDeleting = false; });
      if (mounted) _showSnack('🗑️ Товарлар өчүрүлдү');
    } catch (e) {
      setState(() => _isDeleting = false);
      if (mounted) _showSnack('Өчүрүүдө ката: $e', isError: true);
    }
  }

  Future<void> _closeAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Дүкөндөн баш тартуу', style: AppTextStyles.headingSmall),
        content: const Text('Бардык товарларыңыз толугу менен өчүрүлөт жана аккаунттан чыгасыз. Бул кайтарылгыс. Улантасызбы?', style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Жок', style: TextStyle(color: AppColors.grey500))),
          TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Ооба, баш тартам', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isDeleting = true);
    try {
      if (_storeId != null) await supabase.from('products').delete().eq('store_id', _storeId!);
      await supabase.auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SellerLoginScreen()), (route) => false);
    } catch (e) {
      setState(() => _isDeleting = false);
      if (mounted) _showSnack('Ката: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final allSelected = _products.isNotEmpty && _selectedIds.length == _products.length;

    final bgColor     = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);
    final appBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final arrowColor  = isDark ? Colors.white : AppColors.black;
    final titleColor  = isDark ? Colors.white : AppColors.black;
    final warnBg      = isDark ? const Color(0xFF2B1E0A) : const Color(0xFFFFF8F0);
    final warnBorder  = AppColors.primary.withValues(alpha: isDark ? 0.5 : 0.3);
    final warnText    = isDark ? const Color(0xFFCCCCCC) : AppColors.black;
    final cardBg      = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final cardBorder  = isDark ? const Color(0xFF2C2C2C) : AppColors.grey200;
    final selBg       = isDark ? AppColors.primary.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.08);
    final labelColor  = isDark ? Colors.white : AppColors.black;
    final bottomBg    = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back, color: arrowColor),
        ),
        title: Text('Дүкөндөн баш тартуу',
            style: AppTextStyles.headingMedium.copyWith(color: titleColor)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // ── Эскертүү ──
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: warnBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: warnBorder),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('⚠️', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Товарларыңызды тандап өчүрө аласыз, же бардыгын өчүрүп аккаунттан баш тарта аласыз.',
                      style: AppTextStyles.bodyMedium.copyWith(color: warnText),
                    )),
                  ]),
                ),

                // ── Баарын белгилөө ──
                if (_products.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      Checkbox(value: allSelected, activeColor: AppColors.primary, onChanged: (_) => _toggleSelectAll()),
                      Text(
                        allSelected ? 'Баарын алып салуу' : 'Баарын белгилөө',
                        style: AppTextStyles.labelLarge.copyWith(color: labelColor),
                      ),
                      const Spacer(),
                      Text('${_selectedIds.length} тандалды',
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
                    ]),
                  ),

                // ── Товарлар тизмеси ──
                Expanded(
                  child: _products.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text('📦', style: TextStyle(fontSize: 64)),
                          const SizedBox(height: 16),
                          Text('Товар жок', style: AppTextStyles.headingSmall.copyWith(color: labelColor)),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _products.length,
                          itemBuilder: (context, i) {
                            final p          = _products[i];
                            final id         = p['id'] as String;
                            final name       = p['title'] as String? ?? 'Аты жок';
                            final price      = (p['price'] as num?)?.toDouble() ?? 0;
                            final inStock    = (p['in_stock'] as num?)?.toInt() ?? 0;
                            final images     = List<String>.from(p['images'] as List? ?? []);
                            final imageUrl   = images.isNotEmpty ? images.first : '';
                            final isSelected = _selectedIds.contains(id);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? selBg : cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : cardBorder,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                onTap: () => _toggleSelection(id),
                                leading: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Checkbox(value: isSelected, activeColor: AppColors.primary, onChanged: (_) => _toggleSelection(id)),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(imageUrl, width: 44, height: 44, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(width: 44, height: 44, color: AppColors.grey100,
                                                child: const Icon(Icons.image, color: AppColors.grey400)))
                                        : Container(width: 44, height: 44, color: AppColors.grey100,
                                            child: const Icon(Icons.image, color: AppColors.grey400)),
                                  ),
                                ]),
                                title: Text(name,
                                    style: AppTextStyles.labelLarge.copyWith(color: labelColor),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text('${price.toInt()} с • $inStock шт',
                                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
                              ),
                            );
                          },
                        ),
                ),

                // ── Аракет баскычтары ──
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  decoration: BoxDecoration(
                    color: bottomBg,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))],
                  ),
                  child: Column(children: [
                    if (_selectedIds.isNotEmpty)
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          onPressed: _isDeleting ? null : _deleteSelected,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _isDeleting
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Text('🗑️ Тандалган товарларды өчүрүү (${_selectedIds.length})',
                                  style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
                        ),
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: OutlinedButton(
                        onPressed: _isDeleting ? null : _closeAccount,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: const BorderSide(color: AppColors.error, width: 1.5),
                        ),
                        child: Text('🚪 Дүкөндөн баш тартуу (баарын өчүрүү)',
                            style: AppTextStyles.labelLarge.copyWith(color: AppColors.error)),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
    );
  }
}