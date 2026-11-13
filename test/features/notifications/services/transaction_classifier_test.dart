import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/features/notifications/domain/models/notification_parse_result.dart';
import 'package:finazaap/features/notifications/services/gemma_classifier_adapter.dart';
import 'package:finazaap/features/notifications/services/learned_patterns_service.dart';
import 'package:finazaap/features/notifications/services/transaction_classifier.dart';

/// Cliente simulado de inferencia Gemma para pruebas unitarias sin cargar modelos pesados.
class MockGemmaClient implements GemmaInferenceClient {
  bool isLoaded;
  String? responseToReturn;
  Duration? delay;
  int callCount = 0;
  String? lastPrompt;

  MockGemmaClient({
    this.isLoaded = true,
    this.responseToReturn,
    this.delay,
  });

  @override
  Future<bool> isModelLoaded() async => isLoaded;

  @override
  Future<String?> generateResponse(String prompt) async {
    callCount++;
    lastPrompt = prompt;
    if (delay != null) {
      await Future.delayed(delay!);
    }
    return responseToReturn;
  }
}

void main() {
  late Directory tempDir;
  late Box<dynamic> patternsBox;
  late LearnedPatternsService patternsService;
  late MockGemmaClient mockGemmaClient;
  late GemmaClassifierAdapter gemmaAdapter;
  late TransactionClassifier classifier;
  late List<AccountItem> userAccounts;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('classifier_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    patternsBox = await Hive.openBox<dynamic>(
        'patterns_${DateTime.now().microsecondsSinceEpoch}');
    patternsService = LearnedPatternsService(box: patternsBox);
    mockGemmaClient = MockGemmaClient();
    gemmaAdapter = GemmaClassifierAdapter(
      client: mockGemmaClient,
      timeout: const Duration(milliseconds: 200),
    );

    userAccounts = [
      AccountItem(
        id: 'acc-1',
        title: 'Bancolombia Ahorros',
        subtitle: 'Cuenta *4821',
        balance: '1500000',
        icon: Icons.account_balance,
        iconColor: Colors.blue,
      ),
      AccountItem(
        id: 'acc-2',
        title: 'Nequi',
        subtitle: 'Celular *1234',
        balance: '350000',
        icon: Icons.phone_android,
        iconColor: Colors.purple,
      ),
    ];

    classifier = TransactionClassifier(
      patternsService: patternsService,
      gemmaAdapter: gemmaAdapter,
      accountsLoader: () async => userAccounts,
    );
  });

  tearDown(() async {
    if (patternsBox.isOpen) {
      await patternsBox.clear();
      await patternsBox.close();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Etapa 0: Anti-Fraude (Bloqueo Absoluto)', () {
    test('Bloquea notificación marcada como SuspiciousNotification', () async {
      final result = await classifier.classify(
        parseResult: SuspiciousNotification(
          rawText:
              'Ingresa a https://bit.ly/actualiza-banco para evitar bloqueo',
          reason: 'Enlace sospechoso',
          fecha: DateTime.now(),
        ),
      );

      expect(result.classification, equals('sospechosa'));
      expect(result.moneoType, isNull);
      expect(result.createTransaction, isFalse);
      expect(result.requiresReview, isTrue);
      expect(result.decisionSource, equals('anti_fraud'));
      expect(result.confidence, equals(0.0));
      expect(mockGemmaClient.callCount, equals(0),
          reason: 'Gemma no debe ser invocado');
    });

    test('Bloquea textos con palabras de urgencia / ingeniería social',
        () async {
      final urgencyPhrases = [
        'URGENTE: cuenta bloqueada, ingresa aquí para desbloquear',
        'Alerta: suspensión inmediata de tus servicios financieros',
        'Por favor verifica tu identidad para continuar operando',
        'Último aviso: actualiza tus datos ahora o se suspenderá la cuenta',
        'Haz clic para confirmar tu transferencia de \$100.000',
        'Evita el bloqueo de tus productos financieros',
        'Acceso suspendido temporalmente por seguridad',
      ];

      for (final text in urgencyPhrases) {
        final parsed = ParsedTransaction(
          tipo: 'gasto',
          monto: 50000,
          comercio: 'Banco Fake',
          fecha: DateTime.now(),
          confidence: 0.90,
          requiresReview: false,
          autoProcessable: true,
        );

        final result = await classifier.classify(
          parseResult: parsed,
          rawText: text,
        );

        expect(result.classification, equals('sospechosa'),
            reason: 'Falló para frase: "$text"');
        expect(result.moneoType, isNull);
        expect(result.createTransaction, isFalse);
        expect(result.requiresReview, isTrue);
        expect(result.decisionSource, equals('anti_fraud'));
        expect(mockGemmaClient.callCount, equals(0));
      }
    });

    test('Bloquea notificaciones con URLs o acortadores de links', () async {
      final linkTexts = [
        'Transacción exitosa. Consulta tu saldo en https://bancolombia.seguro-falso.com',
        'Visita www.bancofalso.com para reclamar tu premio',
        'Mira el comprobante en wa.me/573001234567',
        'Revisa el detalle en t.co/xyz123',
      ];

      for (final text in linkTexts) {
        final parsed = ParsedTransaction(
          tipo: 'gasto',
          monto: 25000,
          comercio: 'Compra online',
          fecha: DateTime.now(),
          confidence: 0.90,
          requiresReview: false,
          autoProcessable: true,
        );

        final result =
            await classifier.classify(parseResult: parsed, rawText: text);
        expect(result.classification, equals('sospechosa'),
            reason: 'Debió bloquear URL en: "$text"');
        expect(result.createTransaction, isFalse);
        expect(result.decisionSource, equals('anti_fraud'));
      }
    });
  });

  group('Etapa 1: Aprendizaje Local ("learned_patterns")', () {
    test(
        'Clasifica exitosamente basándose en un patrón aprendido sin llamar a Gemma',
        () async {
      // Registrar un patrón previo confirmado
      await patternsService.recordConfirmation(
        merchant: 'Éxito Laureles 034',
        category: 'Alimentación',
        accountName: 'Bancolombia Ahorros',
        classification: 'gasto',
      );

      final parsed = ParsedTransaction(
        tipo: 'gasto',
        monto: 145000,
        comercio: 'Éxito Laureles 034',
        fecha: DateTime.now(),
        confidence: 0.70,
        requiresReview: true,
        autoProcessable: false,
      );

      final result = await classifier.classify(parseResult: parsed);

      expect(result.classification, equals('gasto'));
      expect(result.moneoType, equals('Expenses'));
      expect(result.category, equals('Alimentación'));
      expect(result.accountName, equals('Bancolombia Ahorros'));
      expect(result.decisionSource, equals('learned_patterns'));
      expect(result.confidence, greaterThanOrEqualTo(0.85));
      expect(result.requiresReview, isFalse);
      expect(result.createTransaction, isTrue);
      expect(mockGemmaClient.callCount, equals(0),
          reason: 'Gemma NO debe invocarse si hay learned_pattern');
    });

    test('Usa la corrección más reciente guardada por el usuario', () async {
      // Primero se guardó como Otros
      await patternsService.recordConfirmation(
        merchant: 'Farmacia Pasteur',
        category: 'Otros',
      );

      // Luego el usuario corrigió a Salud
      await patternsService.recordCorrection(
        merchant: 'Farmacia Pasteur',
        newCategory: 'Salud',
        newAccountName: 'Nequi',
      );

      final parsed = ParsedTransaction(
        tipo: 'gasto',
        monto: 32000,
        comercio: 'Farmacia Pasteur Suc. 10',
        fecha: DateTime.now(),
        confidence: 0.65,
        requiresReview: true,
        autoProcessable: false,
      );

      final result = await classifier.classify(parseResult: parsed);

      expect(result.category, equals('Salud'));
      expect(result.accountName, equals('Nequi'));
      expect(result.decisionSource, equals('learned_patterns'));
      expect(mockGemmaClient.callCount, equals(0));
    });
  });

  group('Etapa 2: Reglas Deterministas (Sin LLM)', () {
    test('Clasifica gasto en supermercado con categoría "Alimentación"',
        () async {
      final parsed = ParsedTransaction(
        tipo: 'gasto',
        monto: 45000,
        comercio: 'D1 CALLE 50',
        cuenta: const AccountHint(last4: '4821', hint: 'Ahorros'),
        fecha: DateTime.now(),
        confidence: 0.85,
        requiresReview: false,
        autoProcessable: true,
      );

      final result = await classifier.classify(
        parseResult: parsed,
        rawText: 'Compra por \$45.000 en D1 CALLE 50 con tu tarjeta *4821',
      );

      expect(result.classification, equals('gasto'));
      expect(result.moneoType, equals('Expenses'));
      expect(result.category, equals('Alimentación'));
      expect(result.accountName, equals('Bancolombia Ahorros'));
      expect(result.confidence, greaterThanOrEqualTo(0.80));
      expect(result.decisionSource, equals('deterministic_rules'));
      expect(result.createTransaction, isTrue);
      expect(result.requiresReview, isFalse);
      expect(mockGemmaClient.callCount, equals(0));
    });

    test('Clasifica gasto en servicios públicos con categoría "Servicios"',
        () async {
      final parsed = ParsedTransaction(
        tipo: 'gasto',
        monto: 85000,
        comercio: 'Claro Soluciones Móviles',
        cuenta: const AccountHint(last4: '1234', hint: 'Nequi'),
        fecha: DateTime.now(),
        confidence: 0.85,
        requiresReview: false,
        autoProcessable: true,
      );

      final result = await classifier.classify(
        parseResult: parsed,
        rawText: 'Pago de factura Claro Soluciones Móviles por \$85.000',
      );

      expect(result.classification, equals('gasto'));
      expect(result.moneoType, equals('Expenses'));
      expect(result.category, equals('Servicios'));
      expect(result.decisionSource, equals('deterministic_rules'));
      expect(mockGemmaClient.callCount, equals(0));
    });

    test('Clasifica ingreso de nómina con categoría "Salario"', () async {
      final parsed = ParsedTransaction(
        tipo: 'ingreso',
        monto: 2500000,
        comercio: 'EMPRESA SAS',
        cuenta: const AccountHint(last4: '4821', hint: 'Ahorros'),
        fecha: DateTime.now(),
        confidence: 0.90,
        requiresReview: false,
        autoProcessable: true,
      );

      final result = await classifier.classify(
        parseResult: parsed,
        rawText:
            'Abono de nómina EMPRESA SAS por \$2.500.000 en tu cuenta Ahorros *4821',
      );

      expect(result.classification, equals('ingreso'));
      expect(result.moneoType, equals('Income'));
      expect(result.category, equals('Salario'));
      expect(result.accountName, equals('Bancolombia Ahorros'));
      expect(result.decisionSource, equals('deterministic_rules'));
      expect(result.createTransaction, isTrue);
      expect(result.requiresReview, isFalse);
      expect(mockGemmaClient.callCount, equals(0));
    });

    test('Clasifica transferencia entre cuentas propias del usuario', () async {
      final parsed = ParsedTransaction(
        tipo: 'transferencia',
        monto: 200000,
        comercio: null,
        fecha: DateTime.now(),
        confidence: 0.88,
        requiresReview: false,
        autoProcessable: true,
      );

      final result = await classifier.classify(
        parseResult: parsed,
        rawText:
            'Transferencia de \$200.000 desde Bancolombia Ahorros *4821 hacia tu cuenta Nequi *1234',
      );

      expect(result.classification, equals('transferencia-propia'));
      expect(result.moneoType, equals('Transfer'));
      expect(result.category, equals('Transferencia'));
      expect(result.accountName, equals('Bancolombia Ahorros'));
      expect(result.destinationAccount, equals('Nequi'));
      expect(result.destinationAccount, isNotNull);
      expect(result.decisionSource, equals('deterministic_rules'));
      expect(result.createTransaction, isTrue);
      expect(result.requiresReview, isFalse);
      expect(mockGemmaClient.callCount, equals(0));
    });

    test(
        'Transferencia a un tercero es clasificada como gasto, no transferencia propia',
        () async {
      final parsed = ParsedTransaction(
        tipo: 'transferencia',
        monto: 50000,
        comercio: 'Carlos Perez',
        fecha: DateTime.now(),
        confidence: 0.85,
        requiresReview: false,
        autoProcessable: true,
      );

      final result = await classifier.classify(
        parseResult: parsed,
        rawText: 'Transferiste \$50.000 a Carlos Perez desde tu Nequi',
      );

      expect(result.classification, equals('gasto'));
      expect(result.moneoType, equals('Expenses'));
      expect(result.destinationAccount, isNull);
      expect(result.decisionSource, equals('deterministic_rules'));
      expect(mockGemmaClient.callCount, equals(0));
    });
  });

  group('Etapa 3: Respaldo On-Device con Gemma (flutter_gemma)', () {
    test(
        'Invoca a Gemma cuando las reglas deterministas dejan ambigüedad (confidence < 0.80)',
        () async {
      mockGemmaClient.responseToReturn =
          '{"classification": "gasto", "category": "Mascotas", "confidence": 0.88}';

      final ambiguous = ParsedTransaction(
        tipo: 'desconocido',
        monto: 45000,
        comercio: 'Veterinaria El Can',
        fecha: DateTime.now(),
        confidence: 0.50,
        requiresReview: true,
        autoProcessable: false,
      );

      final result = await classifier.classify(
        parseResult: ambiguous,
        rawText: 'Operacion especial en Veterinaria El Can por \$45.000',
      );

      expect(mockGemmaClient.callCount, equals(1),
          reason: 'Gemma debía ser invocado');
      expect(result.decisionSource, equals('gemma_fallback'));
      expect(result.classification, equals('gasto'));
      expect(result.moneoType, equals('Expenses'));
      expect(result.category, equals('Mascotas'));
      expect(result.confidence, equals(0.88));
      expect(result.createTransaction, isTrue);
      expect(result.requiresReview, isFalse);
    });

    test(
        'Maneja respuesta de Gemma con baja confianza activando requiresReview',
        () async {
      mockGemmaClient.responseToReturn =
          '{"classification": "gasto", "category": "Otros", "confidence": 0.65}';

      final ambiguous = ParsedTransaction(
        tipo: 'desconocido',
        monto: 10000,
        comercio: 'Comercio Raro',
        fecha: DateTime.now(),
        confidence: 0.40,
        requiresReview: true,
        autoProcessable: false,
      );

      final result = await classifier.classify(
        parseResult: ambiguous,
        rawText: 'Movimiento no especificado en Comercio Raro por \$10.000',
      );

      expect(result.decisionSource, equals('gemma_fallback'));
      expect(result.requiresReview, isTrue);
      expect(result.createTransaction, isFalse);
    });

    test(
        'Fallback seguro cuando Gemma no está disponible o falla por hardware/RAM',
        () async {
      mockGemmaClient.isLoaded = false; // Modelo no cargado

      final ambiguous = ParsedTransaction(
        tipo: 'desconocido',
        monto: 15000,
        comercio: 'Kiosko 99',
        fecha: DateTime.now(),
        confidence: 0.40,
        requiresReview: true,
        autoProcessable: false,
      );

      final result = await classifier.classify(
        parseResult: ambiguous,
        rawText: 'Movimiento sin categoria Kiosko 99',
      );

      expect(result.decisionSource, equals('fallback_ambiguous'));
      expect(result.classification, equals('gasto'));
      expect(result.moneoType, equals('Expenses'));
      expect(result.requiresReview, isTrue);
      expect(result.createTransaction, isFalse);
    });

    test('Fallback seguro ante timeout de Gemma (> 200 ms)', () async {
      mockGemmaClient.delay =
          const Duration(milliseconds: 500); // Excede timeout de 200ms
      mockGemmaClient.responseToReturn =
          '{"classification": "gasto", "category": "Lenta", "confidence": 0.90}';

      final ambiguous = ParsedTransaction(
        tipo: 'desconocido',
        monto: 70000,
        comercio: 'Comercio Timeout',
        fecha: DateTime.now(),
        confidence: 0.50,
        requiresReview: true,
        autoProcessable: false,
      );

      final result = await classifier.classify(
        parseResult: ambiguous,
        rawText: 'Transacción indeterminada por \$70.000',
      );

      expect(result.decisionSource, equals('fallback_ambiguous'));
      expect(result.requiresReview, isTrue);
      expect(result.createTransaction, isFalse);
    });
  });

  group('Invariantes y Jerarquía de Precedencia', () {
    test(
        'Etapa 0 (Anti-Fraude) tiene precedencia sobre patrón aprendido previo',
        () async {
      // Guardar patrón de comercio
      await patternsService.recordConfirmation(
        merchant: 'bancolombia',
        category: 'Servicios',
      );

      // Llega un intento de phishing simulando ser ese mismo comercio
      final parsed = ParsedTransaction(
        tipo: 'gasto',
        monto: 0,
        comercio: 'Bancolombia',
        fecha: DateTime.now(),
        confidence: 0.90,
        requiresReview: false,
        autoProcessable: true,
      );

      final result = await classifier.classify(
        parseResult: parsed,
        rawText:
            'Bancolombia informa: cuenta bloqueada, ingresa aquí para evitar el bloqueo',
      );

      expect(result.classification, equals('sospechosa'),
          reason: 'Anti-fraude debe superar learned_patterns');
      expect(result.decisionSource, equals('anti_fraud'));
      expect(result.createTransaction, isFalse);
      expect(mockGemmaClient.callCount, equals(0));
    });

    test(
        'Invariante estricto: ninguna clasificación sospechosa crea transacción',
        () async {
      final result = await classifier.classify(
        parseResult: SuspiciousNotification(
          rawText: 'Phishing evidente wa.me/12345 haz clic',
          reason: 'Phishing',
          fecha: DateTime.now(),
        ),
      );

      expect(result.createTransaction, isFalse);
      expect(result.requiresReview, isTrue);
      expect(result.moneoType, isNull);
    });

    test(
        'Invariante estricto: requiresReview=true nunca puede tener createTransaction=true',
        () async {
      // Caso fallback_ambiguous
      mockGemmaClient.isLoaded = false;
      final ambiguous = ParsedTransaction(
        tipo: 'desconocido',
        monto: 5000,
        fecha: DateTime.now(),
        confidence: 0.30,
        requiresReview: true,
        autoProcessable: false,
      );

      final result = await classifier.classify(parseResult: ambiguous);

      if (result.requiresReview) {
        expect(result.createTransaction, isFalse,
            reason:
                'Invariante violado: requiresReview=true con createTransaction=true');
      }
    });

    test(
        'Invariante estricto: transferencia-propia siempre tiene destinationAccount no nulo',
        () async {
      final parsed = ParsedTransaction(
        tipo: 'transferencia',
        monto: 100000,
        fecha: DateTime.now(),
        confidence: 0.90,
        requiresReview: false,
        autoProcessable: true,
      );

      final result = await classifier.classify(
        parseResult: parsed,
        rawText:
            'Transferencia entre tus cuentas: de Bancolombia *4821 a Nequi *1234',
      );

      if (result.classification == 'transferencia-propia') {
        expect(result.destinationAccount, isNotNull);
        expect(result.destinationAccount, isNotEmpty);
      }
    });
  });
}
