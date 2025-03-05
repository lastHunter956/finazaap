import 'package:flutter/material.dart';
import 'package:finazaap/widgets/bottomnavigationbar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'data/model/add_date.dart';
import 'data/utlity.dart'; // Asegúrate de que la ruta sea correcta

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(AddDataAdapter());
  Hive.registerAdapter(AccountItemAdapter()); // Registrar el adaptador de AccountItem
  await Hive.openBox<Add_data>('data');
  await Hive.openBox<AccountItem>('accounts'); // Abrir la caja de cuentas
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
           
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const Bottom(),
    );
  }
}