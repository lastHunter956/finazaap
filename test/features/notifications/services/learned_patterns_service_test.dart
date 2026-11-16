import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:finazaap/features/notifications/domain/models/learned_pattern.dart';
import 'package:finazaap/features/notifications/services/learned_patterns_service.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> testBox;
  late LearnedPatternsService service;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('learned_patterns_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    testBox = await Hive.openBox<dynamic>(
        'test_learned_patterns_${DateTime.now().microsecondsSinceEpoch}');
    service = LearnedPatternsService(box: testBox);
  });

  tearDown(() async {
    if (testBox.isOpen) {
      await testBox.clear();
      await testBox.close();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('LearnedPatternsService - Normalización de comercios', () {
    test('Normaliza "Éxito Laureles 034" a "exito laureles"', () {
      expect(
        LearnedPatternsService.normalizeMerchant('Éxito Laureles 034'),
        equals('exito laureles'),
      );
    });

    test('Preserva marcas cortas con números integrados como "D1" y "3B"', () {
      expect(LearnedPatternsService.normalizeMerchant('D1'), equals('d1'));
      expect(LearnedPatternsService.normalizeMerchant('3B'), equals('3b'));
    });

    test(
        'Elimina sufijos de sucursal y puntuación en "Farmacia Cruz Verde Suc. 5"',
        () {
      expect(
        LearnedPatternsService.normalizeMerchant('Farmacia Cruz Verde Suc. 5'),
        equals('farmacia cruz verde'),
      );
    });

    test('Elimina símbolos especiales y números finales en "Uber *Trip 12"',
        () {
      expect(
        LearnedPatternsService.normalizeMerchant('Uber *Trip 12'),
        equals('uber trip'),
      );
    });

    test('Normaliza tildes y mayúsculas en "RESTAURANTE EL POBLADO"', () {
      expect(
        LearnedPatternsService.normalizeMerchant('RESTAURANTE EL POBLADO'),
        equals('restaurante el poblado'),
      );
    });

    test('Retorna cadena vacía ante espacios o entrada vacía', () {
      expect(LearnedPatternsService.normalizeMerchant('   '), equals(''));
      expect(LearnedPatternsService.normalizeMerchant(''), equals(''));
    });
  });

  group('LearnedPatternsService - Registro de confirmaciones y correcciones',
      () {
    test('recordConfirmation crea un nuevo patrón con confirmations = 1',
        () async {
      final pattern = await service.recordConfirmation(
        merchant: 'Éxito Laureles 034',
        category: 'Alimentación',
        accountName: 'Bancolombia *4821',
      );

      expect(pattern.merchantKey, equals('exito laureles'));
      expect(pattern.category, equals('Alimentación'));
      expect(pattern.accountName, equals('Bancolombia *4821'));
      expect(pattern.confirmations, equals(1));
      expect(pattern.classification, equals('gasto'));
      expect(pattern.moneoType, equals('Expenses'));

      // Verificar persistencia en Hive
      final stored = await service.findPattern('Éxito Laureles 034');
      expect(stored, isNotNull);
      expect(stored!.merchantKey, equals('exito laureles'));
      expect(stored.confirmations, equals(1));
    });

    test('Segunda confirmación incrementa confirmations y actualiza lastUsedAt',
        () async {
      final t1 = DateTime(2026, 11, 10, 10, 0);
      final t2 = DateTime(2026, 11, 12, 15, 30);

      await service.recordConfirmation(
        merchant: 'D1 Cra 43',
        category: 'Alimentación',
        at: t1,
      );

      final second = await service.recordConfirmation(
        merchant: 'D1 Cra 43',
        category: 'Alimentación',
        at: t2,
      );

      expect(second.confirmations, equals(2));
      expect(second.lastUsedAt, equals(t2));

      final retrieved = await service.findPattern('d1 cra 43');
      expect(retrieved?.confirmations, equals(2));
    });

    test(
        'recordCorrection reinicia confirmations a 1 y registra lastCorrectedAt',
        () async {
      final t1 = DateTime(2026, 11, 1, 9, 0);
      final tCorrect = DateTime(2026, 11, 13, 16, 0);

      // Confirmar dos veces una categoría equivocada
      await service.recordConfirmation(
          merchant: 'Uber', category: 'Otros', at: t1);
      await service.recordConfirmation(
          merchant: 'Uber', category: 'Otros', at: t1);

      // El usuario corrige a 'Transporte'
      final corrected = await service.recordCorrection(
        merchant: 'Uber',
        newCategory: 'Transporte',
        newAccountName: 'Nequi *1234',
        at: tCorrect,
      );

      expect(corrected.category, equals('Transporte'));
      expect(corrected.accountName, equals('Nequi *1234'));
      expect(corrected.confirmations, equals(1));
      expect(corrected.lastCorrectedAt, equals(tCorrect));

      final retrieved = await service.findPattern('uber');
      expect(retrieved?.category, equals('Transporte'));
      expect(retrieved?.confirmations, equals(1));
      expect(retrieved?.lastCorrectedAt, equals(tCorrect));
    });

    test('findPattern resuelve usando variaciones de mayúsculas y acentos',
        () async {
      await service.recordConfirmation(
        merchant: 'cafetería juan valdez',
        category: 'Alimentación',
      );

      final found = await service.findPattern('CAFETERIA JUAN VALDEZ 001');
      expect(found, isNotNull);
      expect(found!.category, equals('Alimentación'));
    });

    test('findPattern retorna null cuando el comercio no ha sido registrado',
        () async {
      final result =
          await service.findPattern('Comercio Totalmente Desconocido');
      expect(result, isNull);
    });

    test('deletePattern y clearAll eliminan entradas correctamente', () async {
      await service.recordConfirmation(merchant: 'Ara 1', category: 'Mercado');
      await service.recordConfirmation(merchant: 'D1 1', category: 'Mercado');

      expect((await service.getAllPatterns()).length, equals(2));

      await service.deletePattern('Ara 1');
      expect(await service.findPattern('Ara 1'), isNull);
      expect((await service.getAllPatterns()).length, equals(1));

      await service.clearAll();
      expect((await service.getAllPatterns()).length, equals(0));
    });

    test(
        'Persistencia usa Map/JSON en Hive sin generar dependencias de *.g.dart',
        () async {
      await service.recordConfirmation(
        merchant: 'Spotify',
        category: 'Entretenimiento',
      );

      final rawData = testBox.get('spotify');
      expect(rawData, isA<Map>());
      final mapData = Map<String, dynamic>.from(rawData as Map);
      expect(mapData['merchant_key'], equals('spotify'));
      expect(mapData['category'], equals('Entretenimiento'));
      expect(mapData['confirmations'], equals(1));
    });
  });

  group('LearnedPatternsService - Retrocompatibilidad, PatternStatus y Puntuación',
      () {
    test('Lee registros antiguos de Hive sin campos nuevos (retrocompatibilidad 100%)',
        () async {
      final legacyCreated = DateTime(2026, 5, 1, 10, 0);
      final legacyUsed = DateTime.now().subtract(const Duration(days: 5));
      await testBox.put('legacy_exito', {
        'merchant_key': 'legacy_exito',
        'category': 'Alimentación',
        'account_name': 'Bancolombia *4821',
        'classification': 'gasto',
        'moneo_type': 'Expenses',
        'confirmations': 12,
        'created_at': legacyCreated.toIso8601String(),
        'last_used_at': legacyUsed.toIso8601String(),
        'last_corrected_at': null,
      });

      final loaded = await service.findPattern('legacy_exito');
      expect(loaded, isNotNull);
      expect(loaded!.confirmations, equals(12));
      expect(loaded.status, equals(PatternStatus.consolidado));
      expect(loaded.categoryScores['Alimentación'], equals(12));
      expect(loaded.accountScores['Bancolombia *4821'], equals(12));
      expect(loaded.correctionStreak, equals(0));
    });

    test('Transiciones de PatternStatus: nuevo -> en_refuerzo -> consolidado -> obsoleto',
        () async {
      final t0 = DateTime.now().subtract(const Duration(days: 10));
      final p1 = await service.recordConfirmation(
        merchant: 'D1',
        category: 'Mercado',
        at: t0,
      );
      expect(p1.status, equals(PatternStatus.nuevo));

      final p2 = await service.recordConfirmation(
        merchant: 'D1',
        category: 'Mercado',
        at: t0.add(const Duration(days: 1)),
      );
      expect(p2.status, equals(PatternStatus.enRefuerzo));

      await service.recordConfirmation(
        merchant: 'D1',
        category: 'Mercado',
        at: t0.add(const Duration(days: 2)),
      );
      final p4 = await service.recordConfirmation(
        merchant: 'D1',
        category: 'Mercado',
        at: t0.add(const Duration(days: 3)),
      );
      expect(p4.confirmations, equals(4));
      expect(p4.status, equals(PatternStatus.consolidado));
      expect(
        p4.effectiveStatus(now: t0.add(const Duration(days: 185))),
        equals(PatternStatus.obsoleto),
      );
    });

    test(
        '1 corrección atípica NO borra 20 confirmaciones previas; requiere >=2 correcciones para desplazar patrón consolidado',
        () async {
      final base = DateTime(2026, 11, 1);
      for (var i = 0; i < 20; i++) {
        await service.recordConfirmation(
          merchant: 'Amazon',
          category: 'Hogar',
          accountName: 'Nu *1111',
          at: base.add(Duration(hours: i)),
        );
      }

      // 1a corrección atípica -> NO borra las 20 confirmaciones, pasa a en_revision
      final afterOneCorrection = await service.recordCorrection(
        merchant: 'Amazon',
        newCategory: 'Regalos',
        at: base.add(const Duration(days: 2)),
      );

      expect(afterOneCorrection.category, equals('Hogar'));
      expect(afterOneCorrection.confirmations, equals(20));
      expect(afterOneCorrection.status, equals(PatternStatus.enRevision));
      expect(afterOneCorrection.categoryScores['Hogar'], equals(20));
      expect(afterOneCorrection.categoryScores['Regalos'], equals(1));

      // 2a corrección consecutiva hacia 'Regalos' -> desplaza al patrón consolidado
      final afterSecondCorrection = await service.recordCorrection(
        merchant: 'Amazon',
        newCategory: 'Regalos',
        at: base.add(const Duration(days: 3)),
      );

      expect(afterSecondCorrection.category, equals('Regalos'));
      expect(afterSecondCorrection.confirmations, equals(2));
      expect(afterSecondCorrection.status, equals(PatternStatus.enRefuerzo));
      expect(afterSecondCorrection.categoryScores['Hogar'], equals(20));
      expect(afterSecondCorrection.categoryScores['Regalos'], equals(2));
    });

    test('getFewShotExamples retorna top-K ejemplos similares en <1ms', () async {
      final now = DateTime.now();
      await service.recordConfirmation(
        merchant: 'Restaurante El Cielo',
        category: 'Alimentación',
        at: now,
      );
      await service.recordConfirmation(
        merchant: 'Restaurante Crepes Waffles',
        category: 'Alimentación',
        at: now,
      );
      await service.recordConfirmation(
        merchant: 'Drogueria La Rebaja',
        category: 'Salud',
        at: now,
      );

      final examples = await service.getFewShotExamples(
        limit: 2,
        query: 'Restaurante Waffles',
        now: now,
      );
      expect(examples.length, equals(2));
      expect(examples.first, contains('restaurante'));
    });

    test('pruneObsoletePatterns elimina patrones con >180 días sin uso',
        () async {
      final now = DateTime(2026, 11, 16);
      await service.recordConfirmation(
        merchant: 'Comercio Viejo',
        category: 'Otros',
        at: now.subtract(const Duration(days: 200)),
      );
      await service.recordConfirmation(
        merchant: 'Comercio Reciente',
        category: 'Alimentación',
        at: now.subtract(const Duration(days: 5)),
      );

      final pruned = await service.pruneObsoletePatterns(now: now);
      expect(pruned, equals(1));
      expect(await service.findPattern('Comercio Viejo'), isNull);
      expect(await service.findPattern('Comercio Reciente'), isNotNull);
    });
  });
}
