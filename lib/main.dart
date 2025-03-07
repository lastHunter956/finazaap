import 'package:flutter/material.dart';
import 'package:finazaap/widgets/bottomnavigationbar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'data/model/add_date.dart';
import 'data/utlity.dart'; // Para AccountItem
import 'package:finazaap/Screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Inicializar los datos de localización
    await initializeDateFormatting('es');
    
    // Inicializar Hive
    await Hive.initFlutter();
    
    // Registrar adaptadores con typeIds ÚNICOS
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
    
    if (!Hive.isAdapterRegistered(2)) { // Cambiar a typeId=2
      Hive.registerAdapter(AccountItemAdapter());
    }
    
    // NO abrir las cajas aquí, dejar que SplashScreen lo haga
    // Comentar estas líneas:
    // await Hive.openBox<Add_data>('data');
    // await Hive.openBox<AccountItem>('accounts');
  } catch (e) {
    print('Error durante la inicialización: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(), // Usar SplashScreen en lugar de Bottom
      theme: ThemeData(
        primaryColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        scaffoldBackgroundColor: const Color(0xFF16151A),
      ),
    );
  }
}