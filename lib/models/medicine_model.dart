import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single medicine under a prescription.
/// Firestore path: users/{uid}/members/{memberId}/prescriptions/{prescriptionId}/medicines/{medicineId}
class MedicineModel {
  final String id;
  final String medicineName;
  final String dosage;       // e.g. "500mg"
  final String frequency;   // e.g. "1-0-1", "Once daily"
  final String foodTiming;  // "Before Food" | "After Food" | "With Food"
  final DateTime reminderTime; // daily alarm time
  final DateTime? startDate;   // nullable — no reminder before this
  final DateTime? endDate;     // nullable — cancel reminder after this
  final String notes;
  final List<int> notificationIds; // one per scheduled reminder
  final DateTime createdAt;

  const MedicineModel({
    required this.id,
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    required this.foodTiming,
    required this.reminderTime,
    this.startDate,
    this.endDate,
    required this.notes,
    required this.notificationIds,
    required this.createdAt,
  });

  factory MedicineModel.fromMap(String id, Map<String, dynamic> map) {
    return MedicineModel(
      id: id,
      medicineName: map['medicineName'] as String? ?? '',
      dosage: map['dosage'] as String? ?? '',
      frequency: map['frequency'] as String? ?? '',
      foodTiming: map['foodTiming'] as String? ?? 'After Food',
      reminderTime:
          (map['reminderTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startDate: (map['startDate'] as Timestamp?)?.toDate(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      notes: map['notes'] as String? ?? '',
      notificationIds: List<int>.from(
          (map['notificationIds'] as List<dynamic>? ?? []).map((e) => e as int)),
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medicineName': medicineName,
      'dosage': dosage,
      'frequency': frequency,
      'foodTiming': foodTiming,
      'reminderTime': Timestamp.fromDate(reminderTime),
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'notes': notes,
      'notificationIds': notificationIds,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// True if this medicine should have an active reminder today.
  bool isActiveToday(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    if (startDate != null) {
      final s = DateTime(startDate!.year, startDate!.month, startDate!.day);
      if (day.isBefore(s)) return false;
    }
    if (endDate != null) {
      final e = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (day.isAfter(e)) return false;
    }
    return true;
  }

  MedicineModel copyWith({
    String? id,
    String? medicineName,
    String? dosage,
    String? frequency,
    String? foodTiming,
    DateTime? reminderTime,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    String? notes,
    List<int>? notificationIds,
    DateTime? createdAt,
  }) {
    return MedicineModel(
      id: id ?? this.id,
      medicineName: medicineName ?? this.medicineName,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      foodTiming: foodTiming ?? this.foodTiming,
      reminderTime: reminderTime ?? this.reminderTime,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      notes: notes ?? this.notes,
      notificationIds: notificationIds ?? this.notificationIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

