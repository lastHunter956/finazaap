import 'package:flutter/material.dart';

/// Paleta de colores centralizada de FinazaApp.
/// 
/// Todos los colores utilizados en la aplicación deben estar definidos aquí
/// para facilitar el mantenimiento y futuros cambios de tema.
class AppColors {
  AppColors._(); // Constructor privado para prevenir instanciación

  // ========== Fondos ==========
  /// Color de fondo principal de la aplicación
  static const Color primaryBackground = Color(0xFF1F2639); // Color.fromRGBO(31, 38, 57, 1)
  
  /// Color de fondo de tarjetas y contenedores
  static const Color cardBackground = Color(0xFF2A3143); // Color.fromRGBO(42, 49, 67, 1)
  
  /// Color de fondo más oscuro para elementos internos
  static const Color darkBackground = Color(0xFF1A1F2B);
  
  /// Color de fondo para elementos secundarios
  static const Color secondaryCardBackground = Color(0xFF222939);

  // ========== Colores de Acento ==========
  /// Color de acento principal (cyan brillante)
  static const Color accent = Color(0xFF52E2FF); // Color.fromARGB(255, 82, 226, 255)
  
  /// Color de acento secundario (azul)
  static const Color secondaryAccent = Color(0xFF4A80F0);

  // ========== Colores de Estado ==========
  /// Color para ingresos
  static const Color income = Color(0xFFA7E2A9);
  
  /// Color para gastos
  static const Color expense = Color(0xFFE53935);
  
  /// Color de éxito
  static const Color success = Color(0xFF2ECC71);
  
  /// Color de advertencia
  static const Color warning = Color(0xFFFDD835);
  
  /// Color de error
  static const Color error = Color(0xFFE53935);

  // ========== Colores de Texto ==========
  /// Texto principal (blanco)
  static const Color textPrimary = Colors.white;
  
  /// Texto secundario con opacidad
  static Color textSecondary = Colors.white.withOpacity(0.7);
  
  /// Texto terciario/hint
  static Color textHint = Colors.white.withOpacity(0.4);

  // ========== Colores de Borde ==========
  /// Borde sutil para elementos
  static Color borderSubtle = Colors.white.withOpacity(0.08);
  
  /// Borde más visible
  static Color borderVisible = Colors.white.withOpacity(0.2);

  // ========== Gradientes Predefinidos ==========
  /// Gradiente para cabeceras premium
  static LinearGradient get headerGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.05),
        ],
      );
  
  /// Gradiente de fondo para tarjetas
  static LinearGradient get cardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 1.0],
        colors: [
          const Color(0xFF262D43),
          const Color(0xFF1F2538),
        ],
      );
}
