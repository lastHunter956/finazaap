import 'dart:async';
import 'dart:io';

import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/services/ai_chat_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSessionAdapter implements AiChatSessionAdapter {
  final List<String> sentPrompts = [];
  StreamController<String>? _controller;
  bool stopped = false;
  bool closed = false;
  final List<List<String>> scriptedChunks;
  final bool holdOpenUntilStopped;
  int _turnIndex = 0;

  _FakeSessionAdapter({
    this.scriptedChunks = const [
      ['Hola ', 'mundo'],
      ['Segundo ', 'turno'],
    ],
    this.holdOpenUntilStopped = false,
  });

  @override
  Future<void> addUserMessage(String text) async {
    sentPrompts.add(text);
  }

  @override
  Stream<String> generateResponseStream() {
    if (holdOpenUntilStopped) {
      _controller = StreamController<String>();
      _controller!.add('Parcial ');
      return _controller!.stream;
    }
    final idx = _turnIndex < scriptedChunks.length
        ? _turnIndex++
        : scriptedChunks.length - 1;
    return Stream<String>.fromIterable(scriptedChunks[idx]);
  }

  @override
  Future<void> stopGeneration() async {
    stopped = true;
    if (_controller != null && !_controller!.isClosed) {
      await _controller!.close();
    }
  }

  @override
  Future<void> close() async {
    closed = true;
    if (_controller != null && !_controller!.isClosed) {
      await _controller!.close();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('moneo_audit_t2_1_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    if (!Hive.isBoxOpen('data')) {
      await Hive.openBox<Add_data>('data');
    } else {
      await Hive.box<Add_data>('data').clear();
    }
    final chatService = AiChatService();
    chatService.testSessionCreator = null;
    await chatService.resetGemmaSessionForTests();
    await chatService.initialize();
    await chatService.clearHistory();
    await chatService.setSimulatorMode(false);
  });

  tearDown(() async {
    final chatService = AiChatService();
    chatService.testSessionCreator = null;
    await chatService.resetGemmaSessionForTests();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('reuses single persistent session across turns and streams response', () async {
    final chatService = AiChatService();
    int createCalls = 0;
    final fakeSession = _FakeSessionAdapter();

    chatService.testSessionCreator = (_) async {
      createCalls++;
      return fakeSession;
    };

    await chatService.sendMessage('¿Cómo va mi balance?');
    expect(createCalls, 1);
    expect(fakeSession.sentPrompts.length, 1);
    expect(chatService.messages.last.role, 'model');
    expect(chatService.messages.last.content, 'Hola mundo');

    await chatService.sendMessage('¿Y mis gastos?');
    expect(createCalls, 1);
    expect(fakeSession.sentPrompts.length, 2);
    expect(chatService.messages.last.content, 'Segundo turno');
    expect(chatService.isGenerating, isFalse);
  });

  test('enforces single active generation and supports cancellation', () async {
    final chatService = AiChatService();
    final fakeSession = _FakeSessionAdapter(holdOpenUntilStopped: true);

    chatService.testSessionCreator = (_) async => fakeSession;

    final firstSend = chatService.sendMessage('Genera un análisis');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(chatService.isGenerating, isTrue);

    // Concurrent send while generating must be ignored.
    await chatService.sendMessage('Mensaje concurrente ignorado');
    expect(fakeSession.sentPrompts.length, 1);

    await chatService.cancelGeneration();
    await firstSend;

    expect(fakeSession.stopped, isTrue);
    expect(chatService.isGenerating, isFalse);
    expect(chatService.messages.last.role, 'model');
    expect(chatService.messages.last.content, contains('Parcial'));
  });

  test('summarizes bounded history deterministically without creating second session', () async {
    final chatService = AiChatService();
    int createCalls = 0;
    final fakeSession = _FakeSessionAdapter(
      scriptedChunks: const [
        ['Respuesta breve'],
      ],
    );

    chatService.testSessionCreator = (_) async {
      createCalls++;
      return fakeSession;
    };

    for (int i = 1; i <= 8; i++) {
      await chatService.sendMessage('Consulta número $i');
    }

    expect(createCalls, 1);
    expect(chatService.chatSummary, isNotEmpty);
    expect(chatService.lastSummaryCount, greaterThan(0));
  });
}
