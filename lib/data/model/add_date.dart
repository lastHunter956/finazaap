import 'package:hive/hive.dart';

part 'add_date.g.dart';

@HiveType(typeId: 1)
class Add_data extends HiveObject {
  @HiveField(0)
  String IN;  
  @HiveField(1)
  String amount;
  @HiveField(2)
  DateTime datetime;
  @HiveField(3)
  String detail;
  @HiveField(4)
  String explain;
  @HiveField(5)
  String name;
  @HiveField(6)
  int iconCode;

  // Estos getters son para compatibilidad con el código generadoo generado
  String get type => IN;
  DateTime get date => datetime;
  String get category => explain;
  String get account => name;

  Add_data(
    this.IN,
    this.amount,
    this.datetime,
    this.detail,
    this.explain,
    this.name,
    this.iconCode,
  );
}