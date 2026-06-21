import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../data/models/product_model.dart';
import 'package:share_plus/share_plus.dart';

class ShareWidget {
  static void show(BuildContext context, ProductModel product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareBottomSheet(product: product),
    );
  }
}

class _ShareBottomSheet extends StatelessWidget {
  final ProductModel product;

  const _ShareBottomSheet({required this.product});

  void _shareToApp(BuildContext context, String appName) {
    final text = '${product.name}\n'
        '${product.priceFormatted}\n\n'
        'https://dd-online-web.web.app/product/${product.id}';
    Navigator.pop(context);
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    final apps = [
      {
        'name': 'WhatsApp',
        'color': const Color(0xFF25D366),
        'bg':    const Color(0xFFDCF8C6),
        'svg':   _whatsappSvg,
      },
      {
        'name': 'Telegram',
        'color': const Color(0xFF0088CC),
        'bg':    const Color(0xFFD0EEFF),
        'svg':   _telegramSvg,
      },
      {
        'name': 'Instagram',
        'color': const Color(0xFFE1306C),
        'bg':    const Color(0xFFFFE0EC),
        'svg':   _instagramSvg,
      },
      {
        'name': 'Facebook',
        'color': const Color(0xFF1877F2),
        'bg':    const Color(0xFFD8EAFF),
        'svg':   _facebookSvg,
      },
      {
        'name': 'SMS',
        'color': const Color(0xFF34C759),
        'bg':    const Color(0xFFDDFFE5),
        'svg':   _smsSvg,
      },
      {
        'name':  loc.get('share_other'),
        'color': const Color(0xFF8E8E93),
        'bg':    const Color(0xFFEEEEEE),
        'svg':   _moreSvg,
      },
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(loc.get('share_title'), style: AppTextStyles.headingMedium),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey200),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    product.imageUrl,
                    width: 56, height: 56, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56, height: 56, color: AppColors.grey100,
                      child: const Icon(Icons.image_not_supported_outlined,
                          color: AppColors.grey300),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name,
                          style: AppTextStyles.labelLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(product.priceFormatted,
                          style: AppTextStyles.headingSmall
                              .copyWith(color: AppColors.primary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 1.2,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: apps.map((app) {
              final color     = app['color'] as Color;
              final bg        = app['bg'] as Color;
              final svgWidget = app['svg'] as Widget;
              final name      = app['name'] as String;

              return GestureDetector(
                onTap: () => _shareToApp(context, name),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: bg,
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Center(child: svgWidget),
                    ),
                    const SizedBox(height: 6),
                    Text(name, style: AppTextStyles.labelMedium),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () {
                final link = 'https://dd-online-web.web.app/product/${product.id}';
                Clipboard.setData(ClipboardData(text: link));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.get('share_link_copied')),
                    backgroundColor: AppColors.primary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.grey50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.link, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(loc.get('share_copy_link'),
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.primary)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── SVG Иконкалар ───────────────────────────────────

Widget get _whatsappSvg => SizedBox(
      width: 28, height: 28,
      child: CustomPaint(painter: _WhatsAppPainter()),
    );

Widget get _telegramSvg => SizedBox(
      width: 28, height: 28,
      child: CustomPaint(painter: _TelegramPainter()),
    );

Widget get _instagramSvg => SizedBox(
      width: 28, height: 28,
      child: CustomPaint(painter: _InstagramPainter()),
    );

Widget get _facebookSvg => SizedBox(
      width: 28, height: 28,
      child: CustomPaint(painter: _FacebookPainter()),
    );

Widget get _smsSvg  => const Icon(Icons.sms_rounded, color: Color(0xFF34C759), size: 26);
Widget get _moreSvg => const Icon(Icons.more_horiz_rounded, color: Color(0xFF8E8E93), size: 26);

// ─── WhatsApp ───
class _WhatsAppPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF25D366)..style = PaintingStyle.fill;
    final path  = Path();
    final s     = size.width / 24;
    path.moveTo(12 * s, 2 * s);
    path.cubicTo(6.48 * s, 2 * s, 2 * s, 6.48 * s, 2 * s, 12 * s);
    path.cubicTo(2 * s, 13.85 * s, 2.47 * s, 15.6 * s, 3.34 * s, 17.14 * s);
    path.lineTo(2 * s, 22 * s);
    path.lineTo(6.98 * s, 20.69 * s);
    path.cubicTo(8.46 * s, 21.48 * s, 10.21 * s, 22 * s, 12 * s, 22 * s);
    path.cubicTo(17.52 * s, 22 * s, 22 * s, 17.52 * s, 22 * s, 12 * s);
    path.cubicTo(22 * s, 6.48 * s, 17.52 * s, 2 * s, 12 * s, 2 * s);
    canvas.drawPath(path, paint);
    final wp = Paint()
      ..color = Colors.white..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * s..strokeCap = StrokeCap.round;
    final chat = Path();
    chat.moveTo(8.5 * s, 10 * s);
    chat.cubicTo(8.5 * s, 10 * s, 9 * s, 13.5 * s, 12 * s, 15 * s);
    chat.cubicTo(13.5 * s, 15.8 * s, 15 * s, 16 * s, 16 * s, 15.5 * s);
    canvas.drawPath(chat, wp);
  }
  @override
  bool shouldRepaint(_) => false;
}

// ─── Telegram ───
class _TelegramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0088CC)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, bg);
    final p    = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final path = Path();
    final s    = size.width / 24;
    path.moveTo(5 * s, 12 * s);
    path.lineTo(19 * s, 6 * s);
    path.lineTo(14 * s, 19 * s);
    path.lineTo(11 * s, 14 * s);
    path.close();
    canvas.drawPath(path, p);
  }
  @override
  bool shouldRepaint(_) => false;
}

// ─── Instagram ───
class _InstagramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gradient = const LinearGradient(
      colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF), Color(0xFF515BD4)],
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
    );
    final rect  = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.25));
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRRect(rrect, paint);
    final wp = Paint()
      ..color = Colors.white..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09;
    final innerRect = Rect.fromLTWH(
      size.width * 0.18, size.height * 0.18,
      size.width * 0.64, size.height * 0.64,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(innerRect, Radius.circular(size.width * 0.15)), wp);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.2, wp);
    final dot = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.28), size.width * 0.07, dot);
  }
  @override
  bool shouldRepaint(_) => false;
}

// ─── Facebook ───
class _FacebookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF1877F2)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, bg);
    final p    = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final path = Path();
    final s    = size.width;
    path.moveTo(s * 0.58, s * 0.25);
    path.lineTo(s * 0.5, s * 0.25);
    path.cubicTo(s * 0.42, s * 0.25, s * 0.42, s * 0.33, s * 0.42, s * 0.38);
    path.lineTo(s * 0.42, s * 0.45);
    path.lineTo(s * 0.35, s * 0.45);
    path.lineTo(s * 0.35, s * 0.55);
    path.lineTo(s * 0.42, s * 0.55);
    path.lineTo(s * 0.42, s * 0.78);
    path.lineTo(s * 0.53, s * 0.78);
    path.lineTo(s * 0.53, s * 0.55);
    path.lineTo(s * 0.6, s * 0.55);
    path.lineTo(s * 0.63, s * 0.45);
    path.lineTo(s * 0.53, s * 0.45);
    path.lineTo(s * 0.53, s * 0.38);
    path.cubicTo(s * 0.53, s * 0.35, s * 0.55, s * 0.33, s * 0.58, s * 0.33);
    path.close();
    canvas.drawPath(path, p);
  }
  @override
  bool shouldRepaint(_) => false;
}
