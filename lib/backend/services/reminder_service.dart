import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/medicine_model.dart';
import 'notification_service.dart';

/// ReminderService — single source of truth for:
///   • Scheduling / cancelling medicine notifications
///   • Snooze (reschedule +10 min)
///   • Writing adherence logs (taken / skipped)
///   • Rescheduling all on app startup
///
/// Deterministic notification ID formula:
///   id = (medicineId.hashCode ^ timeSlot.hashCode ^ dateStr.hashCode).abs() % 2^31
///   This ensures the same medicine+time+date always generates the same ID,
///   preventing duplicate notifications on reschedule.
///
/// Adherence log Firestore path:
///   users/{uid}/members/{memberId}/adherence_logs/{logId}
class ReminderService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    return user.uid;
  }

  static CollectionReference<Map<String, dynamic>> _logsRef(
          String memberId) =>
      _firestore
          .collection('users')
          .doc(_uid)
          .collection('members')
          .doc(memberId)
          .collection('adherence_logs');

  // ══════════════════════════════════════════════════════════════
  // DETERMINISTIC NOTIFICATION ID  (stable across Dart VM restarts)
  //
  // ROOT CAUSE OF ORIGINAL BUG:
  //   String.hashCode in Dart is seeded with a per-process random salt
  //   (Dart 2+ security feature). The value is consistent within one
  //   app session but changes on every cold restart. This means:
  //     • addMedicine → notifIdFor → saves ID=X to Firestore
  //     • app restart → rescheduleAll → notifIdFor → produces ID=X'≠X
  //     • cancelMedicineReminders cancels X' (non-existent alarm)
  //     • old alarm at X is never cancelled → duplicates accumulate
  //     • second call to zonedSchedule(X') may overwrite a previously
  //       scheduled unrelated alarm whose real ID happens to be X'
  //
  // FIX: FNV-1a (32-bit Fowler–Noll–Vo) hash over UTF-16 code units.
  //   • Pure arithmetic — no runtime randomness.
  //   • Identical output for identical input on every run, device, restart.
  //   • Collision probability negligible for our key space
  //     (medicineId typically 20 chars + "_" + "HH:mm").
  // ══════════════════════════════════════════════════════════════

  /// Stable notification ID: FNV-1a 32-bit hash of "$medicineId_$timeSlot".
  /// Result is always in [1 .. 2 147 483 646] (positive, non-zero, int32-safe).
  static int notifIdFor(String medicineId, String timeSlot) {
    final key = '${medicineId}_$timeSlot';
    return _fnv1a32(key);
  }

  /// FNV-1a 32-bit hash — deterministic, process-independent.
  static int _fnv1a32(String input) {
    const int fnvPrime = 0x01000193;       // 16 777 619
    const int fnvOffset = 0x811c9dc5;     // 2 166 136 261
    const int mask32 = 0xFFFFFFFF;

    int hash = fnvOffset;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & mask32;
    }

    // Map to [1 .. 2_147_483_646]: keep lower 31 bits, ensure ≥ 1
    final result = (hash & 0x7FFFFFFF);
    return result == 0 ? 1 : result;
  }

  // ══════════════════════════════════════════════════════════════
  // SCHEDULE ALL TIMES FOR A MEDICINE
  // Returns updated notificationMap {timeSlot: notifId}
  // ══════════════════════════════════════════════════════════════

  static Future<Map<String, int>> scheduleMedicineReminders({
    required String memberId,
    required String prescriptionId,
    required String medicineId,
    required String medicineName,
    required String foodTiming,
    required List<String> times,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    dev.log(
      '[ReminderService] scheduleMedicineReminders ▶ '
      'medicine="$medicineName" id=$medicineId  '
      'times=$times  startDate=$startDate  endDate=$endDate',
      name: 'ReminderService',
    );

    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    // Skip entirely if endDate has already passed
    if (endDate != null) {
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      if (todayDay.isAfter(end)) {
        dev.log(
          '[ReminderService] ✗ Skipping "$medicineName" — endDate $end is in the past.',
          name: 'ReminderService',
        );
        return {};
      }
    }

    if (times.isEmpty) {
      dev.log(
        '[ReminderService] ✗ times list is EMPTY for "$medicineName" — nothing scheduled.',
        name: 'ReminderService',
      );
      return {};
    }

    final Map<String, int> result = {};

    for (int i = 0; i < times.length; i++) {
      final timeSlot = times[i];
      final id = notifIdFor(medicineId, timeSlot);
      final reminderDt = _timeSlotToDateTime(timeSlot);

      dev.log(
        '[ReminderService]   slot[$i] timeSlot="$timeSlot"  '
        'notifId=$id  scheduledDateTime=$reminderDt',
        name: 'ReminderService',
      );

      // Payload carries all data needed for snooze in background isolate.
      // Format: uid|memberId|prescriptionId|medicineId|timeSlot|medicineName|foodTiming
      // This keeps snooze fully offline-safe — no Firestore read required.
      final encodedName = medicineName.replaceAll('|', '-');
      final encodedTiming = foodTiming.replaceAll('|', '-');
      final payload =
          '$_uid|$memberId|$prescriptionId|$medicineId|$timeSlot|$encodedName|$encodedTiming';

      final scheduledId = await NotificationService.scheduleMedicineReminder(
        medicineName: medicineName,
        foodTiming: foodTiming,
        reminderTime: reminderDt,
        payload: payload,
        startDate: startDate,
        endDate: endDate,
        notificationId: id,
      );

      if (scheduledId != null) {
        result[timeSlot] = scheduledId;
        dev.log(
          '[ReminderService]   ✓ Scheduled notifId=$scheduledId for slot "$timeSlot"',
          name: 'ReminderService',
        );
      } else {
        dev.log(
          '[ReminderService]   ✗ NotificationService returned null for slot "$timeSlot" — skipped.',
          name: 'ReminderService',
        );
      }
    }

    dev.log(
      '[ReminderService] scheduleMedicineReminders ◀ '
      'result notificationMap=$result  (${result.length}/${times.length} slots scheduled)',
      name: 'ReminderService',
    );

    return result;
  }

  // ══════════════════════════════════════════════════════════════
  // CANCEL ALL NOTIFICATIONS FOR A MEDICINE
  // ══════════════════════════════════════════════════════════════

  static Future<void> cancelMedicineReminders({
    required String medicineId,
    required List<String> times,
  }) async {
    for (final timeSlot in times) {
      final id = notifIdFor(medicineId, timeSlot);
      await NotificationService.cancelNotification(id);
    }
  }

  // ══════════════════════════════════════════════════════════════
  // CANCEL ONE TIME SLOT NOTIFICATION
  // ══════════════════════════════════════════════════════════════

  static Future<void> cancelTimeSlot({
    required String medicineId,
    required String timeSlot,
  }) async {
    final id = notifIdFor(medicineId, timeSlot);
    await NotificationService.cancelNotification(id);
  }

  // ══════════════════════════════════════════════════════════════
  // SNOOZE — schedule a one-time +10 min notification.
  // Does NOT cancel the daily repeating alarm so tomorrow's
  // reminder continues to fire unchanged.
  // Does NOT write adherence log.
  // ══════════════════════════════════════════════════════════════

  static Future<void> snooze({
    required String memberId,
    required String prescriptionId,
    required String medicineId,
    required String medicineName,
    required String foodTiming,
    required String timeSlot,
  }) async {
    // Do NOT cancel the daily alarm — it must continue for future days.
    // The notification tray already dismissed the current one via
    // cancelNotification: true on the action button.

    final snoozeTime = DateTime.now().add(const Duration(minutes: 10));
    // Snooze ID is deterministic but distinct from the daily alarm ID,
    // so it never overwrites it.
    final snoozeId = notifIdFor(medicineId, 'snooze_$timeSlot');

    // Full payload so the snoozed notification's Snooze button also works.
    final encodedName = medicineName.replaceAll('|', '-');
    final encodedTiming = foodTiming.replaceAll('|', '-');
    final payload =
        '$_uid|$memberId|$prescriptionId|$medicineId|$timeSlot|$encodedName|$encodedTiming';

    await NotificationService.scheduleOneTimeReminder(
      id: snoozeId,
      title: medicineName,
      body: foodTiming.isNotEmpty ? '(Snoozed) $foodTiming' : '(Snoozed) Time to take your medicine',
      scheduledTime: snoozeTime,
      payload: payload,
    );
  }

  // ══════════════════════════════════════════════════════════════
  // MARK AS TAKEN — write adherence log only.
  //
  // KEY: Do NOT call cancelTimeSlot here.
  // We switched from repeating alarms to one-shot alarmClock alarms.
  // Cancelling the alarm permanently removes it — tomorrow's notification
  // would never fire. The notification in the tray is already dismissed
  // automatically because the action has cancelNotification: true.
  // rescheduleAll() on every app open re-registers tomorrow's alarm.
  // ══════════════════════════════════════════════════════════════

  static Future<void> markTaken({
    required String memberId,
    required String prescriptionId,
    required String medicineId,
    required String timeSlot,
  }) async {
    await _writeLog(
      memberId: memberId,
      prescriptionId: prescriptionId,
      medicineId: medicineId,
      timeSlot: timeSlot,
      status: 'taken',
    );
    // Do NOT cancel — one-shot alarm must survive for tomorrow.
  }

  // ══════════════════════════════════════════════════════════════
  // SKIP TODAY — write adherence log only.
  // Same reasoning as markTaken — do NOT cancel the alarm.
  // ══════════════════════════════════════════════════════════════

  static Future<void> skipToday({
    required String memberId,
    required String prescriptionId,
    required String medicineId,
    required String timeSlot,
  }) async {
    await _writeLog(
      memberId: memberId,
      prescriptionId: prescriptionId,
      medicineId: medicineId,
      timeSlot: timeSlot,
      status: 'skipped',
    );
    // Do NOT cancel — one-shot alarm must survive for tomorrow.
  }

  // ══════════════════════════════════════════════════════════════
  // ADHERENCE LOG WRITE
  // ══════════════════════════════════════════════════════════════

  static Future<void> _writeLog({
    required String memberId,
    required String prescriptionId,
    required String medicineId,
    required String timeSlot,
    required String status, // "taken" | "skipped"
  }) async {
    final today = DateTime.now();
    final dateStr = _dateKey(today);
    // Deterministic log ID — prevents duplicate writes
    final logId = '${medicineId}_${dateStr}_${timeSlot.replaceAll(':', '')}';

    await _logsRef(memberId).doc(logId).set({
      'prescriptionId': prescriptionId,
      'medicineId': medicineId,
      'scheduledDate': dateStr,
      'scheduledTime': timeSlot,
      'status': status,
      'actionTime': FieldValue.serverTimestamp(),
    });
  }

  // ══════════════════════════════════════════════════════════════
  // CHECK IF ALREADY LOGGED TODAY (used by reminder screen filter)
  // ══════════════════════════════════════════════════════════════

  /// Returns set of "medicineId_timeSlot" keys that are already
  /// taken or skipped today. Used to filter reminder cards.
  static Future<Set<String>> getLoggedKeysForToday(
      String memberId) async {
    final today = _dateKey(DateTime.now());
    final snap = await _logsRef(memberId)
        .where('scheduledDate', isEqualTo: today)
        .where('status', whereIn: ['taken', 'skipped']).get();

    return snap.docs
        .map((d) =>
            '${d.data()['medicineId']}_${d.data()['scheduledTime']}')
        .toSet();
  }

  /// Stream version for real-time reminder card updates.
  static Stream<Set<String>> loggedKeysStream(String memberId) {
    final today = _dateKey(DateTime.now());
    return _logsRef(memberId)
        .where('scheduledDate', isEqualTo: today)
        .where('status', whereIn: ['taken', 'skipped'])
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                '${d.data()['medicineId']}_${d.data()['scheduledTime']}')
            .toSet());
  }

  // ══════════════════════════════════════════════════════════════
  // RESCHEDULE ALL ON APP STARTUP / DEVICE REBOOT
  // ══════════════════════════════════════════════════════════════

  static Future<void> rescheduleAll({
    required String uid,
    required String memberId,
  }) async {
    dev.log(
      '[ReminderService] rescheduleAll ▶  uid=$uid  memberId=$memberId',
      name: 'ReminderService',
    );

    try {
      // ⚠️  DO NOT call cancelAll() here — this was the root cause of
      // "only one notification fires" bug:
      //
      //   cancelAll() wipes EVERY pending alarm from AlarmManager.
      //   Then re-schedule loop runs. For any slot whose time already
      //   passed today (e.g. you set 7:41 & 7:43, app opens at 7:42):
      //     _scheduleDailyAt sees 7:41 < now → +1 day (ok, already fired)
      //     _scheduleDailyAt sees 7:43 < now(after cancelAll wipes it)
      //       → 7:43 pushed to TOMORROW → user never gets second notification.
      //
      //   Fix: zonedSchedule() with the same deterministic notifId
      //   replaces the existing alarm in AlarmManager automatically.
      //   No explicit cancel is ever needed.

      final prescSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('members')
          .doc(memberId)
          .collection('prescriptions')
          .get();

      dev.log(
        '[ReminderService] rescheduleAll: found ${prescSnap.docs.length} prescriptions',
        name: 'ReminderService',
      );

      int scheduledCount = 0;
      int skippedCount = 0;

      for (final prescDoc in prescSnap.docs) {
        final medsSnap =
            await prescDoc.reference.collection('medicines').get();

        for (final medDoc in medsSnap.docs) {
          final med = MedicineModel.fromMap(medDoc.id, medDoc.data());
          final active = med.isActiveToday(DateTime.now());

          dev.log(
            '[ReminderService]   medicine="${med.medicineName}"  '
            'times=${med.times}  active=$active',
            name: 'ReminderService',
          );

          if (!active) {
            skippedCount++;
            continue;
          }

          await scheduleMedicineReminders(
            memberId: memberId,
            prescriptionId: prescDoc.id,
            medicineId: med.id,
            medicineName: med.medicineName,
            foodTiming: med.foodTiming,
            times: med.times,
            startDate: med.startDate,
            endDate: med.endDate,
          );
          scheduledCount++;
        }
      }

      dev.log(
        '[ReminderService] rescheduleAll ◀  '
        'scheduled=$scheduledCount  skipped=$skippedCount',
        name: 'ReminderService',
      );
    } catch (e, stack) {
      dev.log(
        '[ReminderService] rescheduleAll ERROR: $e\n$stack',
        name: 'ReminderService',
        error: e,
        stackTrace: stack,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════

  /// "HH:mm" string → DateTime today at that time
  static DateTime _timeSlotToDateTime(String slot) {
    final parts = slot.split(':');
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day,
        int.tryParse(parts[0]) ?? 8, int.tryParse(parts[1]) ?? 0);
  }

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

