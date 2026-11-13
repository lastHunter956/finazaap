import 'package:flutter/material.dart';
import 'package:finazaap/themes/app_theme_mode.dart';

import 'package:finazaap/core/theme_notifier.dart';

/// Extensión de tema personalizada con todos los colores y estilos de botones.
///
/// Acceso en widgets: `context.appTheme.primaryBackground`
class AppTheme extends ThemeExtension<AppTheme> {
  // Fondos
  final Color primaryBackground;
  final Color cardBackground;
  final Color darkBackground;
  final Color secondaryCardBackground;

  // Texto
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;

  // Bordes
  final Color borderSubtle;
  final Color borderVisible;

  // Acento
  final Color accent;
  final Color secondaryAccent;

  // Estado (mismos en todos los temas para coherencia financiera)
  final Color income;
  final Color expense;
  final Color success;
  final Color warning;
  final Color error;

  // Botones
  final Color buttonBackground;
  final Color buttonForeground;
  final List<BoxShadow> buttonShadow;
  final bool filledButtons;

  const AppTheme({
    required this.primaryBackground,
    required this.cardBackground,
    required this.darkBackground,
    required this.secondaryCardBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.borderSubtle,
    required this.borderVisible,
    required this.accent,
    required this.secondaryAccent,
    required this.income,
    required this.expense,
    required this.success,
    required this.warning,
    required this.error,
    required this.buttonBackground,
    required this.buttonForeground,
    required this.buttonShadow,
    required this.filledButtons,
  });

  @override
  AppTheme copyWith({
    Color? primaryBackground,
    Color? cardBackground,
    Color? darkBackground,
    Color? secondaryCardBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? borderSubtle,
    Color? borderVisible,
    Color? accent,
    Color? secondaryAccent,
    Color? income,
    Color? expense,
    Color? success,
    Color? warning,
    Color? error,
    Color? buttonBackground,
    Color? buttonForeground,
    List<BoxShadow>? buttonShadow,
    bool? filledButtons,
  }) {
    return AppTheme(
      primaryBackground: primaryBackground ?? this.primaryBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      darkBackground: darkBackground ?? this.darkBackground,
      secondaryCardBackground: secondaryCardBackground ?? this.secondaryCardBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderVisible: borderVisible ?? this.borderVisible,
      accent: accent ?? this.accent,
      secondaryAccent: secondaryAccent ?? this.secondaryAccent,
      income: income ?? this.income,
      expense: expense ?? this.expense,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      buttonBackground: buttonBackground ?? this.buttonBackground,
      buttonForeground: buttonForeground ?? this.buttonForeground,
      buttonShadow: buttonShadow ?? this.buttonShadow,
      filledButtons: filledButtons ?? this.filledButtons,
    );
  }

  @override
  AppTheme lerp(AppTheme? other, double t) {
    if (other == null) return this;
    return AppTheme(
      primaryBackground: Color.lerp(primaryBackground, other.primaryBackground, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      darkBackground: Color.lerp(darkBackground, other.darkBackground, t)!,
      secondaryCardBackground: Color.lerp(secondaryCardBackground, other.secondaryCardBackground, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderVisible: Color.lerp(borderVisible, other.borderVisible, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      secondaryAccent: Color.lerp(secondaryAccent, other.secondaryAccent, t)!,
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      buttonBackground: Color.lerp(buttonBackground, other.buttonBackground, t)!,
      buttonForeground: Color.lerp(buttonForeground, other.buttonForeground, t)!,
      buttonShadow: t < 0.5 ? buttonShadow : other.buttonShadow,
      filledButtons: t < 0.5 ? filledButtons : other.filledButtons,
    );
  }

  // ─────────────────────────── 4 TEMAS ───────────────────────────

  static const AppTheme _defaultDark = AppTheme(
    primaryBackground: Color(0xFF1F2639),
    cardBackground: Color(0xFF2A3143),
    darkBackground: Color(0xFF1A1F2B),
    secondaryCardBackground: Color(0xFF222939),
    textPrimary: Colors.white,
    textSecondary: Color(0xFFB0C4DE), // Opaque light steel blue
    textHint: Color(0xFF708090),      // Opaque grey
    borderSubtle: Color(0xFF2F374A),
    borderVisible: Color(0xFF4A556E),
    accent: Color(0xFF52E2FF),
    secondaryAccent: Color(0xFF4A80F0),
    income: Color(0xFFA7E2A9),
    expense: Color(0xFFE53935),
    success: Color(0xFF2ECC71),
    warning: Color(0xFFFDD835),
    error: Color(0xFFE53935),
    buttonBackground: Color(0xFF52E2FF),
    buttonForeground: Color(0xFF1F2639),
    buttonShadow: [],
    filledButtons: false,
  );

  static const AppTheme _diurno = AppTheme(
    primaryBackground: Color(0xFFF8FAFC),
    cardBackground: Colors.white,
    darkBackground: Color(0xFFE2E8F0),
    secondaryCardBackground: Color(0xFFF1F5F9),
    textPrimary: Color(0xFF0F172A),   // Slate 900 for absolute contrast
    textSecondary: Color(0xFF334155), // Slate 700
    textHint: Color(0xFF64748B),      // Slate 500
    borderSubtle: Color(0xFFE2E8F0),
    borderVisible: Color(0xFF94A3B8),
    accent: Color(0xFF2563EB),        // Electric blue
    secondaryAccent: Color(0xFF1D4ED8),
    income: Color(0xFF16A34A),
    expense: Color(0xFFDC2626),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
    buttonBackground: Color(0xFF2563EB),
    buttonForeground: Colors.white,
    buttonShadow: [],
    filledButtons: false,
  );

  static const AppTheme _nocturno = AppTheme(
    primaryBackground: Color(0xFF000000),      // Pure Pitch Black
    cardBackground: Color(0xFF121212),         // Dark Charcoal
    darkBackground: Color(0xFF070707),
    secondaryCardBackground: Color(0xFF1E1E1E),
    textPrimary: Colors.white,                 // Pure White
    textSecondary: Color(0xFFE2E8F0),          // Opaque off-white
    textHint: Color(0xFF94A3B8),               // Slate 400
    borderSubtle: Color(0xFF2D2D2D),
    borderVisible: Color(0xFF4D4D4D),
    accent: Color(0xFF00E5FF),                 // Neon Cyan
    secondaryAccent: Color(0xFF00B0FF),
    income: Color(0xFF00E676),
    expense: Color(0xFFFF1744),
    success: Color(0xFF00E676),
    warning: Color(0xFFFFEA00),
    error: Color(0xFFFF1744),
    buttonBackground: Color(0xFF00E5FF),
    buttonForeground: Color(0xFF000000),
    buttonShadow: [],
    filledButtons: true,
  );

  static final AppTheme _dia = AppTheme(
    primaryBackground: const Color(0xFFFFFDF5), // Creamy white
    cardBackground: Colors.white,
    darkBackground: const Color(0xFFFEF3C7),
    secondaryCardBackground: const Color(0xFFFFFBEB),
    textPrimary: const Color(0xFF1E1B4B),      // Ultra-dark Indigo 950
    textSecondary: const Color(0xFF312E81),    // Indigo 900
    textHint: const Color(0xFF4F46E5),         // Indigo 600
    borderSubtle: const Color(0xFFE2E8F0),
    borderVisible: const Color(0xFF6366F1),
    accent: const Color(0xFFD97706),           // Deep rich amber
    secondaryAccent: const Color(0xFFB45309),
    income: const Color(0xFF16A34A),
    expense: const Color(0xFFDC2626),
    success: const Color(0xFF16A34A),
    warning: const Color(0xFFD97706),
    error: const Color(0xFFDC2626),
    buttonBackground: const Color(0xFFD97706),
    buttonForeground: Colors.white,
    buttonShadow: [
      BoxShadow(
        color: Color(0x59D97706),
        blurRadius: 12,
        offset: Offset(0, 4),
        spreadRadius: 1,
      ),
    ],
    filledButtons: true,
  );

  static AppTheme forMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.defaultDark: return _defaultDark;
      case AppThemeMode.diurno:      return _diurno;
      case AppThemeMode.nocturno:    return _nocturno;
      case AppThemeMode.dia:         return _dia;
      case AppThemeMode.automatico:
        return forMode(ThemeNotifier.activeMode);
    }
  }
}

/// Construye el ThemeData completo para un AppThemeMode.
ThemeData buildThemeData(AppThemeMode mode) {
  final resolvedMode = mode == AppThemeMode.automatico ? ThemeNotifier.activeMode : mode;
  final t = AppTheme.forMode(resolvedMode);
  final isDark = resolvedMode == AppThemeMode.defaultDark || resolvedMode == AppThemeMode.nocturno;

  return ThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: t.primaryBackground,
    primaryColor: t.primaryBackground,
    colorScheme: ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: t.accent,
      onPrimary: t.buttonForeground,
      secondary: t.secondaryAccent,
      onSecondary: Colors.white,
      error: t.error,
      onError: Colors.white,
      surface: t.cardBackground,
      onSurface: t.textPrimary,
    ),
    cardTheme: CardThemeData(
      color: t.cardBackground,
      elevation: isDark ? 0 : 1,
      shadowColor: t.borderSubtle,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.cardBackground,
      foregroundColor: t.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: t.filledButtons ? t.buttonBackground : t.accent,
        foregroundColor: t.buttonForeground,
        elevation: t.buttonShadow.isNotEmpty ? 4 : 0,
        shadowColor: t.buttonShadow.isNotEmpty
            ? t.buttonShadow.first.color
            : Colors.transparent,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: t.cardBackground,
      selectedItemColor: t.accent,
      unselectedItemColor: t.textHint,
    ),
    dividerTheme: DividerThemeData(color: t.borderSubtle),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.darkBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: t.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: t.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: t.accent, width: 1.5),
      ),
      hintStyle: TextStyle(color: t.textHint),
      labelStyle: TextStyle(color: t.textSecondary),
    ),
    extensions: [t],
    useMaterial3: true,
  );
}

/// Extensión de BuildContext para acceso ergonómico al tema.
extension AppThemeExt on BuildContext {
  AppTheme get appTheme => Theme.of(this).extension<AppTheme>()!;
}
