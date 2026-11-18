import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/data/monthly_summary_cache.dart';
import 'package:finazaap/features/notifications/domain/models/learned_pattern.dart';
import 'package:finazaap/features/notifications/domain/models/notification_parse_result.dart';
import 'package:finazaap/features/notifications/services/gemma_classifier_adapter.dart';
import 'package:finazaap/features/notifications/services/learned_patterns_service.dart';
import 'package:finazaap/features/notifications/services/text_similarity_index.dart';
import 'package:finazaap/features/notifications/services/transaction_classifier.dart';

class _MockGemmaClient implements GemmaInferenceClient {
  bool isLoaded = true;
  String? responseToReturn;
  int callCount = 0;

  @override
  Future<bool> isModelLoaded() async => isLoaded;

  @override
  Future<String?> generateResponse(String prompt) async {
    callCount++;
    return responseToReturn;
  }
}

/// Wrapper ligero sobre Hive [Box] para contar lecturas reales de disco (`get`)
/// y comprobar que el Mini-RAG solo lee el ganador tras indexar cabeceras.
class _CountingBox implements Box<dynamic> {
  final Box<dynamic> _inner;
  int getCount = 0;
  final List<dynamic> readKeys = [];

  _CountingBox(this._inner);

  void resetCounters() {
    getCount = 0;
    readKeys.clear();
  }

  @override
  dynamic get(key, {defaultValue}) {
    getCount++;
    readKeys.add(key);
    return _inner.get(key, defaultValue: defaultValue);
  }

  @override
  Iterable<dynamic> get keys => _inner.keys;

  @override
  int get length => _inner.length;

  @override
  bool get isOpen => _inner.isOpen;

  @override
  Future<void> put(key, value) => _inner.put(key, value);

  @override
  Future<void> delete(key) => _inner.delete(key);

  @override
  Future<int> clear() => _inner.clear();

  @override
  Future<void> compact() => _inner.compact();

  @override
  Future<void> close() => _inner.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory tempDir;
  late Box<dynamic> rawBox;
  late _CountingBox countingBox;
  late LearnedPatternsService service;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('learned_patterns_rag_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
  });

  setUp(() async {
    rawBox = await Hive.openBox<dynamic>(
      'rag_patterns_${DateTime.now().microsecondsSinceEpoch}',
    );
    countingBox = _CountingBox(rawBox);
    service = LearnedPatternsService(box: countingBox);
  });

  tearDown(() async {
    if (Hive.isBoxOpen('data')) {
      final dataBox = Hive.box<Add_data>('data');
      await dataBox.clear();
      await dataBox.close();
      MonthlySummaryCache.instance.invalidate();
    }
    if (rawBox.isOpen) {
      await rawBox.clear();
      await rawBox.close();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('LearnedPattern - aliases, knownPackages y retrocompatibilidad', () {
    test('Deserializa JSON legado sin aliases ni known_packages', () {
      final now = DateTime(2026, 11, 10);
      final legacy = LearnedPattern.fromJson({
        'merchant_key': 'exito laureles',
        'category': 'Alimentación',
        'confirmations': 5,
        'created_at': now.toIso8601String(),
        'last_used_at': now.toIso8601String(),
      });

      expect(legacy.aliases, isEmpty);
      expect(legacy.knownPackages, isEmpty);
      expect(legacy.status, equals(PatternStatus.consolidado));
    });

    test('Preserva aliases y knownPackages en toJson, fromJson, copyWith y ciclos',
        () {
      final t0 = DateTime(2026, 11, 1);
      final base = LearnedPattern(
        merchantKey: 'exito laureles',
        category: 'Alimentación',
        accountName: 'Bancolombia',
        confirmations: 4,
        createdAt: t0,
        lastUsedAt: t0,
        aliases: ['Almacenes Exito', 'almacenes exito', '  Exito Express  '],
        knownPackages: ['com.bancolombia.personas', '  '],
      );

      expect(base.aliases, equals(['Almacenes Exito', 'Exito Express']));
      expect(base.knownPackages, equals(['com.bancolombia.personas']));

      final roundTrip = LearnedPattern.fromJson(base.toJson());
      expect(roundTrip, equals(base));

      final incremented = base.incrementConfirmation(
        at: t0.add(const Duration(days: 1)),
        alias: 'Exito Colombia',
        packageName: 'com.nequi.MobileApp',
      );
      expect(
        incremented.aliases,
        equals(['Almacenes Exito', 'Exito Express', 'Exito Colombia']),
      );
      expect(
        incremented.knownPackages,
        equals(['com.bancolombia.personas', 'com.nequi.MobileApp']),
      );

      // 1a corrección atípica sobre consolidado -> en_revision preservando aliases/packages
      final inRevision = incremented.applyCorrection(
        newCategory: 'Hogar',
        at: t0.add(const Duration(days: 2)),
        alias: 'Exito Hogar',
      );
      expect(inRevision.status, equals(PatternStatus.enRevision));
      expect(inRevision.aliases, contains('Exito Hogar'));
      expect(inRevision.knownPackages, contains('com.bancolombia.personas'));

      final copied = inRevision.copyWith(aliases: ['Solo Uno']);
      expect(copied.aliases, equals(['Solo Uno']));
      expect(copied.knownPackages, equals(inRevision.knownPackages));
    });
  });

  group('CompactSimilarityIndex - ecuación híbrida y posting lists', () {
    test('Calcula Score híbrido usando merchantKey, aliases, category, package y confirmations',
        () {
      final index = CompactSimilarityIndex();
      index.upsert(const CompactSimilarityEntry(
        key: 'exito laureles',
        aliases: ['almacenes exito', 'exito envigado'],
        category: 'Alimentación',
        knownPackages: ['com.bancolombia.personas'],
        confirmations: 5,
      ));
      index.upsert(const CompactSimilarityEntry(
        key: 'farmacia pasteur',
        aliases: ['drogueria pasteur'],
        category: 'Salud',
        knownPackages: ['com.nu.production'],
        confirmations: 4,
      ));

      final hitsSamePkg = index.search(
        'almacenes exito',
        packageName: 'com.bancolombia.personas',
        minScore: 0.88,
      );
      expect(hitsSamePkg, isNotEmpty);
      expect(hitsSamePkg.first.key, equals('exito laureles'));
      expect(hitsSamePkg.first.bm25, equals(1.0));
      expect(hitsSamePkg.first.jaccard3Gram, equals(1.0));
      expect(hitsSamePkg.first.pkgMatch, equals(1.0));
      expect(hitsSamePkg.first.confBoost, equals(1.0));
      expect(hitsSamePkg.first.score, closeTo(1.0, 1e-6));

      // Paquete distinto penaliza PkgMatch (0.0) evitando auto-resolución ciega >= 0.88
      final hitsWrongPkg = index.search(
        'almacenes exito',
        packageName: 'com.otro.banco',
        minScore: 0.88,
      );
      expect(hitsWrongPkg, isEmpty);

      final hitsWrongPkgUnfiltered = index.search(
        'almacenes exito',
        packageName: 'com.otro.banco',
        minScore: 0.0,
      );
      expect(hitsWrongPkgUnfiltered.first.pkgMatch, equals(0.0));
      expect(hitsWrongPkgUnfiltered.first.score, closeTo(0.85, 1e-6));
    });

    test('upsert y remove mantienen el índice invertido consistente', () {
      final index = CompactSimilarityIndex();
      index.upsert(const CompactSimilarityEntry(
        key: 'uber eats',
        aliases: ['uber food'],
        category: 'Alimentación',
        confirmations: 4,
      ));
      expect(index.length, equals(1));
      expect(index.search('uber food', minScore: 0.88), isNotEmpty);

      index.remove('uber eats');
      expect(index.length, equals(0));
      expect(index.search('uber food', minScore: 0.0), isEmpty);
    });
  });

  group('LearnedPatternsService - Mini-RAG en disco y caché compacta', () {
    test(
        'findBestSemanticMatch lee de disco solo al ganador sin deserializar toda la caja en cada consulta',
        () async {
      final now = DateTime.now();
      for (var i = 0; i < 40; i++) {
        await service.recordConfirmation(
          merchant: 'Comercio Alfa$i',
          category: 'Otros',
          packageName: 'com.nu.production',
          at: now,
        );
      }
      await service.recordConfirmation(
        merchant: 'Crepes y Waffles',
        category: 'Alimentación',
        accountName: 'Bancolombia Ahorros',
        alias: 'Crepes Waffles Medellin',
        packageName: 'com.bancolombia.personas',
        at: now,
      );

      // Primera búsqueda hidrata cabeceras compactas en RAM
      final warmup = await service.findBestSemanticMatch(
        'Crepes Waffles Medellin',
        packageName: 'com.bancolombia.personas',
      );
      expect(warmup, isNotNull);
      expect(warmup!.merchantKey, equals('crepes y waffles'));
      expect(service.cachedHeaderCount, equals(41));

      // Segunda búsqueda: 0 escaneos completos; SOLO 1 lectura box.get(ganador)
      countingBox.resetCounters();
      final hit = await service.findBestSemanticMatch(
        'Crepes Waffles Medellin',
        packageName: 'com.bancolombia.personas',
      );
      expect(hit, isNotNull);
      expect(hit!.category, equals('Alimentación'));
      expect(countingBox.getCount, equals(1));
      expect(countingBox.readKeys, equals(['crepes y waffles']));
    });

    test('findBestSemanticMatch omite patrones en_revision y obsoletos',
        () async {
      final now = DateTime.now();
      // Patrón consolidado que entra en_revision tras 1 corrección
      for (var i = 0; i < 4; i++) {
        await service.recordConfirmation(
          merchant: 'Amazon Prime',
          category: 'Entretenimiento',
          alias: 'Amazon Video',
          packageName: 'com.nu.production',
          at: now,
        );
      }
      await service.recordCorrection(
        merchant: 'Amazon Prime',
        newCategory: 'Hogar',
        packageName: 'com.nu.production',
        at: now,
      );

      // Patrón obsoleto (>180 días)
      await service.recordConfirmation(
        merchant: 'Blockbuster Video',
        category: 'Entretenimiento',
        alias: 'Blockbuster Store',
        packageName: 'com.nu.production',
        at: now.subtract(const Duration(days: 220)),
      );

      // Calentar índice
      await service.findBestSemanticMatch('inexistente', now: now);
      countingBox.resetCounters();

      final revMatch = await service.findBestSemanticMatch(
        'Amazon Video',
        packageName: 'com.nu.production',
        now: now,
      );
      final obsMatch = await service.findBestSemanticMatch(
        'Blockbuster Store',
        packageName: 'com.nu.production',
        now: now,
      );

      expect(revMatch, isNull);
      expect(obsMatch, isNull);
      // Descartados en cabecera RAM sin leer de disco
      expect(countingBox.getCount, equals(0));
    });

    test('Benchmark: 500 patrones resuelven búsqueda semántica en < 1 ms',
        () async {
      final now = DateTime.now();
      final entries = <CompactSimilarityEntry>[];
      for (var i = 0; i < 499; i++) {
        entries.add(CompactSimilarityEntry(
          key: 'comercio local numero $i',
          aliases: ['sucursal comercio $i', 'tienda barrio $i'],
          category: i.isEven ? 'Alimentación' : 'Transporte',
          knownPackages: const ['com.bancolombia.personas'],
          confirmations: 4,
        ));
      }
      entries.add(const CompactSimilarityEntry(
        key: 'supermercado carulla',
        aliases: ['carulla express laureles', 'almacenes carulla'],
        category: 'Alimentación',
        knownPackages: ['com.bancolombia.personas'],
        confirmations: 5,
      ));

      final index = CompactSimilarityIndex()..rebuild(entries);

      // Warmup JIT
      for (var i = 0; i < 20; i++) {
        index.search(
          'carulla express laureles',
          packageName: 'com.bancolombia.personas',
          minScore: 0.88,
        );
      }

      const iterations = 100;
      final sw = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        final res = index.search(
          'carulla express laureles',
          packageName: 'com.bancolombia.personas',
          minScore: 0.88,
        );
        expect(res, isNotEmpty);
        expect(res.first.key, equals('supermercado carulla'));
      }
      sw.stop();

      final avgMicros = sw.elapsedMicroseconds / iterations;
      // Presupuesto estricto de especificación: < 1 ms por consulta
      expect(
        avgMicros,
        lessThan(1000.0),
        reason: 'Promedio observado: ${avgMicros.toStringAsFixed(1)} µs',
      );

      // También verificar latencia end-to-end en LearnedPatternsService con 500 registros Hive
      for (final e in entries) {
        await rawBox.put(
          e.key,
          LearnedPattern(
            merchantKey: e.key,
            category: e.category,
            aliases: e.aliases,
            knownPackages: e.knownPackages,
            confirmations: e.confirmations,
            createdAt: now,
            lastUsedAt: now,
          ).toJson(),
        );
      }
      // Hidratación inicial + warmup de lectura Hive
      for (var i = 0; i < 5; i++) {
        await service.findBestSemanticMatch(
          'carulla express laureles',
          packageName: 'com.bancolombia.personas',
        );
      }

      final swService = Stopwatch()..start();
      for (var i = 0; i < 25; i++) {
        final found = await service.findBestSemanticMatch(
          'carulla express laureles',
          packageName: 'com.bancolombia.personas',
        );
        expect(found?.merchantKey, equals('supermercado carulla'));
      }
      swService.stop();
      final avgServiceMicros = swService.elapsedMicroseconds / 25;
      expect(
        avgServiceMicros,
        lessThan(1000.0),
        reason:
            'Promedio service end-to-end: ${avgServiceMicros.toStringAsFixed(1)} µs',
      );
    });
  });

  group('TransactionClassifier - Etapa 1 semántica y strategicNote O(1)', () {
    late _MockGemmaClient mockGemma;
    late TransactionClassifier classifier;
    late List<AccountItem> accounts;

    setUp(() {
      mockGemma = _MockGemmaClient();
      accounts = [
        AccountItem(
          id: 'acc-1',
          title: 'Bancolombia Ahorros',
          subtitle: 'Cuenta *4821',
          balance: '1000000',
          icon: Icons.account_balance,
          iconColor: Colors.blue,
        ),
      ];
      classifier = TransactionClassifier(
        patternsService: service,
        gemmaAdapter: GemmaClassifierAdapter(
          client: mockGemma,
          timeout: const Duration(milliseconds: 200),
        ),
        accountsLoader: () async => accounts,
      );
    });

    test(
        'Etapa 1 resuelve variante del comercio por alias sin despertar a Gemma y genera strategicNote con MonthlySummaryCache',
        () async {
      final now = DateTime(2026, 11, 15, 14, 0);
      await service.recordConfirmation(
        merchant: 'Supermercado La Vaquita',
        category: 'Alimentación',
        accountName: 'Bancolombia Ahorros',
        alias: 'La Vaquita Express',
        packageName: 'com.bancolombia.personas',
        at: now,
      );

      // Abrir caja 'data' con un gasto previo del mismo mes para validar resumen O(1)
      final dataBox = await Hive.openBox<Add_data>('data');
      await dataBox.add(Add_data(
        'Expenses',
        '80000',
        now.subtract(const Duration(days: 2)),
        'Compra previa',
        'Alimentación',
        'Bancolombia Ahorros',
        Icons.fastfood.codePoint,
      ));
      MonthlySummaryCache.instance.invalidate();

      final result = await classifier.classify(
        parseResult: ParsedTransaction(
          tipo: 'gasto',
          monto: 45000,
          comercio: 'La Vaquita Express 02',
          fecha: now,
          confidence: 0.70,
          requiresReview: true,
          autoProcessable: false,
        ),
        packageName: 'com.bancolombia.personas',
      );

      expect(result.decisionSource, equals('learned_patterns'));
      expect(result.category, equals('Alimentación'));
      expect(result.createTransaction, isTrue);
      expect(result.requiresReview, isFalse);
      expect(mockGemma.callCount, equals(0));
      expect(result.strategicNote, isNotNull);
      expect(result.strategicNote, contains('Patrón similar'));
      expect(result.strategicNote, contains('Alimentación'));
      expect(result.strategicNote, contains('Acumulado del mes'));
      expect(result.strategicNote, contains('80.000'));
    });

    test(
        'Etapa 0 sigue bloqueando fraude aunque coincida con alias aprendido',
        () async {
      await service.recordConfirmation(
        merchant: 'Bancolombia Pagos',
        category: 'Servicios',
        alias: 'Bancolombia Movil',
        packageName: 'com.bancolombia.personas',
      );

      final result = await classifier.classify(
        parseResult: ParsedTransaction(
          tipo: 'gasto',
          monto: 50000,
          comercio: 'Bancolombia Movil',
          fecha: DateTime.now(),
          confidence: 0.90,
          requiresReview: false,
          autoProcessable: true,
        ),
        rawText: 'URGENTE cuenta bloqueada ingresa en https://bit.ly/phish',
        packageName: 'com.bancolombia.personas',
      );

      expect(result.classification, equals('sospechosa'));
      expect(result.decisionSource, equals('anti_fraud'));
      expect(result.createTransaction, isFalse);
      expect(mockGemma.callCount, equals(0));
    });

    test(
        'Etapa 2 funciona con caja data cerrada y genera strategicNote seguro',
        () async {
      expect(Hive.isBoxOpen('data'), isFalse);

      final result = await classifier.classify(
        parseResult: ParsedTransaction(
          tipo: 'gasto',
          monto: 42000,
          comercio: 'D1',
          cuenta: const AccountHint(last4: '4821'),
          fecha: DateTime(2026, 11, 15),
          confidence: 0.85,
          requiresReview: false,
          autoProcessable: true,
        ),
        rawText: 'Compra por \$42.000 en D1 con tarjeta *4821',
      );

      expect(result.decisionSource, equals('deterministic_rules'));
      expect(result.category, equals('Alimentación'));
      expect(result.strategicNote, isNotNull);
      expect(result.strategicNote, contains('Regla determinista'));
      expect(result.strategicNote, contains('Alimentación'));
    });

    test('Etapa 3 propaga strategicNote de Gemma cuando viene en el JSON',
        () async {
      mockGemma.responseToReturn =
          '{"classification": "gasto", "category": "Mascotas", "confidence": 0.90, '
          '"strategic_note": "Gasto recurrente en clínica veterinaria."}';

      final result = await classifier.classify(
        parseResult: ParsedTransaction(
          tipo: 'desconocido',
          monto: 65000,
          comercio: 'Clinica Vet Huellitas',
          fecha: DateTime(2026, 11, 15),
          confidence: 0.50,
          requiresReview: true,
          autoProcessable: false,
        ),
        rawText: 'Operacion especial en Clinica Vet Huellitas por \$65.000',
      );

      expect(result.decisionSource, equals('gemma_fallback'));
      expect(result.category, equals('Mascotas'));
      expect(
        result.strategicNote,
        equals('Gasto recurrente en clínica veterinaria.'),
      );
    });

    test(
        'Etapa 3 genera nota explicativa de IA cuando Gemma no envía strategic_note',
        () async {
      mockGemma.responseToReturn =
          '{"classification": "gasto", "category": "Mascotas", "confidence": 0.89}';

      final result = await classifier.classify(
        parseResult: ParsedTransaction(
          tipo: 'desconocido',
          monto: 65000,
          comercio: 'Clinica Vet Huellitas',
          fecha: DateTime(2026, 11, 15),
          confidence: 0.50,
          requiresReview: true,
          autoProcessable: false,
        ),
        rawText: 'Operacion especial en Clinica Vet Huellitas por \$65.000',
      );

      expect(result.decisionSource, equals('gemma_fallback'));
      expect(result.strategicNote, isNotNull);
      expect(result.strategicNote, contains('asistente IA'));
      expect(result.strategicNote, contains('Mascotas'));
    });
  });
}
