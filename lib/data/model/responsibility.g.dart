// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'responsibility.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ResponsibilityAdapter extends TypeAdapter<Responsibility> {
  @override
  final int typeId = 2;

  @override
  Responsibility read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Responsibility(
      id: fields[0] as String?,
      name: fields[1] as String?,
      amount: fields[2] as double?,
      dueDay: fields[3] as int?,
      category: fields[4] as String?,
      frequency: fields[5] as String?,
      isPaid: fields[6] as bool?,
      lastPaymentDate: fields[7] as DateTime?,
      iconCode: fields[8] as int?,
      cardLimit: fields[9] as double?,
      cardBalance: fields[10] as double?,
      minimumPayment: fields[11] as double?,
      cutoffDay: fields[12] as int?,
      paymentDay: fields[13] as int?,
      interestRate: fields[14] as double?,
      installments: fields[15] as int?,
      installmentPlansJson: (fields[16] as List?)?.cast<String>(),
      paidAmountThisMonth: fields[17] as double?,
      lastPaymentMonth: fields[18] as int?,
      lastPaymentYear: fields[19] as int?,
      paymentDates: (fields[20] as List?)?.cast<DateTime>(),
    );
  }

  @override
  void write(BinaryWriter writer, Responsibility obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.dueDay)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.frequency)
      ..writeByte(6)
      ..write(obj.isPaid)
      ..writeByte(7)
      ..write(obj.lastPaymentDate)
      ..writeByte(8)
      ..write(obj.iconCode)
      ..writeByte(9)
      ..write(obj.cardLimit)
      ..writeByte(10)
      ..write(obj.cardBalance)
      ..writeByte(11)
      ..write(obj.minimumPayment)
      ..writeByte(12)
      ..write(obj.cutoffDay)
      ..writeByte(13)
      ..write(obj.paymentDay)
      ..writeByte(14)
      ..write(obj.interestRate)
      ..writeByte(15)
      ..write(obj.installments)
      ..writeByte(16)
      ..write(obj.installmentPlansJson)
      ..writeByte(17)
      ..write(obj.paidAmountThisMonth)
      ..writeByte(18)
      ..write(obj.lastPaymentMonth)
      ..writeByte(19)
      ..write(obj.lastPaymentYear)
      ..writeByte(20)
      ..write(obj.paymentDates);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResponsibilityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
