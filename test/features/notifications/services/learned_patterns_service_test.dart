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
    testBox = await Hive.openBox<dynamic>('test_learned_patterns_${DateTime.now().microsecondsSinceEpoch}');
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

    test('Elimina sufijos de sucursal y puntuación en "Farmacia Cruz Verde Suc. 5"', () {
      expect(
        LearnedPatternsService.normalizeMerchant('Farmacia Cruz Verde Suc. 5'),
        equals('farmacia cruz verde'),
      );
    });

    test('Elimina símbolos especiales y números finales en "Uber *Trip 12"', () {
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

  group('LearnedPatternsService - Registro de confirmaciones y correcciones', () {
    test('recordConfirmation crea un nuevo patrón con confirmations = 1', () async {
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

    test('Segunda confirmación incrementa confirmations y actualiza lastUsedAt', () async {
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

    test('recordCorrection reinicia confirmations a 1 y registra lastCorrectedAt', () async {
      final t1 = DateTime(2026, 11, 1, 9, 0);
      final tCorrect = DateTime(2026, 11, 13, 16, 0);

      // Confirmar dos veces una categoría equivocada
      await service.recordConfirmation(merchant: 'Uber', category: 'Otros', at: t1);
      await service.recordConfirmation(merchant: 'Uber', category: 'Otros', at: t1);

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

    test('findPattern resuelve usando variaciones de mayúsculas y acentos', () async {
      await service.recordConfirmation(
        merchant: 'cafetería juan valdez',
        category: 'Alimentación',
      );

      final found = await service.findPattern('CAFETERIA JUAN VALDEZ 001');
      expect(found, isNotNull);
      expect(found!.category, equals('Alimentación'));
    });

    test('findPattern retorna null cuando el comercio no ha sido registrado', () async {
      final result = await service.findPattern('Comercio Totalmente Desconocido');
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

    test('Persistencia usa Map/JSON en Hive sin generar dependencias de *.g.dart', () async {
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
}
