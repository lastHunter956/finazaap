// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_date.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AddDataAdapter extends TypeAdapter<Add_data> {
  @override
  final int typeId = 0;

  @override
  Add_data read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return Add_data(
      fields[0] as String, // type
      fields[1] as String, // amount
      fields[2] as DateTime, // date
      fields[3] as String, // detail
      fields[4] as String, // category
      fields[5] as String, // account
      fields[6] as int, // iconCode
    );
  }

  @override
  void write(BinaryWriter writer, Add_data obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.detail)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.account)
      ..writeByte(6)
      ..write(obj.iconCode);
  }
}