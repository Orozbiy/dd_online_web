import 'package:flutter/material.dart';

/// Figma "E-Commerce Mobile App UI Kit" дизайн токендери.
/// Жайгашуусу: lib/config/theme/dd_design.dart
class DD {
  DD._();

  // Түстөр (Figma: #E84427 негизги, #E86827 экинчи, #23262F / #353945 текст)
  static const accent = Color(0xFFE84427);
  static const accent2 = Color(0xFFE86827);
  static const ink = Color(0xFF23262F);
  static const inkSoft = Color(0xFF353945);
  static const mint = Color(0xFFEDFFEF);
  static const sky = Color(0xFFE5FAFF);
  static const bgDark = Color(0xFF000000);
  static const bgDark2 = Color(0xFF0B0A0A);
  static const bgLight = Color(0xFFFCFCFD);

  static const accentGradient = LinearGradient(
    colors: [accent2, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Радиустар (Figma: пилюля 90, карта 24, badge 12)
  static const rPill = 90.0;
  static const rCard = 24.0;
  static const rBadge = 12.0;

  /// Figma'дагы айнек карта (blur + ак чек + радиал жарык)
  static BoxDecoration glass({double radius = rCard, double fill = 0.08}) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.4,
          colors: [
            Colors.white.withValues(alpha: 0.40 * (fill / 0.08).clamp(0.3, 1)),
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
      );

  /// Карточка (жарык/караңгы тема) — Figma стили: жумшак көлөкө, жукалтылган чек
  static BoxDecoration card(bool isDark, {double radius = 24}) => BoxDecoration(
        color: isDark ? null : Colors.white,
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.07),
                  Colors.white.withValues(alpha: 0.02),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark
              ? accent2.withValues(alpha: 0.18)
              : const Color(0xFFF0F0F2),
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: -8,
                ),
              ]
            : [
                BoxShadow(
                  color: ink.withValues(alpha: 0.07),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
              ],
      );
}

// ══════════════════════════════════════════════════════
// ЖАРЫК / КАРАҢГЫ — эки өзүнчө палитра (Figma стили)
// Колдонуу:  final c = DDPalette.of(context);
// ══════════════════════════════════════════════════════
class DDPalette {
  final bool isDark;
  final Color bg, card, text, subText, divider, chip, chipBorder, field;
  const DDPalette._({
    required this.isDark,
    required this.bg,
    required this.card,
    required this.text,
    required this.subText,
    required this.divider,
    required this.chip,
    required this.chipBorder,
    required this.field,
  });

  static const dark = DDPalette._(
    isDark: true,
    bg: DD.bgDark,
    card: Color(0xFF15120F),
    text: Colors.white,
    subText: Color(0xFF9A948F),
    divider: Color(0x14FFFFFF),
    chip: Color(0xFF1F1A16),
    chipBorder: Color(0xFF3A2E26),
    field: Color(0xFF1A1613),
  );

  static const light = DDPalette._(
    isDark: false,
    bg: DD.bgLight,
    card: Colors.white,
    text: DD.ink,
    subText: Color(0xFF777E90),
    divider: Color(0xFFEDEDF0),
    chip: Color(0xFFF7F7F9),
    chipBorder: Color(0xFFECECF0),
    field: Color(0xFFF4F5F7),
  );

  static DDPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Бардык экрандарга бирдей фон: кара/ак + кызгылт сары жарык (Figma "blur gradient")
class DDBackground extends StatelessWidget {
  final Widget child;
  const DDBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = DDPalette.of(context);
    return Stack(children: [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _DDBgPainter(p.isDark)),
        ),
      ),
      child,
    ]);
  }
}

class _DDBgPainter extends CustomPainter {
  final bool isDark;
  _DDBgPainter(this.isDark);

  void _blob(Canvas c, Offset o, double r, Color color) {
    final paint = Paint();
    paint.shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
        .createShader(Rect.fromCircle(center: o, radius: r));
    c.drawCircle(o, r, paint);
  }

  @override
  void paint(Canvas canvas, Size s) {
    final bgPaint = Paint();
    bgPaint.color = isDark ? DD.bgDark : DD.bgLight;
    canvas.drawRect(Offset.zero & s, bgPaint);
    if (isDark) {
      _blob(canvas, Offset(s.width * 0.12, s.height * 0.05), s.width * 0.9,
          DD.accent2.withValues(alpha: 0.26));
      _blob(canvas, Offset(s.width * 0.95, s.height * 0.92), s.width * 0.95,
          DD.accent.withValues(alpha: 0.20));
    } else {
      _blob(canvas, Offset(s.width * 0.2, s.height * 0.04), s.width * 0.75,
          DD.accent2.withValues(alpha: 0.14));
      _blob(canvas, Offset(s.width * 0.98, s.height * 0.02), s.width * 0.5,
          DD.accent.withValues(alpha: 0.10));
    }
  }

  @override
  bool shouldRepaint(_DDBgPainter o) => o.isDark != isDark;
}

/// Карточка (тема менен автоматтык өзгөрөт)
class DDCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  const DDCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = DDPalette.of(context);
    return Container(
      margin: margin,
      decoration: DD.card(p.isDark),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Градиент квадрат иконка (ичинде ак иконка)
class DDIconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  const DDIconBadge(this.icon, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: DD.accentGradient,
          borderRadius: BorderRadius.circular(size * 0.34),
          boxShadow: [
            BoxShadow(
              color: DD.accent.withValues(alpha: 0.30),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      );
}

/// Пилюля баскыч (негизги — кызгылт сары, экинчи — контурлуу)
class DDPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool outlined;
  final IconData? icon;
  const DDPillButton(this.label,
      {super.key, this.onTap, this.outlined = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final p = DDPalette.of(context);
    final fg = outlined ? DD.accent : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: outlined ? null : DD.accentGradient,
          color: outlined ? p.card : null,
          borderRadius: BorderRadius.circular(DD.rPill),
          border: outlined ? Border.all(color: DD.accent, width: 1.5) : null,
          boxShadow: outlined
              ? null
              : [
                  BoxShadow(
                    color: DD.accent.withValues(alpha: 0.40),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                    spreadRadius: -4,
                  ),
                ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 8),
          ],
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}