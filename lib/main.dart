import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/core/security/encryption_service.dart';
import 'package:finazaap/services/notification_service.dart';
import 'package:finazaap/presentation/screens/auth_splash_screen.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/core/utils/app_logger.dart';
import 'package:finazaap/core/prefs_manager.dart';
// Nuevas importaciones para localizacion
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:finazaap/services/ai_chat_service.dart';

/// Punto de entrada principal de FinazaApp
/// Inicializa servicios de seguridad, Hive y registra adaptadores
void main() async {
  // Asegurar que los bindings de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    AppLogger.start('Iniciando FinazaApp');

    // Inicializar SharedPreferences (singleton cacheado)
    await PrefsManager.init();

    // Inicializar formateo de fechas para español
    await initializeDateFormatting('es_ES', null);
    
    // Inicializar Flutter Gemma (motor de IA on-device)
    // IMPORTANTE: webStorageMode solo existe en Web. En Android/iOS se omite.
    try {
      if (kIsWeb) {
        await FlutterGemma.initialize(
          inferenceEngines: const [MediaPipeEngine(), LiteRtLmEngine()],
          webStorageMode: WebStorageMode.streaming,
          maxDownloadRetries: 5,
        );
      } else {
        // En Android/iOS solo necesitamos LiteRtLmEngine (soporta .litertlm nativo via FFI)
        await FlutterGemma.initialize(
          inferenceEngines: const [LiteRtLmEngine()],
          maxDownloadRetries: 3,
        );
      }
      AppLogger.success('FlutterGemma inicializado correctamente para ${kIsWeb ? "Web" : "nativo"}');
    } catch (e) {
      AppLogger.warning('Error inicializando FlutterGemma (continuando sin IA): $e');
      AiChatService.initError = e.toString();
    }
    
    // 1. Inicializar Hive (CRÍTICO)
    // Esto es lo más importante, si falla, la app no funciona
    try {
      await Hive.initFlutter();
      
      // Registrar el adapter de Add_data generado por Hive
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(AdddataAdapter());
      }
      
      // Registrar el adapter de Responsibility
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(ResponsibilityAdapter());
      }
      
      // Abrir las cajas principales de datos
      await Hive.openBox<Add_data>('data');
      await Hive.openBox('transactions_v2');
      await Hive.openBox('accounts');
      await Hive.openBox('accounts_v2');
      
      AppLogger.success('Hive inicializado correctamente');
    } catch (e) {
      AppLogger.error('CRITICAL: Fallo al inicializar Hive', error: e);
      throw Exception('Fallo crítico de base de datos: $e');
    }
    
    // 1.5. Inicializar Currency Helper (Fallo recuperable)
    try {
      await CurrencyHelper.loadCurrency();
      AppLogger.success('CurrencyHelper inicializado');
    } catch (e) {
      AppLogger.warning('Error cargando divisa (usando default): $e');
    }
    
    // 2. Inicializar Seguridad (Fallo recuperable)
    try {
      // Inicializar servicio de encriptación
      final encryptionService = EncryptionService();
      await encryptionService.initialize();
      AppLogger.success('EncryptionService inicializado');
      
    } catch (e) {
      AppLogger.warning('Error en servicios de seguridad (continuando app): $e');
    }
    
    // 3. Inicializar Notificaciones (Fallo recuperable)
    try {
      final notificationService = NotificationService();
      await notificationService.init();
      
      // Si están habilitadas, programar notificaciones
      if (await notificationService.isEnabled()) {
        await notificationService.scheduleAllNotifications();
      }
      AppLogger.success('NotificationService inicializado');
    } catch (e) {
      AppLogger.warning('Error en servicio de notificaciones: $e');
    }
    
    // Ejecutar la aplicación
    runApp(const FinazaApp());
    
  } catch (e, stackTrace) {
    AppLogger.error('ERROR FATAL al iniciar la aplicación', error: e, stackTrace: stackTrace);
    
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
