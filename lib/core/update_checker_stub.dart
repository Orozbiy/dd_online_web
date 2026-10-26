import 'package:flutter/material.dart';

// Веб платформа үчүн stub — update checker мобайлда гана иштейт
Future<void> check(BuildContext context, String langCode) async {
  // Веб'де эч нерсе кылбайт
}

/// app'тагы UpdateChecker менен бир эле API (home_screen ушуну чакырат).
/// Веб'де жаңыртуу текшерилбейт — браузер дайыма акыркы версияны жүктөйт.
class UpdateChecker {
  UpdateChecker._();
  static Future<void> check(BuildContext context, String langCode) async {}
}
