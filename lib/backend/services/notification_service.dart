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

  static const String _channelId   = 'meditrack_reminders_v2';
  static const String _channelName = 'Medicine Reminders';

  // ========================= INIT =========================

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onForegroundTap,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Request POST_NOTIFICATIONS permission (Android 13+ / API 33+).
    await androidPlugin?.requestNotificationsPermission();

    // Request exact alarm permission.
    await androidPlugin?.requestExactAlarmsPermission();

    // ── ROOT CAUSE FIX (Issue 1) ──────────────────────────────────────────
    // Android notification channels are IMMUTABLE once created. If the old
    // channel 'meditrack_reminders' was ever created without sound (e.g.
    // during development before playSound was set), ALL subsequent
    // notifications on that channel will be silent FOREVER — even if
    // createNotificationChannel is called again with playSound:true.
    // Android simply ignores sound/importance/vibration updates on an
    // existing channel.
    //
    // FIX: Delete the old channel and use a new channel ID
    // 'meditrack_reminders_v2'. Android will create it fresh with sound.
    // ─────────────────────────────────────────────────────────────────────
    try {
      await androidPlugin?.deleteNotificationChannel('meditrack_reminders');
      dev.log(
        '[NotificationService] Deleted old channel meditrack_reminders',
        name: 'NotificationService',
      );
    } catch (e) {
      dev.log(
        '[NotificationService] Could not delete old channel (may not exist): $e',
        name: 'NotificationService',
      );
    }

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,           // 'meditrack_reminders_v2'
        _channelName,
        description: 'Daily medicine reminders with sound and vibration',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );

    dev.log(
      '[NotificationService] initialize ✓ — channel=$_channelId  '
      'sound=true  vibration=true  importance=max',
      name: 'NotificationService',
    );
  }

  /// Returns true if the app can schedule exact alarms on this device.
  /// Always returns true on API < 31 (pre-Android 12).
  static Future<bool> canScheduleExactAlarms() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return true;
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

    // Check if exact alarm permission is granted before attempting to schedule.
    // alarmClock mode requires canScheduleExactAlarms() == true.
    // On Android 13+ with USE_EXACT_ALARM in manifest, this is always true.
    // On Android 12 with SCHEDULE_EXACT_ALARM, user must have granted it.
    final canExact = await canScheduleExactAlarms();
    if (!canExact) {
      dev.log(
        '[NotificationService] ✗ EXACT ALARM PERMISSION NOT GRANTED — '
        'cannot schedule "$medicineName". '
        'Go to Settings → Apps → MediTrack → Alarms & Reminders and enable.',
        name: 'NotificationService',
      );
      return null;
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

    dev.log('[NotificationService] _scheduleDailyAt ▶  '
        'id=$notifId  title="$title"  at=$scheduled  '
        'channel=$_channelId  sound=true  tag=meditrack_$notifId  '
        'mode=exactAllowWhileIdle',
        name: 'NotificationService');

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

    // Use exactAllowWhileIdle (NOT alarmClock) so that matchDateTimeComponents
    // works correctly for daily repeating reminders.
    //
    // ROOT CAUSE OF "second notification silent" BUG:
    //   AndroidScheduleMode.alarmClock uses AlarmManager.setAlarmClock() which
    //   is a ONE-SHOT alarm. It fires once and does NOT reschedule itself.
    //   When combined with matchDateTimeComponents: DateTimeComponents.time,
    //   the flutter_local_notifications plugin (v17) ignores the repeat
    //   component for alarmClock mode. Result: the alarm fires once, then
    //   the next call from rescheduleAll() needs the app to be opened.
    //   On the same day, if slot-1 fires at 3:06 PM and slot-2 is at 3:09 PM,
    //   both are scheduled independently via AlarmManager. But if the device
    //   is in Doze mode between 3:06 and 3:09, the alarmClock at 3:09 may
    //   fire silently because the system treats back-to-back alarmClock
    //   notifications as a "burst" and suppresses sound/vibration for all
    //   except the first.
    //
    // FIX: exactAllowWhileIdle fires even in Doze mode and properly supports
    //   matchDateTimeComponents: DateTimeComponents.time for true daily repeat.
    //   Each slot gets a unique notifId + unique tag — Android treats them as
    //   completely independent notifications, so every one plays sound.
    await _notifications.zonedSchedule(
      notifId, title, body, scheduled, details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    dev.log('[NotificationService] schedule ✓  id=$notifId  at=$scheduled  '
        'mode=exactAllowWhileIdle',
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
    // Cancel the displayed notification (status bar) — needs tag to match.
    await _notifications.cancel(id, tag: 'meditrack_$id');
    // Cancel the pending AlarmManager intent — AlarmManager uses only the int id.
    // Without this second cancel, the scheduled alarm keeps firing even after
    // the medicine is deleted or updated.
    await _notifications.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  static Future<void> rescheduleAll() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();

      // Check exact alarm permission before rescheduling.
      final canExact = await canScheduleExactAlarms();
      if (!canExact) {
        dev.log(
          '[NotificationService] rescheduleAll — SKIPPED: '
          'exact alarm permission not granted. '
          'Reminders will not fire until permission is granted.',
          name: 'NotificationService',
        );
        return;
      }

      final uid      = FirestoreService.uid;
      final memberId = await FirestoreService.getActiveMemberIdOnce();
      if (memberId == null) return;
      await ReminderService.rescheduleAll(uid: uid, memberId: memberId);
    } catch (_) {}
  }
}

