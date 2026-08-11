import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final _localNotif = FlutterLocalNotificationsPlugin();
bool _initialized = false;

// ✅ ОҢДОЛДУ: AndroidNotificationChannel — named параметрлер
const _channel = AndroidNotificationChannel(
  'chat_messages',
  'Чат билдирүүлөрү',
  description:       'DD Online чат билдирүүлөрү',
  importance:        Importance.max,
  playSound:         true,
  enableVibration:   true,
);

Future<void> initLocalNotifications() async {
  if (_initialized) return;

  await _localNotif
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);

  await _localNotif.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS:     DarwinInitializationSettings(),
    ),
  );

  _initialized = true;
}

Future<void> showLocalNotification({
  required int                   id,
  required String                title,
  required String                body,
  required String                payload,
  required void Function(String) onTap,
}) async {
  // ✅ ОҢДОЛДУ: _localNotif.show() — named параметрлер
  await _localNotif.show(
    id,
    title,
    body,
    NotificationDetails(
      // ✅ ОҢДОЛДУ: AndroidNotificationDetails — named параметрлер
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance:         Importance.max,
        priority:           Priority.high,
        icon:               '@mipmap/ic_launcher',
        playSound:          true,
        enableVibration:    true,
        channelShowBadge:   true,
        styleInformation:   BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: payload,
  );
}