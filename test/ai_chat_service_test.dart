import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:finazaap/services/ai_chat_service.dart';
import 'package:finazaap/data/model/add_date.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    tempDir = await Directory.systemTemp.createTemp('moneo_ai_svc_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final box = await Hive.openBox<Add_data>('data');
    await box.clear();
  });

  tearDown(() async {
    await Hive.close();
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('AiChatService inicializa correctamente con memoria limpia', () async {
    final chatService = AiChatService();
    await chatService.initialize();

    expect(chatService.messages.length, equals(1));
    expect(chatService.chatSummary, isEmpty);
    expect(chatService.lastSummaryCount, equals(0));
  });

  test('AiChatService realiza resumen interno después de acumular 7 mensajes nuevos', () async {
    final chatService = AiChatService();
    await chatService.initialize();
    
    // Activar simulador local para evitar cargar el modelo Gemma real en tests
    await chatService.setSimulatorMode(true);

    // Enviar 7 turnos completos (cada uno añade 2 mensajes, total 14 nuevos + 1 inicial = 15)
    for (int i = 1; i <= 7; i++) {
      if (i == 3) {
        await chatService.sendMessage('Mi meta es ahorrar para un viaje');
      } else if (i == 4) {
        await chatService.sendMessage('Quiero comprar tenis de 120 dólares, ¿es buena idea?');
      } else {
        await chatService.sendMessage('Mensaje de prueba $i');
      }
      expect(chatService.chatSummary, isEmpty, reason: 'Aún no debe resumir en el turno $i');
    }

    // Turno 8:
    // Al enviar el octavo mensaje, el userChat se añade, la longitud es 16,
    // y se dispara el resumen de los primeros 8 mensajes (índices 0 a 7).
    await chatService.sendMessage('¿Qué deudas tengo pendientes?');
    
    expect(chatService.chatSummary, isNotEmpty, reason: 'Debería haber generado un resumen interno');
    expect(chatService.lastSummaryCount, equals(8), reason: 'El contador de último resumen debe ser 8');
    
    // Validar que el resumen fallback contiene los tópicos clave
    expect(chatService.chatSummary.contains('viaje') || chatService.chatSummary.contains('metas de ahorro') || chatService.chatSummary.contains('compra'), isTrue);
  });

  test('clearHistory limpia el historial y el resumen de memoria', () async {
    final chatService = AiChatService();
    await chatService.initialize();
    await chatService.setSimulatorMode(true);

    // Mandar mensajes para poblar el historial y disparar resumen
    for (int i = 1; i <= 8; i++) {
      await chatService.sendMessage('Mensaje de prueba $i');
    }

    expect(chatService.chatSummary, isNotEmpty);
    
    // Limpiar historial
    await chatService.clearHistory();

    expect(chatService.messages.length, equals(1));
    expect(chatService.chatSummary, isEmpty);
    expect(chatService.lastSummaryCount, equals(0));
  });

  test('Gemma streaming extrae y acumula metas sin borrar previas', () async {
    final chatService = AiChatService();
    chatService.testSessionCreator = (_) async => _FakeAiSessionAdapter('Respuesta breve de prueba.');
    addTearDown(() async {
      chatService.testSessionCreator = null;
      await chatService.clearHistory();
      await chatService.setSimulatorMode(true);
    });

    await chatService.initialize();
    await chatService.setSimulatorMode(false);

    await chatService.sendMessage('Mi meta es viajar a Japón');
    expect(chatService.userGoals, contains('viajar a Japón'));

    await chatService.sendMessage('Quiero ahorrar para una casa');
    expect(chatService.userGoals, contains('viajar a Japón'));
    expect(chatService.userGoals, contains('una casa'));
  });

  test('resumen interno es acumulativo entre múltiples lotes', () async {
    final chatService = AiChatService();
    await chatService.initialize();
    await chatService.setSimulatorMode(true);

    await chatService.sendMessage('Quiero comprar unos tenis de 100');
    for (int i = 0; i < 7; i++) {
      await chatService.sendMessage('Consulta general $i');
    }
    final firstSummary = chatService.chatSummary;
    expect(firstSummary, contains('compra'));

    await chatService.sendMessage('¿Qué deudas tengo pendientes?');
    for (int i = 0; i < 7; i++) {
      await chatService.sendMessage('Otro mensaje $i');
    }

    expect(chatService.chatSummary, contains('compra'));
    expect(chatService.chatSummary, contains('obligaciones financieras'));
  });

  test('updateLearnedPatterns usa ventana móvil de 60 días (ignora historial viejo)', () async {
    final box = Hive.box<Add_data>('data');
    final now = DateTime.now();
    await box.add(Add_data('Expenses', '99999', now.subtract(const Duration(days: 150)), 'Viaje antiguo', 'LujoAntiguo', 'Banco', 0));
    await box.add(Add_data('Expenses', '250', now.subtract(const Duration(days: 10)), 'Almuerzo', 'Alimentación', 'Banco', 0));

    final chatService = AiChatService();
    await chatService.initialize();

    expect(chatService.expenseCount, equals(1));
    expect(chatService.topCategory, equals('Alimentación'));
  });

  test('ai_chat_history en SharedPreferences se acota a los últimos 80 mensajes', () async {
    final chatService = AiChatService();
    chatService.testSessionCreator = (_) async => _FakeAiSessionAdapter('Ok.');
    addTearDown(() async {
      chatService.testSessionCreator = null;
      await chatService.clearHistory();
      await chatService.setSimulatorMode(true);
    });

    await chatService.initialize();
    await chatService.setSimulatorMode(false);

    // 42 turnos => > 80 mensajes
    for (int i = 0; i < 42; i++) {
      await chatService.sendMessage('Turno $i');
    }

    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs.getStringList('ai_chat_history') ?? [];
    expect(persisted.length, lessThanOrEqualTo(80));
    expect(chatService.messages.length, lessThanOrEqualTo(80));
  });

  test('sesión Gemma rota automáticamente al acercarse al presupuesto de 2048 tokens', () async {
    final List<String> systemPrompts = [];
    final chatService = AiChatService();
    chatService.testSessionCreator = (sys) async {
      systemPrompts.add(sys);
      return _FakeAiSessionAdapter(List.filled(60, 'respuesta').join(' '));
    };
    addTearDown(() async {
      chatService.testSessionCreator = null;
      await chatService.clearHistory();
      await chatService.setSimulatorMode(true);
    });

    await chatService.initialize();
    await chatService.setSimulatorMode(false);

    final longQuestion = List.filled(110, 'gasto').join(' ');
    for (int i = 0; i < 12; i++) {
      await chatService.sendMessage(longQuestion);
    }

    expect(chatService.sessionRotationCount, greaterThanOrEqualTo(1));
    expect(systemPrompts.length, greaterThanOrEqualTo(2));
  });
}

class _FakeAiSessionAdapter implements AiChatSessionAdapter {
  final String reply;
  bool closed = false;

  _FakeAiSessionAdapter(this.reply);

  @override
  Future<void> addUserMessage(String text) async {}

  @override
  Stream<String> generateResponseStream() async* {
    yield reply;
  }

  @override
  Future<void> stopGeneration() async {}

  @override
  Future<void> close() async {
    closed = true;
  }
}
