// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_date.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AdddataAdapter extends TypeAdapter<Add_data> {
  @override
  final int typeId = 1;

  @override
  Add_data read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Add_data(
      fields[0] as String,
      fields[1] as String,
      fields[2] as DateTime,
      fields[3] as String,
      fields[4] as String,
      fields[5] as String,
      fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Add_data obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.IN)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.datetime)
      ..writeByte(3)
      ..write(obj.detail)
      ..writeByte(4)
      ..write(obj.explain)
      ..writeByte(5)
      ..write(obj.name)
      ..writeByte(6)
      ..write(obj.iconCode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdddataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
