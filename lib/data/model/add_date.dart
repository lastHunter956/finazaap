import 'package:hive/hive.dart';
part 'add_date.g.dart';

@HiveType(typeId: 1)
class Add_data extends HiveObject {
  @HiveField(0)
  String name;
  @HiveField(1)
  String explain;
  @HiveField(2)
  String amount;
  @HiveField(3)
  String IN;
  @HiveField(4)
  DateTime datetime;
  @HiveField(5)
  int iconCode; // Nueva propiedad para el código del icono

  Add_data(this.IN, this.amount, this.datetime, this.explain, this.name, [int? iconCode])
      : this.iconCode = iconCode ?? 0; // Proporciona un valor predeterminado si es null
}