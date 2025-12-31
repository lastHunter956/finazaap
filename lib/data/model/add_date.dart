import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

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
  @HiveField(7, defaultValue: '1')
  String? installments;
  @HiveField(8, defaultValue: false)
  bool? isInterestFree;

  // Estos getters son para compatibilidad con el código generado
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
    [this.iconCode = 0,
    this.installments = '1',
    this.isInterestFree = false]
  );
}

// Estructura para gráficos - simplemente la clase, no los métodos
class ChartData {
  final String x;
  final double y;
  final Color color;
  final int iconCode; // Añadido para almacenar el código del icono

  ChartData(this.x, this.y, [this.color = Colors.teal, this.iconCode = 0]);
}