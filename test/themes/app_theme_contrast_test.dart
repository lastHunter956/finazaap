import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';

double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('AppTheme - Tokens y Contraste WCAG 2.1', () {
    test('Default mantiene su paleta base con tokens ajustados a WCAG AA', () {
      final def = AppTheme.forMode(AppThemeMode.defaultDark);
      expect(def.primaryBackground, const Color(0xFF1F2639));
      expect(def.cardBackground, const Color(0xFF2A3143));
      expect(def.darkBackground, const Color(0xFF1A1F2B));
      expect(def.secondaryCardBackground, const Color(0xFF222939));
      expect(def.textPrimary, Colors.white);
      expect(def.textSecondary, const Color(0xFFB0C4DE));
      expect(def.textHint, const Color(0xFF90A0B5));
      expect(def.borderSubtle, const Color(0xFF2F374A));
      expect(def.borderVisible, const Color(0xFF4A556E));
      expect(def.accent, const Color(0xFF52E2FF));
      expect(def.secondaryAccent, const Color(0xFF6B9EFF));
      expect(def.income, const Color(0xFFA7E2A9));
      expect(def.expense, const Color(0xFFFF6B6B));
      expect(def.success, const Color(0xFF2ECC71));
      expect(def.warning, const Color(0xFFFDD835));
      expect(def.error, const Color(0xFFFF6B6B));
      expect(def.buttonBackground, const Color(0xFF52E2FF));
      expect(def.buttonForeground, const Color(0xFF1F2639));
      expect(def.buttonShadow, isEmpty);
      expect(def.filledButtons, isFalse);
    });

    test('Nocturno adopta la paleta oficial de Dracula', () {
      final noct = AppTheme.forMode(AppThemeMode.nocturno);
      expect(noct.primaryBackground, const Color(0xFF282A36));
      expect(noct.cardBackground, const Color(0xFF21222C));
      expect(noct.darkBackground, const Color(0xFF191A21));
      expect(noct.secondaryCardBackground, const Color(0xFF44475A));
      expect(noct.textPrimary, const Color(0xFFF8F8F2));
      expect(noct.textHint, const Color(0xFF909EC7));
      expect(noct.borderSubtle, const Color(0xFF44475A));
      expect(noct.borderVisible, const Color(0xFF6272A4));
      expect(noct.accent, const Color(0xFFBD93F9));
      expect(noct.secondaryAccent, const Color(0xFF8BE9FD));
      expect(noct.income, const Color(0xFF50FA7B));
      expect(noct.success, const Color(0xFF50FA7B));
      expect(noct.warning, const Color(0xFFFFB86C));
      expect(noct.expense, const Color(0xFFFF5555));
      expect(noct.error, const Color(0xFFFF5555));
      expect(AppTheme.draculaPink, const Color(0xFFFF79C6));
      expect(AppTheme.draculaComment, const Color(0xFF6272A4));
    });

    test('Todos los temas cumplen AAA en texto primario y AA en texto secundario y botones', () {
      for (final mode in [
        AppThemeMode.defaultDark,
        AppThemeMode.diurno,
        AppThemeMode.nocturno,
        AppThemeMode.dia,
      ]) {
        final t = AppTheme.forMode(mode);
        expect(
          _contrastRatio(t.textPrimary, t.primaryBackground),
          greaterThanOrEqualTo(7.0),
          reason: '$mode: textPrimary vs primaryBackground debe cumplir AAA (>=7.0)',
        );
        expect(
          _contrastRatio(t.textPrimary, t.cardBackground),
          greaterThanOrEqualTo(7.0),
          reason: '$mode: textPrimary vs cardBackground debe cumplir AAA (>=7.0)',
        );
        expect(
          _contrastRatio(t.textPrimary, t.darkBackground),
          greaterThanOrEqualTo(7.0),
          reason: '$mode: textPrimary vs darkBackground debe cumplir AAA (>=7.0)',
        );
        expect(
          _contrastRatio(t.textSecondary, t.primaryBackground),
          greaterThanOrEqualTo(4.5),
          reason: '$mode: textSecondary vs primaryBackground debe cumplir AA (>=4.5)',
        );
        expect(
          _contrastRatio(t.textSecondary, t.cardBackground),
          greaterThanOrEqualTo(4.5),
          reason: '$mode: textSecondary vs cardBackground debe cumplir AA (>=4.5)',
        );
        expect(
          _contrastRatio(t.buttonForeground, t.buttonBackground),
          greaterThanOrEqualTo(4.5),
          reason: '$mode: buttonForeground vs buttonBackground debe cumplir AA (>=4.5)',
        );
      }
    });

    test('Todos los temas (Default, Diurno, Día y Nocturno) cumplen AA (>=4.5:1) en todos los tokens sobre sus 3 superficies', () {
      for (final mode in [
        AppThemeMode.defaultDark,
        AppThemeMode.diurno,
        AppThemeMode.dia,
        AppThemeMode.nocturno,
      ]) {
        final t = AppTheme.forMode(mode);
        final surfaces = <String, Color>{
          'primaryBackground': t.primaryBackground,
          'cardBackground': t.cardBackground,
          'darkBackground': t.darkBackground,
        };
        final foregrounds = <String, Color>{
          'textSecondary': t.textSecondary,
          'textHint': t.textHint,
          'accent': t.accent,
          'secondaryAccent': t.secondaryAccent,
          'income': t.income,
          'expense': t.expense,
          'success': t.success,
          'warning': t.warning,
          'error': t.error,
        };

        for (final surface in surfaces.entries) {
          for (final fg in foregrounds.entries) {
            expect(
              _contrastRatio(fg.value, surface.value),
              greaterThanOrEqualTo(4.5),
              reason: '$mode: ${fg.key} vs ${surface.key} debe cumplir WCAG AA (>=4.5)',
            );
          }
        }
      }

      for (final mode in [AppThemeMode.diurno, AppThemeMode.dia]) {
        final t = AppTheme.forMode(mode);
        expect(
          (t.primaryBackground.computeLuminance() - t.cardBackground.computeLuminance()).abs(),
          greaterThan(0.05),
          reason: '$mode: debe existir separación perceptible entre lienzo y tarjeta',
        );
      }

      final noct = AppTheme.forMode(AppThemeMode.nocturno);
      expect(
        _contrastRatio(AppTheme.draculaPink, noct.cardBackground),
        greaterThanOrEqualTo(4.5),
      );

      final themeData = buildThemeData(AppThemeMode.nocturno);
      expect(themeData.brightness, Brightness.dark);
      expect(
        _contrastRatio(themeData.colorScheme.onSecondary, themeData.colorScheme.secondary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(themeData.colorScheme.onError, themeData.colorScheme.error),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
