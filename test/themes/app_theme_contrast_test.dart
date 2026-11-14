import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/Screens/ai_chat_screen.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/services/ai_chat_service.dart';
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
  group('AppTheme Fase 1 - Tokens y Contraste WCAG 2.1', () {
    test('Default permanece 100% intacto sin modificaciones', () {
      final def = AppTheme.forMode(AppThemeMode.defaultDark);
      expect(def.primaryBackground, const Color(0xFF1F2639));
      expect(def.cardBackground, const Color(0xFF2A3143));
      expect(def.darkBackground, const Color(0xFF1A1F2B));
      expect(def.secondaryCardBackground, const Color(0xFF222939));
      expect(def.textPrimary, Colors.white);
      expect(def.textSecondary, const Color(0xFFB0C4DE));
      expect(def.textHint, const Color(0xFF708090));
      expect(def.borderSubtle, const Color(0xFF2F374A));
      expect(def.borderVisible, const Color(0xFF4A556E));
      expect(def.accent, const Color(0xFF52E2FF));
      expect(def.secondaryAccent, const Color(0xFF4A80F0));
      expect(def.income, const Color(0xFFA7E2A9));
      expect(def.expense, const Color(0xFFE53935));
      expect(def.success, const Color(0xFF2ECC71));
      expect(def.warning, const Color(0xFFFDD835));
      expect(def.error, const Color(0xFFE53935));
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

    test('Diurno, Día y Nocturno cumplen AA (>=4.5:1) en todos los tokens sobre sus 3 superficies', () {
      for (final mode in [
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

  group('LiquidGlassSurface - Exclusividad Diurno y Respaldo Accesible', () {
    Widget buildHarness(
      AppThemeMode mode, {
      bool accessibleNavigation = false,
      bool highContrast = false,
      bool disableAnimations = false,
    }) {
      return MaterialApp(
        key: ValueKey('$mode-$accessibleNavigation-$highContrast-$disableAnimations'),
        theme: buildThemeData(mode),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            accessibleNavigation: accessibleNavigation,
            highContrast: highContrast,
            disableAnimations: disableAnimations,
          ),
          child: const Scaffold(
            body: Center(
              child: LiquidGlassSurface(
                borderRadius: BorderRadius.all(Radius.circular(24)),
                padding: EdgeInsets.all(16),
                child: Text('Control Funcional'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Aplica BackdropFilter en Diurno y lo omite en Día, Nocturno y Default', (tester) async {
      await tester.pumpWidget(buildHarness(AppThemeMode.diurno));
      expect(find.byType(BackdropFilter), findsOneWidget);

      for (final mode in [AppThemeMode.dia, AppThemeMode.nocturno, AppThemeMode.defaultDark]) {
        await tester.pumpWidget(buildHarness(mode));
        expect(
          find.byType(BackdropFilter),
          findsNothing,
          reason: '$mode no debe aplicar Liquid Glass / BackdropFilter',
        );
      }
    });

    testWidgets('Desactiva BackdropFilter en Diurno ante preferencias de accesibilidad', (tester) async {
      await tester.pumpWidget(buildHarness(AppThemeMode.diurno, highContrast: true));
      expect(find.byType(BackdropFilter), findsNothing);

      await tester.pumpWidget(buildHarness(AppThemeMode.diurno, accessibleNavigation: true));
      expect(find.byType(BackdropFilter), findsNothing);

      await tester.pumpWidget(buildHarness(AppThemeMode.diurno, disableAnimations: true));
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('AiChatScreen - Diseño Responsive, Anchura Orgánica y Aislamiento de Glass', () {
    late Directory tempDir;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tempDir = await Directory.systemTemp.createTemp('moneo_ai_chat_test_');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(AdddataAdapter());
      }
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({'ai_use_local_simulator': true});
      await Hive.openBox<Add_data>('data');
    });

    tearDown(() async {
      await Hive.close();
    });

    tearDownAll(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Widget buildChatApp(
      AppThemeMode mode, {
      Size size = const Size(360, 640),
      EdgeInsets viewInsets = EdgeInsets.zero,
    }) {
      return MaterialApp(
        key: ValueKey(mode),
        theme: buildThemeData(mode),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            viewInsets: viewInsets,
          ),
          child: const AiChatScreen(),
        ),
      );
    }

    testWidgets('Renderiza sin overflow en 360x640 y con teclado abierto en los 4 temas', (tester) async {
      final originalOnError = FlutterError.onError;
      final capturedErrors = <FlutterErrorDetails>[];
      FlutterError.onError = (details) {
        capturedErrors.add(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final mode in [
        AppThemeMode.diurno,
        AppThemeMode.dia,
        AppThemeMode.nocturno,
        AppThemeMode.defaultDark,
      ]) {
        await tester.pumpWidget(buildChatApp(mode));
        await tester.pump(const Duration(milliseconds: 300));

        if (mode == AppThemeMode.diurno) {
          expect(find.byType(BackdropFilter), findsAtLeastNWidgets(1));
        } else {
          expect(
            find.byType(BackdropFilter),
            findsNothing,
            reason: '$mode no debe renderizar BackdropFilter en AiChatScreen',
          );
        }

        // Simular teclado abierto y texto multilínea largo en el composer
        await tester.pumpWidget(
          buildChatApp(
            mode,
            viewInsets: const EdgeInsets.only(bottom: 280),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        await tester.enterText(
          find.byKey(const Key('ai_chat_input_field')),
          'Necesito analizar un gasto extraordinario muy detallado con múltiples categorías, pagos diferidos a cuotas sin intereses y presupuesto mensual ajustado.',
        );
        await tester.pump();
      }

      expect(capturedErrors, isEmpty);
    });

    testWidgets('Las burbujas usan ancho orgánico según contenido y crecen en mensajes largos', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildChatApp(AppThemeMode.diurno));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      const shortMsg = 'Hola';
      await tester.enterText(find.byKey(const Key('ai_chat_input_field')), shortMsg);
      await tester.pump();
      await tester.tap(find.byKey(const Key('ai_chat_send_button')));
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        AiChatService().messages.map((m) => m.content),
        contains(shortMsg),
      );
      final chatList = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      );
      if (find.text(shortMsg).evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          find.text(shortMsg),
          -120,
          scrollable: chatList,
        );
      }
      await tester.pump();
      final shortWidth = tester.getSize(find.text(shortMsg)).width;
      expect(shortWidth, lessThan(120.0));

      const longMsg =
          'Quiero revisar mi balance mensual completo incluyendo ingresos fijos, gastos variables de alimentación, transporte y cuotas pendientes de tarjeta.';
      await tester.enterText(find.byKey(const Key('ai_chat_input_field')), longMsg);
      await tester.pump();
      await tester.tap(find.byKey(const Key('ai_chat_send_button')));
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        AiChatService().messages.map((m) => m.content),
        contains(longMsg),
      );
      if (find.text(longMsg).evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          find.text(longMsg),
          -120,
          scrollable: chatList,
        );
      }
      await tester.pump();
      final longWidth = tester.getSize(find.text(longMsg)).width;
      expect(longWidth, greaterThan(shortWidth * 2));
      expect(longWidth, lessThanOrEqualTo(360.0 * 0.80));
    });
  });
}
