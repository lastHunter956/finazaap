import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/themes/app_theme_mode.dart';

class ThemeModeNotifier extends ValueNotifier<AppThemeMode> {
  ThemeModeNotifier(super.value);

  void triggerUpdate() {
    notifyListeners();
  }
}

class ThemeNotifier {
  ThemeNotifier._();

  static final ThemeModeNotifier mode =
      ThemeModeNotifier(AppThemeMode.defaultDark);

  static AppThemeMode preferredDarkMode = AppThemeMode.defaultDark;
  static AppThemeMode preferredLightMode = AppThemeMode.diurno;

  static AppThemeMode get activeMode {
    final current = mode.value;
    if (current != AppThemeMode.automatico) {
      return current;
    }
    // Si es automático, resolvemos según el brillo del sistema y las preferencias guardadas
    final isDark = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    if (isDark) {
      return preferredDarkMode;
    } else {
      return preferredLightMode;
    }
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Cargar preferencia de modo de tema principal
    final saved = prefs.getString('app_theme_mode');
    if (saved != null) {
      mode.value = AppThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => AppThemeMode.defaultDark,
      );
    }

    // Cargar preferencias del tema por defecto cuando está en modo oscuro
    final savedDark = prefs.getString('preferred_dark_theme');
    if (savedDark != null) {
      preferredDarkMode = AppThemeMode.values.firstWhere(
        (m) => m.name == savedDark,
        orElse: () => AppThemeMode.defaultDark,
      );
    }

    // Cargar preferencias del tema por defecto cuando está en modo claro
    final savedLight = prefs.getString('preferred_light_theme');
    if (savedLight != null) {
      preferredLightMode = AppThemeMode.values.firstWhere(
        (m) => m.name == savedLight,
        orElse: () => AppThemeMode.diurno,
      );
    }

    // Registrar listener para cuando cambie el brillo del sistema (si está en modo automático)
    PlatformDispatcher.instance.onPlatformBrightnessChanged = () {
      if (mode.value == AppThemeMode.automatico) {
        mode.triggerUpdate();
      }
    };
  }

  static Future<void> setMode(AppThemeMode newMode) async {
    final prefs = await SharedPreferences.getInstance();
    if (newMode == AppThemeMode.automatico) {
      mode.value = newMode;
      await prefs.setString('app_theme_mode', newMode.name);
    } else {
      // Si el usuario escoge un modo explícito, también actualizamos su preferencia por defecto
      final isDarkTheme = newMode == AppThemeMode.defaultDark || newMode == AppThemeMode.nocturno;
      if (isDarkTheme) {
        preferredDarkMode = newMode;
        await prefs.setString('preferred_dark_theme', newMode.name);
      } else {
        preferredLightMode = newMode;
        await prefs.setString('preferred_light_theme', newMode.name);
      }
      mode.value = newMode;
      await prefs.setString('app_theme_mode', newMode.name);
    }
  }
}
