import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:finazaap/services/ai_chat_service.dart';
import 'package:finazaap/data/model/add_date.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    
    // Inicializar Hive en memoria temporal
    Hive.init('.');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(AdddataAdapter());
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Hive.openBox<Add_data>('data');
  });

  tearDown(() async {
    await Hive.close();
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
}
