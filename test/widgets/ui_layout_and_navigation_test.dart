import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finazaap/Screens/ai_chat_screen.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/services/ai_chat_service.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/widgets/custom_pill_bottom_nav_bar.dart';
import 'package:finazaap/widgets/floating_action_menu.dart';
import 'package:finazaap/widgets/moneo_header_bar.dart';

void main() {
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

    testWidgets(
      'Aplica BackdropFilter en Diurno y lo omite en Día, Nocturno y Default',
      (tester) async {
        await tester.pumpWidget(buildHarness(AppThemeMode.diurno));
        expect(find.byType(BackdropFilter), findsOneWidget);

        for (final mode in [
          AppThemeMode.dia,
          AppThemeMode.nocturno,
          AppThemeMode.defaultDark,
        ]) {
          await tester.pumpWidget(buildHarness(mode));
          expect(
            find.byType(BackdropFilter),
            findsNothing,
            reason: '$mode no debe aplicar Liquid Glass / BackdropFilter',
          );
        }
      },
    );

    testWidgets(
      'Desactiva BackdropFilter en Diurno ante preferencias de accesibilidad',
      (tester) async {
        await tester.pumpWidget(
          buildHarness(AppThemeMode.diurno, highContrast: true),
        );
        expect(find.byType(BackdropFilter), findsNothing);

        await tester.pumpWidget(
          buildHarness(AppThemeMode.diurno, accessibleNavigation: true),
        );
        expect(find.byType(BackdropFilter), findsNothing);

        await tester.pumpWidget(
          buildHarness(AppThemeMode.diurno, disableAnimations: true),
        );
        expect(find.byType(BackdropFilter), findsNothing);
      },
    );
  });

  group('CustomPillBottomNavBar & FloatingActionMenu - Clearance y SpringSimulation', () {
    Widget buildNavAndFabHarness({
      required AppThemeMode mode,
      required int selectedIndex,
      required ValueChanged<int> onItemSelected,
      double textScale = 1.35,
      EdgeInsets padding = const EdgeInsets.only(bottom: 16),
    }) {
      final isDiurno = mode == AppThemeMode.diurno;
      return MaterialApp(
        key: ValueKey('nav-fab-$mode'),
        theme: buildThemeData(mode),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 640),
            textScaler: TextScaler.linear(textScale),
            padding: padding,
            viewPadding: padding,
          ),
          child: Builder(
            builder: (rootContext) {
              final navHeight =
                  MoneoLayoutMetrics.bottomNavBarHeight(rootContext);
              final bottomInset = MediaQuery.viewInsetsOf(rootContext).bottom;
              final effectiveBottomClearance =
                  math.max(0.0, navHeight - bottomInset);

              return Scaffold(
                extendBody: isDiurno,
                body: Builder(
                  builder: (bodyContext) {
                    final mq = MediaQuery.of(bodyContext);
                    final bodyMediaQuery = isDiurno
                        ? mq.copyWith(
                            padding: mq.padding.copyWith(
                              bottom: math.max(
                                mq.padding.bottom,
                                effectiveBottomClearance,
                              ),
                            ),
                            viewPadding: mq.viewPadding.copyWith(
                              bottom: math.max(
                                mq.viewPadding.bottom,
                                effectiveBottomClearance,
                              ),
                            ),
                          )
                        : mq;

                    return MoneoNavBarScope(
                      navBarHeight: navHeight,
                      extendBody: isDiurno,
                      child: MediaQuery(
                        data: bodyMediaQuery,
                        child: Scaffold(
                          body: ListView(
                            padding: MoneoLayoutMetrics.scrollBottomPadding(
                              bodyContext,
                              hasFab: true,
                            ),
                            children: const [
                              SizedBox(height: 60, child: Text('Elemento final')),
                            ],
                          ),
                          floatingActionButton: const FloatingActionMenu(),
                          floatingActionButtonLocation:
                              FloatingActionButtonLocation.endFloat,
                        ),
                      ),
                    );
                  },
                ),
                bottomNavigationBar: CustomPillBottomNavBar(
                  selectedIndex: selectedIndex,
                  onItemSelected: onItemSelected,
                ),
              );
            },
          ),
        ),
      );
    }

    testWidgets(
      'El botón + no se solapa con la barra inferior y anima con SpringSimulation sin errores en 360x640 con TextScaler 1.35',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        for (final mode in [
          AppThemeMode.diurno,
          AppThemeMode.dia,
          AppThemeMode.nocturno,
          AppThemeMode.defaultDark,
        ]) {
          int currentTab = 0;

          await tester.pumpWidget(
            StatefulBuilder(
              builder: (context, setState) {
                return buildNavAndFabHarness(
                  mode: mode,
                  selectedIndex: currentTab,
                  onItemSelected: (idx) => setState(() => currentTab = idx),
                );
              },
            ),
          );
          await tester.pump();

          final fabRect = tester.getRect(find.byType(FloatingActionButton));
          final navRect = tester.getRect(find.byType(CustomPillBottomNavBar));
          final pillRect = tester.getRect(
            find.byKey(const Key('nav_active_pill_indicator')),
          );
          final barInnerRect = tester.getRect(
            find.descendant(
              of: find.byType(CustomPillBottomNavBar),
              matching: find.byType(LayoutBuilder),
            ),
          );

          expect(
            (pillRect.center.dy - barInnerRect.center.dy).abs(),
            lessThanOrEqualTo(1.0),
            reason: '$mode: la píldora activa debe quedar centrada verticalmente dentro de la barra',
          );

          expect(
            fabRect.overlaps(navRect),
            isFalse,
            reason: '$mode: FloatingActionButton no debe solaparse con CustomPillBottomNavBar',
          );
          expect(
            fabRect.bottom,
            lessThanOrEqualTo(navRect.top),
            reason: '$mode: el borde inferior del FAB debe quedar encima del borde superior de la barra',
          );

          await tester.tap(find.byIcon(Icons.insert_chart_outlined_rounded));
          await tester.pump(const Duration(milliseconds: 60));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await tester.tap(find.byIcon(Icons.settings_outlined));
          await tester.pump(const Duration(milliseconds: 60));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
  });

  group('AiChatScreen - Conversación Moderna, Perfil Cognitivo y Aislamiento Glass', () {
    late Directory tempDir;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      GoogleFonts.config.allowRuntimeFetching = false;
      tempDir = await Directory.systemTemp.createTemp('moneo_ui_layout_chat_');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(AdddataAdapter());
      }
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({'ai_use_local_simulator': true});
      final box = await Hive.openBox<Add_data>('data');
      await box.add(
        Add_data(
          'Expenses',
          '250000',
          DateTime.now(),
          'CompraSupermercadoLarga',
          'SupermercadoOrgánicoMensual',
          'Efectivo',
        ),
      );
      await AiChatService().updateLearnedPatterns();
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
      double textScale = 1.3,
    }) {
      return MaterialApp(
        key: ValueKey('chat-$mode-${viewInsets.bottom}-$textScale'),
        theme: buildThemeData(mode),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            viewInsets: viewInsets,
            textScaler: TextScaler.linear(textScale),
          ),
          child: AiChatScreen(
            key: ValueKey('ai-chat-$mode-${viewInsets.bottom}-$textScale'),
          ),
        ),
      );
    }

    testWidgets(
      'Renderiza Chat y Perfil Cognitivo sin overflow ni BackdropFilter en burbujas en los 4 temas (360x640, teclado abierto, TextScaler 1.3)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        for (final mode in [
          AppThemeMode.diurno,
          AppThemeMode.dia,
          AppThemeMode.nocturno,
          AppThemeMode.defaultDark,
        ]) {
          await tester.pumpWidget(
            buildChatApp(
              mode,
              viewInsets: const EdgeInsets.only(bottom: 280),
            ),
          );
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 80));
          }

          if (mode == AppThemeMode.diurno) {
            expect(find.byType(BackdropFilter), findsAtLeastNWidgets(1));
          } else {
            expect(
              find.byType(BackdropFilter),
              findsNothing,
              reason: '$mode no debe renderizar BackdropFilter en AiChatScreen',
            );
          }

          await tester.enterText(
            find.byKey(const Key('ai_chat_input_field')),
            'Hola',
          );
          await tester.pump();
          await tester.tap(find.byKey(const Key('ai_chat_send_button')));
          for (var i = 0; i < 12; i++) {
            await tester.pump(const Duration(milliseconds: 80));
          }

          expect(
            find.descendant(
              of: find.byType(ListView),
              matching: find.byType(BackdropFilter),
            ),
            findsNothing,
            reason: '$mode: las burbujas del ListView nunca deben llevar BackdropFilter',
          );

          // Cerrar teclado simulado antes de evaluar toda la altura de Perfil Cognitivo
          await tester.pumpWidget(
            buildChatApp(mode, viewInsets: EdgeInsets.zero),
          );
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 80));
          }

          await tester.tap(find.text('Perfil Cognitivo'));
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 80));
          }

          final profileScroll = find
              .ancestor(
                of: find.text('Tasa de Ahorro'),
                matching: find.byType(Scrollable),
              )
              .first;

          if (find.text('SupermercadoOrgánicoMensual').evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              find.text('SupermercadoOrgánicoMensual'),
              150,
              scrollable: profileScroll,
            );
          }
          expect(
            find.text('SupermercadoOrgánicoMensual'),
            findsWidgets,
            reason: '$mode: Perfil Cognitivo no debe truncar nombres largos de categoría',
          );

          if (find.text('CompraSupermercadoLarga').evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              find.text('CompraSupermercadoLarga'),
              150,
              scrollable: profileScroll,
            );
          }
          expect(
            find.text('CompraSupermercadoLarga'),
            findsWidgets,
            reason: '$mode: Perfil Cognitivo no debe truncar nombres largos de transacción',
          );
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'Las burbujas usan ancho orgánico según contenido y crecen en mensajes largos',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildChatApp(AppThemeMode.diurno, textScale: 1.0));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        const shortMsg = 'Hola';
        await tester.enterText(
          find.byKey(const Key('ai_chat_input_field')),
          shortMsg,
        );
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
        expect(shortWidth, lessThan(140.0));

        const longMsg =
            'Quiero revisar mi balance mensual completo incluyendo ingresos fijos, gastos variables de alimentación, transporte y cuotas pendientes de tarjeta.';
        await tester.enterText(
          find.byKey(const Key('ai_chat_input_field')),
          longMsg,
        );
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
      },
    );
  });

  group('MoneoHeaderBar & MoneoSegmentedControl - Jerarquía y Responsividad', () {
    testWidgets(
      'Las 3 variantes de MoneoHeaderBar y MoneoSegmentedControl renderizan sin overflow en 360x640 y TextScaler 1.35 en los 4 temas',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        for (final mode in [
          AppThemeMode.diurno,
          AppThemeMode.dia,
          AppThemeMode.nocturno,
          AppThemeMode.defaultDark,
        ]) {
          bool isMonthly = true;

          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey('headers-$mode'),
              theme: buildThemeData(mode),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(360, 640),
                  textScaler: TextScaler.linear(1.35),
                ),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return Scaffold(
                      appBar: MoneoHeaderBar.subScreen(
                        title: 'Proyección Anual Detallada',
                        subtitle: 'Resumen de obligaciones y liquidez',
                        badge: const Chip(label: Text('3')),
                      ).asPreferredSize(context),
                      body: Column(
                        children: [
                          MoneoHeaderBar.primaryTab(
                            title: 'Informes',
                            subtitle: 'Noviembre 2026',
                            statusDotColor: context.appTheme.accent,
                            bottomChild: MoneoSegmentedControl<bool>(
                              options: const [
                                MoneoSegmentOption(value: true, label: 'Mensual'),
                                MoneoSegmentOption(value: false, label: 'Anual'),
                              ],
                              selectedValue: isMonthly,
                              onChanged: (v) => setState(() => isMonthly = v),
                            ),
                          ),
                          MoneoHeaderBar.form(
                            title: 'Nuevo Movimiento Financiero',
                            subtitle: 'Sin cajas pesadas',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pump();

          await tester.tap(find.text('Anual'));
          await tester.pump(const Duration(milliseconds: 60));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
