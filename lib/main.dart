import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/core/security/encryption_service.dart';
import 'package:finazaap/presentation/screens/auth_splash_screen.dart';
// Nuevas importaciones para localizacion
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Punto de entrada principal de FinazaApp
/// Inicializa servicios de seguridad, Hive y registra adaptadores
void main() async {
  // Asegurar que los bindings de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('🚀 Iniciando FinazaApp...');

    // Inicializar formateo de fechas para español
    await initializeDateFormatting('es_ES', null);
    
    // 1. Inicializar Hive (CRÍTICO)
    // Esto es lo más importante, si falla, la app no funciona
    try {
      await Hive.initFlutter();
      
      // Registrar el adapter de Add_data generado por Hive
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(AdddataAdapter());
      }
      
      // Abrir las cajas principales de datos
      await Hive.openBox<Add_data>('data');
      await Hive.openBox('transactions_v2');
      await Hive.openBox('accounts');
      await Hive.openBox('accounts_v2');
      
      print('✅ Hive inicializado correctamente');
    } catch (e) {
      print('❌ CRITICAL ERROR: Fallo al inicializar Hive: $e');
      throw Exception('Fallo crítico de base de datos: $e');
    }
    
    // 2. Inicializar Seguridad (Fallo recuperable)
    try {
      // Inicializar servicio de encriptación
      final encryptionService = EncryptionService();
      await encryptionService.initialize();
      print('✅ EncryptionService inicializado');
      
    } catch (e) {
      print('⚠️ ADVERTENCIA: Error en servicios de seguridad (continuando app): $e');
    }
    
    // Ejecutar la aplicación
    runApp(const FinazaApp());
    
  } catch (e, stackTrace) {
    print('❌ ERROR FATAL al iniciar la aplicación: $e');
    print('Stack trace: $stackTrace');
    
    // Ejecutar app con pantalla de error
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 60,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Error Crítico de Inicialización',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No se pudo iniciar la base de datos local.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    e.toString(),
                    style: const TextStyle(
                      color: Colors.redAccent, 
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

/// Widget raíz de FinazaApp
class FinazaApp extends StatelessWidget {
  const FinazaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinazaApp',
      debugShowCheckedModeBanner: false,
      // Configuración de localización
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
         Locale('es', 'ES'), // Español como predeterminado
         Locale('en', 'US'),
      ],
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color.fromRGBO(31, 38, 57, 1),
        scaffoldBackgroundColor: const Color.fromRGBO(31, 38, 57, 1),
        colorScheme: const ColorScheme.dark(
          primary: Color.fromRGBO(31, 38, 57, 1),
          secondary: Color.fromARGB(255, 82, 226, 255),
        ),
        useMaterial3: true,
      ),
      // Iniciar con pantalla de splash que verifica PIN
      home: const AuthSplashScreen(),
    );
  }
}
