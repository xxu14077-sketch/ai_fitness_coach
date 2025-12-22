import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    // For Web, we don't need special initialization here usually, 
    // but flutter_local_notifications doesn't fully support Web scheduling easily without workers.
    // We will focus on mobile/desktop support structure, and degrade gracefully on web.

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings, // Reusing iOS settings for macOS roughly
    );

    await _notifications.initialize(settings);
    _initialized = true;
  }

  Future<void> show(String title, String body) async {
    if (kIsWeb) {
      // Web fallback: maybe just print or use browser API if needed, 
      // but for now we rely on the UI (Snackbars) for immediate feedback in the app.
      // Real web push requires service workers.
      debugPrint("Notification: $title - $body");
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'fitness_channel',
      'Fitness Reminders',
      channelDescription: 'Daily workout reminders and achievements',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecond, // unique id
      title,
      body,
      details,
    );
  }

  Future<void> scheduleDaily(TimeOfDay time) async {
    if (kIsWeb) return;

    await _notifications.zonedSchedule(
      0, // ID 0 for daily reminder
      '该训练了！💪',
      '坚持就是胜利！今天的训练计划准备好了吗？',
      _nextInstanceOfTime(time),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'fitness_channel',
          'Fitness Reminders',
          channelDescription: 'Daily workout reminders',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
