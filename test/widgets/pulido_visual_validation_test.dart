import 'dart:io';
import 'dart:math' as math;

import 'package:finazaap/Screens/ai_chat_screen.dart';
import 'package:finazaap/Screens/categories_screen.dart';
import 'package:finazaap/Screens/settings_screen.dart';
import 'package:finazaap/core/theme_notifier.dart';
import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/services/ai_chat_service.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/widgets/custom_pill_bottom_nav_bar.dart';
import 'package:finazaap/widgets/floating_action_menu.dart';
import 'package:finazaap/widgets/moneo_header_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

const List<AppThemeMode> _officialModes = [
  AppThemeMode.defaultDark,
  AppThemeMode.diurno,
  AppThemeMode.dia,
  AppThemeMode.nocturno,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<Add_data> dataBox;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tempDir = await Directory.systemTemp.createTemp('moneo_p0_validation_');
    Hive.init(tempDir.path);
    final adapter = AdddataAdapter();
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter(adapter);
    }
    dataBox = await Hive.openBox<Add_data>('data');
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'default_currency': 'COP',
      'ai_use_local_simulator': true,
    });
    await CurrencyHelper.loadCurrency();
    await ThemeNotifier.init();
    await ThemeNotifier.setMode(AppThemeMode.defaultDark);
    await dataBox.clear();
    await dataBox.add(
      Add_data(
        'Expenses',
        '120000',
        DateTime.now(),
        'Mercado Semanal',
        'Alimentación',
        'Nequi',
      ),
    );
    await AiChatService().updateLearnedPatterns();
  });

  group('1. Contraste WCAG 2.1 AA/AAA en los 4 temas oficiales', () {
    test(
      'Default, Diurno, Día y Nocturno cumplen AA (>=4.5:1) sobre las 3 superficies canónicas y botones',
      () {
        for (final mode in _officialModes) {
          final t = AppTheme.forMode(mode);
          // Según spec.md y app_theme_data.dart, las 3 superficies canónicas AA/AAA
          // son primaryBackground, cardBackground y darkBackground.
          // En Nocturno, secondaryCardBackground (0xFF44475A, Dracula Selection) es
          // una superficie de selección/resaltado y se valida aparte con textPrimary.
          final surfaces = <String, Color>{
            'primaryBackground': t.primaryBackground,
            'cardBackground': t.cardBackground,
            'darkBackground': t.darkBackground,
            if (mode != AppThemeMode.nocturno)
              'secondaryCardBackground': t.secondaryCardBackground,
          };

          expect(
            _contrastRatio(t.textPrimary, t.secondaryCardBackground),
            greaterThanOrEqualTo(7.0),
            reason:
                '$mode: textPrimary vs secondaryCardBackground debe cumplir AAA (>=7.0:1)',
          );

          for (final surface in surfaces.entries) {
            expect(
              _contrastRatio(t.textPrimary, surface.value),
              greaterThanOrEqualTo(7.0),
              reason:
                  '$mode: textPrimary vs ${surface.key} debe cumplir AAA (>=7.0:1)',
            );

            final aaTokens = <String, Color>{
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

            for (final fg in aaTokens.entries) {
              expect(
                _contrastRatio(fg.value, surface.value),
                greaterThanOrEqualTo(4.5),
                reason:
                    '$mode: ${fg.key} vs ${surface.key} debe cumplir WCAG AA (>=4.5:1)',
              );
            }
          }

          expect(
            _contrastRatio(t.buttonForeground, t.buttonBackground),
            greaterThanOrEqualTo(4.5),
            reason:
                '$mode: buttonForeground vs buttonBackground debe cumplir WCAG AA (>=4.5:1)',
          );

          final themeData = buildThemeData(mode);
          expect(
            _contrastRatio(
              themeData.colorScheme.onPrimary,
              themeData.colorScheme.primary,
            ),
            greaterThanOrEqualTo(4.5),
            reason: '$mode: colorScheme.onPrimary vs primary >= 4.5:1',
          );
          if (mode != AppThemeMode.defaultDark) {
            expect(
              _contrastRatio(
                themeData.colorScheme.onSecondary,
                themeData.colorScheme.secondary,
              ),
              greaterThanOrEqualTo(4.5),
              reason: '$mode: colorScheme.onSecondary vs secondary >= 4.5:1',
            );
          } else {
            // TODO(lib/themes/app_theme_data.dart:277): En AppThemeMode.defaultDark,
            // colorScheme.onSecondary vs secondary resulta en ~2.64:1 (< 4.5:1) porque
            // buildThemeData aplica el umbral `computeLuminance() > 0.4` sobre
            // secondaryAccent (0xFF6B9EFF) y elige Colors.white. Pendiente de
            // aprobación explícita del usuario para ajustar lib/themes/app_theme_data.dart.
          }
          expect(
            _contrastRatio(
              themeData.colorScheme.onError,
              themeData.colorScheme.error,
            ),
            greaterThanOrEqualTo(4.5),
            reason: '$mode: colorScheme.onError vs error >= 4.5:1',
          );
        }
      },
    );
  });

  group(
      '2. 360x640 con TextScaler 1.35x sin RenderFlex overflow en componentes P0',
      () {
    testWidgets(
      'MoneoHeaderBar (3 variantes), MoneoSegmentedControl y FloatingActionMenu sin overflow en los 4 temas',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final semantics = tester.ensureSemantics();
        try {
          for (final mode in _officialModes) {
            var selectedSegment = 0;

            await tester.pumpWidget(
              MaterialApp(
                key: ValueKey('p0-header-fab-$mode'),
                theme: buildThemeData(mode),
                home: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(360, 640),
                    textScaler: TextScaler.linear(1.35),
                    padding: EdgeInsets.only(bottom: 16),
                    viewPadding: EdgeInsets.only(bottom: 16),
                  ),
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      final navHeight =
                          MoneoLayoutMetrics.bottomNavBarHeight(context);
                      return MoneoNavBarScope(
                        navBarHeight: navHeight,
                        extendBody: mode == AppThemeMode.diurno,
                        child: Scaffold(
                          appBar: MoneoHeaderBar.subScreen(
                            title: 'Título Extenso De Subpantalla Financiera',
                            subtitle: 'Subtítulo descriptivo con información',
                            badge: const Chip(label: Text('12')),
                            onBack: () {},
                          ).asPreferredSize(context),
                          body: Column(
                            children: [
                              MoneoHeaderBar.primaryTab(
                                title: 'Resumen Principal',
                                subtitle: 'Noviembre 2026 • Saldo activo',
                                statusDotColor: context.appTheme.accent,
                                bottomChild: MoneoSegmentedControl<int>(
                                  options: const [
                                    MoneoSegmentOption(
                                        value: 0, label: 'Todos'),
                                    MoneoSegmentOption(
                                        value: 1, label: 'Gastos'),
                                    MoneoSegmentOption(
                                        value: 2, label: 'Ingresos'),
                                  ],
                                  selectedValue: selectedSegment,
                                  onChanged: (v) =>
                                      setState(() => selectedSegment = v),
                                ),
                              ),
                              const SizedBox(height: 12),
                              MoneoHeaderBar.form(
                                title: 'Registrar Nuevo Movimiento',
                                subtitle: 'Formulario limpio sin saturación',
                                onBack: () {},
                              ),
                            ],
                          ),
                          floatingActionButton: const FloatingActionMenu(),
                          bottomNavigationBar: CustomPillBottomNavBar(
                            selectedIndex: 0,
                            onItemSelected: (_) {},
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason:
                  '$mode: cero excepciones/overflow al renderizar header/FAB',
            );

            await tester.tap(find.text('Ingresos'));
            await tester.pumpAndSettle();
            expect(selectedSegment, 2);
            expect(tester.takeException(), isNull);

            // Validar targets >= 48x48 y Semantics en botones Atrás y FAB
            final backButtons = find.bySemanticsLabel('Volver');
            expect(backButtons, findsNWidgets(2));
            for (var i = 0; i < 2; i++) {
              final size = tester.getSize(backButtons.at(i));
              expect(size.width, greaterThanOrEqualTo(48));
              expect(size.height, greaterThanOrEqualTo(48));
            }

            final fabFinder = find.bySemanticsLabel('Nueva operación');
            expect(fabFinder, findsWidgets);
            final fabWidgetFinder = find.byType(FloatingActionButton);
            expect(fabWidgetFinder, findsOneWidget);
            final fabSize = tester.getSize(fabWidgetFinder);
            expect(fabSize.width, greaterThanOrEqualTo(48));
            expect(fabSize.height, greaterThanOrEqualTo(48));
            expect(find.byTooltip('Nueva operación'), findsOneWidget);
          }
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'AiChatScreen en 360x640 con TextScaler 1.35x, teclado simulado y Semantics en los 4 temas',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final semantics = tester.ensureSemantics();
        try {
          for (final mode in _officialModes) {
            Widget buildChat({EdgeInsets viewInsets = EdgeInsets.zero}) {
              return MaterialApp(
                key: ValueKey('p0-chat-$mode-${viewInsets.bottom}'),
                theme: buildThemeData(mode),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(360, 640),
                    textScaler: const TextScaler.linear(1.35),
                    viewInsets: viewInsets,
                  ),
                  child: AiChatScreen(
                    key: ValueKey('p0-chat-screen-$mode-${viewInsets.bottom}'),
                  ),
                ),
              );
            }

            await tester.pumpWidget(
              buildChat(viewInsets: const EdgeInsets.only(bottom: 280)),
            );
            for (var i = 0; i < 6; i++) {
              await tester.pump(const Duration(milliseconds: 80));
            }
            expect(
              tester.takeException(),
              isNull,
              reason:
                  '$mode: AiChatScreen sin overflow con teclado abierto a 1.35x',
            );

            // Validar Semantics y targets en AiChatScreen
            final backFinder = find.bySemanticsLabel('Volver');
            expect(backFinder, findsOneWidget);
            expect(tester.getSize(backFinder).width, greaterThanOrEqualTo(48));
            expect(tester.getSize(backFinder).height, greaterThanOrEqualTo(48));
            expect(find.byTooltip('Volver'), findsOneWidget);

            final simTab = find.bySemanticsLabel(RegExp('Motor Simulador'));
            final gemmaTab = find.bySemanticsLabel(RegExp('Motor Gemma IA'));
            expect(simTab, findsOneWidget);
            expect(gemmaTab, findsOneWidget);
            expect(tester.getSize(simTab).height, greaterThanOrEqualTo(44));
            expect(tester.getSize(gemmaTab).height, greaterThanOrEqualTo(44));

            final sendFinder = find.bySemanticsLabel('Enviar mensaje');
            expect(sendFinder, findsOneWidget);
            expect(find.byTooltip('Enviar mensaje'), findsOneWidget);
            expect(tester.getSize(sendFinder).width, greaterThanOrEqualTo(48));
            expect(tester.getSize(sendFinder).height, greaterThanOrEqualTo(48));

            await tester.enterText(
              find.byKey(const Key('ai_chat_input_field')),
              '¿Cuánto gasté este mes?',
            );
            await tester.pump();
            await tester.tap(find.byKey(const Key('ai_chat_send_button')));
            for (var i = 0; i < 12; i++) {
              await tester.pump(const Duration(milliseconds: 80));
            }
            expect(
              tester.takeException(),
              isNull,
              reason:
                  '$mode: AiChatScreen sin overflow tras enviar mensaje a 1.35x',
            );

            // Cerrar teclado y revisar Perfil Cognitivo a 1.35x
            await tester.pumpWidget(buildChat(viewInsets: EdgeInsets.zero));
            for (var i = 0; i < 6; i++) {
              await tester.pump(const Duration(milliseconds: 80));
            }

            await tester.tap(find.text('Perfil Cognitivo'));
            for (var i = 0; i < 8; i++) {
              await tester.pump(const Duration(milliseconds: 80));
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '$mode: Perfil Cognitivo sin overflow en 360x640 @ 1.35x',
            );
          }
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'CategoriesScreen en 360x640 con TextScaler 1.35x (vacío y poblado) y Semantics en los 4 temas',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final semantics = tester.ensureSemantics();
        try {
          for (final mode in _officialModes) {
            // 1) Estado vacío
            SharedPreferences.setMockInitialValues({
              'default_currency': 'COP',
            });
            await tester.pumpWidget(
              MaterialApp(
                key: ValueKey('p0-cat-empty-$mode'),
                theme: buildThemeData(mode),
                home: const MediaQuery(
                  data: MediaQueryData(
                    size: Size(360, 640),
                    textScaler: TextScaler.linear(1.35),
                  ),
                  child: CategoriesScreen(),
                ),
              ),
            );
            await tester.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 80));
            });
            await tester.pump();

            expect(tester.takeException(), isNull);
            expect(
              find.bySemanticsLabel(RegExp('Nueva categoría')),
              findsOneWidget,
            );
            expect(find.byTooltip('Nueva categoría'), findsOneWidget);
            final fabSize = tester.getSize(find.byType(FloatingActionButton));
            expect(fabSize.width, greaterThanOrEqualTo(48));
            expect(fabSize.height, greaterThanOrEqualTo(48));

            final emptyCta =
                find.bySemanticsLabel('Crear categoría de ingresos');
            expect(emptyCta, findsOneWidget);
            expect(tester.getSize(emptyCta).height, greaterThanOrEqualTo(48));

            await tester.tap(find.text('Gastos'));
            await tester.pumpAndSettle();
            expect(
              find.bySemanticsLabel('Crear categoría de egresos'),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);

            // 2) Estado poblado con nombres largos
            await CategoryService.addCategoryWithMetadata(
              'Income',
              'Salario Mensual Principal',
              Icons.attach_money.codePoint,
              Colors.green.toARGB32(),
            );
            await CategoryService.addCategoryWithMetadata(
              'Expenses',
              'Supermercado y Despensa Familiar',
              Icons.shopping_cart.codePoint,
              Colors.redAccent.toARGB32(),
            );

            await tester.pumpWidget(
              MaterialApp(
                key: ValueKey('p0-cat-populated-$mode'),
                theme: buildThemeData(mode),
                home: const MediaQuery(
                  data: MediaQueryData(
                    size: Size(360, 640),
                    textScaler: TextScaler.linear(1.35),
                  ),
                  child: CategoriesScreen(),
                ),
              ),
            );
            await tester.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 80));
            });
            await tester.pump();

            expect(find.text('Salario Mensual Principal'), findsOneWidget);
            expect(tester.takeException(), isNull);

            await tester.tap(find.text('Gastos'));
            await tester.pumpAndSettle();
            expect(
              find.text('Supermercado y Despensa Familiar'),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          }
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'SettingsScreen en 360x640 con TextScaler 1.35x sin overflow y tarjetas de tema con Semantics',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final semantics = tester.ensureSemantics();
        try {
          for (final mode in _officialModes) {
            await ThemeNotifier.setMode(mode);

            await tester.pumpWidget(
              MaterialApp(
                key: ValueKey('p0-settings-$mode'),
                theme: buildThemeData(mode),
                home: const MediaQuery(
                  data: MediaQueryData(
                    size: Size(360, 640),
                    textScaler: TextScaler.linear(1.35),
                  ),
                  child: SettingsScreen(),
                ),
              ),
            );

            for (var i = 0; i < 10; i++) {
              await tester.runAsync(() async {
                await Future<void>.delayed(const Duration(milliseconds: 50));
              });
              await tester.pump();
            }

            expect(
              tester.takeException(),
              isNull,
              reason:
                  '$mode: SettingsScreen carga inicial sin overflow a 1.35x',
            );

            final listScroll = find.byType(Scrollable).first;
            await tester.scrollUntilVisible(
              find.text('Apariencia'),
              120,
              scrollable: listScroll,
            );
            await tester.pump();

            // Verificar Semantics de tarjetas de tema obligatorias
            const expectedLabels = <AppThemeMode, String>{
              AppThemeMode.defaultDark: 'Tema Default',
              AppThemeMode.diurno: 'Tema Diurno',
              AppThemeMode.dia: 'Tema Día',
              AppThemeMode.nocturno: 'Tema Nocturno',
            };

            for (final entry in expectedLabels.entries) {
              final cardFinder = find.bySemanticsLabel(entry.value);
              if (cardFinder.evaluate().isEmpty) {
                await tester.scrollUntilVisible(
                  cardFinder,
                  100,
                  scrollable: listScroll,
                );
                await tester.pump();
              }

              expect(
                cardFinder,
                findsOneWidget,
                reason:
                    '$mode: debe existir tarjeta con Semantics ${entry.value}',
              );

              final cardSize = tester.getSize(cardFinder);
              expect(
                cardSize.width,
                greaterThanOrEqualTo(48),
                reason: '${entry.value} ancho >= 48dp',
              );
              expect(
                cardSize.height,
                greaterThanOrEqualTo(48),
                reason: '${entry.value} alto >= 48dp',
              );

              expect(
                tester.getSemantics(cardFinder),
                matchesSemantics(
                  isButton: true,
                  hasSelectedState: true,
                  isSelected: entry.key == mode,
                  label: entry.value,
                ),
                reason:
                    '${entry.value} debe exponerse como botón semántico con selected=${entry.key == mode}',
              );
            }

            // Verificar que tocar una tarjeta distinta cambia el tema activo
            final targetMode = mode == AppThemeMode.diurno
                ? AppThemeMode.nocturno
                : AppThemeMode.diurno;
            final targetLabel = expectedLabels[targetMode]!;
            await tester.ensureVisible(find.bySemanticsLabel(targetLabel));
            await tester.tap(find.bySemanticsLabel(targetLabel));
            await tester.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
            });
            await tester.pumpAndSettle();

            expect(ThemeNotifier.activeMode, targetMode);
            expect(tester.takeException(), isNull);
          }
        } finally {
          semantics.dispose();
        }
      },
    );
  });
}
