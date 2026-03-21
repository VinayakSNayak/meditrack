// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'adherence_log_model.dart';

// **************************************************************************
/// TypeAdapterGenerator
// **************************************************************************

class AdherenceLogModelAdapter extends TypeAdapter<AdherenceLogModel> {
  @override
  final int typeId = 0;

  @override
  AdherenceLogModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AdherenceLogModel(
      prescriptionId: fields[0] as String,
      medicineName: fields[1] as String,
      dateId: fields[2] as String,
      status: fields[3] as String,
      timestamp: fields[4] as DateTime,
      synced: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AdherenceLogModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.prescriptionId)
      ..writeByte(1)
      ..write(obj.medicineName)
      ..writeByte(2)
      ..write(obj.dateId)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.synced);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdherenceLogModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}
