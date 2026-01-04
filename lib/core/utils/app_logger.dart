import 'package:flutter/foundation.dart';

/// Servicio de logging centralizado para FinazaApp.
/// 
/// Reemplaza llamadas directas a `print()` con un sistema de logging
/// que solo se ejecuta en modo debug, evitando logs en producción.
class AppLogger {
  AppLogger._(); // Constructor privado

  /// Log de información general
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ INFO: $message');
    }
  }

  /// Log de depuración
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('🐛 DEBUG: $message');
    }
  }

  /// Log de advertencia
  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      debugPrint('⚠️ WARNING: $message');
      if (error != null) {
        debugPrint('   Warning details: $error');
      }
    }
  }

  /// Log de error con información de excepción y stack trace
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      debugPrint('❌ ERROR: $message');
      if (error != null) {
        debugPrint('   Error details: $error');
      }
      if (stackTrace != null) {
        debugPrint('   Stack trace:\n$stackTrace');
      }
    }
  }

  /// Log de éxito
  static void success(String message) {
    if (kDebugMode) {
      debugPrint('✅ SUCCESS: $message');
    }
  }

  /// Log de inicio de operación
  static void start(String message) {
    if (kDebugMode) {
      debugPrint('🚀 START: $message');
    }
  }

  /// Log para desarrollo (siempre verbose)
  static void dev(String message) {
    if (kDebugMode) {
      debugPrint('🔧 DEV: $message');
    }
  }
}
