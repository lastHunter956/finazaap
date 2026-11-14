import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/core/utils/app_logger.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/data/transaction_service.dart';
import 'package:finazaap/services/device_capability_service.dart';

class ChatMessage {
  final String role; // 'user' | 'model' | 'system'
  final String content;
  final DateTime timestamp;
  final List<Map<String, dynamic>>? categorySuggestions; // NEW
  final List<Map<String, dynamic>>? transactionSuggestions; // NEW

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.categorySuggestions, // NEW
    this.transactionSuggestions, // NEW
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        if (categorySuggestions != null) 'categorySuggestions': categorySuggestions, // NEW
        if (transactionSuggestions != null) 'transactionSuggestions': transactionSuggestions, // NEW
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] ?? 'user',
        content: json['content'] ?? '',
        timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
        categorySuggestions: json['categorySuggestions'] != null
            ? List<Map<String, dynamic>>.from((json['categorySuggestions'] as List).map((e) => Map<String, dynamic>.from(e)))
            : null, // NEW
        transactionSuggestions: json['transactionSuggestions'] != null
            ? List<Map<String, dynamic>>.from((json['transactionSuggestions'] as List).map((e) => Map<String, dynamic>.from(e)))
            : null, // NEW
      );
}

/// Contrato ligero para abstraer una sesión de chat Gemma (real o sintética en pruebas).
abstract class AiChatSessionAdapter {
  Future<void> addUserMessage(String text);
  Stream<String> generateResponseStream();
  Future<void> stopGeneration();
  Future<void> close();
}

class _FlutterGemmaSessionAdapter implements AiChatSessionAdapter {
  final InferenceChat _chat;

  _FlutterGemmaSessionAdapter(this._chat);

  @override
  Future<void> addUserMessage(String text) async {
    await _chat.addQueryChunk(Message.text(text: text, isUser: true));
  }

  @override
  Stream<String> generateResponseStream() async* {
    await for (final response in _chat.generateChatResponseAsync()) {
      if (response is TextResponse && response.token.isNotEmpty) {
        yield response.token;
      }
    }
  }

  @override
  Future<void> stopGeneration() async {
    await _chat.stopGeneration();
  }

  @override
  Future<void> close() async {
    await _chat.session.close();
  }
}

/// AiChatService — Gestiona el modelo Gemma y el historial de chat.
///
/// ARQUITECTURA DE DESCARGA DEL MODELO:
/// - Web (debug): servidor Python en puerto 8081
/// - Web (release): archivo estático en /models/gemma.litertlm
/// - Android/iOS: URL configurable por el usuario (no hay modelo empaquetado en APK por límite de 2GB)
///   El usuario debe proveer la URL en la pantalla de configuración del chatbot.
///   El modelo se descarga una sola vez y se almacena localmente via flutter_gemma.
/// - Fallback siempre disponible: Simulador financiero basado en reglas (funciona sin IA).
class AiChatService extends ChangeNotifier {
  static String? initError;
  static Future<void> Function()? ensureGemmaInitialized;
  static final AiChatService _instance = AiChatService._internal();

  factory AiChatService() => _instance;

  AiChatService._internal();

  List<ChatMessage> _messages = [];
  // En Android/iOS, el simulador está activo por defecto porque el modelo debe descargarse.
  // En Web, se intentará cargar Gemma automáticamente.
  bool _useLocalSimulator = !kIsWeb;
  bool _gemmaInitialized = false;
  bool _gemmaInitializing = false;
  String? _gemmaError;
  String _userGoals = '';
  String _userNotes = '';
  String _chatSummary = '';
  int _lastSummaryCount = 0;
  bool _isGenerating = false;
  bool _generationCancelled = false;
  Completer<void>? _initCompleter;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  bool _checkingDeviceSpecs = false;
  DeviceCapabilityResult? _deviceCapability;

  @visibleForTesting
  Future<AiChatSessionAdapter> Function(String systemInstruction)? testSessionCreator;

  static const _defaultModelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

  // Metadatos parseados del perfil cognitivo
  double _savingsRatio = 0.0;
  String _topCategory = 'Ninguna';
  double _topCategoryAmount = 0.0;
  double _maxExpense = 0.0;
  String _maxExpenseItem = '';
  int _expenseCount = 0;
  String _ratioStatus = 'none';
  String _ratioMessageText = '';

  // Instancia del modelo Gemma con la API moderna de flutter_gemma 1.0+
  InferenceModel? _gemmaModel;
  InferenceChat? _gemmaChat;
  AiChatSessionAdapter? _sessionAdapter;

  // Getters
  List<ChatMessage> get messages => _messages;
  bool get isGenerating => _isGenerating;
  bool get useLocalSimulator => _useLocalSimulator;
  bool get gemmaInitialized => _gemmaInitialized;
  bool get gemmaInitializing => _gemmaInitializing;
  String? get gemmaError => _gemmaError;
  String get userGoals => _userGoals;
  String get userNotes => _userNotes;
  String get chatSummary => _chatSummary;
  int get lastSummaryCount => _lastSummaryCount;
  double get downloadProgress => _downloadProgress;
  bool get isDownloading => _isDownloading;
  bool get isCheckingDeviceSpecs => _checkingDeviceSpecs;
  DeviceCapabilityResult? get deviceCapability => _deviceCapability;

  double get savingsRatio => _savingsRatio;
  String get topCategory => _topCategory;
  double get topCategoryAmount => _topCategoryAmount;
  double get maxExpense => _maxExpense;
  String get maxExpenseItem => _maxExpenseItem;
  int get expenseCount => _expenseCount;
  String get ratioStatus => _ratioStatus;
  String get ratioMessageText => _ratioMessageText;

  // Cargar historial, configuración y notas de aprendizaje
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // En Web: intentar Gemma por defecto. En Android/iOS: simulador por defecto.
      // Solo respetar la preferencia guardada si el usuario la cambió explícitamente.
      final savedMode = prefs.getBool('ai_use_local_simulator');
      if (savedMode != null) {
        _useLocalSimulator = savedMode;
      } else {
        // Primera vez: Web usa Gemma, nativo usa simulador
        _useLocalSimulator = !kIsWeb;
      }
      
      // Cargar metas y notas aprendidas
      _userGoals = prefs.getString('ai_user_goals') ?? 'Sin metas definidas aún. Cuéntame qué quieres lograr (ej. comprar un auto, ahorrar 20%, salir de deudas).';
      _userNotes = prefs.getString('ai_user_notes') ?? 'Perfil inicial: Esperando analizar transacciones...';
      _chatSummary = prefs.getString('ai_chat_summary') ?? '';
      _lastSummaryCount = prefs.getInt('ai_last_summary_count') ?? 0;

      // Cargar historial de chat
      final chatData = prefs.getStringList('ai_chat_history');
      if (chatData != null) {
        _messages = chatData
            .map((msgStr) => ChatMessage.fromJson(json.decode(msgStr)))
            .toList();
      } else {
        _messages = [
          ChatMessage(
            role: 'model',
            content: '¡Hola! Soy tu asesor financiero de IA. Puedo analizar tus ingresos, egresos y cuentas para darte recomendaciones personalizadas sobre tus finanzas. \n\nSi estás pensando en realizar una compra, pregúntame: *¿Es buena idea comprar [artículo] por [monto]?* y analizaré si tu presupuesto actual lo soporta.',
            timestamp: DateTime.now(),
          )
        ];
      }

      // Intentar cargar Gemma si no está en modo simulador
      if (!_useLocalSimulator) {
        _tryLoadGemmaModel();
      }

      // Analizar transacciones para actualizar perfil en el arranque
      await updateLearnedPatterns();
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error inicializando AiChatService', error: e);
    }
  }

  /// Intenta cargar el modelo Gemma.
  /// 
  /// Flujo:
  /// 1. Verificar si ya hay un modelo instalado (getActiveModel sin instalar)
  /// 2. Si no, instalar desde la fuente correcta para la plataforma
  /// 3. Crear sesión de chat con contexto financiero
  Future<void> _tryLoadGemmaModel({String? customMobileUrl}) async {
    if (_gemmaInitializing) {
      if (_initCompleter != null) {
        AppLogger.info('Gemma ya está inicializándose. Esperando a que termine...');
        await _initCompleter!.future;
      }
      return;
    }
    
    _gemmaInitializing = true;
    _initCompleter = Completer<void>();
    _gemmaError = null;
    notifyListeners();

    if (ensureGemmaInitialized != null) {
      await ensureGemmaInitialized!();
    }

    if (initError != null) {
      _gemmaError = 'Error de inicialización del motor de IA: $initError';
      _gemmaInitialized = false;
      _gemmaInitializing = false;
      _initCompleter?.complete();
      _initCompleter = null;
      notifyListeners();
      return;
    }

    try {
      AppLogger.info('Intentando obtener modelo Gemma activo preexistente...');
      
      // PASO 1: Intentar obtener un modelo ya instalado sin necesidad de descargar
      bool modelAlreadyInstalled = false;
      try {
        _gemmaModel = await FlutterGemma.getActiveModel(
          maxTokens: 2048,
          preferredBackend: PreferredBackend.gpu,
        );
        modelAlreadyInstalled = true;
        AppLogger.success('Modelo Gemma preexistente encontrado y cargado.');
      } catch (e) {
        AppLogger.info('No hay modelo preinstalado activo en memoria, verificando archivos: $e');
      }
      
      // PASO 2: Si no está activo en memoria, verificar si el archivo ya está descargado o instalarlo
      if (!modelAlreadyInstalled) {
        AppLogger.info('Verificando si el modelo ya está instalado localmente...');
        
        if (kIsWeb) {
          // Web: servido por nuestro servidor estático
          final absoluteUrl = kDebugMode 
              ? 'http://localhost:8081/gemma.litertlm'
              : Uri.base.resolve('models/gemma.litertlm').toString();
          
          final filename = Uri.parse(absoluteUrl).pathSegments.last;
          final isInstalled = await FlutterGemma.isModelInstalled(filename);
          
          if (isInstalled) {
            AppLogger.info('Web: El modelo ya está instalado, activándolo...');
          } else {
            AppLogger.info('Web: descargando desde $absoluteUrl');
          }
          
          await FlutterGemma.installModel(
            modelType: ModelType.gemma4,
            fileType: ModelFileType.litertlm,
          ).fromNetwork(absoluteUrl).install();
        } else {
          // Android / iOS: necesitamos una URL del modelo
          var mobileUrl = customMobileUrl ?? await _getSavedModelUrl();

          if (mobileUrl == null || mobileUrl.isEmpty) {
            _checkingDeviceSpecs = true;
            notifyListeners();

            try {
              final cap = await DeviceCapabilityService.check();
              _deviceCapability = cap;
              _checkingDeviceSpecs = false;
              notifyListeners();

              if (cap.canRunModel) {
                AppLogger.info('Dispositivo compatible. Usando URL hardcodeada del modelo.');
                mobileUrl = _defaultModelUrl;
              } else {
                throw Exception(
                  'INCOMPATIBLE: RAM ${cap.totalRAMGB?.toStringAsFixed(1) ?? "?"} GB | '
                  'Espacio ${cap.freeStorageGB.toStringAsFixed(1)} GB | '
                  'ARM64: ${cap.isArm64}',
                );
              }
            } catch (e) {
              _checkingDeviceSpecs = false;
              notifyListeners();
              if (e.toString().contains('INCOMPATIBLE')) rethrow;
              throw Exception('URL del modelo requerida. Introduce la URL de descarga.');
            }
          }
          
          final resolvedUrl = mobileUrl!;
          final filename = Uri.parse(resolvedUrl).pathSegments.last;
          final isInstalled = await FlutterGemma.isModelInstalled(filename);

          if (isInstalled) {
            AppLogger.info('Android/iOS: El modelo ya está instalado localmente, activándolo...');
            // Al estar ya instalado, install() se ejecuta instantáneamente sin descargar
            await FlutterGemma.installModel(
              modelType: ModelType.gemma4,
              fileType: ModelFileType.litertlm,
            ).fromNetwork(resolvedUrl).install();
          } else {
            AppLogger.info('Android/iOS: descargando desde $resolvedUrl');
            _isDownloading = true;
            _downloadProgress = 0.0;
            notifyListeners();

            await FlutterGemma.installModel(
              modelType: ModelType.gemma4,
              fileType: ModelFileType.litertlm,
            )
                .fromNetwork(resolvedUrl)
                .withProgress((progress) {
                  _downloadProgress = (progress / 100.0).clamp(0.0, 1.0);
                  notifyListeners();
                })
                .install();
            
            _isDownloading = false;
          }
        }
        
        // Cargar el modelo recién instalado/activado
        AppLogger.info('Cargando modelo activo en memoria...');
        _gemmaModel = await FlutterGemma.getActiveModel(
          maxTokens: 2048,
          preferredBackend: PreferredBackend.gpu,
        );
      }
      
      // PASO 3: Crear sesión de chat con contexto financiero
      final state = await getFinancialState();
      final systemPrompt = _buildSystemPrompt(state);
      
      _gemmaChat = await _gemmaModel!.createChat(
        systemInstruction: systemPrompt,
        modelType: ModelType.gemma4,
        isThinking: false,
        maxOutputTokens: 320,
      );
      _sessionAdapter = _FlutterGemmaSessionAdapter(_gemmaChat!);
      
      _gemmaInitialized = true;
      _useLocalSimulator = false;
      _isDownloading = false;
      
      // Persistir preferencia
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ai_use_local_simulator', false);
      
      AppLogger.success('Modelo Gemma cargado y listo para inferencia.');
    } catch (e) {
      AppLogger.warning('Modelo Gemma no disponible: $e');
      _gemmaError = e.toString();
      _gemmaInitialized = false;
      _isDownloading = false;
    } finally {
      _gemmaInitializing = false;
      _initCompleter?.complete();
      _initCompleter = null;
      notifyListeners();
    }
  }

  /// Obtiene la URL del modelo guardada por el usuario
  Future<String?> _getSavedModelUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ai_model_url');
  }

  /// Guarda una URL de modelo y dispara la descarga
  Future<void> setModelUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_model_url', url);
    await _tryLoadGemmaModel(customMobileUrl: url);
  }

  /// Construye el prompt del sistema con contexto financiero del usuario
  String _buildSystemPrompt(Map<String, dynamic> financialState) {
    String systemPrompt = 'Eres un asesor financiero personal de IA llamado "Moneo AI" dentro de una app de finanzas personales. '
        'Responde siempre en español, de forma clara, profesional y concisa. Usa viñetas y Markdown. '
        'No inventes datos financieros — usa exclusivamente los que te proporciono.\n\n'
        'ESTADO FINANCIERO DEL USUARIO:\n'
        '- Saldo disponible global: ${CurrencyHelper.format(financialState['availableBalance'])} ${CurrencyHelper.currencyCode}\n'
        '- Ingresos mensuales: ${CurrencyHelper.format(financialState['monthlyIncome'])} ${CurrencyHelper.currencyCode}\n'
        '- Gastos mensuales: ${CurrencyHelper.format(financialState['monthlyExpenses'])} ${CurrencyHelper.currencyCode}\n'
        '- Ahorros netos del mes: ${CurrencyHelper.format(financialState['monthlySavings'])} ${CurrencyHelper.currencyCode}\n'
        '- Metas del usuario: "$_userGoals"\n'
        '- Patrones de gasto: "$_userNotes"';
        
    if (_chatSummary.isNotEmpty) {
      systemPrompt += '\n- Resumen de la conversación anterior: "$_chatSummary"';
    }
    
    return systemPrompt;
  }

  // Cambiar entre simulador e IA local real
  Future<void> setSimulatorMode(bool useSimulator) async {
    _useLocalSimulator = useSimulator;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_use_local_simulator', useSimulator);
    
    if (!useSimulator && !_gemmaInitialized) {
      await _tryLoadGemmaModel();
    }
    notifyListeners();
  }

  // Actualizar metas de forma manual
  Future<void> updateUserGoals(String goals) async {
    _userGoals = goals;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_user_goals', goals);
    notifyListeners();
  }

  // Guardar historial en SharedPreferences
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatList = _messages.map((msg) => json.encode(msg.toJson())).toList();
      await prefs.setStringList('ai_chat_history', chatList);
    } catch (e) {
      AppLogger.error('Error guardando historial de chat', error: e);
    }
  }

  // Limpiar historial
  Future<void> clearHistory() async {
    _messages = [
      ChatMessage(
        role: 'model',
        content: 'Historial de chat reiniciado. ¿En qué puedo ayudarte hoy respecto a tus finanzas?',
        timestamp: DateTime.now(),
      )
    ];
    
    _chatSummary = '';
    _lastSummaryCount = 0;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ai_chat_summary');
    await prefs.setInt('ai_last_summary_count', 0);
    
    // Recrear la sesión de chat si Gemma está activo
    try {
      await _sessionAdapter?.close();
    } catch (_) {}
    _sessionAdapter = null;
    _gemmaChat = null;

    if (testSessionCreator != null) {
      try {
        final state = await getFinancialState();
        _sessionAdapter = await testSessionCreator!(_buildSystemPrompt(state));
      } catch (e) {
        AppLogger.warning('Error recreando sesión de chat de prueba: $e');
      }
    } else if (_gemmaInitialized && _gemmaModel != null) {
      try {
        final state = await getFinancialState();
        _gemmaChat = await _gemmaModel!.createChat(
          systemInstruction: _buildSystemPrompt(state),
          modelType: ModelType.gemma4,
          isThinking: false,
          maxOutputTokens: 320,
        );
        _sessionAdapter = _FlutterGemmaSessionAdapter(_gemmaChat!);
      } catch (e) {
        AppLogger.warning('Error recreando sesión de chat: $e');
      }
    }
    
    await _saveHistory();
    notifyListeners();
  }

  // --- HOOKS & TOOLS: Acceso directo a base de datos local (Hive y SharedPrefs) ---

  // Obtener balance general y detalles de cuentas
  Future<Map<String, dynamic>> getFinancialState() async {
    final prefs = await SharedPreferences.getInstance();
    double availableBalance = prefs.getDouble('available_balance') ?? 0.0;
    
    List<String>? accountsData = prefs.getStringList('accounts');
    List<Map<String, dynamic>> accounts = [];
    if (accountsData != null) {
      accounts = accountsData
          .map((acc) => json.decode(acc) as Map<String, dynamic>)
          .toList();
    }

    // Calcular ingresos y gastos del mes actual
    final box = Hive.isBoxOpen('data')
        ? Hive.box<Add_data>('data')
        : await Hive.openBox<Add_data>('data');
    final now = DateTime.now();
    double monthlyIncome = 0.0;
    double monthlyExpenses = 0.0;

    for (var tx in box.values) {
      if (tx.safeDate.month == now.month && tx.safeDate.year == now.year) {
        double amt = double.tryParse(tx.safeAmount) ?? 0.0;
        if (tx.safeType == 'Income') {
          monthlyIncome += amt;
        } else if (tx.safeType == 'Expenses') {
          monthlyExpenses += amt;
        }
      }
    }

    return {
      'availableBalance': availableBalance,
      'accounts': accounts,
      'monthlyIncome': monthlyIncome,
      'monthlyExpenses': monthlyExpenses,
      'monthlySavings': monthlyIncome - monthlyExpenses,
    };
  }

  // Análisis cognitivo: Aprender los patrones del usuario
  Future<void> updateLearnedPatterns() async {
    try {
      final state = await getFinancialState();
      final box = Hive.isBoxOpen('data')
          ? Hive.box<Add_data>('data')
          : await Hive.openBox<Add_data>('data');
      
      double totalExpenses = state['monthlyExpenses'];
      double totalIncome = state['monthlyIncome'];
      
      // Agrupar gastos por categoría
      Map<String, double> categorySums = {};
      int expenseCount = 0;
      double maxExpense = 0.0;
      String maxExpenseItem = '';

      for (var tx in box.values) {
        if (tx.safeType == 'Expenses') {
          double amt = double.tryParse(tx.safeAmount) ?? 0.0;
          categorySums[tx.safeCategory] = (categorySums[tx.safeCategory] ?? 0) + amt;
          expenseCount++;
          if (amt > maxExpense) {
            maxExpense = amt;
            maxExpenseItem = tx.safeDetail.isNotEmpty ? tx.safeDetail : tx.safeCategory;
          }
        }
      }

      // Encontrar la categoría más costosa
      String topCategory = 'Ninguna';
      double topCategoryAmount = 0.0;
      categorySums.forEach((cat, amt) {
        if (amt > topCategoryAmount) {
          topCategoryAmount = amt;
          topCategory = cat;
        }
      });

      // Evaluar salud financiera
      String ratioMessage = '';
      double savingsRatio = totalIncome > 0 ? ((totalIncome - totalExpenses) / totalIncome) * 100 : 0.0;
      
      String ratioStatus = 'none';
      if (savingsRatio > 20) {
        ratioStatus = 'excellent';
        ratioMessage = 'Excelente capacidad de ahorro (${savingsRatio.toStringAsFixed(1)}%).';
      } else if (savingsRatio > 5) {
        ratioStatus = 'moderate';
        ratioMessage = 'Capacidad de ahorro moderada (${savingsRatio.toStringAsFixed(1)}%). Se sugiere recortar gastos hormiga.';
      } else if (savingsRatio <= 0 && totalIncome > 0) {
        ratioStatus = 'deficit';
        ratioMessage = 'Alerta de déficit financiero. Estás gastando más de lo que ingresas.';
      } else {
        ratioStatus = 'none';
        ratioMessage = 'Aún no posees registros de ingresos suficientes este mes para evaluar.';
      }

      // Guardar en campos privados
      _savingsRatio = savingsRatio;
      _topCategory = topCategory;
      _topCategoryAmount = topCategoryAmount;
      _maxExpense = maxExpense;
      _maxExpenseItem = maxExpenseItem;
      _expenseCount = expenseCount;
      _ratioStatus = ratioStatus;
      _ratioMessageText = ratioMessage;

      // Crear reporte estructurado del aprendizaje
      _userNotes = '### Perfil Cognitivo AI (Aprendido de tus patrones)\n'
          '* **Salud Financiera:** $ratioMessage\n'
          '* **Categoría con mayor gasto:** "$topCategory" (${CurrencyHelper.format(topCategoryAmount)} ${CurrencyHelper.currencyCode})\n'
          '* **Mayor compra realizada:** "$maxExpenseItem" (${CurrencyHelper.format(maxExpense)} ${CurrencyHelper.currencyCode})\n'
          '* **Número de transacciones registradas:** $expenseCount egresos en tu historial.\n'
          '* **Tasa de Ahorro:** ${savingsRatio > 0 ? savingsRatio.toStringAsFixed(1) : 0}%\n'
          '* **Ajuste automático:** El modelo prioriza proteger tu saldo actual y reducir los egresos en "$topCategory".';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_user_notes', _userNotes);
    } catch (e) {
      AppLogger.error('Error actualizando patrones de aprendizaje', error: e);
    }
  }

  // --- TOOL: Analizar viabilidad de compra ---
  Future<Map<String, dynamic>> analyzePurchase(String itemName, double cost) async {
    final state = await getFinancialState();
    double balance = state['availableBalance'];
    double monthlySavings = state['monthlySavings'];
    double monthlyIncome = state['monthlyIncome'];

    String status = 'Aprobado';
    String description = '';
    
    if (cost > balance) {
      status = 'Crítico';
      description = 'No recomendado. El costo de "$itemName" (${CurrencyHelper.format(cost)} ${CurrencyHelper.currencyCode}) supera tu saldo total disponible (${CurrencyHelper.format(balance)} ${CurrencyHelper.currencyCode}). Comprarlo te dejaría en saldo negativo.';
    } else if (cost > (balance * 0.5)) {
      status = 'Cuidado';
      description = 'Riesgo Alto. Comprar "$itemName" por ${CurrencyHelper.format(cost)} ${CurrencyHelper.currencyCode} consumirá más del 50% de todo tu capital disponible (${CurrencyHelper.format(balance)} ${CurrencyHelper.currencyCode}). Se sugiere posponer la compra.';
    } else if (monthlySavings > 0 && cost > monthlySavings) {
      status = 'Cuidado';
      description = 'Cuidado. El artículo equivale a más de un mes entero de tus ahorros netos actuales (${CurrencyHelper.format(monthlySavings)} ${CurrencyHelper.currencyCode}/mes). Tendrás que ahorrar durante más de un mes para recuperarte.';
    } else {
      status = 'Aprobado';
      description = '¡Aprobado! Tu situación financiera actual soporta la compra de "$itemName" (${CurrencyHelper.format(cost)} ${CurrencyHelper.currencyCode}). Representa un porcentaje menor de tu capital disponible y se ajusta a tus ahorros.';
    }

    if (monthlyIncome > 0) {
      double dailyIncome = monthlyIncome / 30;
      double daysOfWork = cost / dailyIncome;
      description += '\n\n*Nota matemática: Esta compra equivale a **${daysOfWork.toStringAsFixed(1)} días de tus ingresos** diarios promedio.*';
    }

    return {
      'status': status,
      'description': description,
      'cost': cost,
      'itemName': itemName,
    };
  }

  /// Cancela la generación activa de Gemma si está en curso.
  Future<void> cancelGeneration() async {
    if (!_isGenerating) return;
    _generationCancelled = true;
    try {
      await _sessionAdapter?.stopGeneration();
    } catch (e) {
      AppLogger.warning('Error deteniendo generación Gemma: $e');
    }
    notifyListeners();
  }

  @visibleForTesting
  Future<void> resetGemmaSessionForTests() async {
    try {
      await _sessionAdapter?.close();
    } catch (_) {}
    _sessionAdapter = null;
    _gemmaChat = null;
    _gemmaInitialized = false;
    _isGenerating = false;
    _generationCancelled = false;
  }

  // --- ENVIAR MENSAJE Y PROCESAR RESPUESTA ---
  Future<void> sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty || _isGenerating) return;

    _isGenerating = true;
    _generationCancelled = false;

    try {

    // 1. Agregar mensaje del usuario a la lista
    final userChat = ChatMessage(role: 'user', content: userMessage, timestamp: DateTime.now());
    _messages.add(userChat);
    notifyListeners();
    await _saveHistory();

    // Comprobar si necesitamos hacer un resumen interno
    try {
      int messagesOutsideWindow = _messages.length - 8;
      if (messagesOutsideWindow - _lastSummaryCount >= 7) {
        await _generateInternalSummary();
      }
    } catch (e) {
      AppLogger.error('Error al generar el resumen interno', error: e);
    }

    // 2. Analizar transacciones para tener datos frescos
    await updateLearnedPatterns();
    final financialState = await getFinancialState();

    // Detectar categorías de SharedPreferences
    String categoriesContext = '';
    final lowerMsg = userMessage.toLowerCase();
    if (lowerMsg.contains('categoria') || lowerMsg.contains('categorias') || lowerMsg.contains('rubro') || lowerMsg.contains('rubros') || lowerMsg.contains('egreso') || lowerMsg.contains('ingreso')) {
      categoriesContext = await _getCategoriesContext();
    }

    // Detectar si el usuario quiere crear/sugerir categorías
    List<Map<String, dynamic>>? suggestedCategories;
    if (lowerMsg.contains('crear') || lowerMsg.contains('suger') || lowerMsg.contains('recomen') || lowerMsg.contains('propon') || lowerMsg.contains('propón')) {
      if (lowerMsg.contains('categoria') || lowerMsg.contains('categoría') || lowerMsg.contains('categorias') || lowerMsg.contains('categorías') || lowerMsg.contains('rubro') || lowerMsg.contains('rubros')) {
        String type = 'Expenses';
        if (lowerMsg.contains('ingreso') || lowerMsg.contains('ingresos')) {
          type = 'Income';
        }
        
        // Determinar número de categorías a sugerir
        int count = 3;
        final RegExp numberRegex = RegExp(r'\b([1-9])\b');
        final match = numberRegex.firstMatch(lowerMsg);
        if (match != null) {
          count = int.tryParse(match.group(1)!) ?? 3;
        }
        
        suggestedCategories = await generateCategorySuggestions(type: type, limit: count);
      }
    }

    // Detectar si el usuario quiere registrar una transacción
    final suggestedTransactions = await detectAndGenerateTransactionSuggestions(userMessage);

    // Detectar obligaciones y deudas
    String obligationsContext = '';
    if (lowerMsg.contains('obligacion') || lowerMsg.contains('obligaciones') || lowerMsg.contains('deuda') || lowerMsg.contains('deudas') || lowerMsg.contains('pago') || lowerMsg.contains('pagar') || lowerMsg.contains('responsabilidad') || lowerMsg.contains('responsabilidades')) {
      obligationsContext = await _getObligationsContext();
    }

    // Detectar y ejecutar consultas a la base de datos de transacciones (herramienta de IA / Hook)
    final queryAnalysis = await _detectAndExecuteQuery(userMessage);

    // 3. Detectar si el usuario está preguntando por una compra específica
    Map<String, dynamic>? purchaseAnalysis;
    final RegExp priceRegex = RegExp(r'(?:comprar|compra)\s+([a-zA-Záéíóúñ\s]+)\s+(?:por|de|cuesta|a)?\s*\$?\s*([0-9]+(?:\.[0-9]+)?)', caseSensitive: false);
    final match = priceRegex.firstMatch(userMessage);

    if (match != null) {
      String item = match.group(1)!.trim();
      double? price = double.tryParse(match.group(2)!.trim());
      if (price != null && price > 0) {
        purchaseAnalysis = await analyzePurchase(item, price);
      }
    }

    // 4. Generar respuesta
    String responseText = '';
    
    if (suggestedCategories != null && suggestedCategories.isNotEmpty) {
      final typeLabel = suggestedCategories.first['type'] == 'Income' ? 'ingresos' : 'gastos';
      String listText = suggestedCategories.map((c) => '- **${c['name']}**').join('\n');
      responseText = '### 💡 Sugerencias de Categorías de ${typeLabel == "Income" ? "Ingresos" : "Gastos"}\n\n'
          'He analizado tus categorías actuales. Para ayudarte a organizar mejor tus finanzas, te sugiero crear las siguientes categorías:\n\n'
          '$listText\n\n'
          'Usa las tarjetas interactivas de abajo para aceptarlas, editarlas o rechazarlas.';
    } else if (suggestedTransactions != null && suggestedTransactions.isNotEmpty) {
      final tx = suggestedTransactions.first;
      final typeLabel = tx['type'] == 'Income' ? 'Ingreso' : 'Gasto';
      final formattedAmt = CurrencyHelper.format(tx['amount']);
      final dateLabel = _formatDate(DateTime.parse(tx['date']));
      
      responseText = '### 📝 Propuesta de Registro de $typeLabel\n\n'
          'Entendido, he preparado la transacción para tu confirmación:\n\n'
          '*   **Tipo**: $typeLabel\n'
          '*   **Monto**: $formattedAmt ${CurrencyHelper.currencyCode}\n'
          '*   **Detalle**: "${tx['detail']}"\n'
          '*   **Categoría**: *${tx['category']}*\n'
          '*   **Fecha**: $dateLabel\n'
          '*   **Cuenta**: ${tx['account']} ${tx['accountInferred'] == true ? "*(sugerida)*" : ""}\n\n'
          'Confirma si los datos son correctos usando las tarjetas de abajo para guardarla, editarla o rechazarla.';
    } else if (!_useLocalSimulator) {
      if (testSessionCreator != null) {
        if (_sessionAdapter == null) {
          final systemPrompt = _buildSystemPrompt(financialState);
          _sessionAdapter = await testSessionCreator!(systemPrompt);
        }
        _gemmaInitialized = true;
      } else if (!_gemmaInitialized || _sessionAdapter == null) {
        AppLogger.info('Gemma no inicializado, intentando cargar sobre la marcha...');
        await _tryLoadGemmaModel();
        if (_gemmaInitialized && _gemmaModel != null && _sessionAdapter == null) {
          final systemPrompt = _buildSystemPrompt(financialState);
          _gemmaChat = await _gemmaModel!.createChat(
            systemInstruction: systemPrompt,
            modelType: ModelType.gemma4,
            isThinking: false,
            maxOutputTokens: 320,
          );
          _sessionAdapter = _FlutterGemmaSessionAdapter(_gemmaChat!);
        }
      }

      if (_gemmaInitialized && _sessionAdapter != null) {
        // --- RESPUESTA REAL USANDO SESIÓN PERSISTENTE + STREAMING GEMMA ---
        try {
          String enrichedPrompt = userMessage;
          
          if (purchaseAnalysis != null) {
            enrichedPrompt += '\n\n[CONTEXTO DE HERRAMIENTA INTERNA - Análisis de compra]\n'
                'Artículo: "${purchaseAnalysis['itemName']}", Costo: ${CurrencyHelper.format(purchaseAnalysis['cost'])} ${CurrencyHelper.currencyCode}\n'
                'Diagnóstico: ${purchaseAnalysis['status']} — ${purchaseAnalysis['description']}\n'
                '[Usa este análisis como base para tu respuesta]';
          }

          if (categoriesContext.isNotEmpty) {
            enrichedPrompt += '\n\n[CONTEXTO DE HERRAMIENTA INTERNA - Categorías]\n$categoriesContext';
          }

          if (obligationsContext.isNotEmpty) {
            enrichedPrompt += '\n\n[CONTEXTO DE HERRAMIENTA INTERNA - Obligaciones]\n$obligationsContext';
          }

          if (queryAnalysis != null) {
            final queryCtx = _formatQueryResultContext(queryAnalysis);
            enrichedPrompt += '\n\n$queryCtx';
          }
          
          await _sessionAdapter!.addUserMessage(enrichedPrompt);

          final modelIndex = _messages.length;
          _messages.add(
            ChatMessage(
              role: 'model',
              content: '',
              timestamp: DateTime.now(),
              categorySuggestions: suggestedCategories,
              transactionSuggestions: suggestedTransactions,
            ),
          );
          notifyListeners();

          final buffer = StringBuffer();
          final stopwatch = Stopwatch()..start();

          await for (final token in _sessionAdapter!.generateResponseStream()) {
            if (_generationCancelled) break;
            buffer.write(token);
            if (stopwatch.elapsedMilliseconds >= 60) {
              _messages[modelIndex] = ChatMessage(
                role: 'model',
                content: buffer.toString(),
                timestamp: _messages[modelIndex].timestamp,
                categorySuggestions: suggestedCategories,
                transactionSuggestions: suggestedTransactions,
              );
              notifyListeners();
              stopwatch.reset();
            }
          }

          if (buffer.isNotEmpty) {
            responseText = buffer.toString();
          } else if (_generationCancelled) {
            responseText = '*(Generación cancelada.)*';
          } else {
            responseText = 'No pude generar una respuesta en este momento. Intenta de nuevo.';
          }

          _messages[modelIndex] = ChatMessage(
            role: 'model',
            content: responseText,
            timestamp: _messages[modelIndex].timestamp,
            categorySuggestions: suggestedCategories,
            transactionSuggestions: suggestedTransactions,
          );
          await _saveHistory();
          return;
        } catch (e) {
          AppLogger.error('Error en inferencia Gemma (replegando a simulador)', error: e);
          responseText = '*(Nota: Ocurrió un error con Gemma IA. El simulador financiero respondió por seguridad.)*\n\n';
          responseText += await _generateSimulatorResponse(userMessage, financialState, purchaseAnalysis, queryAnalysis);
          if (_messages.isNotEmpty && _messages.last.role == 'model' && _messages.last.content.isEmpty) {
            _messages.removeLast();
          }
        }
      } else {
        // No está inicializado — dar respuesta de error con instrucciones claras
        if (kIsWeb) {
          responseText = '⚠️ **Motor Gemma IA no disponible en Web.**\n\n'
              'Asegúrate de que el servidor de modelos esté corriendo (`make web`) y '
              'que el archivo `models/gemma.litertlm` esté accesible en el puerto 8081.\n\n'
              '_Usando el simulador financiero mientras tanto..._\n\n'
              '${await _generateSimulatorResponse(userMessage, financialState, purchaseAnalysis, queryAnalysis)}';
        } else {
          responseText = '⚠️ **Gemma IA no configurado para este dispositivo.**\n\n'
              'El modelo (2.5 GB) debe descargarse una sola vez. Para configurarlo:\n\n'
              '1. Toca el ícono ⚙️ en la esquina superior de esta pantalla\n'
              '2. Ingresa la URL de descarga de tu modelo `.litertlm`\n'
              '3. Espera a que se complete la descarga (~5-20 min según tu red)\n\n'
              '_Mientras tanto, el simulador financiero está activo y funcional._\n\n'
              '${await _generateSimulatorResponse(userMessage, financialState, purchaseAnalysis, queryAnalysis)}';
        }
      }
    } else {
      // --- RESPUESTA SIMULADA BASADA EN REGLAS FINANCIERAS ---
      await Future.delayed(const Duration(milliseconds: 800));
      responseText = await _generateSimulatorResponse(userMessage, financialState, purchaseAnalysis, queryAnalysis);
    }

    // 5. Detectar aprendizaje implícito en el mensaje del usuario
    final RegExp goalKeywords = RegExp(r'(?:quiero|mi meta es|planeo|ahorrar para)\s+([a-zA-Záéíóúñ\s]{3,30})', caseSensitive: false);
    final goalMatch = goalKeywords.firstMatch(userMessage);
    if (goalMatch != null) {
      String extractedGoal = goalMatch.group(1)!.trim();
      await updateUserGoals('Ahorrar para: $extractedGoal');
    }

    // 6. Agregar respuesta del modelo a la lista
    final modelChat = ChatMessage(
      role: 'model',
      content: responseText,
      timestamp: DateTime.now(),
      categorySuggestions: suggestedCategories,
      transactionSuggestions: suggestedTransactions,
    );
    _messages.add(modelChat);
    await _saveHistory();
    } finally {
      _isGenerating = false;
      _generationCancelled = false;
      notifyListeners();
    }
  }

  /// Genera una respuesta usando el motor de reglas financieras local (simulador) con acceso a base de datos
  Future<String> _generateSimulatorResponse(
    String userMessage,
    Map<String, dynamic> financialState,
    Map<String, dynamic>? purchaseAnalysis,
    Map<String, dynamic>? queryAnalysis,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    if (purchaseAnalysis != null) {
      String statusEmoji = purchaseAnalysis['status'] == 'Aprobado' 
          ? '✅ **[APROBADO]**' 
          : purchaseAnalysis['status'] == 'Cuidado' 
              ? '⚠️ **[PRECAUCIÓN]**' 
              : '🚨 **[NO RECOMENDADO]**';
      
      return '$statusEmoji\n\n'
          'He analizado tu solicitud de compra para **"${purchaseAnalysis['itemName']}"** por un valor de **${CurrencyHelper.format(purchaseAnalysis['cost'])} ${CurrencyHelper.currencyCode}**.\n\n'
          '${purchaseAnalysis['description']}\n\n'
          '### 💳 Resumen de tu Estado Financiero:\n'
          '*   **Saldo disponible global:** ${CurrencyHelper.format(financialState['availableBalance'])} ${CurrencyHelper.currencyCode}\n'
          '*   **Ingresos mensuales:** ${CurrencyHelper.format(financialState['monthlyIncome'])} ${CurrencyHelper.currencyCode}\n'
          '*   **Gastos mensuales:** ${CurrencyHelper.format(financialState['monthlyExpenses'])} ${CurrencyHelper.currencyCode}\n\n'
          '¿Deseas que busquemos formas de reducir tus gastos habituales para ahorrar más rápido para este artículo?';
    }

    if (queryAnalysis != null) {
      final int count = queryAnalysis['count'] ?? 0;
      final double totalSum = queryAnalysis['totalSum'] ?? 0.0;
      final double average = queryAnalysis['average'] ?? 0.0;
      final String period = queryAnalysis['searchedPeriod'] ?? 'este mes';
      final String? cat = queryAnalysis['searchedCategory'];
      final String? type = queryAnalysis['searchedType'];

      String response = '### 📊 Reporte de Transacciones ($period)\n\n';
      if (count == 0) {
        response += 'No encontré ninguna transacción registrada';
        if (cat != null) response += ' en la categoría **"$cat"**';
        if (type != null) response += ' del tipo **"${type == 'Income' ? 'Ingreso' : 'Egreso'}"**';
        response += ' durante este período.';
        return response;
      }

      response += 'He consultado tu historial y encontré **$count transacciones**:\n\n'
          '*   **Monto total:** ${CurrencyHelper.format(totalSum)} ${CurrencyHelper.currencyCode}\n'
          '*   **Promedio por transacción:** ${CurrencyHelper.format(average)} ${CurrencyHelper.currencyCode}\n'
          '*   **Monto máximo:** ${CurrencyHelper.format(queryAnalysis['maxAmount'])} ${CurrencyHelper.currencyCode}\n\n'
          '**Detalles de los registros encontrados:**\n';

      final List<dynamic> txs = queryAnalysis['transactions'];
      for (var tx in txs.take(5)) {
        final txType = tx['type'] == 'Income' ? '🟢 Ingreso' : '🔴 Gasto';
        response += '*   ${_formatDate(tx['date'])}: $txType de **${CurrencyHelper.format(tx['amount'])}** en *${tx['category']}* - "${tx['detail']}"\n';
      }
      if (txs.length > 5) {
        response += '*   *... y ${txs.length - 5} transacciones adicionales en el historial.*\n';
      }
      return response;
    }

    // Procesamiento inteligente de intenciones
    final lowerMsg = userMessage.toLowerCase().trim();
    
    if (lowerMsg.contains('categoria') || lowerMsg.contains('categorias') || lowerMsg.contains('rubro') || lowerMsg.contains('rubros')) {
      final expenseCats = prefs.getStringList('expense_categories') ?? [];
      final incomeCats = prefs.getStringList('income_categories') ?? [];
      return '### 🗂️ Categorías de Ingresos y Egresos\n\n'
          'Aquí tienes la lista de categorías configuradas en tu aplicación:\n\n'
          '**🔴 Categorías de Egresos:**\n'
          '${expenseCats.map((c) => '*   $c').join('\n')}\n\n'
          '**🟢 Categorías de Ingresos:**\n'
          '${incomeCats.map((c) => '*   $c').join('\n')}\n\n'
          '¿Te gustaría saber cuánto has gastado en alguna de estas categorías este mes?';
    }
    else if (lowerMsg.contains('obligacion') || lowerMsg.contains('obligaciones') || lowerMsg.contains('deuda') || lowerMsg.contains('deudas') || lowerMsg.contains('responsabilidad') || lowerMsg.contains('responsabilidades') || lowerMsg.contains('pago') || lowerMsg.contains('pagar')) {
      final obligationsCtx = await _getObligationsContext();
      return '### 📅 Tus Obligaciones y Deudas\n\n'
          'Aquí está el estado actual de tus obligaciones programadas:\n\n'
          '$obligationsCtx\n\n'
          '¿Quieres que calculemos cómo impactarán estos pagos en tu saldo de fin de mes?';
    }
    else if (lowerMsg == 'hola' || lowerMsg == 'buenas' || lowerMsg == 'buenos dias' || lowerMsg == 'que tal' || lowerMsg == 'hola!') {
      return '¡Hola! 👋 Qué gusto saludarte. Como tu asesor financiero de IA, he estado analizando tus datos en tiempo real.\n\n'
          'Actualmente tienes **${CurrencyHelper.format(financialState['availableBalance'])} ${CurrencyHelper.currencyCode}** disponibles en total.\n\n'
          '¿En qué te gustaría que nos enfoquemos hoy?\n'
          '*   📊 *¿Cómo van mis gastos e ingresos de este mes?*\n'
          '*   📅 *¿Qué obligaciones o deudas tengo pendientes hoy?*\n'
          '*   🛍️ *¿Es buena idea realizar una compra?* (ej: *¿debería comprar un celular de 400 dólares?*)\n'
          '*   💡 *Dame sugerencias para ahorrar o salir de deudas.*';
    } 
    else if (lowerMsg.contains('ayuda') || lowerMsg.contains('que haces') || lowerMsg.contains('como funcionas')) {
      return '### 🤖 ¿Qué puedo hacer por ti?\n\n'
          'Como tu asistente financiero integrado, tengo acceso a tus balances y cuentas en la app:\n\n'
          '1.  **Analizar Compras:** Si estás pensando en adquirir algo, pregúntame: *¿Debería comprar [artículo] por [precio]?* y evaluaré su impacto en tu presupuesto.\n'
          '2.  **Reporte de Saldos:** Pregúntame sobre tus *saldos* o *cuentas* para ver dónde tienes dinero.\n'
          '3.  **Auditoría de Gastos:** Evaluamos en qué categorías estás gastando de más este mes.\n'
          '4.  **Aprender de tus Metas:** Escríbeme algo como *quiero ahorrar para un viaje* y adaptaré mis consejos a esa meta.';
    }
    else if (lowerMsg.contains('saldo') || lowerMsg.contains('cuenta') || lowerMsg.contains('tengo') || lowerMsg.contains('dinero')) {
      return '### 💰 Reporte de tus Cuentas Activas\n\n'
          'Actualmente cuentas con un total disponible de **${CurrencyHelper.format(financialState['availableBalance'])} ${CurrencyHelper.currencyCode}**.\n\n'
          '**Distribución de tus saldos:**\n'
          '${_formatAccountsList(financialState['accounts'])}\n\n'
          '¿Te gustaría analizar si estás distribuyendo de forma correcta tus ingresos este mes?';
    } 
    else if (lowerMsg.contains('gasto') || lowerMsg.contains('ahorro') || lowerMsg.contains('presupuesto') || lowerMsg.contains('patrones') || lowerMsg.contains('habito') || lowerMsg.contains('cómo estoy')) {
      return '### 🔍 Diagnóstico de Hábitos y Consumos\n\n'
          '$_userNotes\n\n'
          '💡 **Consejo Personalizado:** Tu tasa de ahorro determina tu velocidad para cumplir metas. Si quieres mejorarla, te sugiero poner un límite semanal estricto a las compras secundarias.';
    } 
    else if (lowerMsg.contains('meta') || lowerMsg.contains('ahorrar para')) {
      return '### 🎯 Tus Metas de Ahorro\n\n'
          'Tus objetivos de ahorro actuales registrados en mi base de datos:\n\n'
          '*"$_userGoals"*\n\n'
          'Si deseas cambiar este objetivo, solo dime algo como: *Mi meta es [tu nuevo objetivo]*. Adaptaré todos mis análisis de compra futuros a este plan.';
    }
    else if (lowerMsg.contains('comprar') || lowerMsg.contains('compra') || lowerMsg.contains('adquirir')) {
      return '¡Excelente! Puedo ayudarte a evaluar la viabilidad de esa compra. Sin embargo, para hacer el cálculo matemático de tu presupuesto, necesito saber **el costo aproximado** del artículo.\n\n'
          'Por favor, pregúntame de esta forma:\n'
          '*   *¿Debería comprar una televisión de 450 dólares?*\n'
          '*   *Quiero comprar tenis de 120 dólares, ¿es buena idea?*';
    }
    else if (lowerMsg == 'gracias' || lowerMsg == 'gracias!' || lowerMsg == 'ok' || lowerMsg == 'entendido' || lowerMsg == 'perfecto') {
      return '¡Con mucho gusto! 😊 Estoy aquí para ayudarte a tomar decisiones financieras inteligentes. Si quieres simular otra compra o revisar tu presupuesto, solo escribe.';
    }
    else {
      return 'Entiendo tu consulta. Como tu asesor financiero inteligente en tiempo real, veo que tienes un balance global de **${CurrencyHelper.format(financialState['availableBalance'])} ${CurrencyHelper.currencyCode}**.\n\n'
          'Para darte una asesoría más detallada, puedes hacerme preguntas específicas como:\n'
          '*   *¿Cómo van mis gastos de este mes?*\n'
          '*   *¿Debería comprar una mochila por 45 dólares?*\n'
          '*   *¿Cuál es mi mayor categoría de gasto?*';
    }
  }

  // Obtener gastos de este mes agrupados por categoría
  Map<String, double> getCategoryExpenses() {
    if (!Hive.isBoxOpen('data')) return {};
    final box = Hive.box<Add_data>('data');
    final now = DateTime.now();
    Map<String, double> categorySums = {};
    
    for (var tx in box.values) {
      if (tx.safeType == 'Expenses' && tx.safeDate.month == now.month && tx.safeDate.year == now.year) {
        double amt = double.tryParse(tx.safeAmount) ?? 0.0;
        categorySums[tx.safeCategory] = (categorySums[tx.safeCategory] ?? 0.0) + amt;
      }
    }
    return categorySums;
  }

  // Dar formato Markdown legible a la lista de cuentas
  String _formatAccountsList(List<dynamic> accounts) {
    if (accounts.isEmpty) return '*   No tienes cuentas registradas aún.';
    return accounts.map((acc) {
      final title = acc['title'] ?? 'Sin nombre';
      final subtitle = acc['subtitle'] ?? 'General';
      final balance = double.tryParse(acc['balance']?.toString() ?? '0') ?? 0.0;
      return '*   **$title** (*$subtitle*): ${CurrencyHelper.format(balance)} ${CurrencyHelper.currencyCode}';
    }).join('\n');
  }

  // --- HERRAMIENTAS Y HOOKS ADICIONALES ---

  Future<String> _getCategoriesContext() async {
    final prefs = await SharedPreferences.getInstance();
    final expenseCategories = prefs.getStringList('expense_categories') ?? [];
    final incomeCategories = prefs.getStringList('income_categories') ?? [];
    
    return 'CATEGORÍAS DISPONIBLES EN LA APP:\n'
        '- Categorías de Egreso/Gasto: ${expenseCategories.join(", ")}\n'
        '- Categorías de Ingreso: ${incomeCategories.join(", ")}';
  }

  Future<String> _getObligationsContext() async {
    try {
      await ResponsibilityService.init();
      final all = ResponsibilityService.getAllResponsibilities();
      if (all.isEmpty) {
        return 'OBLIGACIONES PENDIENTES:\n- El usuario no tiene obligaciones creadas aún.';
      }

      final now = DateTime.now();
      String contextStr = 'OBLIGACIONES / DEUDAS REGISTRADAS:\n';
      for (var r in all) {
        final expected = r.getAmountForDate(now.month, now.year);
        final paid = r.getPaidAmountInCycle(now.month, now.year);
        final remaining = (expected - paid).clamp(0.0, double.infinity);
        final status = r.isPaidInMonth(now.month, now.year) ? 'PAGADO' : 'PENDIENTE';

        contextStr += '- **${r.safeName}** | Categoría: ${r.safeCategory} | Frecuencia: ${r.safeFrequency} | '
            'Cuota: ${CurrencyHelper.format(expected)} | Pagado: ${CurrencyHelper.format(paid)} | '
            'Resta: ${CurrencyHelper.format(remaining)} | Estado este mes: $status | Día vencimiento: ${r.safeDueDay}\n';
      }
      return contextStr;
    } catch (e) {
      AppLogger.error('Error cargando obligaciones para contexto', error: e);
      return 'OBLIGACIONES:\n- Error al cargar las obligaciones desde la base de datos.';
    }
  }

  Future<Map<String, dynamic>?> _detectAndExecuteQuery(String userMessage) async {
    final lowerMsg = userMessage.toLowerCase();
    
    // 1. Detectar si el usuario está preguntando por transacciones
    bool asksAboutTransactions = false;
    final transactionKeywords = [
      'gasto', 'gastos', 'gaste', 'gasté',
      'ingreso', 'ingresos', 'ingresé', 'ingrese',
      'transaccion', 'transacciones', 'movimiento', 'movimientos',
      'promedio', 'cuánto', 'cuanto', 'suma', 'total', 'historial'
    ];
    for (var keyword in transactionKeywords) {
      if (lowerMsg.contains(keyword)) {
        asksAboutTransactions = true;
        break;
      }
    }

    if (!asksAboutTransactions) return null;

    // 2. Parsear Tipo
    String? type;
    if (lowerMsg.contains('ingreso') || lowerMsg.contains('ingresé') || lowerMsg.contains('ingrese')) {
      type = 'Income';
    } else if (lowerMsg.contains('gasto') || lowerMsg.contains('gasté') || lowerMsg.contains('gaste')) {
      type = 'Expenses';
    }

    // 3. Parsear Rango de Fechas
    DateTime? startDate;
    DateTime? endDate;
    final now = DateTime.now();

    if (lowerMsg.contains('mes pasado')) {
      startDate = DateTime(now.year, now.month - 1, 1);
      endDate = DateTime(now.year, now.month, 0, 23, 59, 59);
    } else if (lowerMsg.contains('esta semana')) {
      startDate = now.subtract(Duration(days: now.weekday - 1));
      startDate = DateTime(startDate.year, startDate.month, startDate.day);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (lowerMsg.contains('hoy')) {
      startDate = DateTime(now.year, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (lowerMsg.contains('año pasado')) {
      startDate = DateTime(now.year - 1, 1, 1);
      endDate = DateTime(now.year - 1, 12, 31, 23, 59, 59);
    } else if (lowerMsg.contains('este año')) {
      startDate = DateTime(now.year, 1, 1);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (lowerMsg.contains('todo') || lowerMsg.contains('siempre') || lowerMsg.contains('historial') || lowerMsg.contains('completo')) {
      // Sin límites de fecha
    } else {
      // Por defecto: este mes
      startDate = DateTime(now.year, now.month, 1);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }

    // 4. Parsear Categoría
    String? matchedCategory;
    final prefs = await SharedPreferences.getInstance();
    final expenseCats = prefs.getStringList('expense_categories') ?? [];
    final incomeCats = prefs.getStringList('income_categories') ?? [];
    final allCats = [...expenseCats, ...incomeCats];

    for (var cat in allCats) {
      if (lowerMsg.contains(_normalizeString(cat))) {
        matchedCategory = cat;
        break;
      }
    }

    // 5. Parsear Palabra Clave en Detalles (entre comillas)
    String? keyword;
    final quoteRegex = RegExp(r'["\u201c\u201d]([^"\u201c\u201d]+)["\u201c\u201d]');
    final quoteMatch = quoteRegex.firstMatch(userMessage);
    if (quoteMatch != null) {
      keyword = quoteMatch.group(1);
    }

    // Ejecutar consulta
    final queryResult = await queryTransactionsTool(
      type: type,
      category: matchedCategory,
      keyword: keyword,
      startDate: startDate,
      endDate: endDate,
    );

    queryResult['searchedType'] = type;
    queryResult['searchedCategory'] = matchedCategory;
    queryResult['searchedKeyword'] = keyword;
    queryResult['searchedPeriod'] = startDate == null 
        ? 'Todo el historial' 
        : '${_formatDate(startDate)} a ${_formatDate(endDate!)}';

    return queryResult;
  }

  Future<Map<String, dynamic>> queryTransactionsTool({
    String? type,
    String? category,
    String? keyword,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final box = Hive.isBoxOpen('data')
        ? Hive.box<Add_data>('data')
        : await Hive.openBox<Add_data>('data');
    double totalSum = 0.0;
    int count = 0;
    double maxAmount = 0.0;
    double minAmount = double.infinity;
    List<Map<String, dynamic>> matchedList = [];

    final cleanKeyword = keyword != null ? _normalizeString(keyword) : null;
    final cleanCategory = category != null ? _normalizeString(category) : null;

    for (var tx in box.values) {
      // 1. Filtrar por tipo
      if (type != null && tx.safeType != type) continue;

      // 2. Filtrar por rango de fechas
      if (startDate != null && tx.safeDate.isBefore(startDate)) continue;
      if (endDate != null && tx.safeDate.isAfter(endDate)) continue;

      // 3. Filtrar por categoría
      if (cleanCategory != null && _normalizeString(tx.safeCategory) != cleanCategory) continue;

      // 4. Filtrar por palabra clave en detalles
      if (cleanKeyword != null && !_normalizeString(tx.safeDetail).contains(cleanKeyword)) continue;

      double amt = double.tryParse(tx.safeAmount) ?? 0.0;
      totalSum += amt;
      count++;
      if (amt > maxAmount) maxAmount = amt;
      if (amt < minAmount) minAmount = amt;

      matchedList.add({
        'type': tx.safeType,
        'amount': amt,
        'date': tx.safeDate,
        'detail': tx.safeDetail,
        'category': tx.safeCategory,
        'account': tx.safeAccount,
      });
    }

    double average = count > 0 ? totalSum / count : 0.0;
    if (minAmount == double.infinity) minAmount = 0.0;

    return {
      'totalSum': totalSum,
      'count': count,
      'average': average,
      'maxAmount': maxAmount,
      'minAmount': minAmount,
      'transactions': matchedList,
    };
  }

  String _formatQueryResultContext(Map<String, dynamic> result) {
    String contextStr = '[RESULTADO DE CONSULTA A BASE DE DATOS DE TRANSACCIONES]\n'
        '- Período consultado: ${result['searchedPeriod']}\n'
        '- Tipo filtrado: ${result['searchedType'] ?? "Todos"}\n'
        '- Categoría filtrada: ${result['searchedCategory'] ?? "Todas"}\n'
        '- Palabra clave filtrada: ${result['searchedKeyword'] ?? "Ninguna"}\n'
        '- Total de transacciones encontradas: ${result['count']}\n'
        '- Suma total acumulada: ${CurrencyHelper.format(result['totalSum'])} ${CurrencyHelper.currencyCode}\n'
        '- Promedio por transacción: ${CurrencyHelper.format(result['average'])} ${CurrencyHelper.currencyCode}\n'
        '- Transacción de monto máximo: ${CurrencyHelper.format(result['maxAmount'])} ${CurrencyHelper.currencyCode}\n'
        '- Transacción de monto mínimo: ${CurrencyHelper.format(result['minAmount'])} ${CurrencyHelper.currencyCode}\n\n';

    final List<dynamic> txs = result['transactions'];
    if (txs.isNotEmpty) {
      contextStr += 'DETALLE DE TRANSACCIONES ENCONTRADAS:\n';
      final displayedTxs = txs.take(10).toList();
      for (var tx in displayedTxs) {
        contextStr += '- ${_formatDate(tx['date'])} | ${tx['type'] == "Income" ? "INGRESO" : "EGRESO"} | '
            '${CurrencyHelper.format(tx['amount'])} | Categoría: ${tx['category']} | Detalle: ${tx['detail']} | Cuenta: ${tx['account']}\n';
      }
      if (txs.length > 10) {
        contextStr += '- ... y ${txs.length - 10} transacciones más.\n';
      }
    } else {
      contextStr += 'No se encontraron transacciones con los filtros aplicados.\n';
    }

    return contextStr;
  }

  Future<List<Map<String, dynamic>>> generateCategorySuggestions({
    required String type,
    int limit = 3,
  }) async {
    final existing = await CategoryService.getCategories(type);
    final normalizedExisting = existing.map((c) => _normalizeString(c)).toSet();

    final List<Map<String, dynamic>> allPossible = type == 'Income'
        ? [
            {'name': 'Salario', 'icon': Icons.attach_money.codePoint, 'color': Colors.greenAccent.value, 'type': 'Income'},
            {'name': 'Freelance', 'icon': Icons.work.codePoint, 'color': Colors.amberAccent.value, 'type': 'Income'},
            {'name': 'Inversiones', 'icon': Icons.savings.codePoint, 'color': Colors.tealAccent.value, 'type': 'Income'},
            {'name': 'Ventas', 'icon': Icons.trending_up.codePoint, 'color': Colors.blueAccent.value, 'type': 'Income'},
            {'name': 'Renta de Propiedad', 'icon': Icons.home.codePoint, 'color': Colors.purpleAccent.value, 'type': 'Income'},
            {'name': 'Regalos', 'icon': Icons.card_giftcard.codePoint, 'color': Colors.pinkAccent.value, 'type': 'Income'},
            {'name': 'Reembolsos', 'icon': Icons.swap_horiz_rounded.codePoint, 'color': Colors.orangeAccent.value, 'type': 'Income'},
            {'name': 'Pensión', 'icon': Icons.account_balance.codePoint, 'color': Colors.blueGrey.value, 'type': 'Income'},
          ]
        : [
            {'name': 'Supermercado', 'icon': Icons.shopping_cart.codePoint, 'color': Colors.orangeAccent.value, 'type': 'Expenses'},
            {'name': 'Restaurantes', 'icon': Icons.fastfood.codePoint, 'color': Colors.deepOrangeAccent.value, 'type': 'Expenses'},
            {'name': 'Transporte Público', 'icon': Icons.directions_bus.codePoint, 'color': Colors.blueAccent.value, 'type': 'Expenses'},
            {'name': 'Gasolina', 'icon': Icons.directions_car.codePoint, 'color': Colors.lightBlueAccent.value, 'type': 'Expenses'},
            {'name': 'Suscripciones', 'icon': Icons.tv.codePoint, 'color': Colors.redAccent.value, 'type': 'Expenses'},
            {'name': 'Gimnasio y Deporte', 'icon': Icons.fitness_center.codePoint, 'color': Colors.tealAccent.value, 'type': 'Expenses'},
            {'name': 'Salud y Farmacia', 'icon': Icons.local_hospital.codePoint, 'color': Colors.greenAccent.value, 'type': 'Expenses'},
            {'name': 'Educación', 'icon': Icons.school.codePoint, 'color': Colors.indigoAccent.value, 'type': 'Expenses'},
            {'name': 'Moda y Ropa', 'icon': Icons.shopping_bag.codePoint, 'color': Colors.pinkAccent.value, 'type': 'Expenses'},
            {'name': 'Mascotas', 'icon': Icons.pets.codePoint, 'color': Colors.amberAccent.value, 'type': 'Expenses'},
            {'name': 'Servicios del Hogar', 'icon': Icons.lightbulb.codePoint, 'color': Colors.yellowAccent.value, 'type': 'Expenses'},
            {'name': 'Viajes y Ocio', 'icon': Icons.flight.codePoint, 'color': Colors.cyanAccent.value, 'type': 'Expenses'},
            {'name': 'Regalos y Donaciones', 'icon': Icons.card_giftcard.codePoint, 'color': Colors.purpleAccent.value, 'type': 'Expenses'},
            {'name': 'Mantenimiento Vehículo', 'icon': Icons.build.codePoint, 'color': Colors.grey.value, 'type': 'Expenses'},
          ];

    final List<Map<String, dynamic>> suggestions = [];
    for (var item in allPossible) {
      if (suggestions.length >= limit) break;
      final normName = _normalizeString(item['name'] as String);
      if (!normalizedExisting.contains(normName)) {
        suggestions.add(item);
      }
    }

    int counter = 1;
    while (suggestions.length < limit) {
      final name = type == 'Income' ? 'Otro Ingreso $counter' : 'Otro Gasto $counter';
      final normName = _normalizeString(name);
      if (!normalizedExisting.contains(normName)) {
        suggestions.add({
          'name': name,
          'icon': type == 'Income' ? Icons.attach_money.codePoint : Icons.shopping_cart.codePoint,
          'color': type == 'Income' ? Colors.greenAccent.value : Colors.blueAccent.value,
          'type': type,
        });
      }
      counter++;
    }

    return suggestions;
  }

  Future<void> removeCategorySuggestion(int messageIndex, String categoryName) async {
    if (messageIndex >= 0 && messageIndex < _messages.length) {
      final msg = _messages[messageIndex];
      if (msg.categorySuggestions != null) {
        final updatedSuggestions = List<Map<String, dynamic>>.from(msg.categorySuggestions!);
        updatedSuggestions.removeWhere((sug) => sug['name'] == categoryName);
        
        _messages[messageIndex] = ChatMessage(
          role: msg.role,
          content: msg.content,
          timestamp: msg.timestamp,
          categorySuggestions: updatedSuggestions.isEmpty ? null : updatedSuggestions,
        );
        
        notifyListeners();
        await _saveHistory();
      }
    }
  }

  Future<void> acceptCategorySuggestion(int messageIndex, Map<String, dynamic> suggestion) async {
    final String name = suggestion['name'] ?? '';
    final String type = suggestion['type'] ?? 'Expenses';
    final int iconCode = suggestion['icon'] ?? Icons.category.codePoint;
    final int colorValue = suggestion['color'] ?? Colors.blueAccent.value;
    
    if (name.isNotEmpty) {
      await CategoryService.addCategoryWithMetadata(type, name, iconCode, colorValue);
      await removeCategorySuggestion(messageIndex, name);
      
      // Actualizar patrones frescos y estado cognitivo de inmediato
      await updateLearnedPatterns();
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>?> detectAndGenerateTransactionSuggestions(String userMessage) async {
    final lowerMsg = userMessage.toLowerCase();
    
    // 1. Detectar si el usuario está reportando una transacción (gasto o ingreso)
    bool isExpense = false;
    bool isIncome = false;
    
    final expenseVerbs = ['gaste', 'gasté', 'pague', 'pagué', 'compre', 'compré', 'gastar', 'pagar', 'comprar', 'sali', 'salí', 'comimos', 'consumí', 'consumi'];
    final incomeVerbs = ['ingrese', 'ingresé', 'gane', 'gané', 'recibi', 'recibí', 'ingresar', 'ganar', 'recibir', 'me pagaron', 'depositaron'];
    
    for (var verb in expenseVerbs) {
      if (lowerMsg.contains(verb)) {
        isExpense = true;
        break;
      }
    }
    
    for (var verb in incomeVerbs) {
      if (lowerMsg.contains(verb)) {
        isIncome = true;
        break;
      }
    }
    
    if (!isExpense && !isIncome) {
      if (lowerMsg.contains('gasto de') || lowerMsg.contains('egreso de')) {
        isExpense = true;
      } else if (lowerMsg.contains('ingreso de') || lowerMsg.contains('pago de')) {
        isIncome = true;
      }
    }
    
    if (!isExpense && !isIncome) return null;
    
    // 2. Extraer Monto
    double? amount;
    final RegExp amountRegex = RegExp(r'\b(\d{1,3}(?:[\.,]\d{3})*|\d+)\b');
    final matches = amountRegex.allMatches(lowerMsg);
    for (var match in matches) {
      final cleanNumStr = match.group(1)!.replaceAll('.', '').replaceAll(',', '');
      final val = double.tryParse(cleanNumStr);
      if (val != null && val >= 100) {
        if (val == 2026 || val == 2025) continue;
        amount = val;
        break;
      }
    }
    
    if (amount == null) return null;
    
    final String type = isIncome ? 'Income' : 'Expenses';
    
    // 3. Determinar Fecha
    DateTime date = DateTime.now();
    if (lowerMsg.contains('ayer')) {
      date = DateTime.now().subtract(const Duration(days: 1));
    } else if (lowerMsg.contains('antier') || lowerMsg.contains('anteayer')) {
      date = DateTime.now().subtract(const Duration(days: 2));
    }
    
    // 4. Determinar Detalle
    String detail = '';
    if (lowerMsg.contains('novia') && (lowerMsg.contains('comimos') || lowerMsg.contains('comida') || lowerMsg.contains('cena') || lowerMsg.contains('restaurante'))) {
      detail = 'Comida con novia';
    } else if (lowerMsg.contains('novia')) {
      detail = 'Salida con novia';
    } else if (lowerMsg.contains('comimos') || lowerMsg.contains('restaurante') || lowerMsg.contains('cena') || lowerMsg.contains('almuerzo')) {
      detail = 'Comida / Restaurante';
    } else if (lowerMsg.contains('cine') || lowerMsg.contains('pelicula') || lowerMsg.contains('película')) {
      detail = 'Cine';
    } else if (lowerMsg.contains('taxi') || lowerMsg.contains('uber') || lowerMsg.contains('cabify')) {
      detail = 'Transporte Taxi/Uber';
    } else if (lowerMsg.contains('gasolina') || lowerMsg.contains('tanquear') || lowerMsg.contains('combustible')) {
      detail = 'Gasolina';
    } else if (lowerMsg.contains('supermercado') || lowerMsg.contains('mercado') || lowerMsg.contains('mercando')) {
      detail = 'Mercado';
    } else {
      String cleanText = userMessage;
      cleanText = cleanText.replaceAll(RegExp(r'\b\d+(?:[\.,]\d+)?\b'), '');
      
      final stopWords = [
        'gaste', 'gasté', 'pague', 'pagué', 'compre', 'compré', 
        'gastar', 'pagar', 'comprar', 'sali', 'salí',
        'ingrese', 'ingresé', 'gane', 'gané', 'recibi', 'recibí', 
        'ingresar', 'ganar', 'recibir', 'me pagaron', 'depositaron',
        'registra', 'registrar', 'ingresa', 'ingresar', 'agrega', 'agregar', 
        'adiciona', 'adicionar', 'pago', 'recibo', 'sueldo', 'salario',
        'ayer', 'hoy', 'cop', 'pesos', 'usd', 'dolares', 'dólares', '\$',
        'un', 'una', 'el', 'la', 'de', 'del', 'por', 'con', 'en', 'para', 'mi', 'mis'
      ];
      
      for (var word in stopWords) {
        cleanText = cleanText.replaceAll(RegExp('\\b$word\\b', caseSensitive: false), '');
      }
      
      cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (cleanText.isNotEmpty) {
        if (cleanText.length > 25) {
          cleanText = cleanText.substring(0, 25);
        }
        detail = cleanText[0].toUpperCase() + cleanText.substring(1);
      }
    }
    
    // 5. Buscar Categoría
    final categories = await CategoryService.getCategories(type);
    final normMsg = _normalizeString(userMessage);
    
    String? matchedCategory;
    for (var cat in categories) {
      final normCat = _normalizeString(cat);
      if (normMsg.contains(normCat)) {
        matchedCategory = cat;
        break;
      }
      if (normCat == 'comida' || normCat == 'alimentos' || normCat == 'restaurantes' || normCat == 'gastronomia' || normCat == 'gastronomía') {
        if (normMsg.contains('comi') || normMsg.contains('cena') || normMsg.contains('almuer') || normMsg.contains('restaurante')) {
          matchedCategory = cat;
          break;
        }
      }
      if (normCat == 'novia' || normCat == 'pareja' || normCat == 'salidas') {
        if (normMsg.contains('novia') || normMsg.contains('pareja')) {
          matchedCategory = cat;
          break;
        }
      }
      if (normCat == 'transporte' || normCat == 'viajes' || normCat == 'vehículo' || normCat == 'vehiculo') {
        if (normMsg.contains('taxi') || normMsg.contains('uber') || normMsg.contains('cabify') || normMsg.contains('gasolina') || normMsg.contains('bus')) {
          matchedCategory = cat;
          break;
        }
      }
      if (normCat == 'salario' || normCat == 'sueldo' || normCat == 'nomina' || normCat == 'nómina') {
        if (normMsg.contains('salario') || normMsg.contains('sueldo') || normMsg.contains('pago') || normMsg.contains('nomina') || normMsg.contains('nómina')) {
          matchedCategory = cat;
          break;
        }
      }
    }

    String bestCategory = matchedCategory ?? '';
    if (bestCategory.isEmpty) {
      for (var cat in categories) {
        final norm = _normalizeString(cat);
        if (norm == 'otros' || norm == 'general' || norm == 'varios' || norm.contains('otros')) {
          bestCategory = cat;
          break;
        }
      }
      if (bestCategory.isEmpty && categories.isNotEmpty) {
        bestCategory = categories.first;
      }
    }
    
    if (detail.isEmpty) {
      detail = bestCategory;
    }
    
    // 6. Determinar Cuenta
    final financialState = await getFinancialState();
    final List<dynamic> accountsList = financialState['accounts'] ?? [];
    String selectedAccount = accountsList.isNotEmpty ? accountsList.first['title'] : 'Efectivo';
    bool accountInferred = true;
    
    for (var acc in accountsList) {
      final title = acc['title']?.toString() ?? '';
      final normTitle = _normalizeString(title);
      if (normMsg.contains(normTitle)) {
        selectedAccount = title;
        accountInferred = false;
        break;
      }
    }
    
    if (accountInferred) {
      if (normMsg.contains('nequi')) {
        for (var acc in accountsList) {
          if (_normalizeString(acc['title']).contains('nequi')) {
            selectedAccount = acc['title'];
            accountInferred = false;
            break;
          }
        }
      } else if (normMsg.contains('efectivo')) {
        for (var acc in accountsList) {
          if (_normalizeString(acc['title']).contains('efectivo')) {
            selectedAccount = acc['title'];
            accountInferred = false;
            break;
          }
        }
      }
    }
    
    return [
      {
        'type': type,
        'amount': amount,
        'category': bestCategory,
        'detail': detail,
        'date': date.toIso8601String(),
        'account': selectedAccount,
        'accountInferred': accountInferred,
      }
    ];
  }

  Future<void> removeTransactionSuggestion(int messageIndex, String detail) async {
    if (messageIndex >= 0 && messageIndex < _messages.length) {
      final msg = _messages[messageIndex];
      if (msg.transactionSuggestions != null) {
        final updatedSuggestions = List<Map<String, dynamic>>.from(msg.transactionSuggestions!);
        updatedSuggestions.removeWhere((sug) => sug['detail'] == detail);
        
        _messages[messageIndex] = ChatMessage(
          role: msg.role,
          content: msg.content,
          timestamp: msg.timestamp,
          categorySuggestions: msg.categorySuggestions,
          transactionSuggestions: updatedSuggestions.isEmpty ? null : updatedSuggestions,
        );
        
        notifyListeners();
        await _saveHistory();
      }
    }
  }

  Future<void> acceptTransactionSuggestion(int messageIndex, Map<String, dynamic> suggestion) async {
    final String type = suggestion['type'] ?? 'Expenses';
    final double amount = suggestion['amount'] ?? 0.0;
    final String category = suggestion['category'] ?? 'Otros';
    final String detail = suggestion['detail'] ?? '';
    final DateTime date = DateTime.tryParse(suggestion['date'] ?? '') ?? DateTime.now();
    
    // Validar y asegurar cuenta válida
    final financialState = await getFinancialState();
    final List<dynamic> accountsList = financialState['accounts'] ?? [];
    String account = suggestion['account'] ?? '';
    
    // Si la cuenta sugerida no existe en el sistema, usar la primera cuenta disponible como fallback
    bool accountExists = accountsList.any((acc) => acc['title']?.toString() == account);
    if (!accountExists && accountsList.isNotEmpty) {
      account = accountsList.first['title']?.toString() ?? 'Efectivo';
    } else if (account.isEmpty) {
      account = 'Efectivo';
    }
    
    if (amount > 0) {
      int iconCode = Icons.receipt_long_rounded.codePoint;
      try {
        final catsWithMeta = await CategoryService.getCategoriesWithMetadata(type);
        for (var cat in catsWithMeta) {
          if (cat['text'] == category) {
            iconCode = cat['icon'] ?? iconCode;
            break;
          }
        }
      } catch (e) {
        AppLogger.error('Error fetching category icon for suggestion', error: e);
      }

      // Procesar el saldo de la cuenta
      final balanceUpdated = await TransactionService.processTransaction(
        type: type,
        amount: amount,
        accountName: account,
        isNewTransaction: true,
        recordInHive: false,
      );
      if (!balanceUpdated) {
        AppLogger.warning('acceptTransactionSuggestion: no se pudo actualizar saldo para cuenta "$account"');
        return;
      }

      // Registrar en el historial local de Hive para visualización inmediata y persistencia
      final box = Hive.isBoxOpen('data')
          ? Hive.box<Add_data>('data')
          : await Hive.openBox<Add_data>('data');
      final transaction = Add_data(
        type,
        amount.toString(),
        date,
        detail,
        category,
        account,
        iconCode,
        '1',
        true,
      );
      await box.add(transaction);
      await removeTransactionSuggestion(messageIndex, detail);
      
      // Actualizar patrones frescos y estado cognitivo de inmediato
      await updateLearnedPatterns();
      notifyListeners();
    }
  }

  String _normalizeString(String str) {
    return str
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Genera un resumen interno de los mensajes anteriores (excluyendo la ventana de los últimos 8)
  Future<void> _generateInternalSummary() async {
    final int endIndex = _messages.length - 8;
    if (endIndex <= _lastSummaryCount) return;
    
    final messagesToSummarize = _messages.sublist(_lastSummaryCount, endIndex);
    if (messagesToSummarize.isEmpty) return;

    final String newSummary = _generateFallbackSummary(messagesToSummarize);
    
    if (newSummary.isNotEmpty) {
      _chatSummary = newSummary;
      _lastSummaryCount = endIndex; // Actualizar el contador al índice final de los mensajes resumidos
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_chat_summary', _chatSummary);
      await prefs.setInt('ai_last_summary_count', _lastSummaryCount);
      AppLogger.info('Resumen interno guardado. Mensajes procesados hasta el índice: $_lastSummaryCount');
    }
  }

  /// Genera un resumen alternativo offline mediante reglas en caso de fallo del modelo o simulador activo
  String _generateFallbackSummary(List<ChatMessage> messagesToSummarize) {
    List<String> topics = [];
    double totalConsultedCost = 0.0;
    
    for (var msg in messagesToSummarize) {
      final content = msg.content.toLowerCase();
      if (msg.role == 'user') {
        if (content.contains('comprar') || content.contains('compra')) {
          final RegExp priceRegex = RegExp(r'\$?\s*([0-9]+(?:\.[0-9]+)?)');
          final match = priceRegex.firstMatch(content);
          if (match != null) {
            double? cost = double.tryParse(match.group(1)!);
            if (cost != null) totalConsultedCost += cost;
          }
          topics.add('consulta de compra');
        }
        if (content.contains('meta') || content.contains('ahorrar')) {
          topics.add('metas de ahorro');
        }
        if (content.contains('gasto') || content.contains('egreso') || content.contains('transacción') || content.contains('transaccion')) {
          topics.add('registro/análisis de transacciones');
        }
        if (content.contains('obligación') || content.contains('obligacion') || content.contains('deuda')) {
          topics.add('obligaciones financieras');
        }
      }
    }
    
    topics = topics.toSet().toList(); // eliminar duplicados
    String summary = 'El usuario conversó sobre: ${topics.isEmpty ? "consultas generales" : topics.join(", ")}.';
    if (totalConsultedCost > 0) {
      summary += ' Se analizaron compras por un total de ${CurrencyHelper.format(totalConsultedCost)} ${CurrencyHelper.currencyCode}.';
    }
    return summary;
  }
}
