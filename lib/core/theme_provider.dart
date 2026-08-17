import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, system }

class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_mode';
  AppThemeMode _mode = AppThemeMode.system;

  AppThemeMode get mode => _mode;

  // Эски кодго шайкеш (башка жерде isDark колдонулса иштейт)
  bool get isDark => _mode == AppThemeMode.dark;

  ThemeMode get themeMode {
    switch (_mode) {
      case AppThemeMode.light:  return ThemeMode.light;
      case AppThemeMode.dark:   return ThemeMode.dark;
      case AppThemeMode.system: return ThemeMode.system;
    }
  }

  Future<void> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key) ?? 'system';
    _mode = AppThemeMode.values.firstWhere(
      (e) => e.name == saved,
      orElse: () => AppThemeMode.system,
    );
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  // Эски setDark() колдонулган жерлер үчүн
  Future<void> setDark(bool value) async {
    await setMode(value ? AppThemeMode.dark : AppThemeMode.light);
  }
}