import 'dart:developer' as dev;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'firestore_service.dart';
import 'reminder_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId   = 'meditrack_reminders';
  static const String _channelName = 'Medicine Reminders';

  // ========================= INIT =========================

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    // No background handler needed — no action buttons on notifications.
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onForegroundTap,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Daily medicine reminders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );
  }

  // ========================= FOREGROUND TAP HANDLER =========================

  // Tapping the notification opens the app — snooze is inside Reminders screen.
  static Future<void> _onForegroundTap(NotificationResponse response) async {
    dev.log(
      '[NotificationService] notification tapped  payload="${response.payload}"',
      name: 'NotificationService',
    );
  }

  // ========================= MEDICINE REMINDER =========================

  static Future<int?> scheduleMedicineReminder({
    required String medicineName,
    required String foodTiming,
    required DateTime reminderTime,
    required String payload,
    DateTime? startDate,
    DateTime? endDate,
    int? notificationId,
  }) async {
    final today    = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    if (endDate != null) {
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      if (todayDay.isAfter(end)) return null;
    }

    final id = notificationId ??
        DateTime.now().millisecondsSinceEpoch.remainder(100000);

    return await _scheduleDailyAt(
      id: id,
      title: medicineName,
      body: foodTiming.isNotEmpty ? foodTiming : 'Time to take your medicine',
      time: reminderTime,
      payload: payload,
    );
  }

  /// Used by ReminderService.snooze() to schedule a +10 min one-shot.
  static Future<void> scheduleOneTimeReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
  }) async {
    await _scheduleOneTime(
        id: id, title: title, body: body,
        scheduledTime: scheduledTime, payload: payload);
  }

  // ========================= LEGACY COMPAT =========================

  static Future<int> scheduleDailyNotification({
    required String title,
    required String body,
    required DateTime time,
    required String payload,
  }) async {
    return await _scheduleDailyAt(
        title: title, body: body, time: time, payload: payload);
  }

  // ========================= INTERNAL SCHEDULING =========================

  static Future<int> _scheduleDailyAt({
    required String title,
    required String body,
    required DateTime time,
    required String payload,
    int? id,
  }) async {
    final notifId = id ??
        DateTime.now().millisecondsSinceEpoch.remainder(100000);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, time.hour, time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    dev.log('[NotificationService] schedule  id=$notifId  '
        'title="$title"  at=$scheduled', name: 'NotificationService');

    // Each notification gets its own tag (string form of the ID) so that
    // Android treats them as completely independent notifications and plays
    // sound + shows heads-up for every one, even when multiple arrive close
    // together on the same channel.
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId, _channelName,
        channelDescription: 'Medicine reminder',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        tag: 'meditrack_$notifId',
      ),
    );

    await _notifications.zonedSchedule(
      notifId, title, body, scheduled, details,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    dev.log('[NotificationService] schedule ✓  id=$notifId  at=$scheduled',
        name: 'NotificationService');
    return notifId;
  }

  static Future<void> _scheduleOneTime({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
  }) async {
    final tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);

    dev.log('[NotificationService] scheduleOneTime  id=$id  '
        'title="$title"  at=$tzScheduled', name: 'NotificationService');

    // Unique tag ensures this one-time (snooze) notification is treated
    // independently — no silent grouping, sound always plays.
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId, _channelName,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        tag: 'meditrack_$id',
      ),
    );

    await _notifications.zonedSchedule(
      id, title, body, tzScheduled, details,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    dev.log('[NotificationService] scheduleOneTime ✓  id=$id',
        name: 'NotificationService');
  }

  static Future<void> cancelNotification(int id) async {
    // Must pass the same tag used when scheduling, otherwise Android
    // won't find and cancel the notification.
    await _notifications.cancel(id, tag: 'meditrack_$id');
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  static Future<void> rescheduleAll() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final uid      = FirestoreService.uid;
      final memberId = await FirestoreService.getActiveMemberIdOnce();
      if (memberId == null) return;
      await ReminderService.rescheduleAll(uid: uid, memberId: memberId);
    } catch (_) {}
  }
}

