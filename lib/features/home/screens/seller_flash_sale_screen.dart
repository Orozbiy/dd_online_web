import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/supabase_client.dart';

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
        setState(() {
          _flashProducts = items;
          _nearestEnd = nearest;
          _loading = false;
        });
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
      if (r.isNegative) {
        _timer?.cancel();
        _load();
        return;
      }
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
    final loc = AppLocalizations.of(context);
    // Сатуучунун флеш сатуудагысыз товарларын жүктө
    // ignore: unused_local_variable
    final now = DateTime.now().toUtc().toIso8601String();
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(loc.get('promo_no_products_to_add')),
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
    final loc = AppLocalizations.of(context);
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
        title: Text(
          ' ${loc.get('flash_sale_title')}',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: _showAddBottomSheet,
            tooltip: loc.get('add_product_btn'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBottomSheet,
        backgroundColor: const Color(0xFFDC2626),
        icon: const Icon(Icons.bolt_rounded, color: Colors.white),
        label: Text(loc.get('add_product_btn'),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.error))
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
                            onRemove: () => _removeFromFlash(
                                _flashProducts[i]['id'] as String),
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
    final loc = AppLocalizations.of(context);
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
            '${loc.get('flash_sale_ends_label')}: $h:$m:$s',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
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
  const _FlashProductTile(
      {required this.item, required this.isDark, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final name = item['title'] as String? ?? '';
    final images = List<String>.from(item['images'] as List? ?? []);
    final imageUrl = images.isNotEmpty ? images.first : '';
    final origPrice = (item['price'] as num?)?.toDouble() ?? 0;
    final flashPrice =
        (item['flash_sale_price'] as num?)?.toDouble() ?? origPrice;
    final discPct = origPrice > 0
        ? ((origPrice - flashPrice) / origPrice * 100).round()
        : 0;
    final endStr = item['flash_end_time'] as String?;
    final endTime = endStr != null ? DateTime.parse(endStr).toLocal() : null;
    final timeLeft =
        endTime != null ? endTime.difference(DateTime.now()) : Duration.zero;
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
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
      ),
      child: Row(
        children: [
          // Сүрөт
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(16)),
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover)
                : Container(
                    width: 80,
                    height: 80,
                    color: border,
                    child: const Icon(Icons.image_outlined,
                        color: AppColors.grey400)),
          ),
          const SizedBox(width: 12),
          // Маалымат
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A))),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('${flashPrice.toStringAsFixed(0)} с',
                        style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    if (discPct > 0)
                      Text('${origPrice.toStringAsFixed(0)} с',
                          style: TextStyle(
                              color:
                                  isDark ? Colors.white38 : AppColors.grey400,
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                              decorationColor:
                                  isDark ? Colors.white38 : AppColors.grey400)),
                    if (discPct > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text('-$discPct%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.timer_outlined,
                        size: 12, color: AppColors.error),
                    const SizedBox(width: 3),
                    Text('$h ${loc.get('unit_hour_short')} $mn ${loc.get('unit_minute_short')} ${loc.get('time_left_suffix')}',
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 11)),
                  ]),
                ],
              ),
            ),
          ),
          // Жок кылуу
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: AppColors.error, size: 20),
            onPressed: onRemove,
            tooltip: loc.get('remove_from_promo_tooltip'),
          ),
        ],
      ),
    );
  }
}

// ── Товар кошуу bottom sheet ──
class _AddFlashSheet extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final Future<void> Function(String productId, double flashPrice, int hours)
      onAdd;
  const _AddFlashSheet({required this.products, required this.onAdd});

  @override
  State<_AddFlashSheet> createState() => _AddFlashSheetState();
}

class _AddFlashSheetState extends State<_AddFlashSheet> {
  Map<String, dynamic>? _selected;
  final _priceCtrl = TextEditingController();
  int _hours = 24;
  bool _saving = false;

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  double get _origPrice => (_selected?['price'] as num?)?.toDouble() ?? 0;
  double get _flashPrice => double.tryParse(_priceCtrl.text) ?? 0;
  int get _discPct => _origPrice > 0 && _flashPrice > 0
      ? ((_origPrice - _flashPrice) / _origPrice * 100).round()
      : 0;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final subColor = isDark ? Colors.white70 : const Color(0xFF555555);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Center(
                child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2)),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(children: [
                const Icon(Icons.bolt_rounded,
                    color: AppColors.error, size: 22),
                const SizedBox(width: 8),
                Text(loc.get('flash_sale_add_title'),
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark ? Colors.white : const Color(0xFF1A1A1A))),
              ]),
            ),

            // ── Товар тизмеси ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(loc.get('promo_select_product'),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: subColor)),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.products.length,
                itemBuilder: (_, i) {
                  final p = widget.products[i];
                  final imgs = List<String>.from(p['images'] as List? ?? []);
                  final img = imgs.isNotEmpty ? imgs.first : '';
                  final isSelected = _selected?['id'] == p['id'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selected = p;
                        _priceCtrl.text =
                            ((p['price'] as num?)?.toDouble() ?? 0)
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
                          color:
                              isSelected ? AppColors.error : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: img.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: img,
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover)
                                : Container(
                                    width: 70,
                                    height: 70,
                                    color: Colors.grey.withOpacity(0.2)),
                          ),
                          const SizedBox(height: 2),
                          Text(p['title'] as String? ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                    Text(loc.get('promo_price_label'),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: subColor)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: loc.get('promo_price_hint'),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xFFF5F5F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      if (_discPct > 0) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('-$_discPct%',
                              style: const TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18)),
                        ),
                      ],
                    ]),
                    if (_origPrice > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                            '${loc.get('promo_original_price_label')}: ${_origPrice.toStringAsFixed(0)} с',
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
                    Text(loc.get('time_label'),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: subColor)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [3, 6, 12, 24, 48, 72].map((h) {
                        final isActive = _hours == h;
                        return GestureDetector(
                          onTap: () => setState(() => _hours = h),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.error
                                  : (isDark
                                      ? const Color(0xFF2A2A2A)
                                      : const Color(0xFFF0F0F0)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              h < 24 ? '$h ${loc.get('unit_hour_short')}' : '${h ~/ 24} ${loc.get('unit_day_short')}',
                              style: TextStyle(
                                color: isActive ? Colors.white : subColor,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
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
                    onPressed: (_saving ||
                            _flashPrice <= 0 ||
                            _flashPrice >= _origPrice)
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            await widget.onAdd(_selected!['id'] as String,
                                _flashPrice, _hours);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                const Icon(Icons.bolt_rounded,
                                    color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                    '${loc.get('promo_add_to_sale_btn')} ($_hours ${loc.get('unit_hour_short')})',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15)),
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
    final loc = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⚡', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(loc.get('flash_sale_empty_title'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(loc.get('flash_sale_empty_subtitle'),
              style: TextStyle(color: AppColors.grey400, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.bolt_rounded),
            label: Text(loc.get('add_product_btn')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}
