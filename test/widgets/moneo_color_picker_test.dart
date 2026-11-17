import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/widgets/moneo_color_picker.dart';

void main() {
  const fourThemes = [
    AppThemeMode.defaultDark,
    AppThemeMode.diurno,
    AppThemeMode.dia,
    AppThemeMode.nocturno,
  ];

  Widget wrapInViewport({
    required AppThemeMode mode,
    required Widget child,
    double textScale = 1.0,
    Size viewport = const Size(360, 640),
  }) {
    return MaterialApp(
      key: ValueKey('picker-$mode-$textScale'),
      theme: buildThemeData(mode),
      home: MediaQuery(
        data: MediaQueryData(
          size: viewport,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('kMoneoWheelColors y kMoneoQuickColors', () {
    test('contiene exactamente 48 colores únicos sin blanco ni negro puros', () {
      expect(kMoneoWheelColors.length, 48);
      final uniqueArgb = kMoneoWheelColors.map((c) => c.toARGB32()).toSet();
      expect(uniqueArgb.length, 48);

      for (final color in kMoneoWheelColors) {
        expect(color.toARGB32(), isNot(0xFFFFFFFF));
        expect(color.toARGB32(), isNot(0xFF000000));
      }
    });

    test('kMoneoQuickColors contiene 8 favoritos únicos dentro de la rueda', () {
      expect(kMoneoQuickColors.length, 8);
      final quickSet = kMoneoQuickColors.map((c) => c.toARGB32()).toSet();
      final wheelSet = kMoneoWheelColors.map((c) => c.toARGB32()).toSet();
      expect(quickSet.length, 8);
      expect(wheelSet.containsAll(quickSet), isTrue);
    });

    test('hitTestWheelColorIndex mapea los 4 anillos x 12 sectores con precisión', () {
      const size = Size(200, 200);
      const center = Offset(100, 100);
      const outerRadius = 96.0; // min(200, 200)/2 - 4
      const innerRadius = outerRadius * 0.24;
      const ringStep = (outerRadius - innerRadius) / 4.0;

      // Fuera de la rueda o en el núcleo central debe ser null
      expect(MoneoColorPickerPanel.hitTestWheelColorIndex(center, size), isNull);
      expect(
        MoneoColorPickerPanel.hitTestWheelColorIndex(const Offset(1, 1), size),
        isNull,
      );

      for (var ring = 0; ring < 4; ring++) {
        final r = innerRadius + (ring + 0.5) * ringStep;
        for (var sector = 0; sector < 12; sector++) {
          final angle = -math.pi / 2 + (sector + 0.5) * (2 * math.pi / 12);
          final point = Offset(
            center.dx + r * math.cos(angle),
            center.dy + r * math.sin(angle),
          );
          expect(
            MoneoColorPickerPanel.hitTestWheelColorIndex(point, size),
            ring * 12 + sector,
            reason: 'Fallo en anillo $ring, sector $sector',
          );
        }
      }
    });
  });

  group('MoneoColorPickerTrigger', () {
    testWidgets('mantiene altura compacta (>=48 y <=64) y Semantics correctos', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();
      var tapped = false;
      var expanded = false;

      await tester.pumpWidget(
        wrapInViewport(
          mode: AppThemeMode.defaultDark,
          child: StatefulBuilder(
            builder: (context, setState) {
              return MoneoColorPickerTrigger(
                selectedColor: kMoneoWheelColors[12],
                isExpanded: expanded,
                onTap: () {
                  tapped = true;
                  setState(() => expanded = !expanded);
                },
              );
            },
          ),
        ),
      );

      final triggerFinder = find.byType(MoneoColorPickerTrigger);
      final triggerBox = tester.getSize(triggerFinder);
      expect(triggerBox.height, greaterThanOrEqualTo(48.0));
      expect(triggerBox.height, lessThanOrEqualTo(64.0));

      final collapsedSemantics = tester.getSemantics(triggerFinder);
      expect(collapsedSemantics.flagsCollection.isButton, isTrue);
      expect(
        collapsedSemantics.flagsCollection.isExpanded.toBoolOrNull(),
        isFalse,
      );
      expect(collapsedSemantics.label, contains('Color, seleccionado'));

      await tester.tap(triggerFinder);
      await tester.pump();
      expect(tapped, isTrue);

      final expandedSemantics = tester.getSemantics(triggerFinder);
      expect(
        expandedSemantics.flagsCollection.isExpanded.toBoolOrNull(),
        isTrue,
      );

      semanticsHandle.dispose();
    });

    testWidgets('sin overflow en 360x640 @ 1.35x en los 4 temas (lado a lado)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final mode in fourThemes) {
        await tester.pumpWidget(
          wrapInViewport(
            mode: mode,
            textScale: 1.35,
            child: Row(
              children: [
                Expanded(
                  child: MoneoColorPickerTrigger(
                    selectedColor: kMoneoWheelColors[14],
                    isExpanded: false,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MoneoColorPickerTrigger(
                    selectedColor: kMoneoWheelColors[20],
                    isExpanded: true,
                    label: 'Color cuenta',
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        );

        expect(
          tester.takeException(),
          isNull,
          reason: 'Overflow detectado en MoneoColorPickerTrigger para $mode',
        );
      }
    });
  });

  group('MoneoColorPickerPanel', () {
    testWidgets(
      'renderiza rueda, selecciona sector por toque, selecciona favorito rápido y cambia a Paleta',
      (tester) async {
        final semanticsHandle = tester.ensureSemantics();
        Color selected = kMoneoWheelColors[0];

        await tester.pumpWidget(
          wrapInViewport(
            mode: AppThemeMode.diurno,
            child: StatefulBuilder(
              builder: (context, setState) {
                return MoneoColorPickerPanel(
                  selectedColor: selected,
                  onColorSelected: (c) => setState(() => selected = c),
                );
              },
            ),
          ),
        );

        // Inicia en modo Rueda
        final wheelFinder = find.byKey(const Key('moneo_color_wheel'));
        expect(wheelFinder, findsOneWidget);
        expect(
          find.descendant(of: wheelFinder, matching: find.byType(CustomPaint)),
          findsOneWidget,
        );

        // Tocar sector 3 del anillo 1 (Ámbar vibrante: índice 15)
        final wheelRect = tester.getRect(wheelFinder);
        final outerRadius = math.min(wheelRect.width, wheelRect.height) / 2 - 4.0;
        final innerRadius = outerRadius * 0.24;
        final ringStep = (outerRadius - innerRadius) / 4.0;
        final targetRadius = innerRadius + 1.5 * ringStep;
        const targetAngle = -math.pi / 2 + 3.5 * (2 * math.pi / 12);
        final tapOffset = Offset(
          wheelRect.center.dx + targetRadius * math.cos(targetAngle),
          wheelRect.center.dy + targetRadius * math.sin(targetAngle),
        );

        await tester.tapAt(tapOffset);
        await tester.pump();
        expect(selected.toARGB32(), kMoneoWheelColors[15].toARGB32());

        // Tocar favorito rápido #3 (Esmeralda vibrante)
        final quickFinder = find.byKey(const Key('moneo_quick_color_3'));
        await tester.tap(quickFinder);
        await tester.pump();
        expect(selected.toARGB32(), kMoneoQuickColors[3].toARGB32());

        // Cambiar a Paleta y verificar los 48 swatches accesibles
        await tester.tap(find.text('Paleta'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('moneo_color_wheel')), findsNothing);
        expect(find.byKey(const Key('moneo_palette_color_0')), findsOneWidget);
        expect(find.byKey(const Key('moneo_palette_color_47')), findsOneWidget);

        final swatchSemantics = tester.getSemantics(
          find.byKey(const Key('moneo_palette_color_42')),
        );
        expect(swatchSemantics.flagsCollection.isButton, isTrue);

        await tester.tap(find.byKey(const Key('moneo_palette_color_42')));
        await tester.pump();
        expect(selected.toARGB32(), kMoneoWheelColors[42].toARGB32());

        // Regresar a Rueda
        await tester.tap(find.text('Rueda'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('moneo_color_wheel')), findsOneWidget);

        semanticsHandle.dispose();
      },
    );

    testWidgets(
      'cero overflow en Rueda y Paleta a 360x640 @ 1.35x en los 4 temas',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        for (final mode in fourThemes) {
          Color current = kMoneoWheelColors[18];

          await tester.pumpWidget(
            wrapInViewport(
              mode: mode,
              textScale: 1.35,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MoneoColorPickerTrigger(
                        selectedColor: current,
                        isExpanded: true,
                        onTap: () {},
                      ),
                      const SizedBox(height: 10),
                      MoneoColorPickerPanel(
                        selectedColor: current,
                        onColorSelected: (c) => setState(() => current = c),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: 'Overflow en modo Rueda para $mode a 360x640 @ 1.35x',
          );

          await tester.tap(find.text('Paleta'));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Overflow en modo Paleta para $mode a 360x640 @ 1.35x',
          );
        }
      },
    );
  });
}
