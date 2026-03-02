import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'firestore_service.dart';
import 'local_cache_service.dart';
import 'sync_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'meditrack_reminders';
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
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTapBackground,
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
      ),
    );
  }

  // ========================= RESPONSE HANDLERS =========================

  static Future<void> _onNotificationTap(NotificationResponse response) async {
    await _handleAction(response.payload, response.actionId);
  }

  /// Background isolate handler — must initialize Firebase before using Firestore
  @pragma('vm:entry-point')
  static Future<void> _onNotificationTapBackground(
      NotificationResponse response) async {
    // Ensure Firebase is initialized in the background isolate
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (_) {}
    await _handleAction(response.payload, response.actionId);
  }

  /// Payload format: "uid|memberId|prescriptionId|medicineId"
  static Future<void> _handleAction(
      String? payload, String? actionId) async {
    if (payload == null || payload.isEmpty) return;

    if (actionId == 'snooze') {
      final snoozeTime = DateTime.now().add(const Duration(minutes: 10));
      final snoozeId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      await _scheduleOneTime(
        id: snoozeId,
        title: 'Medicine Reminder (Snoozed)',
        body: 'Time to take your medicine',
        scheduledTime: snoozeTime,
        payload: payload,
      );
    }
    // No taken/missed handling in notification — managed from in-app UI only
  }

  // ========================= MEDICINE REMINDER =========================

  /// Schedule a daily reminder for a medicine.
  /// Respects startDate (don't schedule if today < startDate).
  /// Returns notificationId or null if not scheduled (expired/not started).
  static Future<int?> scheduleMedicineReminder({
    required String medicineName,
    required String foodTiming,
    required DateTime reminderTime,
    required String payload,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    // Do not schedule if already past endDate
    if (endDate != null) {
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      if (todayDay.isAfter(end)) return null;
    }

    return await _scheduleDailyAt(
      title: medicineName,
      body: foodTiming.isNotEmpty ? foodTiming : 'Time to take your medicine',
      time: reminderTime,
      payload: payload,
    );
  }

  // ========================= LEGACY COMPAT =========================

  /// Keep for backward compatibility — wraps scheduleDailyAt.
  static Future<int> scheduleDailyNotification({
    required String title,
    required String body,
    required DateTime time,
    required String payload,
  }) async {
    return await _scheduleDailyAt(
      title: title,
      body: body,
      time: time,
      payload: payload,
    );
  }

  // ========================= INTERNAL SCHEDULING =========================

  static Future<int> _scheduleDailyAt({
    required String title,
    required String body,
    required DateTime time,
    required String payload,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, time.hour, time.minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Medicine reminder',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        actions: const [
          AndroidNotificationAction(
            'snooze',
            '⏰ Snooze 10 min',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
    );

    await _notifications.zonedSchedule(
      id, title, body, scheduled, details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    return id;
  }

  /// One-time notification for snooze.
  static Future<void> _scheduleOneTime({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
  }) async {
    final tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        actions: const [
          AndroidNotificationAction(
            'snooze', '⏰ Snooze 10 min',
            showsUserInterface: false, cancelNotification: true),
        ],
      ),
    );

    await _notifications.zonedSchedule(
      id, title, body, tzScheduled, details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Reschedule all active medicines after device reboot.
  static Future<void> rescheduleAll() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();

      final uid = FirestoreService.uid;
      final memberId = await FirestoreService.getActiveMemberIdOnce();
      if (memberId == null) return;

      // Use PrescriptionFirestoreService to get all medicines
      final allMedicines = await _getAllMedicinesForMember(uid, memberId);

      for (final entry in allMedicines) {
        final med = entry['medicine'];
        final prescriptionId = entry['prescriptionId'] as String;
        final medId = med['id'] as String;
        final reminderTime = (med['reminderTime'] as Timestamp).toDate();
        final endDate = (med['endDate'] as Timestamp?)?.toDate();
        final medicineName = med['medicineName'] as String? ?? '';
        final foodTiming = med['foodTiming'] as String? ?? '';

        final today = DateTime.now();
        if (endDate != null &&
            DateTime(today.year, today.month, today.day)
                .isAfter(DateTime(endDate.year, endDate.month, endDate.day))) {
          continue;
        }

        final payload = '$uid|$memberId|$prescriptionId|$medId';
        await scheduleMedicineReminder(
          medicineName: medicineName,
          foodTiming: foodTiming,
          reminderTime: reminderTime,
          payload: payload,
          endDate: endDate,
        );
      }
    } catch (_) {
      // Best-effort — silent fail on reboot
    }
  }

  static Future<List<Map<String, dynamic>>> _getAllMedicinesForMember(
      String uid, String memberId) async {
    final firestore = FirebaseFirestore.instance;
    final prescSnap = await firestore
        .collection('users')
        .doc(uid)
        .collection('members')
        .doc(memberId)
        .collection('prescriptions')
        .get();

    final result = <Map<String, dynamic>>[];
    for (final p in prescSnap.docs) {
      final medsSnap = await p.reference.collection('medicines').get();
      for (final m in medsSnap.docs) {
        result.add({
          'prescriptionId': p.id,
          'medicine': {'id': m.id, ...m.data()},
        });
      }
    }
    return result;
  }
}

