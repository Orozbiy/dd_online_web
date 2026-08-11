// lib/features/seller/screens/flash_sale_manage_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/supabase_client.dart';

class FlashSaleManageScreen extends StatefulWidget {
  const FlashSaleManageScreen({super.key});

  @override
  State<FlashSaleManageScreen> createState() => _FlashSaleManageScreenState();
}

class _FlashSaleManageScreenState extends State<FlashSaleManageScreen> {
  final _searchCtrl     = TextEditingController();
  final _flashPriceCtrl = TextEditingController();

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filtered    = [];
  Map<String, dynamic>? _selected;

  bool _loading = true;
  bool _saving  = false;

  DateTime _endTime = DateTime.now().add(const Duration(hours: 3));
  Timer? _previewTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _updateRemaining();
    _previewTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _flashPriceCtrl.dispose();
    _previewTimer?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    if (!mounted) return;
    final r = _endTime.difference(DateTime.now());
    setState(() => _remaining = r.isNegative ? Duration.zero : r);
  }

  Future<void> _loadProducts() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final stores   = await supabase.from('stores').select('id').eq('owner_id', uid);
      final storeIds = (stores as List).map((s) => s['id'] as String).toList();
      if (storeIds.isEmpty) {
        setState(() { _allProducts = []; _filtered = []; _loading = false; });
        return;
      }
      final rows = await supabase
          .from('products')
          .select('id, title, images, price, flash_sale_price, flash_end_time, is_flash_sale, is_active')
          .inFilter('store_id', storeIds)
          .eq('is_active', true)
          .order('title');
      final products = (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      setState(() { _allProducts = products; _filtered = products; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _onSearch(String q) {
    setState(() {
      _filtered = q.isEmpty
          ? _allProducts
          : _allProducts.where((p) =>
              (p['title'] as String? ?? '').toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  void _selectProduct(Map<String, dynamic> p) {
    _flashPriceCtrl.text = (p['flash_sale_price'] as num?)?.toStringAsFixed(0) ?? '';
    final existing = p['flash_end_time'] as String?;
    if (existing != null) {
      final t = DateTime.parse(existing).toLocal();
      if (t.isAfter(DateTime.now())) _endTime = t;
    }
    setState(() => _selected = p);
    _updateRemaining();
  }

  Future<void> _pickEndTime() async {
    final loc = AppLocalizations.of(context);
    final now = DateTime.now();

    final quick = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(loc.get('fs_pick_time'), style: AppTextStyles.headingSmall),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: [
                  _quickBtn(ctx, loc.get('fs_1h'),  1),
                  _quickBtn(ctx, loc.get('fs_2h'),  2),
                  _quickBtn(ctx, loc.get('fs_3h'),  3),
                  _quickBtn(ctx, loc.get('fs_6h'),  6),
                  _quickBtn(ctx, loc.get('fs_12h'), 12),
                  _quickBtn(ctx, loc.get('fs_24h'), 24),
                  _quickBtn(ctx, loc.get('fs_48h'), 48),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, -1),
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(loc.get('fs_pick_datetime')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (quick == null) return;
    if (quick == -1) {
      final date = await showDatePicker(
        context: context,
        initialDate: _endTime,
        firstDate: now,
        lastDate: now.add(const Duration(days: 30)),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary)),
          child: child!,
        ),
      );
      if (date == null || !mounted) return;
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_endTime));
      if (time == null || !mounted) return;
      setState(() {
        _endTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      });
    } else {
      setState(() => _endTime = now.add(Duration(hours: quick)));
    }
    _updateRemaining();
  }

  Widget _quickBtn(BuildContext ctx, String label, int hours) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx, hours),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
      ),
    );
  }

  Future<void> _saveFlashSale() async {
    final loc = AppLocalizations.of(context);
    if (_selected == null) return;
    final flashPrice = double.tryParse(_flashPriceCtrl.text.trim());
    final origPrice  = (_selected!['price'] as num?)?.toDouble() ?? 0;

    if (flashPrice == null || flashPrice <= 0) {
      _showSnack(loc.get('fs_err_price'), isError: true); return;
    }
    if (flashPrice >= origPrice) {
      _showSnack(loc.get('fs_err_price_low'), isError: true); return;
    }
    if (_endTime.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
      _showSnack(loc.get('fs_err_time'), isError: true); return;
    }

    setState(() => _saving = true);
    try {
      await supabase.from('products').update({
        'is_flash_sale'    : true,
        'flash_sale_price' : flashPrice,
        'flash_end_time'   : _endTime.toUtc().toIso8601String(),
      }).eq('id', _selected!['id'] as String);

      final idx = _allProducts.indexWhere((p) => p['id'] == _selected!['id']);
      if (idx != -1) {
        setState(() {
          _allProducts[idx]['is_flash_sale']    = true;
          _allProducts[idx]['flash_sale_price'] = flashPrice;
          _allProducts[idx]['flash_end_time']   = _endTime.toIso8601String();
          _selected = _allProducts[idx];
        });
      }
      _showSnack(loc.get('fs_saved'));
    } catch (e) {
      _showSnack('${loc.get('error')}: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeFlashSale() async {
    final loc = AppLocalizations.of(context);
    if (_selected == null) return;
    setState(() => _saving = true);
    try {
      await supabase.from('products').update({
        'is_flash_sale'    : false,
        'flash_sale_price' : null,
        'flash_end_time'   : null,
      }).eq('id', _selected!['id'] as String);

      final idx = _allProducts.indexWhere((p) => p['id'] == _selected!['id']);
      if (idx != -1) {
        setState(() {
          _allProducts[idx]['is_flash_sale']    = false;
          _allProducts[idx]['flash_sale_price'] = null;
          _allProducts[idx]['flash_end_time']   = null;
          _selected = _allProducts[idx];
        });
      }
      _flashPriceCtrl.clear();
      _showSnack(loc.get('fs_removed'));
    } catch (e) {
      _showSnack('${loc.get('error')}: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _formatTime(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  bool get _hasActiveFlash =>
      _selected != null && (_selected!['is_flash_sale'] as bool? ?? false);

  @override
  Widget build(BuildContext context) {
    final loc     = AppLocalizations.of(context);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('⚡ Flash Sale', style: AppTextStyles.headingMedium),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Container(
                  color: cardColor,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearch,
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark ? Colors.white : AppColors.black),
                    decoration: InputDecoration(
                      hintText: loc.get('fs_search'),
                      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey400),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2C2C2C) : AppColors.grey100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    ),
                  ),
                ),

                if (_selected != null) _SelectedPanel(
                  product: _selected!,
                  flashPriceCtrl: _flashPriceCtrl,
                  endTime: _endTime,
                  remaining: _remaining,
                  hasActiveFlash: _hasActiveFlash,
                  formatTime: _formatTime,
                  onPickTime: _pickEndTime,
                  onRemove: _removeFlashSale,
                  isDark: isDark,
                ),

                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('📦', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text(loc.get('fs_not_found'),
                                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) {
                            final p = _filtered[i];
                            return _ProductTile(
                              product: p,
                              isSelected: _selected?['id'] == p['id'],
                              isFlash: p['is_flash_sale'] as bool? ?? false,
                              isDark: isDark,
                              onTap: () => _selectProduct(p),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: _selected != null
          ? _BottomBar(saving: _saving, hasFlash: _hasActiveFlash, onSave: _saveFlashSale, isDark: isDark)
          : null,
    );
  }
}

// ══════════════════════════════════════════════════════
// ТАНДАЛГАН ТОВАР ПАНЕЛИ
// ══════════════════════════════════════════════════════
class _SelectedPanel extends StatelessWidget {
  final Map<String, dynamic> product;
  final TextEditingController flashPriceCtrl;
  final DateTime endTime;
  final Duration remaining;
  final bool hasActiveFlash;
  final String Function(Duration) formatTime;
  final VoidCallback onPickTime;
  final VoidCallback onRemove;
  final bool isDark;

  const _SelectedPanel({
    required this.product, required this.flashPriceCtrl, required this.endTime,
    required this.remaining, required this.hasActiveFlash, required this.formatTime,
    required this.onPickTime, required this.onRemove, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final loc       = AppLocalizations.of(context);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fieldFill = isDark ? const Color(0xFF2C2C2C) : AppColors.grey100;
    final textColor = isDark ? Colors.white : AppColors.black;
    final name      = product['title'] as String? ?? '';
    final origPrice = (product['price'] as num?)?.toDouble() ?? 0;
    final images    = product['images'] as List? ?? [];
    final imageUrl  = images.isNotEmpty ? images.first as String : '';

    final flashPriceVal = double.tryParse(flashPriceCtrl.text);
    final discount = (flashPriceVal != null && origPrice > 0)
        ? ((origPrice - flashPriceVal) / origPrice * 100).round()
        : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.error.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                      : _placeholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.labelLarge.copyWith(color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${loc.get('fs_orig_price')}: ${origPrice.toStringAsFixed(0)} с',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey500)),
                    ],
                  ),
                ),
                if (hasActiveFlash)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(8)),
                    child: Text('⚡ ${loc.get('fs_active')}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            Text('⚡ ${loc.get('fs_flash_price')}',
                style: AppTextStyles.labelMedium.copyWith(color: textColor)),
            const SizedBox(height: 8),
            TextField(
              controller: flashPriceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.headingSmall.copyWith(color: AppColors.error),
              decoration: InputDecoration(
                hintText: '${loc.get('fs_example')}: ${(origPrice * 0.7).toStringAsFixed(0)}',
                hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400),
                filled: true,
                fillColor: fieldFill,
                prefixIcon: const Icon(Icons.bolt, color: AppColors.error, size: 20),
                suffixText: discount > 0 ? '-$discount%' : '',
                suffixStyle: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
              ),
            ),

            const SizedBox(height: 14),

            Text('🕐 ${loc.get('fs_ends_at')}',
                style: AppTextStyles.labelMedium.copyWith(color: textColor)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onPickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: fieldFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${endTime.day.toString().padLeft(2, '0')}.${endTime.month.toString().padLeft(2, '0')}.${endTime.year}  '
                            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                            style: AppTextStyles.labelLarge.copyWith(color: textColor),
                          ),
                          Text('${loc.get('fs_time_left')}: ${formatTime(remaining)}',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey500)),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_calendar_outlined, color: AppColors.grey400, size: 18),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text('⚡ ${loc.get('fs_timer_preview')}',
                      style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(formatTime(remaining),
                      style: const TextStyle(
                        color: AppColors.error, fontSize: 28, fontWeight: FontWeight.w800,
                        letterSpacing: 3, fontFeatures: [FontFeature.tabularFigures()],
                      )),
                ],
              ),
            ),

            if (hasActiveFlash) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.flash_off_rounded, color: AppColors.error, size: 18),
                  label: Text(loc.get('fs_remove')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : AppColors.grey100,
          borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.image_not_supported_outlined, color: AppColors.grey400));
}

// ══════════════════════════════════════════════════════
// ТОВАР ТИЗМЕСИ
// ══════════════════════════════════════════════════════
class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool isSelected;
  final bool isFlash;
  final bool isDark;
  final VoidCallback onTap;

  const _ProductTile({
    required this.product, required this.isSelected,
    required this.isFlash, required this.isDark, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name       = product['title'] as String? ?? '';
    final price      = (product['price'] as num?)?.toDouble() ?? 0;
    final flashPrice = (product['flash_sale_price'] as num?)?.toDouble();
    final images     = product['images'] as List? ?? [];
    final imageUrl   = images.isNotEmpty ? images.first as String : '';

    final unselBg     = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final selBg       = AppColors.error.withValues(alpha: isDark ? 0.12 : 0.06);
    final unselBorder = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);
    final nameColor   = isDark ? Colors.white : AppColors.black;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? selBg : unselBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.error : isFlash ? AppColors.error.withValues(alpha: 0.4) : unselBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imgPlaceholder())
                : _imgPlaceholder(),
          ),
          title: Text(name, style: AppTextStyles.labelLarge.copyWith(color: nameColor), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${price.toStringAsFixed(0)} с', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
              if (isFlash && flashPrice != null)
                Text('⚡ Flash: ${flashPrice.toStringAsFixed(0)} с',
                    style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          trailing: isFlash
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(6)),
                  child: const Text('⚡', style: TextStyle(fontSize: 14)),
                )
              : isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.error, size: 22) : null,
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
      width: 48, height: 48,
      color: const Color(0xFF2C2C2C),
      child: const Icon(Icons.image, color: AppColors.grey400, size: 20));
}

// ══════════════════════════════════════════════════════
// АСТЫҢКЫ САКТОО БАСКЫЧЫ
// ══════════════════════════════════════════════════════
class _BottomBar extends StatelessWidget {
  final bool saving;
  final bool hasFlash;
  final VoidCallback onSave;
  final bool isDark;

  const _BottomBar({required this.saving, required this.hasFlash, required this.onSave, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final loc      = AppLocalizations.of(context);
    final barColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final divColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(color: barColor, border: Border(top: BorderSide(color: divColor))),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.bolt_rounded, color: Colors.white),
          label: Text(
            hasFlash ? loc.get('fs_update') : loc.get('fs_add'),
            style: AppTextStyles.headingSmall.copyWith(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            disabledBackgroundColor: AppColors.grey300,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}