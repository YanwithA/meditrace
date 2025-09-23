import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// One shared instance
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'meditrace_reminders',
    'MediTrace Reminders',
    description: 'Scheduled medication reminders',
    importance: Importance.max,
  );

  /// Call this once in main() *before* runApp
  static Future<void> init() async {
    // Timezone init
    tzdata.initializeTimeZones();
    // Use device local timezone
    final String localName = DateTime.now().timeZoneName;
    // Fallback to local if tz can't resolve (rare)
    tz.setLocalLocation(
      tz.getLocation(tz.timeZoneDatabase.locations.keys.contains(localName)
          ? localName
          : 'UTC'),
    );

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSInit = DarwinInitializationSettings();
    const init = InitializationSettings(android: androidInit, iOS: iOSInit);

    await _plugin.initialize(init);

    // Android 13+ runtime permission
    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(_channel);
      await androidImpl?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Schedule a weekly notification for a given weekday (1=Mon..7=Sun)
  /// `time` provides hour/minute; we compute the next instance.
  static Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int weekday,
    required DateTime time,
  }) async {
    final next = _nextInstanceOfWeekday(
      weekday,
      hour: time.hour,
      minute: time.minute,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      next,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.wallClockTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static tz.TZDateTime _nextInstanceOfWeekday(int weekday,
      {required int hour, required int minute}) {
    // weekday: 1=Mon..7=Sun
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
    tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // Move forward to correct weekday if needed
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
      scheduled = tz.TZDateTime(
          tz.local, scheduled.year, scheduled.month, scheduled.day, hour, minute);
    }
    return scheduled;
    // With matchDateTimeComponents: dayOfWeekAndTime, it will repeat weekly
  }

  static Future<void> cancelNotification(int id) =>
      _plugin.cancel(id);

  static Future<void> cancelAll() => _plugin.cancelAll();
}
