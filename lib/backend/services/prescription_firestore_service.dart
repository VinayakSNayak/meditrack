import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/prescription_model.dart';
import '../../models/medicine_model.dart';
import 'notification_service.dart';
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

    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await _uploadImage(imageFile, docRef.id);
    }

    await docRef.set({
      'name': name,
      'hospitalName': hospitalName,
      'diagnosis': diagnosis,
      'visitDate': Timestamp.fromDate(visitDate),
      'imageUrl': imageUrl,
      'medicineCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

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

  /// Delete prescription + all medicines + cancel all notifications.
  static Future<void> deletePrescription({
    required String memberId,
    required String prescriptionId,
  }) async {
    // Cancel all medicine notifications first
    final medicines = await _medicinesRef(memberId, prescriptionId).get();
    for (final doc in medicines.docs) {
      final ids = List<int>.from(
          (doc.data()['notificationIds'] as List<dynamic>? ?? [])
              .map((e) => e as int));
      for (final id in ids) {
        await NotificationService.cancelNotification(id);
      }
      await doc.reference.delete();
    }

    // Delete the prescription document itself
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

  /// Add a medicine under a prescription and schedule its notification.
  static Future<void> addMedicine({
    required String memberId,
    required String prescriptionId,
    required String medicineName,
    required String dosage,
    required String frequency,
    required String foodTiming,
    required DateTime reminderTime,
    DateTime? startDate,
    DateTime? endDate,
    required String notes,
  }) async {
    final docRef = _medicinesRef(memberId, prescriptionId).doc();

    // Schedule daily notification
    final payload = '$_uid|$memberId|$prescriptionId|${docRef.id}';
    final notifId = await NotificationService.scheduleMedicineReminder(
      medicineName: medicineName,
      foodTiming: foodTiming,
      reminderTime: reminderTime,
      payload: payload,
      startDate: startDate,
      endDate: endDate,
    );

    await docRef.set({
      'medicineName': medicineName,
      'dosage': dosage,
      'frequency': frequency,
      'foodTiming': foodTiming,
      'reminderTime': Timestamp.fromDate(reminderTime),
      'startDate': startDate != null ? Timestamp.fromDate(startDate) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
      'notes': notes,
      'notificationIds': notifId != null ? [notifId] : [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Increment medicine count on parent
    await _prescriptionsRef(memberId).doc(prescriptionId).update({
      'medicineCount': FieldValue.increment(1),
    });
  }

  /// Update medicine fields and reschedule notification.
  static Future<void> updateMedicine({
    required String memberId,
    required String prescriptionId,
    required String medicineId,
    required String medicineName,
    required String dosage,
    required String frequency,
    required String foodTiming,
    required DateTime reminderTime,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    required String notes,
    required List<int> oldNotificationIds,
  }) async {
    // Cancel old notifications
    for (final id in oldNotificationIds) {
      await NotificationService.cancelNotification(id);
    }

    // Schedule new notification
    final payload = '$_uid|$memberId|$prescriptionId|$medicineId';
    final notifId = await NotificationService.scheduleMedicineReminder(
      medicineName: medicineName,
      foodTiming: foodTiming,
      reminderTime: reminderTime,
      payload: payload,
      startDate: clearStartDate ? null : startDate,
      endDate: clearEndDate ? null : endDate,
    );

    await _medicinesRef(memberId, prescriptionId).doc(medicineId).update({
      'medicineName': medicineName,
      'dosage': dosage,
      'frequency': frequency,
      'foodTiming': foodTiming,
      'reminderTime': Timestamp.fromDate(reminderTime),
      'startDate': clearStartDate
          ? null
          : (startDate != null ? Timestamp.fromDate(startDate) : null),
      'endDate': clearEndDate
          ? null
          : (endDate != null ? Timestamp.fromDate(endDate) : null),
      'notes': notes,
      'notificationIds': notifId != null ? [notifId] : [],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a medicine and cancel its notifications.
  static Future<void> deleteMedicine({
    required String memberId,
    required String prescriptionId,
    required String medicineId,
    required List<int> notificationIds,
  }) async {
    for (final id in notificationIds) {
      await NotificationService.cancelNotification(id);
    }
    await _medicinesRef(memberId, prescriptionId).doc(medicineId).delete();

    // Decrement medicine count
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

  static Future<String> _uploadImage(File file, String prescriptionId) async {
    return StorageService.uploadPrescriptionImage(
      file: file,
      uid: _uid,
      prescriptionId: prescriptionId,
    );
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


