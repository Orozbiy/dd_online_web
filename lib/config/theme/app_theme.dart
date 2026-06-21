import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  // ── Жалпы маанилер ──────────────────────────────────────────
  static const _borderRadius = BorderRadius.all(Radius.circular(12));
  static const _buttonRadius = BorderRadius.all(Radius.circular(8));
  static const _inputPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const _buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 12);

  static const _colorSchemeLight = ColorScheme.light(
    primary:   AppColors.primary,
    secondary: AppColors.secondary,
    surface:   AppColors.white,
    error:     Color(0xFFEC6B6B),
    outline:   Color(0xFFD1D8E4),
  );

  static const _colorSchemeDark = ColorScheme.dark(
    primary:   AppColors.primary,
    secondary: AppColors.secondary,
    surface:   Color(0xFF1E1E1E),
    error:     Color(0xFFEC6B6B),
    outline:   Color(0xFF3A3A3A),
  );

  static const _textTheme = TextTheme(
    displayLarge:  AppTextStyles.displayLarge,
    displayMedium: AppTextStyles.displayMedium,
    headlineSmall: AppTextStyles.headingLarge,
    titleLarge:    AppTextStyles.headingMedium,
    titleMedium:   AppTextStyles.headingSmall,
    bodyLarge:     AppTextStyles.bodyLarge,
    bodyMedium:    AppTextStyles.bodyMedium,
    bodySmall:     AppTextStyles.bodySmall,
    labelLarge:    AppTextStyles.labelLarge,
    labelMedium:   AppTextStyles.labelMedium,
    labelSmall:    AppTextStyles.labelSmall,
  );

  static InputDecorationTheme _inputTheme(Color fillColor) =>
      InputDecorationTheme(
        filled: true,
        fillColor: fillColor,
        contentPadding: _inputPadding,
        border: OutlineInputBorder(borderRadius: _borderRadius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: _borderRadius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: _borderRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: AppTextStyles.bodyMedium,
        prefixIconColor: AppColors.grey400,
        suffixIconColor: AppColors.grey400,
      );

  static final _buttonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      padding: _buttonPadding,
      shape: const RoundedRectangleBorder(borderRadius: _buttonRadius),
      elevation: 0,
    ),
  );

  // ── Жарык теma ──────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.white,
        colorScheme: _colorSchemeLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: AppTextStyles.headingLarge,
        ),
        textTheme: _textTheme,
        inputDecorationTheme: _inputTheme(AppColors.grey100),
        elevatedButtonTheme: _buttonTheme,
        cardTheme: CardThemeData(
          color: AppColors.white,
          elevation: 1,
          shape: const RoundedRectangleBorder(borderRadius: _borderRadius),
        ),
      );

  // ── Карагы тема ─────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: _colorSchemeDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: AppTextStyles.headingLarge,
        ),
        textTheme: _textTheme,
        inputDecorationTheme: _inputTheme(const Color(0xFF2C2C2C)),
        elevatedButtonTheme: _buttonTheme,
        cardTheme: CardThemeData(
          color: const Color(0xFF2C2C2C),
          elevation: 1,
          shape: const RoundedRectangleBorder(borderRadius: _borderRadius),
        ),
      );
}