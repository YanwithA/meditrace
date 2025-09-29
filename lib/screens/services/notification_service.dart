import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSInit = DarwinInitializationSettings();

    const initSettings =
    InitializationSettings(android: androidInit, iOS: iOSInit);

    await _notificationsPlugin.initialize(initSettings);
  }

  /// Weekly notification (already used in your reminders)
  static Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int weekday, // 1=Mon..7=Sun
    required DateTime time,
  }) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfWeekday(weekday, time),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_channel',
          'Weekly Reminders',
          channelDescription: 'Weekly medicine reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static tz.TZDateTime _nextInstanceOfWeekday(int weekday, DateTime time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }
    return scheduledDate;
  }

  /// ❗ NEW: One-time notification (for expiry alerts)
  static Future<void> scheduleOneTimeNotification({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    final tzTime = tz.TZDateTime.from(dateTime, tz.local);

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'expiry_channel',
          'Expiry Alerts',
          channelDescription: 'Medicine expiry alerts',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );
  }

  /// Cancel a notification by ID
  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
