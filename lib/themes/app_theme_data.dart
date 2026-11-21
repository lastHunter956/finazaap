import 'package:flutter/material.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/core/theme_notifier.dart';

export 'package:finazaap/widgets/liquid_glass_surface.dart';

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
    textHint: Color(0xFF90A0B5),      // Opaque slate grey (WCAG AA >= 4.87:1)
    borderSubtle: Color(0xFF2F374A),
    borderVisible: Color(0xFF4A556E),
    accent: Color(0xFF52E2FF),
    secondaryAccent: Color(0xFF6B9EFF),
    income: Color(0xFFA7E2A9),
    expense: Color(0xFFFF6B6B),
    success: Color(0xFF2ECC71),
    warning: Color(0xFFFDD835),
    error: Color(0xFFFF6B6B),
    buttonBackground: Color(0xFF52E2FF),
    buttonForeground: Color(0xFF1F2639),
    buttonShadow: [],
    filledButtons: false,
  );

  /// Rosa y comentario oficiales de Dracula para indicadores y biseles.
  static const Color draculaPink = Color(0xFFFF79C6);
  static const Color draculaComment = Color(0xFF6272A4);

  static const AppTheme _diurno = AppTheme(
    primaryBackground: Color(0xFFEEF2F8),       // Cool Alabaster Canvas (separa claramente de tarjetas)
    cardBackground: Color(0xFFFFFFFF),          // Pure White Surface
    darkBackground: Color(0xFFE2E8F2),          // Soft Frost Well (inputs, barras internas)
    secondaryCardBackground: Color(0xFFF7F9FC), // Elevated Cool Surface
    textPrimary: Color(0xFF0B132B),             // Deep Ink (AAA en 3 superficies)
    textSecondary: Color(0xFF334155),           // Slate 700 (AAA en 3 superficies)
    textHint: Color(0xFF52637A),                // Slate 600 (AA en 3 superficies)
    borderSubtle: Color(0xFFD5DFEE),            // Cool Hairline
    borderVisible: Color(0xFF8496B0),           // Active Control Border
    accent: Color(0xFF0062CC),                  // Apple Accessible System Blue (AA en 3 superficies)
    secondaryAccent: Color(0xFF4F46E5),         // Indigo 600 (AA en 3 superficies)
    income: Color(0xFF046B4D),                  // Emerald 800 (AA en 3 superficies)
    expense: Color(0xFFBE123C),                 // Crimson 700 (AA en 3 superficies)
    success: Color(0xFF046B4D),                 // Emerald 800
    warning: Color(0xFF92400E),                 // Amber 800 (AA en 3 superficies)
    error: Color(0xFFBE123C),                   // Crimson 700
    buttonBackground: Color(0xFF0062CC),
    buttonForeground: Colors.white,             // AA vs buttonBackground (5.80:1)
    buttonShadow: [
      BoxShadow(
        color: Color(0x1F0062CC),
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
    filledButtons: true,
  );

  static const AppTheme _nocturno = AppTheme(
    primaryBackground: Color(0xFF282A36),       // Dracula Background oficial
    cardBackground: Color(0xFF21222C),          // Dracula ANSI Black / Panel (garantiza AA >=4.5 con #FF5555)
    darkBackground: Color(0xFF191A21),          // Dracula Deep Well oficial (inputs)
    secondaryCardBackground: Color(0xFF252733), // Superficie elevada/modal Dracula (contraste AA y separación nítida de borderSubtle)
    textPrimary: Color(0xFFF8F8F2),             // Dracula Foreground oficial (AAA en 3 superficies)
    textSecondary: Color(0xFFC6CEE0),           // Gris azulado Dracula legible (AAA en 3 superficies)
    textHint: Color(0xFF909EC7),                // Dracula Comment aclarado para legibilidad AA (>=5.36:1)
    borderSubtle: Color(0xFF44475A),            // Dracula Selection oficial
    borderVisible: Color(0xFF6272A4),           // Dracula Comment oficial (bordes y divisores)
    accent: Color(0xFFBD93F9),                  // Dracula Purple oficial (AA en 3 superficies)
    secondaryAccent: Color(0xFF8BE9FD),         // Dracula Cyan oficial (AAA en 3 superficies)
    income: Color(0xFF50FA7B),                  // Dracula Green oficial (acento/indicador/montos)
    expense: Color(0xFFFF5555),                 // Dracula Red oficial (AA en 3 superficies: 4.53–5.52:1)
    success: Color(0xFF50FA7B),                 // Dracula Green oficial
    warning: Color(0xFFFFB86C),                 // Dracula Orange oficial (AAA en 3 superficies)
    error: Color(0xFFFF5555),                   // Dracula Red oficial
    buttonBackground: Color(0xFFBD93F9),        // Dracula Purple oficial
    buttonForeground: Color(0xFF282A36),        // Dracula Background (AA 5.90:1 vs purple)
    buttonShadow: [],
    filledButtons: true,
  );

  static const AppTheme _dia = AppTheme(
    primaryBackground: Color(0xFFF4EFE6),       // Warm Alabaster / Stone Pearl
    cardBackground: Color(0xFFFFFDF9),          // Warm Ivory White
    darkBackground: Color(0xFFE6DFD3),          // Warm Sand Well
    secondaryCardBackground: Color(0xFFFAF6F0), // Soft Linen Surface
    textPrimary: Color(0xFF1C1917),             // Stone 900 / Warm Obsidian (AAA en 3 superficies)
    textSecondary: Color(0xFF44403C),           // Stone 700 / Warm Charcoal (AAA en 3 superficies)
    textHint: Color(0xFF68625D),                // Stone 600 (AA en 3 superficies)
    borderSubtle: Color(0xFFDAD2C4),            // Warm Stone Hairline
    borderVisible: Color(0xFF968E83),           // Warm Taupe Active Border
    accent: Color(0xFF0E665F),                  // Deep Ocean Teal 800 (AA en 3 superficies)
    secondaryAccent: Color(0xFF92400E),         // Warm Copper Amber 800 (AA en 3 superficies)
    income: Color(0xFF146C34),                  // Green 800 (AA en 3 superficies)
    expense: Color(0xFFB91C1C),                 // Red 700 (AA en 3 superficies)
    success: Color(0xFF146C34),                 // Green 800
    warning: Color(0xFF92400E),                 // Amber 800 (AA en 3 superficies)
    error: Color(0xFFB91C1C),                   // Red 700
    buttonBackground: Color(0xFF0E665F),
    buttonForeground: Colors.white,             // AA 6.81:1 vs buttonBackground
    buttonShadow: [
      BoxShadow(
        color: Color(0x1F0E665F),
        blurRadius: 10,
        offset: Offset(0, 4),
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

  /// Retorna un color de primer plano con contraste WCAG AA sobre [background].
  Color foregroundOn(Color background) =>
      background.computeLuminance() > 0.20
          ? const Color(0xFF191A21)
          : Colors.white;
}

DatePickerThemeData _buildDatePickerThemeData(AppTheme t, Color accentColor) {
  final onAccent = t.foregroundOn(accentColor);
  return DatePickerThemeData(
    backgroundColor: t.secondaryCardBackground,
    headerBackgroundColor: t.cardBackground,
    headerForegroundColor: t.textPrimary,
    surfaceTintColor: Colors.transparent,
    dividerColor: t.borderVisible,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: t.borderVisible),
    ),
    dayForegroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return onAccent;
      if (states.contains(WidgetState.disabled)) return t.textHint;
      return t.textPrimary;
    }),
    dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return accentColor;
      return null;
    }),
    todayForegroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return onAccent;
      return accentColor;
    }),
    todayBorder: BorderSide(color: accentColor),
    yearForegroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return onAccent;
      return t.textPrimary;
    }),
    yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return accentColor;
      return null;
    }),
    weekdayStyle: TextStyle(color: t.textSecondary, fontWeight: FontWeight.w600),
    dayStyle: TextStyle(color: t.textPrimary),
    cancelButtonStyle: TextButton.styleFrom(foregroundColor: t.textSecondary),
    confirmButtonStyle: TextButton.styleFrom(foregroundColor: accentColor),
  );
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
      onSecondary: t.secondaryAccent.computeLuminance() > 0.25
          ? const Color(0xFF282A36)
          : Colors.white,
      error: t.error,
      onError: t.error.computeLuminance() > 0.25
          ? const Color(0xFF282A36)
          : Colors.white,
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
    datePickerTheme: _buildDatePickerThemeData(t, t.accent),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
      },
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        color: t.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        color: t.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineLarge: TextStyle(
        color: t.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        color: t.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineSmall: TextStyle(
        color: t.textPrimary,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(
        color: t.textPrimary,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        color: t.textPrimary,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleSmall: TextStyle(
        color: t.textPrimary,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      bodyLarge: TextStyle(
        color: t.textPrimary,
        height: 1.4,
      ),
      bodyMedium: TextStyle(
        color: t.textPrimary,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        color: t.textSecondary,
        height: 1.35,
      ),
      labelLarge: TextStyle(
        color: t.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        color: t.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        color: t.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.secondaryCardBackground,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Colors.black.withValues(alpha: isDark ? 0.65 : 0.45),
      showDragHandle: true,
      dragHandleColor: t.borderVisible,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.secondaryCardBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: t.borderSubtle),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.secondaryCardBackground,
      contentTextStyle: TextStyle(color: t.textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: t.borderSubtle),
      ),
    ),
    splashFactory: InkRipple.splashFactory,
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

  /// Indica si el tema resuelto corresponde a `Diurno`, único tema con Liquid Glass.
  bool get isDiurno =>
      Theme.of(this).brightness == Brightness.light &&
      appTheme.primaryBackground == const Color(0xFFEEF2F8);

  /// Indica si el tema resuelto corresponde a `Default` (identidad original).
  bool get isDefaultDark =>
      Theme.of(this).brightness == Brightness.dark &&
      appTheme.primaryBackground == const Color(0xFF1F2639);

  /// Construye un [ThemeData] para [showDatePicker] usando [accentColor] con
  /// contraste garantizado y divisores nítidos sobre el tema actual.
  ThemeData datePickerThemeWithAccent(Color accentColor) {
    final base = Theme.of(this);
    final t = appTheme;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: accentColor,
        onPrimary: t.foregroundOn(accentColor),
        surface: t.secondaryCardBackground,
        onSurface: t.textPrimary,
      ),
      dividerTheme: DividerThemeData(color: t.borderVisible),
      datePickerTheme: _buildDatePickerThemeData(t, accentColor),
    );
  }
}
