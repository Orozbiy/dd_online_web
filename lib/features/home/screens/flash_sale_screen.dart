// lib/features/home/screens/flash_sale_screen.dart
//
// Сатып алуучу үчүн Flash Sale экраны
// Drawer'дагы ⚡ баннерди бассаңда ушул ачылат
// Товарлар + чоң таймер көрүнөт

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';
import '../../../data/models/product_model.dart';
import '../../product_detail/screens/product_detail_screen.dart';

class FlashSaleScreen extends StatefulWidget {
  const FlashSaleScreen({super.key});

  @override
  State<FlashSaleScreen> createState() => _FlashSaleScreenState();
}

class _FlashSaleScreenState extends State<FlashSaleScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  DateTime? _nearestEnd;
  Duration _remaining = Duration.zero;
  Timer? _timer;

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
          .select('id, title, images, price, flash_sale_price, flash_end_time, stores(store_name)')
          .eq('is_flash_sale', true)
          .eq('is_active', true)
          .gt('flash_end_time', now)
          .order('flash_end_time', ascending: true);

      final items = (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();

      // Эң жакын аяктоо убактысы
      DateTime? nearest;
      for (final item in items) {
        final endStr = item['flash_end_time'] as String?;
        if (endStr != null) {
          final t = DateTime.parse(endStr).toLocal();
          if (nearest == null || t.isBefore(nearest)) nearest = t;
        }
      }

      if (mounted) {
        setState(() {
          _items = items;
          _nearestEnd = nearest;
          _loading = false;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
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
        _load(); // Убакыт өттү → кайра жүктө
        return;
      }
      setState(() => _remaining = r);
    });
  }

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bgColor   = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);
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
          '⚡ Тез арада жетишип кал!',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.error))
          : _items.isEmpty
              ? _EmptyState()
              : Column(
                  children: [
                    // ── Чоң таймер ──
                    _BigTimer(remaining: _remaining, fmt: _fmt),

                    // ── Товарлар Grid ──
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.error,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(14),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: _items.length,
                          itemBuilder: (ctx, i) => _FlashCard(
                            item: _items[i],
                            isDark: isDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ══════════════════════════════════════════════════════
// ЧОҢ ТАЙМЕР БЛОГУ
// ══════════════════════════════════════════════════════
class _BigTimer extends StatelessWidget {
  final Duration remaining;
  final String Function(Duration) fmt;

  const _BigTimer({required this.remaining, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Акция бүтөөгө калган убакыт',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          // Саат : Мүнөт : Секунд
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TimeBox(value: h, label: 'саат'),
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(' : ',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold)),
              ),
              _TimeBox(value: m, label: 'мүнөт'),
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(' : ',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold)),
              ),
              _TimeBox(value: s, label: 'секунд'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String value;
  final String label;

  const _TimeBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════
// ТОВАР КАРТОЧКАСЫ
// ══════════════════════════════════════════════════════
class _FlashCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDark;

  const _FlashCard({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardColor  = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final name       = item['title'] as String? ?? '';
    final images     = List<String>.from(item['images'] as List? ?? []);
    final imageUrl   = images.isNotEmpty ? images.first : '';
    final origPrice  = (item['price'] as num?)?.toDouble() ?? 0;
    final flashPrice = (item['flash_sale_price'] as num?)?.toDouble() ?? origPrice;
    final store      = item['stores'] as Map<String, dynamic>?;
    final shopName   = store?['store_name'] as String? ?? '';

    // Flash убактысы
    final endStr  = item['flash_end_time'] as String?;
    final endTime = endStr != null ? DateTime.parse(endStr).toLocal() : null;
    final timeLeft = endTime != null
        ? endTime.difference(DateTime.now())
        : Duration.zero;
    final h = timeLeft.inHours.toString().padLeft(2, '0');
    final minLeft = (timeLeft.inMinutes % 60).toString().padLeft(2, '0');

    final discountPct = origPrice > 0
        ? ((origPrice - flashPrice) / origPrice * 100).round()
        : 0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ProductDetailScreen(product: ProductModel.fromMap(item)),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.3),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Сүрөт + скидка badge ──
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 140,
                            color: isDark
                                ? const Color(0xFF2C2C2C)
                                : AppColors.grey100,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 140,
                            color: isDark
                                ? const Color(0xFF2C2C2C)
                                : AppColors.grey100,
                            child: const Icon(Icons.image_not_supported_outlined,
                                color: AppColors.grey400),
                          ),
                        )
                      : Container(
                          height: 140,
                          color: isDark
                              ? const Color(0xFF2C2C2C)
                              : AppColors.grey100,
                          child: const Icon(Icons.image_outlined,
                              color: AppColors.grey400),
                        ),
                ),
                // Скидка %
                if (discountPct > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-$discountPct%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Убакыт
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined,
                            color: Colors.white, size: 11),
                        const SizedBox(width: 3),
                        Text(
                          '$h:$minLeft',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Маалымат ──
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isDark ? Colors.white70 : AppColors.grey600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Flash баасы
                  Text(
                    '${flashPrice.toStringAsFixed(0)} с',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  // Эски баасы
                  if (discountPct > 0)
                    Text(
                      '${origPrice.toStringAsFixed(0)} с',
                      style: const TextStyle(
                        color: AppColors.grey400,
                        fontSize: 11,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: AppColors.grey400,
                      ),
                    ),
                  if (shopName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.grey400,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// БОШ АБАЛ
// ══════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⚡', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'Азырынча Flash Sale жок',
            style: AppTextStyles.headingSmall
                .copyWith(color: AppColors.grey500),
          ),
          const SizedBox(height: 8),
          Text(
            'Кийинчерээк кайра кириңиз',
            style:
                AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400),
          ),
        ],
      ),
    );
  }
}
