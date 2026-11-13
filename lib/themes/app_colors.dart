import 'package:flutter/material.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/core/theme_notifier.dart';

/// Paleta de colores centralizada de FinazaApp.
/// 
/// Todos los colores utilizados en la aplicación se resuelven dinámicamente
/// a partir del tema activo en ThemeNotifier.
class AppColors {
  AppColors._();

  static AppTheme get _current => AppTheme.forMode(ThemeNotifier.activeMode);

  /// Acceso contextual al tema activo. Shortcut para Theme.of(context).extension<AppTheme>()!
  static AppTheme of(BuildContext context) =>
      Theme.of(context).extension<AppTheme>()!;

  /// Ajusta un color para asegurar que tenga suficiente contraste contra el fondo.
  /// Si el tema es claro y el color es muy brillante, lo oscurece.
  /// Si el tema es oscuro y el color es muy oscuro, lo aclara.
  static Color getReadableColor(Color color, BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final luminance = color.computeLuminance();
    
    if (isLight && luminance > 0.4) {
      final hsl = HSLColor.fromColor(color);
      return hsl.withLightness(hsl.lightness > 0.38 ? 0.38 : hsl.lightness).toColor();
    } else if (!isLight && luminance < 0.15) {
      final hsl = HSLColor.fromColor(color);
      return hsl.withLightness(hsl.lightness < 0.65 ? 0.65 : hsl.lightness).toColor();
    }
    return color;
  }

  // ========== Fondos ==========
  /// Color de fondo principal de la aplicación
  static Color get primaryBackground => _current.primaryBackground;
  
  /// Color de fondo de tarjetas y contenedores
  static Color get cardBackground => _current.cardBackground;
  
  /// Color de fondo más oscuro para elementos internos
  static Color get darkBackground => _current.darkBackground;
  
  /// Color de fondo para elementos secundarios
  static Color get secondaryCardBackground => _current.secondaryCardBackground;

  // ========== Colores de Acento ==========
  /// Color de acento principal (cyan brillante)
  static Color get accent => _current.accent;
  
  /// Color de acento secundario (azul)
  static Color get secondaryAccent => _current.secondaryAccent;

  // ========== Colores de Estado ==========
  /// Color para ingresos
  static Color get income => _current.income;
  
  /// Color para gastos
  static Color get expense => _current.expense;
  
  /// Color de éxito
  static Color get success => _current.success;
  
  /// Color de advertencia
  static Color get warning => _current.warning;
  
  /// Color de error
  static Color get error => _current.error;

  // ========== Colores de Texto ==========
  /// Texto principal (blanco en oscuro, azul/negro en claro)
  static Color get textPrimary => _current.textPrimary;
  
  /// Texto secundario con opacidad
  static Color get textSecondary => _current.textSecondary;
  
  /// Texto terciario/hint
  static Color get textHint => _current.textHint;

  // ========== Colores de Borde ==========
  /// Borde sutil para elementos
  static Color get borderSubtle => _current.borderSubtle;
  
  /// Borde más visible
  static Color get borderVisible => _current.borderVisible;

  // ========== Gradientes Predefinidos ==========
  /// Gradiente para cabeceras premium
  static LinearGradient get headerGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _current.textPrimary.withValues(alpha: 0.1),
          _current.textPrimary.withValues(alpha: 0.05),
        ],
      );
  
  /// Gradiente de fondo para tarjetas
  static LinearGradient get cardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 1.0],
        colors: [
          _current.cardBackground,
          _current.primaryBackground,
        ],
      );
}
