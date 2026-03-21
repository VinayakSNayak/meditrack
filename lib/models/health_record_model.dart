import 'package:cloud_firestore/cloud_firestore.dart';

// ========================= BODY VITAL =========================

class BodyVitalModel {
  final String id;
  final String type;
  final dynamic value;
  final String unit;
  final DateTime recordDate;

  const BodyVitalModel({
    required this.id,
    required this.type,
    required this.value,
    required this.unit,
    required this.recordDate,
  });

  factory BodyVitalModel.fromMap(String id, Map<String, dynamic> map) {
    return BodyVitalModel(
      id: id,
      type: map['type'] as String? ?? '',
      value: map['value'],
      unit: map['unit'] as String? ?? '',
      recordDate:
          (map['recordDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'value': value,
      'unit': unit,
      'recordDate': Timestamp.fromDate(recordDate),
    };
  }
}

// ========================= BLOOD METRIC =========================

class BloodMetricModel {
  final String id;
  final String type;
  final dynamic value;
  final String unit;
  final DateTime recordDate;

  const BloodMetricModel({
    required this.id,
    required this.type,
    required this.value,
    required this.unit,
    required this.recordDate,
  });

  factory BloodMetricModel.fromMap(String id, Map<String, dynamic> map) {
    return BloodMetricModel(
      id: id,
      type: map['type'] as String? ?? '',
      value: map['value'],
      unit: map['unit'] as String? ?? '',
      recordDate:
          (map['recordDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'value': value,
      'unit': unit,
      'recordDate': Timestamp.fromDate(recordDate),
    };
  }
}

// ========================= CONDITION =========================

class ConditionModel {
  final String id;
  final String conditionName;
  final DateTime diagnosedDate;
  final String status;
  final bool hasMedication;
  final String medication;
  final String doctorName;
  final String notes;

  const ConditionModel({
    required this.id,
    required this.conditionName,
    required this.diagnosedDate,
    required this.status,
    required this.hasMedication,
    required this.medication,
    required this.doctorName,
    required this.notes,
  });

  factory ConditionModel.fromMap(String id, Map<String, dynamic> map) {
    return ConditionModel(
      id: id,
      conditionName: map['conditionName'] as String? ?? '',
      diagnosedDate:
          (map['diagnosedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] as String? ?? '',
      hasMedication: map['hasMedication'] as bool? ?? false,
      medication: map['medication'] as String? ?? '',
      doctorName: map['doctorName'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conditionName': conditionName,
      'diagnosedDate': Timestamp.fromDate(diagnosedDate),
      'status': status,
      'hasMedication': hasMedication,
      'medication': medication,
      'doctorName': doctorName,
      'notes': notes,
    };
  }
}

// ========================= OTHER RECORD =========================

class OtherRecordModel {
  final String id;
  final String recordName;
  final String measurement;
  final DateTime recordDate;

  const OtherRecordModel({
    required this.id,
    required this.recordName,
    required this.measurement,
    required this.recordDate,
  });

  factory OtherRecordModel.fromMap(String id, Map<String, dynamic> map) {
    return OtherRecordModel(
      id: id,
      recordName: map['recordName'] as String? ?? '',
      measurement: map['measurement'] as String? ?? '',
      recordDate:
          (map['recordDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recordName': recordName,
      'measurement': measurement,
      'recordDate': Timestamp.fromDate(recordDate),
    };
  }
}

