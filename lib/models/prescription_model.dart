import 'package:cloud_firestore/cloud_firestore.dart';

/// Prescription envelope — groups medicines under one hospital visit.
/// Firestore path: users/{uid}/members/{memberId}/prescriptions/{prescriptionId}
class PrescriptionModel {
  final String id;
  final String name;          // e.g. "Diabetic Prescription"
  final String hospitalName;
  final String diagnosis;
  final DateTime visitDate;
  final String? imageUrl;     // Firebase Storage URL (nullable)
  final int medicineCount;    // denormalized for list display
  final DateTime createdAt;

  const PrescriptionModel({
    required this.id,
    required this.name,
    required this.hospitalName,
    required this.diagnosis,
    required this.visitDate,
    this.imageUrl,
    this.medicineCount = 0,
    required this.createdAt,
  });

  factory PrescriptionModel.fromMap(String id, Map<String, dynamic> map) {
    return PrescriptionModel(
      id: id,
      name: map['name'] as String? ?? '',
      hospitalName: map['hospitalName'] as String? ?? '',
      diagnosis: map['diagnosis'] as String? ?? '',
      visitDate:
          (map['visitDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: map['imageUrl'] as String?,
      medicineCount: (map['medicineCount'] as num?)?.toInt() ?? 0,
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'hospitalName': hospitalName,
      'diagnosis': diagnosis,
      'visitDate': Timestamp.fromDate(visitDate),
      'imageUrl': imageUrl,
      'medicineCount': medicineCount,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  PrescriptionModel copyWith({
    String? id,
    String? name,
    String? hospitalName,
    String? diagnosis,
    DateTime? visitDate,
    String? imageUrl,
    bool clearImageUrl = false,
    int? medicineCount,
    DateTime? createdAt,
  }) {
    return PrescriptionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      hospitalName: hospitalName ?? this.hospitalName,
      diagnosis: diagnosis ?? this.diagnosis,
      visitDate: visitDate ?? this.visitDate,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      medicineCount: medicineCount ?? this.medicineCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
