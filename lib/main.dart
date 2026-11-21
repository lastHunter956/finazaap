import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/responsibility_service.dart';
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
import 'package:finazaap/services/ai_provider_config.dart';
import 'package:finazaap/services/ai_provider_router.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/core/theme_notifier.dart';
import 'package:finazaap/features/notifications/services/gemma_classifier_adapter.dart';
import 'package:finazaap/features/notifications/services/local_gemma_coordinator.dart';
import 'package:finazaap/features/notifications/services/notification_pipeline_service.dart';

/// Punto de entrada principal de FinazaApp
/// Inicializa servicios de seguridad, Hive y registra adaptadores
void main() async {
  // Asegurar que los bindings de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  
  try {
    AppLogger.start('Iniciando FinazaApp');

    // Inicialización paralela mínima para primer frame (Prefs, fechas y Hive)
    await Future.wait([
      PrefsManager.init(),
      initializeDateFormatting('es_ES', null),
      Hive.initFlutter(),
    ]);

    // 1. Inicializar seguridad y base de datos cifrada Hive (CRÍTICO / fail-closed)
    try {
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(AdddataAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(ResponsibilityAdapter());
      }

      await EncryptionService().initialize();
      AppLogger.success('EncryptionService inicializado');

      await EncryptionService().openEncryptedBox<Add_data>('data');
      await ResponsibilityService.init();
      AppLogger.success('Hive inicializado y cifrado correctamente');
    } catch (e) {
      AppLogger.error('CRITICAL: Fallo al inicializar Hive cifrado', error: e);
      throw Exception('Fallo crítico de base de datos: $e');
    }

    // 1.5. Inicializar CurrencyHelper y Tema en paralelo (fallos recuperables)
    await Future.wait([
      CurrencyHelper.loadCurrency().then((_) {
        AppLogger.success('CurrencyHelper inicializado');
      }).catchError((e) {
        AppLogger.warning('Error cargando divisa (usando default): $e');
      }),
      ThemeNotifier.init(),
    ]);

    // Registrar router multi-IA y hooks lazy de Gemma antes de montar el árbol de widgets
    AiProviderRouter.registerHooks();
    AiChatService.ensureGemmaInitialized = _ensureGemmaInitialized;
    DefaultGemmaInferenceClient.ensureGemmaInitialized = _ensureGemmaInitialized;
    LocalGemmaCoordinator.instance.ensureGemmaInitialized = _ensureGemmaInitialized;
    LocalGemmaCoordinator.instance.registerLifecycleObserver();

    // Ejecutar la aplicación inmediatamente tras inicializar estado esencial
    runApp(const FinazaApp());

    // Diferir inicializaciones no críticas para el primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDeferredServices();
    });
    
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

Future<void>? _gemmaInitFuture;

/// Garantiza una sola inicialización de FlutterGemma incluso si el chat se abre antes del post-frame.
Future<void> _ensureGemmaInitialized() {
  return _gemmaInitFuture ??= () async {
    try {
      if (kIsWeb) {
        await FlutterGemma.initialize(
          inferenceEngines: const [MediaPipeEngine(), LiteRtLmEngine()],
          webStorageMode: WebStorageMode.streaming,
          maxDownloadRetries: 5,
        );
      } else {
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
  }();
}

/// Inicializa servicios secundarios después del primer frame.
///
/// Carga perezosa: si la IA Principal configurada es Cloud o Simulador,
/// omite por completo `FlutterGemma.initialize(...)` al arrancar (0 MB RAM de Gemma).
Future<void> _initializeDeferredServices() async {
  AiProviderRouter.registerHooks();
  try {
    final aiConfig = await AiProviderConfigStore.instance.loadConfig();
    if (aiConfig.primaryProvider.isLocalGemma) {
      await _ensureGemmaInitialized();
    } else {
      AppLogger.info(
        'IA Principal (${aiConfig.primaryProvider.displayName}): '
        'se omite inicialización de FlutterGemma en arranque.',
      );
    }
  } catch (e) {
    AppLogger.warning('Error consultando AiProviderConfigStore en arranque: $e');
  }

  try {
    final notificationService = NotificationService();
    await notificationService.init();
    if (await notificationService.isEnabled()) {
      await notificationService.scheduleAllNotifications();
    }
    AppLogger.success('NotificationService inicializado');
  } catch (e) {
    AppLogger.warning('Error en servicio de notificaciones: $e');
  }

  try {
    await NotificationPipelineService.instance.initialize();
    AppLogger.success('NotificationPipelineService inicializado');
  } catch (e) {
    AppLogger.warning('Error en pipeline de notificaciones bancarias: $e');
  }
}

/// ScrollBehavior sin StretchingOverscrollIndicator para evitar saveLayer de pantalla completa en scroll.
class _MoneoScrollBehavior extends MaterialScrollBehavior {
  const _MoneoScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: Theme.of(context).colorScheme.primary,
      child: child,
    );
  }
}

/// Widget raíz de FinazaApp
class FinazaApp extends StatelessWidget {
  const FinazaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: ThemeNotifier.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'FinazaApp',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const _MoneoScrollBehavior(),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', 'ES'),
            Locale('en', 'US'),
          ],
          theme: buildThemeData(mode),
          home: const AuthSplashScreen(),
        );
      },
    );
  }
}
