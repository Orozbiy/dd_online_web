// Веб платформа үчүн stub
// flutter_local_notifications веб'де жок — бул файл аны алмаштырат

Future<void> initLocalNotifications() async {
  // Веб'де эч нерсе кылбайт
}

Future<void> showLocalNotification({
  required int id,
  required String title,
  required String body,
  required String payload,
  required void Function(String) onTap,
}) async {
  // Веб'де эч нерсе кылбайт
  // notification_service.dart'та _showWebSnackbar() колдонулат
}
