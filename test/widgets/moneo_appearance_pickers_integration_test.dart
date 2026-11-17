import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finazaap/Screens/categories_screen.dart';
import 'package:finazaap/core/theme_notifier.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/widgets/add_account_dialogs.dart';
import 'package:finazaap/widgets/add_responsibility_dialog.dart';
import 'package:finazaap/widgets/edit_account_dialogs.dart';
import 'package:finazaap/widgets/moneo_appearance_pickers_row.dart';
import 'package:finazaap/widgets/moneo_color_picker.dart';
import 'package:finazaap/widgets/moneo_icon_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fourThemes = [
    AppThemeMode.defaultDark,
    AppThemeMode.diurno,
    AppThemeMode.dia,
    AppThemeMode.nocturno,
  ];

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'default_currency': 'COP',
    });
    await CurrencyHelper.loadCurrency();
    await ThemeNotifier.init();
    await ThemeNotifier.setMode(AppThemeMode.defaultDark);
  });

  Widget wrapCompactViewport({
    required AppThemeMode mode,
    required Widget child,
    double textScale = 1.35,
  }) {
    return MaterialApp(
      key: ValueKey('integration-${mode.name}-${child.hashCode}'),
      theme: buildThemeData(mode),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 640),
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    );
  }

  Future<void> setCompactSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  group('MoneoAppearancePickersRow', () {
    testWidgets(
      'renderiza ambos triggers lado a lado (48dp+) y abre cada selector en ventana emergente',
      (tester) async {
        await setCompactSurface(tester);

        Color selectedColor = kMoneoWheelColors[12];
        IconData selectedIcon = Icons.account_balance_wallet;

        await tester.pumpWidget(
          wrapCompactViewport(
            mode: AppThemeMode.diurno,
            textScale: 1.0,
            child: Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      return MoneoAppearancePickersRow(
                        selectedColor: selectedColor,
                        selectedIcon: selectedIcon,
                        onColorChanged: (c) =>
                            setState(() => selectedColor = c),
                        onIconChanged: (i) => setState(() => selectedIcon = i),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );

        final colorTrigger = find.byType(MoneoColorPickerTrigger);
        final iconTrigger = find.byType(MoneoIconPickerTrigger);
        expect(colorTrigger, findsOneWidget);
        expect(iconTrigger, findsOneWidget);

        // Triggers lado a lado en la misma fila y altura compacta >= 48dp
        final colorRect = tester.getRect(colorTrigger);
        final iconRect = tester.getRect(iconTrigger);
        expect(colorRect.height, greaterThanOrEqualTo(48));
        expect(iconRect.height, greaterThanOrEqualTo(48));
        expect(colorRect.height, lessThanOrEqualTo(64));
        expect(iconRect.height, lessThanOrEqualTo(64));
        expect((colorRect.top - iconRect.top).abs(), lessThanOrEqualTo(4));
        expect(iconRect.left, greaterThan(colorRect.right));

        // Estado inicial cerrado
        expect(find.byType(MoneoColorPickerPanel), findsNothing);
        expect(find.byType(MoneoIconPickerPanel), findsNothing);

        // 1. Abrir Color -> muestra ventana emergente con Rueda, Paleta y Aplicar
        await tester.tap(colorTrigger);
        await tester.pumpAndSettle();
        expect(find.text('Elegir color'), findsOneWidget);
        expect(find.byType(MoneoColorPickerPanel), findsOneWidget);
        expect(find.byType(MoneoIconPickerPanel), findsNothing);
        expect(find.byKey(const Key('moneo_color_wheel')), findsOneWidget);

        await tester.tap(find.text('Paleta'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('moneo_palette_color_0')), findsOneWidget);

        await tester.tap(find.byKey(const Key('moneo_palette_color_18')));
        await tester.pump();
        await tester.tap(find.text('Aplicar'));
        await tester.pumpAndSettle();
        expect(selectedColor.toARGB32(), kMoneoWheelColors[18].toARGB32());
        expect(find.byType(MoneoColorPickerPanel), findsNothing);

        // 2. Abrir Ícono -> muestra ventana emergente con categorías, búsqueda y cierre al elegir
        await tester.tap(iconTrigger);
        await tester.pumpAndSettle();
        expect(find.text('Elegir ícono'), findsOneWidget);
        expect(find.byType(MoneoIconPickerPanel), findsOneWidget);
        expect(find.byType(MoneoColorPickerPanel), findsNothing);

        await tester.drag(find.text('Finanzas'), const Offset(-120, 0));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Comida'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.restaurant), findsOneWidget);

        await tester.drag(find.text('Comida'), const Offset(120, 0));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Todos'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'café');
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.local_cafe), findsOneWidget);

        await tester.ensureVisible(find.byIcon(Icons.local_cafe));
        await tester.tap(find.byIcon(Icons.local_cafe));
        await tester.pumpAndSettle();
        expect(selectedIcon, Icons.local_cafe);
        expect(find.byType(MoneoIconPickerPanel), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'cero overflow en 360x640 @ 1.35x en los 4 temas (triggers y ventanas emergentes)',
      (tester) async {
        await setCompactSurface(tester);

        for (final mode in fourThemes) {
          Color selectedColor = kMoneoWheelColors[14];
          IconData selectedIcon = Icons.savings;

          await tester.pumpWidget(
            wrapCompactViewport(
              mode: mode,
              textScale: 1.35,
              child: Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        return MoneoAppearancePickersRow(
                          selectedColor: selectedColor,
                          selectedIcon: selectedIcon,
                          onColorChanged: (c) =>
                              setState(() => selectedColor = c),
                          onIconChanged: (i) =>
                              setState(() => selectedIcon = i),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Overflow colapsado en $mode',
          );

          await tester.tap(find.byType(MoneoColorPickerTrigger));
          await tester.pumpAndSettle();
          expect(find.byType(MoneoColorPickerPanel), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: 'Overflow en popup Color (Rueda) en $mode',
          );

          await tester.tap(find.text('Paleta'));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Overflow en popup Color (Paleta) en $mode',
          );

          await tester.tap(find.text('Aplicar'));
          await tester.pumpAndSettle();

          await tester.tap(find.byType(MoneoIconPickerTrigger));
          await tester.pumpAndSettle();
          expect(find.byType(MoneoIconPickerPanel), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: 'Overflow en popup Ícono en $mode',
          );

          await tester.tap(find.byTooltip('Cerrar'));
          await tester.pumpAndSettle();
        }
      },
    );
  });

  group('Smoke tests de integración en diálogos (360x640 @ 1.35x)', () {
    testWidgets(
      'showAddAccountDialog integra MoneoAppearancePickersRow sin overflow',
      (tester) async {
        await setCompactSurface(tester);

        await tester.pumpWidget(
          wrapCompactViewport(
            mode: AppThemeMode.diurno,
            textScale: 1.35,
            child: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showAddAccountDialog(context),
                    child: const Text('Abrir Cuenta'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Cuenta'));
        await tester.pumpAndSettle();

        expect(find.byType(AddAccountDialog), findsOneWidget);
        expect(find.byType(MoneoAppearancePickersRow), findsOneWidget);

        final colorTrigger = find.byType(MoneoColorPickerTrigger);
        await tester.ensureVisible(colorTrigger);
        await tester.pumpAndSettle();
        await tester.tap(colorTrigger);
        await tester.pumpAndSettle();
        expect(find.byType(MoneoColorPickerPanel), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Aplicar'));
        await tester.pumpAndSettle();

        final iconTrigger = find.byType(MoneoIconPickerTrigger);
        await tester.ensureVisible(iconTrigger);
        await tester.pumpAndSettle();
        await tester.tap(iconTrigger);
        await tester.pumpAndSettle();
        expect(find.byType(MoneoColorPickerPanel), findsNothing);
        expect(find.byType(MoneoIconPickerPanel), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Cerrar').last);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'showEditAccountDialog integra MoneoAppearancePickersRow sin overflow',
      (tester) async {
        await setCompactSurface(tester);

        final existing = AccountItem(
          id: 'acc_smoke_1',
          icon: Icons.account_balance,
          title: 'Banco Principal',
          subtitle: 'Cuenta de Ahorros',
          balance: '250000',
          iconColor: kMoneoWheelColors[20],
        );

        await tester.pumpWidget(
          wrapCompactViewport(
            mode: AppThemeMode.nocturno,
            textScale: 1.35,
            child: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showEditAccountDialog(context, existing),
                    child: const Text('Editar Cuenta'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Editar Cuenta'));
        await tester.pumpAndSettle();

        expect(find.byType(EditAccountDialog), findsOneWidget);
        expect(find.byType(MoneoAppearancePickersRow), findsOneWidget);

        final iconTrigger = find.byType(MoneoIconPickerTrigger);
        await tester.ensureVisible(iconTrigger);
        await tester.pumpAndSettle();
        await tester.tap(iconTrigger);
        await tester.pumpAndSettle();
        expect(find.byType(MoneoIconPickerPanel), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Cerrar').last);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'AddResponsibilityDialog integra MoneoIconPickerTrigger con ventana emergente sin overflow',
      (tester) async {
        await setCompactSurface(tester);

        await tester.pumpWidget(
          wrapCompactViewport(
            mode: AppThemeMode.dia,
            textScale: 1.35,
            child: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const AddResponsibilityDialog(),
                    ),
                    child: const Text('Nueva Obligación'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Nueva Obligación'));
        await tester.pumpAndSettle();

        expect(find.byType(AddResponsibilityDialog), findsOneWidget);
        expect(find.byType(MoneoIconPickerTrigger), findsOneWidget);
        expect(find.byType(MoneoColorPickerTrigger), findsNothing);
        expect(find.byType(MoneoIconPickerPanel), findsNothing);

        final iconTrigger = find.byType(MoneoIconPickerTrigger);
        await tester.ensureVisible(iconTrigger);
        await tester.pumpAndSettle();
        await tester.tap(iconTrigger);
        await tester.pumpAndSettle();

        expect(find.byType(MoneoIconPickerPanel), findsOneWidget);
        await tester.ensureVisible(find.text('Finanzas'));
        await tester.tap(find.text('Finanzas'));
        await tester.pumpAndSettle();

        final receiptIcon = find.descendant(
          of: find.byType(MoneoIconPickerPanel),
          matching: find.byIcon(Icons.receipt_long),
        );
        await tester.ensureVisible(receiptIcon);
        await tester.tap(receiptIcon);
        await tester.pumpAndSettle();

        expect(find.byType(MoneoIconPickerPanel), findsNothing);
        expect(
          tester.widget<MoneoIconPickerTrigger>(iconTrigger).selectedIcon,
          Icons.receipt_long,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'CategoriesScreen diálogo integra MoneoAppearancePickersRow y despliega ambos paneles sin overflow',
      (tester) async {
        await setCompactSurface(tester);

        await tester.pumpWidget(
          wrapCompactViewport(
            mode: AppThemeMode.defaultDark,
            textScale: 1.35,
            child: const CategoriesScreen(),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
        });
        await tester.pump();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        expect(find.text('Nueva Categoría'), findsOneWidget);
        expect(find.byType(MoneoAppearancePickersRow), findsOneWidget);

        final colorTrigger = find.byType(MoneoColorPickerTrigger);
        await tester.ensureVisible(colorTrigger);
        await tester.pumpAndSettle();
        await tester.tap(colorTrigger);
        await tester.pumpAndSettle();
        expect(find.byType(MoneoColorPickerPanel), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Aplicar'));
        await tester.pumpAndSettle();

        final iconTrigger = find.byType(MoneoIconPickerTrigger);
        await tester.ensureVisible(iconTrigger);
        await tester.pumpAndSettle();
        await tester.tap(iconTrigger);
        await tester.pumpAndSettle();
        expect(find.byType(MoneoColorPickerPanel), findsNothing);
        expect(find.byType(MoneoIconPickerPanel), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Cerrar').last);
        await tester.pumpAndSettle();
      },
    );
  });
}
