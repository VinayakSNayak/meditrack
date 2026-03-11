import 'dart:developer' as dev;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/prescription_model.dart';
import '../../models/medicine_model.dart';
import 'notification_service.dart';
import 'reminder_service.dart';
import 'storage_service.dart';

/// Handles all Firestore + Storage operations for the Prescription module.
/// Firestore structure:
///   users/{uid}/members/{memberId}/prescriptions/{prescriptionId}
///   users/{uid}/members/{memberId}/prescriptions/{prescriptionId}/medicines/{medicineId}
class PrescriptionFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    return user.uid;
  }

  static CollectionReference<Map<String, dynamic>> _prescriptionsRef(
          String memberId) =>
      _firestore
          .collection('users')
          .doc(_uid)
          .collection('members')
          .doc(memberId)
          .collection('prescriptions');

  /// Public accessor used by reminder_screen to query prescriptions directly.
  static CollectionReference<Map<String, dynamic>> rawPrescriptionsRef(
          String memberId) =>
      _prescriptionsRef(memberId);

  static CollectionReference<Map<String, dynamic>> _medicinesRef(
          String memberId, String prescriptionId) =>
      _prescriptionsRef(memberId)
          .doc(prescriptionId)
          .collection('medicines');

  // ========================= PRESCRIPTION CRUD =========================

  /// Create a new prescription envelope (no medicines yet).
  static Future<String> addPrescription({
    required String memberId,
    required String name,
    required String hospitalName,
    required String diagnosis,
    required DateTime visitDate,
    File? imageFile,
  }) async {
    final docRef = _prescriptionsRef(memberId).doc();

    dev.log('[PrescriptionFirestoreService] addPrescription ▶  '
        'id=${docRef.id}  name="$name"  hasImage=${imageFile != null}',
        name: 'PrescriptionFirestoreService');

    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await _uploadImage(imageFile, docRef.id);
    }

    dev.log('[PrescriptionFirestoreService] addPrescription — imageUrl=$imageUrl',
        name: 'PrescriptionFirestoreService');

    await docRef.set({
      'name': name,
      'hospitalName': hospitalName,
      'diagnosis': diagnosis,
      'visitDate': Timestamp.fromDate(visitDate),
      'imageUrl': imageUrl,
      'medicineCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    dev.log('[PrescriptionFirestoreService] addPrescription ✓  '
        'id=${docRef.id}  imageUrl=$imageUrl',
        name: 'PrescriptionFirestoreService');

    return docRef.id;
  }

  /// Update prescription envelope fields.
  static Future<void> updatePrescription({
    required String memberId,
    required String prescriptionId,
    required String name,
    required String hospitalName,
    required String diagnosis,
    required DateTime visitDate,
    File? newImageFile,
    bool removeImage = false,
  }) async {
    final updates = <String, dynamic>{
      'name': name,
      'hospitalName': hospitalName,
      'diagnosis': diagnosis,
      'visitDate': Timestamp.fromDate(visitDate),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (removeImage) {
      updates['imageUrl'] = null;
    } else if (newImageFile != null) {
      updates['imageUrl'] =
          await _uploadImage(newImageFile, prescriptionId);
    }

    await _prescriptionsRef(memberId).doc(prescriptionId).update(updates);
  }

  /// Delete prescription + all medicines + cancel all their notifications.
  static Future<void> deletePrescription({
    required String memberId,
    required String prescriptionId,
  }) async {
    final medicines = await _medicinesRef(memberId, prescriptionId).get();

    for (final doc in medicines.docs) {
      final med = MedicineModel.fromMap(doc.id, doc.data());

      if (med.times.isNotEmpty) {
        // Deterministic cancel — works even if notificationIds is stale
        await ReminderService.cancelMedicineReminders(
          medicineId: med.id,
          times: med.times,
        );
      } else {
        // Legacy fallback
        for (final id in med.notificationIds) {
          await NotificationService.cancelNotification(id);
        }
      }

      await doc.reference.delete();
    }

    await _prescriptionsRef(memberId).doc(prescriptionId).delete();
  }

  /// Stream of prescriptions ordered by visitDate desc.
  static Stream<List<PrescriptionModel>> prescriptionsStream(
      String memberId) {
    return _prescriptionsRef(memberId)
        .orderBy('visitDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PrescriptionModel.fromMap(d.id, d.data()))
            .toList());
  }

  // ========================= MEDICINE CRUD =========================

  /// Add a medicine under a prescription and schedule notifications for ALL time slots.
  static Future<void> addMedicine({
    required String memberId,
    required String prescriptionId,
    required String medicineName,
    required String dosage,
    required String frequency,
    required String foodTiming,
    required List<String> times,
    DateTime? startDate,
    DateTime? endDate,
    required String notes,
    bool reminderEnabled = true,
  }) async {
    // ── DEBUG: confirm what times list arrived at the service layer ──
    dev.log(
      '[PrescriptionFirestoreService] addMedicine ▶\n'
      '  medicine   = "$medicineName"\n'
      '  frequency  = "$frequency"\n'
      '  times      = $times  (count=${times.length})\n'
      '  startDate  = $startDate\n'
      '  endDate    = $endDate',
      name: 'PrescriptionFirestoreService',
    );

    final docRef = _medicinesRef(memberId, prescriptionId).doc();
    final medicineId = docRef.id;

    // Schedule one notification per time slot via ReminderService.
    // Returns {timeSlot: notifId} map — empty if endDate already passed or reminder disabled.
    final notificationMap = reminderEnabled && times.isNotEmpty
        ? await ReminderService.scheduleMedicineReminders(
            memberId: memberId,
            prescriptionId: prescriptionId,
            medicineId: medicineId,
            medicineName: medicineName,
            foodTiming: foodTiming,
            times: times,
            startDate: startDate,
            endDate: endDate,
          )
        : <String, int>{};

    // First time slot as DateTime — stored as backward-compat reminderTime field.
    final firstTime = _parseTimeString(times.isNotEmpty ? times.first : '08:00');

    final docData = {
      'medicineName': medicineName,
      'dosage': dosage,
      'frequency': frequency,
      'foodTiming': foodTiming,
      // Primary source of truth for scheduling
      'times': times,
      // notificationMap: {timeSlot → notifId} — used for targeted cancellation
      'notificationMap': notificationMap,
      // Backward compat: readable by old code that only knows reminderTime
      'reminderTime': Timestamp.fromDate(firstTime),
      // Legacy compat: derived from notificationMap values
      'notificationIds': notificationMap.values.toList(),
      'startDate': startDate != null ? Timestamp.fromDate(startDate) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
      'notes': notes,
      'reminderEnabled': reminderEnabled,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // ── DEBUG: print the exact map being written to Firestore ──
    dev.log(
      '[PrescriptionFirestoreService] addMedicine — writing document:\n'
      '  docId      = $medicineId\n'
      '  times      = ${docData['times']}\n'
      '  notifMap   = ${docData['notificationMap']}\n'
      '  reminderTime (compat) = ${docData['reminderTime']}',
      name: 'PrescriptionFirestoreService',
    );

    await docRef.set(docData);

    // ── DEBUG: read back the document to verify Firestore contents ──
    final saved = await docRef.get();
    if (saved.exists) {
      final savedTimes = saved.data()?['times'];
      dev.log(
        '[PrescriptionFirestoreService] addMedicine ◀ VERIFIED\n'
        '  Firestore times field = $savedTimes\n'
        '  times count = ${(savedTimes as List?)?.length ?? 0}',
        name: 'PrescriptionFirestoreService',
      );
    } else {
      dev.log(
        '[PrescriptionFirestoreService] addMedicine ◀ WARNING: '
        'document not found after set() — possible Firestore issue',
        name: 'PrescriptionFirestoreService',
      );
    }

    // Increment medicine count on parent prescription document
    await _prescriptionsRef(memberId).doc(prescriptionId).update({
      'medicineCount': FieldValue.increment(1),
    });
  }

  /// Update medicine fields, cancel old notifications, reschedule all new time slots.
  ///
  /// [oldTimes] — time slots that were previously saved (used to cancel
  ///   deterministic IDs). Falls back to [oldNotificationIds] for legacy docs.
  static Future<void> updateMedicine({
    required String memberId,
    required String prescriptionId,
    required String medicineId,
    required String medicineName,
    required String dosage,
    required String frequency,
    required String foodTiming,
    required List<String> times,
    required List<String> oldTimes,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    required String notes,
    // Legacy param — only used if oldTimes is empty
    List<int> oldNotificationIds = const [],
    bool reminderEnabled = true,
  }) async {
    // ── DEBUG: confirm what arrived at the service layer ──
    dev.log(
      '[PrescriptionFirestoreService] updateMedicine ▶\n'
      '  medicine   = "$medicineName"\n'
      '  medicineId = $medicineId\n'
      '  frequency  = "$frequency"\n'
      '  oldTimes   = $oldTimes  (count=${oldTimes.length})\n'
      '  newTimes   = $times  (count=${times.length})\n'
      '  startDate  = $startDate  clearStart=$clearStartDate\n'
      '  endDate    = $endDate  clearEnd=$clearEndDate',
      name: 'PrescriptionFirestoreService',
    );

    // ── 1. Cancel OLD notifications ─────────────────────────────
    if (oldTimes.isNotEmpty) {
      // Deterministic cancel using medicineId + old time slot
      await ReminderService.cancelMedicineReminders(
        medicineId: medicineId,
        times: oldTimes,
      );
    } else {
      // Legacy fallback: cancel by raw IDs stored in Firestore
      for (final id in oldNotificationIds) {
        await NotificationService.cancelNotification(id);
      }
    }

    final effectiveStartDate = clearStartDate ? null : startDate;
    final effectiveEndDate = clearEndDate ? null : endDate;

    // ── 2. Schedule NEW notifications for ALL time slots ────────
    final notificationMap = reminderEnabled && times.isNotEmpty
        ? await ReminderService.scheduleMedicineReminders(
            memberId: memberId,
            prescriptionId: prescriptionId,
            medicineId: medicineId,
            medicineName: medicineName,
            foodTiming: foodTiming,
            times: times,
            startDate: effectiveStartDate,
            endDate: effectiveEndDate,
          )
        : <String, int>{};

    final firstTime = _parseTimeString(times.isNotEmpty ? times.first : '08:00');

    final updateData = {
      'medicineName': medicineName,
      'dosage': dosage,
      'frequency': frequency,
      'foodTiming': foodTiming,
      'times': times,
      'notificationMap': notificationMap,
      'reminderTime': Timestamp.fromDate(firstTime),
      'notificationIds': notificationMap.values.toList(),
      'startDate': clearStartDate
          ? null
          : (startDate != null ? Timestamp.fromDate(startDate) : null),
      'endDate': clearEndDate
          ? null
          : (endDate != null ? Timestamp.fromDate(endDate) : null),
      'notes': notes,
      'reminderEnabled': reminderEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // ── DEBUG: print the exact map being written to Firestore ──
    dev.log(
      '[PrescriptionFirestoreService] updateMedicine — writing update:\n'
      '  times      = ${updateData['times']}\n'
      '  notifMap   = ${updateData['notificationMap']}\n'
      '  reminderTime (compat) = ${updateData['reminderTime']}',
      name: 'PrescriptionFirestoreService',
    );

    // ── 3. Persist updated fields ────────────────────────────────
    final docRef = _medicinesRef(memberId, prescriptionId).doc(medicineId);
    await docRef.update(updateData);

    // ── DEBUG: read back the document to verify Firestore contents ──
    final saved = await docRef.get();
    if (saved.exists) {
      final savedTimes = saved.data()?['times'];
      dev.log(
        '[PrescriptionFirestoreService] updateMedicine ◀ VERIFIED\n'
        '  Firestore times field = $savedTimes\n'
        '  times count = ${(savedTimes as List?)?.length ?? 0}',
        name: 'PrescriptionFirestoreService',
      );
    } else {
      dev.log(
        '[PrescriptionFirestoreService] updateMedicine ◀ WARNING: '
        'document not found after update() — possible Firestore issue',
        name: 'PrescriptionFirestoreService',
      );
    }
  }

  /// Delete a medicine and cancel all its scheduled notifications.
  ///
  /// [times] is the current times list from MedicineModel — used to
  /// compute deterministic notification IDs for cancellation.
  /// [notificationIds] is kept as a legacy fallback for old documents
  /// that don't have a times list.
  static Future<void> deleteMedicine({
    required String memberId,
    required String prescriptionId,
    required String medicineId,
    List<String> times = const [],
    // Legacy fallback
    List<int> notificationIds = const [],
  }) async {
    if (times.isNotEmpty) {
      await ReminderService.cancelMedicineReminders(
        medicineId: medicineId,
        times: times,
      );
    } else {
      for (final id in notificationIds) {
        await NotificationService.cancelNotification(id);
      }
    }
    await _medicinesRef(memberId, prescriptionId).doc(medicineId).delete();

    // Decrement medicine count on parent
    await _prescriptionsRef(memberId).doc(prescriptionId).update({
      'medicineCount': FieldValue.increment(-1),
    });
  }

  /// Stream of medicines under a prescription.
  static Stream<List<MedicineModel>> medicinesStream(
      String memberId, String prescriptionId) {
    return _medicinesRef(memberId, prescriptionId)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MedicineModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Get all medicines for active-today reminder screen.
  static Future<List<Map<String, dynamic>>> getActiveMedicinesForToday(
      String memberId) async {
    final today = DateTime.now();
    final prescSnap =
        await _prescriptionsRef(memberId).get();

    final result = <Map<String, dynamic>>[];

    for (final prescDoc in prescSnap.docs) {
      final medsSnap =
          await _medicinesRef(memberId, prescDoc.id).get();

      for (final medDoc in medsSnap.docs) {
        final med = MedicineModel.fromMap(medDoc.id, medDoc.data());
        if (med.isActiveToday(today)) {
          result.add({
            'prescriptionId': prescDoc.id,
            'prescriptionName':
                prescDoc.data()['name'] as String? ?? '',
            'medicine': med,
          });
        }
      }
    }
    return result;
  }

  /// Get ALL medicines (for rescheduleAll on startup).
  static Future<List<Map<String, dynamic>>> getAllMedicines(
      String memberId) async {
    final prescSnap = await _prescriptionsRef(memberId).get();
    final result = <Map<String, dynamic>>[];

    for (final prescDoc in prescSnap.docs) {
      final medsSnap = await _medicinesRef(memberId, prescDoc.id).get();
      for (final medDoc in medsSnap.docs) {
        result.add({
          'prescriptionId': prescDoc.id,
          'uid': _uid,
          'memberId': memberId,
          'medicine': MedicineModel.fromMap(medDoc.id, medDoc.data()),
        });
      }
    }
    return result;
  }

  /// Mark medicine daily snooze status.
  static Future<void> snoozeLog({
    required String memberId,
    required String prescriptionId,
    required String medicineId,
  }) async {
    final today = DateTime.now();
    final dateId =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await _medicinesRef(memberId, prescriptionId)
        .doc(medicineId)
        .collection('dailyStatus')
        .doc(dateId)
        .set({
      'status': 'snoozed',
      'snoozedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ========================= STORAGE =========================

  /// Parse "HH:mm" string → DateTime on today's date.
  static DateTime _parseTimeString(String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  static Future<String?> _uploadImage(File file, String prescriptionId) async {
    dev.log('[PrescriptionFirestoreService] _uploadImage ▶  '
        'prescriptionId=$prescriptionId  file=${file.path}',
        name: 'PrescriptionFirestoreService');
    final url = await StorageService.uploadPrescriptionImage(
      file: file,
      uid: _uid,
      prescriptionId: prescriptionId,
    );
    // Return null if upload failed (empty string returned by StorageService on error)
    final result = url.isEmpty ? null : url;
    dev.log('[PrescriptionFirestoreService] _uploadImage ◀  result=$result',
        name: 'PrescriptionFirestoreService');
    return result;
  }

  // ========================= CONTEXT FOR CHATBOT =========================

  static Future<List<Map<String, dynamic>>> getActivePrescriptionsForContext(
      String memberId) async {
    final today = DateTime.now();
    final result = <Map<String, dynamic>>[];
    final prescSnap = await _prescriptionsRef(memberId).get();

    for (final p in prescSnap.docs) {
      final medsSnap = await _medicinesRef(memberId, p.id).get();
      for (final m in medsSnap.docs) {
        final med = MedicineModel.fromMap(m.id, m.data());
        if (med.isActiveToday(today)) {
          result.add({
            'medicineName': med.medicineName,
            'dosage': med.dosage,
            'foodTiming': med.foodTiming,
            'reminderTime': Timestamp.fromDate(med.reminderTime),
          });
        }
      }
    }
    return result;
  }
}


