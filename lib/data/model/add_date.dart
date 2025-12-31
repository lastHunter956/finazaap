import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'add_date.g.dart';

@HiveType(typeId: 1)
class Add_data extends HiveObject {
  @HiveField(0)
  String? IN;  
  
  @HiveField(1)
  String? amount;
  
  @HiveField(2)
  DateTime? datetime;
  
  @HiveField(3)
  String? detail;
  
  @HiveField(4)
  String? explain;
  
  @HiveField(5)
  String? name;
  
  @HiveField(6)
  int? iconCode;
  
  @HiveField(7, defaultValue: '1')
  String? installments;
  
  @HiveField(8, defaultValue: false)
  bool? isInterestFree;

  // Getters seguros para evitar TypeErrors y LateInitializationErrors
  String get safeType => IN ?? 'Expenses';
  String get safeAmount => amount ?? '0';
  DateTime get safeDate => datetime ?? DateTime.now();
  String get safeDetail => detail ?? '';
  String get safeCategory => explain ?? 'Sin categoría';
  String get safeAccount => name ?? 'Sin cuenta';
  int get safeIconCode => iconCode ?? 0;

  // Estos getters son para compatibilidad con el código existente
  String get type => safeType;
  DateTime get date => safeDate;
  String get category => safeCategory;
  String get account => safeAccount;

  Add_data(
    this.IN,
    this.amount,
    this.datetime,
    this.detail,
    this.explain, [
    this.name,
    this.iconCode = 0,
    this.installments = '1',
    this.isInterestFree = false]
  );
}

// Estructura para gráficos
class ChartData {
  final String x;
  final double y;
  final Color color;
  final int iconCode;

  ChartData(this.x, this.y, [this.color = Colors.teal, this.iconCode = 0]);
}