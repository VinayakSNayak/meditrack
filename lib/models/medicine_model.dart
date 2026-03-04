import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single medicine under a prescription.
/// Firestore path:
///   users/{uid}/members/{memberId}/prescriptions/{prescriptionId}/medicines/{medicineId}
///
/// Frequency → times mapping:
///   Once daily  → 1 time
///   Twice daily → 2 times
///   Thrice daily → 3 times
///   1-0-1       → 2 times (count of '1' digits)
///   1-1-1       → 3 times
///   0-0-1       → 1 time
///   SOS / other → 1 time (user sets manually)
class MedicineModel {
  final String id;
  final String medicineName;
  final String dosage;
  final String frequency;
  final String foodTiming;

  /// List of "HH:mm" strings — one entry per daily reminder time.
  /// e.g. ["08:00", "14:00", "21:00"] for Thrice daily.
  /// Replaces the old single `reminderTime` field.
  final List<String> times;

  final DateTime? startDate;
  final DateTime? endDate;
  final String notes;

  /// Map from time-slot key → notificationId.
  /// Key format: "HH:mm"  e.g. {"08:00": 12345, "21:00": 67890}
  final Map<String, int> notificationMap;

  final DateTime createdAt;

  const MedicineModel({
    required this.id,
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    required this.foodTiming,
    required this.times,
    this.startDate,
    this.endDate,
    required this.notes,
    required this.notificationMap,
    required this.createdAt,
  });

  // ── Backward compat: expose first time as DateTime (used by dashboard/home) ──
  DateTime get reminderTime {
    if (times.isEmpty) return DateTime.now().copyWith(hour: 8, minute: 0);
    final parts = times.first.split(':');
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day,
        int.tryParse(parts[0]) ?? 8, int.tryParse(parts[1]) ?? 0);
  }

  // ── Legacy compat: notificationIds list (used by old callers) ──
  List<int> get notificationIds => notificationMap.values.toList();

  // ── Frequency → expected number of time slots ──────────────────
  static int timesCountForFrequency(String frequency) {
    if (frequency.isEmpty) return 1;
    final lower = frequency.toLowerCase().trim();
    if (lower == 'twice daily' || lower == 'bd') return 2;
    if (lower == 'thrice daily' || lower == 'tds') return 3;
    // Pattern like "1-0-1", "1-1-1", "0-0-1" — count the 1s
    if (RegExp(r'^[01]-[01]-[01]$').hasMatch(lower)) {
      return lower.replaceAll(RegExp(r'[^1]'), '').length.clamp(1, 3);
    }
    return 1; // Once daily / SOS / As needed / unknown
  }

  // ── fromMap with full backward compatibility ────────────────────
  factory MedicineModel.fromMap(String id, Map<String, dynamic> map) {
    // Parse times list — new field
    List<String> times;
    if (map['times'] != null) {
      times = List<String>.from(
          (map['times'] as List<dynamic>).map((e) => e.toString()));
    } else if (map['reminderTime'] != null) {
      // Backward compat: convert old single reminderTime → times list
      final dt = (map['reminderTime'] as Timestamp).toDate();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      times = ['$hh:$mm'];
    } else {
      times = ['08:00'];
    }

    // Parse notificationMap — new field
    Map<String, int> notificationMap;
    if (map['notificationMap'] != null) {
      notificationMap = Map<String, int>.from(
          (map['notificationMap'] as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, (v as num).toInt())));
    } else if (map['notificationIds'] != null) {
      // Backward compat: map old notificationIds list → {"08:00": id, ...}
      final ids = List<int>.from(
          (map['notificationIds'] as List<dynamic>).map((e) => (e as num).toInt()));
      notificationMap = {};
      for (int i = 0; i < ids.length && i < times.length; i++) {
        notificationMap[times[i]] = ids[i];
      }
    } else {
      notificationMap = {};
    }

    return MedicineModel(
      id: id,
      medicineName: map['medicineName'] as String? ?? '',
      dosage: map['dosage'] as String? ?? '',
      frequency: map['frequency'] as String? ?? '',
      foodTiming: map['foodTiming'] as String? ?? 'After Food',
      times: times,
      startDate: (map['startDate'] as Timestamp?)?.toDate(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      notes: map['notes'] as String? ?? '',
      notificationMap: notificationMap,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medicineName': medicineName,
      'dosage': dosage,
      'frequency': frequency,
      'foodTiming': foodTiming,
      'times': times,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'notes': notes,
      'notificationMap': notificationMap,
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
    List<String>? times,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    String? notes,
    Map<String, int>? notificationMap,
    DateTime? createdAt,
  }) {
    return MedicineModel(
      id: id ?? this.id,
      medicineName: medicineName ?? this.medicineName,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      foodTiming: foodTiming ?? this.foodTiming,
      times: times ?? this.times,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      notes: notes ?? this.notes,
      notificationMap: notificationMap ?? this.notificationMap,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
