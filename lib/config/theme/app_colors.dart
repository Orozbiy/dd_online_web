import 'package:flutter/material.dart';

/// Тиркеменин бардык түстүүлөрү
class AppColors {
  // Башкы түстөр - базардын жылуу түстөрү
  static const Color primary = Color(0xFFD97706);        // Алтын-оранжевый
  static const Color primaryLight = Color(0xFFF59E0B);   // Жеңил алтын
  static const Color primaryDark = Color(0xFFB45309);    // Төмөнкү алтын

  // Өстүк түстөр
  static const Color secondary = Color(0xFF8B5CF6);      // Фиолет
  static const Color secondaryLight = Color.fromARGB(0, 161, 131, 249);

  // Боюз түстөр
  static const Color black = Color(0xFF1F2937);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);

  // Статус түстөрү
  static const Color success = Color(0xFF10B981);    // Ийгилик (зелёный)
  static const Color error = Color(0xFFF87171);      // Ката (кызыл)
  static const Color warning = Color(0xFFFB923C);    // Эскертүү (сары)
  static const Color info = Color(0xFF3B82F6);       // Маалымат (көк)

  // Градиенттер - кооз эффект үчүн
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryDark, primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [grey50, Color(0xFFFEF3C7)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
