// lib/features/home/screens/flash_sale_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../config/theme/dd_design.dart';
import '../../../core/app_localizations.dart';
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

      final items = (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();

      DateTime? nearest;
      for (final item in items) {
        final endStr = item['flash_end_time'] as String?;
        if (endStr != null) {
          final t = DateTime.parse(endStr).toLocal();
          if (nearest == null || t.isBefore(nearest)) nearest = t;
        }
      }

      if (mounted) {
        setState(() { _items = items; _nearestEnd = nearest; _loading = false; });
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
      if (r.isNegative) { _timer?.cancel(); _load(); return; }
      setState(() => _remaining = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFDC2626).withOpacity(isDark ? 0.85 : 0.92),
                    const Color(0xFFB91C1C).withOpacity(isDark ? 0.80 : 0.88),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),
        leading: IconButton(
          icon: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              loc.get('flash_sale_title'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // ── Фон жарыктары ──
          Positioned.fill(child: _FlashBackground(isDark: isDark)),

          _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.error))
              : _items.isEmpty
                  ? _EmptyState()
                  : Column(
                      children: [
                        _BigTimer(remaining: _remaining),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _load,
                            color: AppColors.error,
                            child: GridView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.72,
                              ),
                              itemCount: _items.length,
                              itemBuilder: (ctx, i) => _FlashCard(item: _items[i], isDark: isDark),
                            ),
                          ),
                        ),
                      ],
                    ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// ФОН ЖАРЫКТАРЫ
// ══════════════════════════════════════════════════════
class _FlashBackground extends StatelessWidget {
  final bool isDark;
  const _FlashBackground({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _FlashBgPainter(isDark)),
    );
  }
}

class _FlashBgPainter extends CustomPainter {
  final bool isDark;
  _FlashBgPainter(this.isDark);

  void _blob(Canvas c, Offset o, double r, Color color) {
    c.drawCircle(o, r,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withOpacity(0)])
              .createShader(Rect.fromCircle(center: o, radius: r)));
  }

  @override
  void paint(Canvas canvas, Size s) {
    final bgPaint = Paint()..color = isDark ? const Color(0xFF0D0000) : const Color(0xFFFFF5F5);
    canvas.drawRect(Offset.zero & s, bgPaint);
    if (isDark) {
      _blob(canvas, Offset(s.width * 0.1, s.height * 0.08), s.width * 0.85,
          const Color(0xFFDC2626).withOpacity(0.22));
      _blob(canvas, Offset(s.width * 0.9, s.height * 0.9), s.width * 0.9,
          const Color(0xFFB91C1C).withOpacity(0.18));
      _blob(canvas, Offset(s.width * 0.5, s.height * 0.5), s.width * 0.6,
          DD.accent2.withOpacity(0.08));
    } else {
      _blob(canvas, Offset(s.width * 0.15, s.height * 0.06), s.width * 0.7,
          const Color(0xFFDC2626).withOpacity(0.10));
      _blob(canvas, Offset(s.width * 0.95, s.height * 0.88), s.width * 0.6,
          const Color(0xFFEF4444).withOpacity(0.08));
      _blob(canvas, Offset(s.width * 0.6, s.height * 0.4), s.width * 0.4,
          DD.accent2.withOpacity(0.05));
    }
  }

  @override
  bool shouldRepaint(_FlashBgPainter o) => o.isDark != isDark;
}

// ══════════════════════════════════════════════════════
// ЧОҢ ТАЙМЕР
// ══════════════════════════════════════════════════════
class _BigTimer extends StatelessWidget {
  final Duration remaining;
  const _BigTimer({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFFDC2626).withOpacity(0.80), const Color(0xFF7F1D1D).withOpacity(0.70)]
                  : [const Color(0xFFDC2626).withOpacity(0.95), const Color(0xFFEF4444).withOpacity(0.90)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.15), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withOpacity(isDark ? 0.4 : 0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
                spreadRadius: -5,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.white70, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          loc.get('flash_time_left'),
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TimeBox(value: h, label: loc.get('flash_hours')),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 22, left: 6, right: 6),
                    child: Text(' : ', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 34, fontWeight: FontWeight.w800)),
                  ),
                  _TimeBox(value: m, label: loc.get('flash_minutes')),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 22, left: 6, right: 6),
                    child: Text(' : ', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 34, fontWeight: FontWeight.w800)),
                  ),
                  _TimeBox(value: s, label: loc.get('flash_seconds')),
                ],
              ),
            ],
          ),
        ),
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
          width: 76,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
              shadows: [Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
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
    final name       = item['title'] as String? ?? '';
    final images     = List<String>.from(item['images'] as List? ?? []);
    final imageUrl   = images.isNotEmpty ? images.first : '';
    final origPrice  = (item['price'] as num?)?.toDouble() ?? 0;
    final flashPrice = (item['flash_sale_price'] as num?)?.toDouble() ?? origPrice;
    final store      = item['stores'] as Map<String, dynamic>?;
    final shopName   = store?['store_name'] as String? ?? '';

    final endStr  = item['flash_end_time'] as String?;
    final endTime = endStr != null ? DateTime.parse(endStr).toLocal() : null;
    final timeLeft = endTime != null ? endTime.difference(DateTime.now()) : Duration.zero;
    final h       = timeLeft.inHours.toString().padLeft(2, '0');
    final minLeft = (timeLeft.inMinutes % 60).toString().padLeft(2, '0');
    final discountPct = origPrice > 0 ? ((origPrice - flashPrice) / origPrice * 100).round() : 0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: ProductModel.fromMap(item))),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? const Color(0xFFDC2626).withOpacity(0.25)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // ── Карточка фону ──
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A0A0A) : Colors.white,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFFDC2626).withOpacity(0.30)
                        : const Color(0xFFDC2626).withOpacity(0.12),
                    width: 1.2,
                  ),
                ),
              ),
              // ── Фон жарык ──
              if (isDark)
                Positioned(
                  top: -30, right: -30,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        const Color(0xFFDC2626).withOpacity(0.18),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                height: 140, width: double.infinity, fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  height: 140,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: isDark
                                        ? [const Color(0xFF2A0A0A), const Color(0xFF1A0505)]
                                        : [AppColors.grey100, AppColors.grey200],
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(height: 140, color: isDark ? const Color(0xFF2C2C2C) : AppColors.grey100, child: const Icon(Icons.image_not_supported_outlined, color: AppColors.grey400)),
                              )
                            : Container(height: 140, color: isDark ? const Color(0xFF2C2C2C) : AppColors.grey100, child: const Icon(Icons.image_outlined, color: AppColors.grey400)),
                      ),
                      // ── Фото үстүнө градиент ──
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      if (discountPct > 0)
                        Positioned(
                          top: 8, left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFFDC2626).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Text('-$discountPct%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      Positioned(
                        bottom: 6, right: 6,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withOpacity(0.15)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timer_outlined, color: Colors.white70, size: 11),
                                  const SizedBox(width: 3),
                                  Text('$h:$minLeft', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: isDark ? Colors.white.withOpacity(0.85) : AppColors.grey600,
                              fontSize: 12, height: 1.3,
                            )),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('${flashPrice.toStringAsFixed(0)} с',
                                style: const TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 16, fontWeight: FontWeight.w800,
                                  shadows: [Shadow(color: Color(0x40EF4444), blurRadius: 8)],
                                )),
                            if (discountPct > 0) ...[
                              const SizedBox(width: 5),
                              Text('${origPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(color: AppColors.grey400, fontSize: 10, decoration: TextDecoration.lineThrough, decorationColor: AppColors.grey400)),
                            ],
                          ],
                        ),
                        if (shopName.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.store_rounded, size: 9, color: isDark ? Colors.white30 : AppColors.grey400),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(shopName, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: isDark ? Colors.white30 : AppColors.grey400, fontSize: 10)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
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
    final loc = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⚡', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(loc.get('flash_sale_empty'),
              style: AppTextStyles.headingSmall.copyWith(color: AppColors.grey500)),
          const SizedBox(height: 8),
          Text(loc.get('flash_sale_empty_sub'),
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400)),
        ],
      ),
    );
  }
}