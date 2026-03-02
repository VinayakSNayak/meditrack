import 'package:hive/hive.dart';

part 'adherence_log_model.g.dart';

@HiveType(typeId: 0)
class AdherenceLogModel extends HiveObject {
  @HiveField(0)
  final String prescriptionId;

  @HiveField(1)
  final String medicineName;

  @HiveField(2)
  final String dateId; // "2025-01-01"

  @HiveField(3)
  final String status; // "taken" | "missed" | "snoozed" | "pending"

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final bool synced;

  AdherenceLogModel({
    required this.prescriptionId,
    required this.medicineName,
    required this.dateId,
    required this.status,
    required this.timestamp,
    this.synced = false,
  });

  AdherenceLogModel copyWith({
    String? prescriptionId,
    String? medicineName,
    String? dateId,
    String? status,
    DateTime? timestamp,
    bool? synced,
  }) {
    return AdherenceLogModel(
      prescriptionId: prescriptionId ?? this.prescriptionId,
      medicineName: medicineName ?? this.medicineName,
      dateId: dateId ?? this.dateId,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      synced: synced ?? this.synced,
    );
  }
}

