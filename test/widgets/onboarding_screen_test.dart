import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finazaap/Screens/onboarding_screen.dart';
import 'package:finazaap/data/account_service.dart';
import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/services/onboarding_service.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';

void main() {
  late Directory tempDir;
  late Box<Add_data> dataBox;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('es', null);
    tempDir = await Directory.systemTemp.createTemp('moneo_onboarding_widget_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ResponsibilityAdapter());
    }
    dataBox = await Hive.openBox<Add_data>('data', bytes: Uint8List(0));
    await Hive.openBox<Responsibility>('responsibilities', bytes: Uint8List(0));
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    await dataBox.clear();
  });

  Widget wrapCompact(Widget child) {
    return MaterialApp(
      theme: buildThemeData(AppThemeMode.diurno),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaler: TextScaler.linear(1.35),
        ),
        child: child,
      ),
    );
  }

  group('OnboardingScreen - Flujo, Persistencia y Accesibilidad', () {
    testWidgets(
      'Flujo completo Pasos 1->5 con texto de privacidad verificable, sin overflow en 360x640 a 1.35x',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var finished = false;
        await tester.pumpWidget(
          wrapCompact(OnboardingScreen(onFinished: () => finished = true)),
        );
        await tester.pumpAndSettle();

        // Paso 1: Bienvenida + texto de privacidad verificable
        expect(find.text('Bienvenido a Moneo'), findsOneWidget);
        expect(
          find.text(
            'Tus datos se guardan en tu dispositivo. Moneo no requiere una cuenta en la nube para usar sus funciones principales.',
          ),
          findsOneWidget,
        );
        expect(find.text('Paso 1 de 5'), findsOneWidget);
        expect(
          tester.getSize(find.widgetWithText(ElevatedButton, 'Comenzar')).height,
          greaterThanOrEqualTo(48),
        );

        await tester.ensureVisible(find.text('Comenzar'));
        await tester.tap(find.text('Comenzar'));
        await tester.pumpAndSettle();

        // Paso 2: Categorías (ninguna preseleccionada)
        expect(find.text('Paso 2 de 5'), findsOneWidget);
        expect(find.text('Continuar sin categorías'), findsOneWidget);

        await tester.tap(find.text('Alimentación'));
        await tester.pumpAndSettle();
        expect(find.text('Guardar y continuar'), findsOneWidget);

        await tester.ensureVisible(find.text('Guardar y continuar'));
        await tester.tap(find.text('Guardar y continuar'));
        await tester.pumpAndSettle();

        // Paso 3: Primera cuenta
        expect(find.text('Paso 3 de 5'), findsOneWidget);
        final accountNameField = find.widgetWithText(TextField, 'Nombre de la cuenta');
        await tester.enterText(accountNameField, 'Efectivo casa');
        await tester.pump();
        final balanceField = find.widgetWithText(TextField, 'Saldo inicial');
        await tester.enterText(balanceField, '50000');
        await tester.pump();

        await tester.ensureVisible(find.text('Crear cuenta y continuar'));
        await tester.tap(find.text('Crear cuenta y continuar'));
        await tester.pumpAndSettle();

        // Paso 4: Primer movimiento real
        expect(find.text('Paso 4 de 5'), findsOneWidget);
        final amountField = find.widgetWithText(TextField, 'Monto');
        await tester.enterText(amountField, '12000');
        await tester.pump();

        await tester.ensureVisible(find.text('Guardar movimiento'));
        await tester.tap(find.text('Guardar movimiento'));
        await tester.pumpAndSettle();

        // Paso 5: Resumen final
        expect(find.text('Paso 5 de 5'), findsOneWidget);
        expect(find.text('¡Todo listo!'), findsOneWidget);
        expect(dataBox.length, 1);

        await tester.ensureVisible(find.text('Ir a Inicio'));
        await tester.tap(find.text('Ir a Inicio'));
        await tester.pumpAndSettle();

        expect(finished, isTrue);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(OnboardingService.completedKey), isTrue);
        expect(prefs.getBool(OnboardingService.skippedKey), isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Omitir en Paso 1 no crea datos y marca onboarding_skipped y onboarding_completed',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var finished = false;
        await tester.pumpWidget(
          wrapCompact(OnboardingScreen(onFinished: () => finished = true)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Omitir'));
        await tester.pumpAndSettle();

        expect(find.text('¿Omitir guía inicial?'), findsOneWidget);
        await tester.tap(find.widgetWithText(ElevatedButton, 'Omitir'));
        await tester.pumpAndSettle();

        expect(finished, isTrue);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(OnboardingService.completedKey), isTrue);
        expect(prefs.getBool(OnboardingService.skippedKey), isTrue);
        expect(await CategoryService.getCategories('Expenses'), isEmpty);
        expect(await AccountService.getActiveAccounts(), isEmpty);
        expect(dataBox.length, 0);
      },
    );

    testWidgets(
      'Omitir Paso 4 no crea ningún movimiento pendiente ni borrador y reapertura desde Ajustes muestra Volver a Ajustes',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          CategoryService.expenseCategoriesKey: ['Alimentación'],
        });
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var finished = false;
        await tester.pumpWidget(
          wrapCompact(
            OnboardingScreen(
              initialStep: 3,
              isReopened: true,
              onFinished: () => finished = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Paso 4 de 5'), findsOneWidget);
        await tester.ensureVisible(find.text('Omitir este paso'));
        await tester.tap(find.text('Omitir este paso'));
        await tester.pumpAndSettle();

        expect(find.text('Paso 5 de 5'), findsOneWidget);
        expect(find.text('Sin movimientos iniciales'), findsOneWidget);
        expect(dataBox.length, 0);

        await tester.ensureVisible(find.text('Volver a Ajustes'));
        await tester.tap(find.text('Volver a Ajustes'));
        await tester.pumpAndSettle();
        expect(finished, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Paso 2 permite crear categoría propia sin bloquear la pantalla y Paso 3 no ofrece Tarjeta de crédito',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          wrapCompact(const OnboardingScreen(initialStep: 1)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Paso 2 de 5'), findsOneWidget);
        await tester.ensureVisible(find.text('Crear categoría propia'));
        await tester.tap(find.text('Crear categoría propia'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Nueva categoría'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextField, 'Nombre de la categoría'),
          'Mascotas',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Crear'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Mascotas'), findsOneWidget);

        await tester.ensureVisible(find.text('Guardar y continuar'));
        await tester.tap(find.text('Guardar y continuar'));
        await tester.pumpAndSettle();

        expect(find.text('Paso 3 de 5'), findsOneWidget);
        expect(find.text('Efectivo'), findsOneWidget);
        expect(find.text('Cuenta bancaria'), findsOneWidget);
        expect(find.text('Billetera digital'), findsOneWidget);
        expect(find.text('Tarjeta de crédito'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
