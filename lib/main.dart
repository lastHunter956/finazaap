import 'package:flutter/material.dart';
import 'package:finazaap/widgets/bottomnavigationbar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'data/model/add_date.dart';
import 'data/utlity.dart'; // Para AccountItem
import 'package:finazaap/Screens/splash_screen.dart';
import 'data/category_service.dart'; 
import 'package:finazaap/data/account_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Inicializar dependencias
    await initializeDateFormatting('es');
    await Hive.initFlutter();
    
    // Registrar adaptadores
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
    
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(AccountItemAdapter());
    }
    
    // Ejecutar limpieza de categorías al inicio
    await CategoryService.cleanupCategories();
    
  } catch (e) {
    print('Error durante inicialización: $e');
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