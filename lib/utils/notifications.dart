import 'package:flutter_local_notifications/flutter_local_notifications.dart';


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();


/// 🔹 Konum hatası bildirimi
Future<void> showLocationErrorNotification() async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'location_error',
    'Konum Hataları',
    channelDescription: 'Konum izni veya arka plan konumu hataları için bildirimler.',
    importance: Importance.max,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  const NotificationDetails details = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    0,
    'Konum Takibi Başarısız',
    '📍 Lütfen arka plan konum iznini veriniz.',
    details,
    payload: 'open_permissions',
  );
}


/// 🔹 Takip bildirimi iptali
Future<void> cancelTrackingNotification() async {
  await flutterLocalNotificationsPlugin.cancel(999);
}
