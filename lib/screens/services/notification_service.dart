// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  /// Initialize notifications
  static Future<void> init() async {
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSInit = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iOSInit,
    );

    await _notificationsPlugin.initialize(initSettings);

    // Android 13+ runtime permission
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Show a notification immediately (no scheduling) — for testing.
  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    await _notificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Immediate test notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Schedule a weekly notification (fires today if time is still ahead).
  static Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int weekday, // 1=Mon..7=Sun
    required DateTime time,
  }) async {
    final tzDate = nextInstanceOfWeekday(weekday, time);

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_channel',
          'Medication Reminders',
          channelDescription: 'Reminders to take your medication',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Compute next occurrence of a weekday & time in local tz.
  /// Fires today if the time is still in the future; otherwise next week.
  static tz.TZDateTime nextInstanceOfWeekday(int weekday, DateTime time) {
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

  /// One-time notification (used for expiry alerts and one-off tests)
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
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel a notification by its ID
  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
