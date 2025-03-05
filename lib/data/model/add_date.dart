import 'package:hive/hive.dart';

part 'add_date.g.dart';

@HiveType(typeId: 0)
class Add_data extends HiveObject {
  @HiveField(0)
  final String type; // 'Income' o 'Expenses'

  @HiveField(1)
  final String amount;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String detail;

  @HiveField(4)
  final String category;

  @HiveField(5)
  final String account;

  @HiveField(6)
  final int iconCode;

  Add_data(
    this.type,
    this.amount,
    this.date,
    this.detail,
    this.category,
    this.account,
    this.iconCode,
  );

  // Getters para los campos utilizados en el código
  String get IN => type;
  DateTime get datetime => date;
  String get explain => account;
  String get name => category;
}