// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_date.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AddDataAdapter extends TypeAdapter<Add_data> {
  @override
  final int typeId = 1;

  @override
  Add_data read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    try {
      return Add_data(
        fields[3] as String, // IN
        fields[2] as String, // amount
        fields[4] as DateTime, // datetime
        fields[1] as String, // explain
        fields[0] as String, // name
        fields[5] as int? ?? 0, // iconCode, con valor predeterminado si es null
      );
    } catch (e) {
      throw FormatException('Error al leer los datos: $e');
    }
  }

  @override
  void write(BinaryWriter writer, Add_data obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.explain)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.IN)
      ..writeByte(4)
      ..write(obj.datetime)
      ..writeByte(5)
      ..write(obj.iconCode);
  }
}

  