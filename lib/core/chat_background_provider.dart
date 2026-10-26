import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

enum ChatBgTheme {
  classic,   // Классикалык
  floral,    // Гүлдөр
  galaxy,    // Галактика
  aurora,    // Аврора 🌌
}

extension ChatBgThemeExt on ChatBgTheme {
  String get label {
    switch (this) {
      case ChatBgTheme.classic: return 'Классикалык';
      case ChatBgTheme.floral:  return 'Гүлдөр 🌸';
      case ChatBgTheme.galaxy:  return 'Галактика 🌌';
      case ChatBgTheme.aurora:  return 'Аврора 🌠';
    }
  }

  String localizedLabel(BuildContext context) => label;

  Color get previewColor {
    switch (this) {
      case ChatBgTheme.classic: return const Color(0xFFF0F2F5);
      case ChatBgTheme.floral:  return const Color(0xFFFFE4F0);
      case ChatBgTheme.galaxy:  return const Color(0xFF1A1040);
      case ChatBgTheme.aurora:  return const Color(0xFF0D2137);
    }
  }

  Widget buildBackground(bool isDark) {
    switch (this) {
      case ChatBgTheme.classic:
        return Container(color: isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5));
      case ChatBgTheme.floral:
        return _FloralBackground(isDark: isDark);
      case ChatBgTheme.galaxy:
        return const _GalaxyBackground();
      case ChatBgTheme.aurora:
        return const _AuroraBackground();
    }
  }

  BoxDecoration backgroundDecoration(bool isDark) {
    switch (this) {
      case ChatBgTheme.classic:
        return BoxDecoration(color: isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5));
      case ChatBgTheme.floral:
        return BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2D1020), const Color(0xFF1A0A18), const Color(0xFF2D1020)]
              : [const Color(0xFFFFF0F5), const Color(0xFFFFD6E8), const Color(0xFFFFF0F5)],
        ));
      case ChatBgTheme.galaxy:
        return const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0D0221), Color(0xFF1A0845), Color(0xFF0D1B2A)],
        ));
      case ChatBgTheme.aurora:
        return const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0D2137), Color(0xFF1A3A2A), Color(0xFF0D2137)],
        ));
    }
  }
}

// ════════════════════════════════════════════════════
// ГҮЛДӨР
// ════════════════════════════════════════════════════
class _FloralBackground extends StatelessWidget {
  final bool isDark;
  const _FloralBackground({required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: isDark
            ? [const Color(0xFF2D1020), const Color(0xFF1A0A18)]
            : [const Color(0xFFFFF0F5), const Color(0xFFFFD6E8)],
      )),
      child: CustomPaint(painter: _FloralPainter(isDark: isDark), child: const SizedBox.expand()),
    );
  }
}

class _FloralPainter extends CustomPainter {
  final bool isDark;
  _FloralPainter({required this.isDark});
  @override
  void paint(Canvas canvas, Size size) {
    final petalColor = isDark
        ? const Color(0xFFFF69B4).withOpacity(0.15)
        : const Color(0xFFFF69B4).withOpacity(0.25);
    final leafColor = isDark
        ? const Color(0xFF90EE90).withOpacity(0.10)
        : const Color(0xFF90EE90).withOpacity(0.20);
    final paint = Paint()..style = PaintingStyle.fill;
    void drawFlower(double cx, double cy, double r) {
      paint.color = petalColor;
      for (int i = 0; i < 6; i++) {
        final angle = i * math.pi / 3;
        canvas.drawCircle(Offset(cx + r * math.cos(angle), cy + r * math.sin(angle)), r * 0.6, paint);
      }
      paint.color = petalColor.withOpacity(petalColor.opacity * 1.5);
      canvas.drawCircle(Offset(cx, cy), r * 0.4, paint);
    }
    void drawLeaf(double cx, double cy, double w, double h, double angle) {
      paint.color = leafColor;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);
      final path = Path()
        ..moveTo(0, -h / 2)
        ..quadraticBezierTo(w / 2, 0, 0, h / 2)
        ..quadraticBezierTo(-w / 2, 0, 0, -h / 2);
      canvas.drawPath(path, paint);
      canvas.restore();
    }
    drawFlower(size.width * 0.15, size.height * 0.12, 28);
    drawFlower(size.width * 0.80, size.height * 0.08, 22);
    drawFlower(size.width * 0.50, size.height * 0.25, 18);
    drawFlower(size.width * 0.10, size.height * 0.55, 24);
    drawFlower(size.width * 0.88, size.height * 0.45, 30);
    drawFlower(size.width * 0.60, size.height * 0.75, 20);
    drawFlower(size.width * 0.30, size.height * 0.85, 26);
    drawFlower(size.width * 0.75, size.height * 0.90, 18);
    drawLeaf(size.width * 0.25, size.height * 0.20, 20, 40, 0.5);
    drawLeaf(size.width * 0.70, size.height * 0.60, 18, 36, -0.8);
    drawLeaf(size.width * 0.45, size.height * 0.80, 22, 44, 1.2);
  }
  @override
  bool shouldRepaint(_FloralPainter old) => false;
}


// ════════════════════════════════════════════════════
// ГАЛАКТИКА
// ════════════════════════════════════════════════════
class _GalaxyBackground extends StatelessWidget {
  const _GalaxyBackground();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF0D0221), Color(0xFF1A0845), Color(0xFF0D1B2A)],
      )),
      child: CustomPaint(painter: _GalaxyPainter(), child: const SizedBox.expand()),
    );
  }
}

class _GalaxyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final starPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 120; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.8 + 0.3;
      final opacity = rng.nextDouble() * 0.7 + 0.3;
      starPaint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), r, starPaint);
    }
    final nebula = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF7B2FBE).withOpacity(0.3), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.3, size.height * 0.3), radius: size.width * 0.4));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), nebula);
  }
  @override
  bool shouldRepaint(_GalaxyPainter old) => false;
}


// ════════════════════════════════════════════════════
// АВРОРА 🌠  (ЖАҢЫ)
// ════════════════════════════════════════════════════
class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF020818), Color(0xFF0D2137), Color(0xFF071A2F)],
      )),
      child: CustomPaint(painter: _AuroraPainter(), child: const SizedBox.expand()),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Жылдыздар
    final starPaint = Paint()..style = PaintingStyle.fill;
    final rng = math.Random(13);
    for (int i = 0; i < 80; i++) {
      starPaint.color = Colors.white.withOpacity(rng.nextDouble() * 0.6 + 0.2);
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height * 0.5),
        rng.nextDouble() * 1.2 + 0.3,
        starPaint,
      );
    }

    // Аврора лентасы — жашыл
    void drawAuroraStrip(List<Color> colors, double baseY, double amplitude, int seed) {
      final r = math.Random(seed);
      final paint = Paint()..style = PaintingStyle.fill;
      for (int layer = 0; layer < 3; layer++) {
        final path = Path();
        path.moveTo(0, size.height);
        for (double x = 0; x <= size.width; x += 2) {
          final t = x / size.width;
          final y = baseY * size.height +
              math.sin(t * 3 * math.pi + layer * 0.8) * amplitude +
              math.sin(t * 5 * math.pi + r.nextDouble()) * amplitude * 0.4;
          if (x == 0) path.moveTo(x, y);
          else path.lineTo(x, y);
        }
        path.lineTo(size.width, size.height);
        path.lineTo(0, size.height);
        path.close();
        paint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors[layer % colors.length].withOpacity(0.18 - layer * 0.04), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
        canvas.drawPath(path, paint);
      }
    }

    drawAuroraStrip([const Color(0xFF00FF88), const Color(0xFF00DDAA), const Color(0xFF00CC77)], 0.35, 30, 1);
    drawAuroraStrip([const Color(0xFF7B2FBE), const Color(0xFF9B4FDE), const Color(0xFF6B1FAE)], 0.50, 25, 2);
    drawAuroraStrip([const Color(0xFF00BFFF), const Color(0xFF0088CC), const Color(0xFF005599)], 0.42, 20, 3);
  }
  @override
  bool shouldRepaint(_AuroraPainter old) => false;
}


// ════════════════════════════════════════════════════
// PROVIDER
// ════════════════════════════════════════════════════
class ChatBackgroundProvider extends ChangeNotifier {
  static const _key = 'chat_bg_theme';
  static final ChatBackgroundProvider instance = ChatBackgroundProvider._internal();
  ChatBackgroundProvider._internal();

  ChatBgTheme _theme = ChatBgTheme.classic;
  ChatBgTheme get theme => _theme;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      _theme = ChatBgTheme.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => ChatBgTheme.classic,
      );
      notifyListeners();
    }
  }

  Future<void> setTheme(ChatBgTheme t) async {
    _theme = t;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, t.name);
  }
}