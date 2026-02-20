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

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation("Asia/Kolkata"));

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings =
    InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
  }

  static Future<void> _onNotificationTap(
      NotificationResponse response) async {
    final prescriptionId = response.payload;
    final actionId = response.actionId;

    if (prescriptionId == null) return;
    if (actionId != 'taken' && actionId != 'missed') return;

    final connectivity =
    await Connectivity().checkConnectivity();

    if (connectivity == ConnectivityResult.none) {
      await LocalCacheService.saveStatus(
        prescriptionId: prescriptionId,
        status: actionId!,
      );
    } else {
      await FirestoreService.markMedicineStatus(
        prescriptionId: prescriptionId,
        status: actionId!,
      );
      await SyncService.syncPendingStatuses();
    }
  }

  static Future<int> scheduleDailyNotification({
    required String title,
    required String body,
    required DateTime time,
    required String payload,
  }) async {

    final id =
    DateTime.now().millisecondsSinceEpoch.remainder(100000);

    final now = DateTime.now();

    DateTime scheduled = time;

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(minutes: 1));
    }

    final tzScheduled =
    tz.TZDateTime.from(scheduled, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'meditrack_channel',
      'Medicine Reminders',
      channelDescription: 'Medicine reminder',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const details =
    NotificationDetails(android: androidDetails);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzScheduled,
      details,
      androidScheduleMode:
      AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    return id;
  }


  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
}