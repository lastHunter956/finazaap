import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/core/utils/app_logger.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

class ChatMessage {
  final String role; // 'user' | 'model' | 'system'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] ?? 'user',
        content: json['content'] ?? '',
        timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      );
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
  bool _isGenerating = false;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  
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

  // Getters
  List<ChatMessage> get messages => _messages;
  bool get useLocalSimulator => _useLocalSimulator;
  bool get gemmaInitialized => _gemmaInitialized;
  bool get gemmaInitializing => _gemmaInitializing;
  String? get gemmaError => _gemmaError;
  String get userGoals => _userGoals;
  String get userNotes => _userNotes;
  double get downloadProgress => _downloadProgress;
  bool get isDownloading => _isDownloading;

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
    if (_gemmaInitializing) return;
    
    _gemmaInitializing = true;
    _gemmaError = null;
    notifyListeners();

    if (initError != null) {
      _gemmaError = 'Error de inicialización del motor de IA: $initError';
      _gemmaInitialized = false;
      _gemmaInitializing = false;
      notifyListeners();
      return;
    }

    try {
      AppLogger.info('Intentando obtener modelo Gemma activo preexistente...');
      
      // PASO 1: Intentar obtener un modelo ya instalado sin necesidad de descargar
      bool modelAlreadyInstalled = false;
      try {
        _gemmaModel = await FlutterGemma.getActiveModel(
          maxTokens: 1024,
          preferredBackend: PreferredBackend.gpu,
        );
        modelAlreadyInstalled = true;
        AppLogger.success('Modelo Gemma preexistente encontrado y cargado.');
      } catch (e) {
        AppLogger.info('No hay modelo preinstalado, procediendo a instalar: $e');
      }
      
      // PASO 2: Si no está instalado, instalarlo según la plataforma
      if (!modelAlreadyInstalled) {
        AppLogger.info('Instalando modelo Gemma...');
        
        if (kIsWeb) {
          // Web: servido por nuestro servidor estático
          final absoluteUrl = kDebugMode 
              ? 'http://localhost:8081/gemma.litertlm'
              : Uri.base.resolve('models/gemma.litertlm').toString();
          
          AppLogger.info('Web: descargando desde $absoluteUrl');
          await FlutterGemma.installModel(
            modelType: ModelType.gemmaIt,
            fileType: ModelFileType.litertlm,
          ).fromNetwork(absoluteUrl).install();
        } else {
          // Android / iOS: necesitamos una URL del modelo
          // No es posible empaquetar el modelo en el APK (2.5GB excede el límite)
          final mobileUrl = customMobileUrl ?? await _getSavedModelUrl();
          
          if (mobileUrl == null || mobileUrl.isEmpty) {
            throw Exception(
              'No hay URL de modelo configurada para este dispositivo.\n\n'
              'El modelo Gemma AI (2.5GB) debe descargarse una vez.\n'
              'Toca "Configurar URL del modelo" para establecer la fuente de descarga.',
            );
          }
          
          AppLogger.info('Android/iOS: descargando desde $mobileUrl');
          _isDownloading = true;
          notifyListeners();
          
          await FlutterGemma.installModel(
            modelType: ModelType.gemmaIt,
            fileType: ModelFileType.litertlm,
          ).fromNetwork(mobileUrl).install();
          
          _isDownloading = false;
        }
        
        // Cargar el modelo recién instalado
        AppLogger.info('Modelo instalado, cargando en memoria...');
        _gemmaModel = await FlutterGemma.getActiveModel(
          maxTokens: 1024,
          preferredBackend: PreferredBackend.gpu,
        );
      }
      
      // PASO 3: Crear sesión de chat con contexto financiero
      final state = await getFinancialState();
      final systemPrompt = _buildSystemPrompt(state);
      
      _gemmaChat = await _gemmaModel!.createChat(
        systemInstruction: systemPrompt,
        maxOutputTokens: 512,
      );
      
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
    return 'Eres un asesor financiero personal de IA llamado "Moneo AI" dentro de una app de finanzas personales. '
        'Responde siempre en español, de forma clara, profesional y concisa. Usa viñetas y Markdown. '
        'No inventes datos financieros — usa exclusivamente los que te proporciono.\n\n'
        'ESTADO FINANCIERO DEL USUARIO:\n'
        '- Saldo disponible global: ${CurrencyHelper.format(financialState['availableBalance'])} ${CurrencyHelper.currencyCode}\n'
        '- Ingresos mensuales: ${CurrencyHelper.format(financialState['monthlyIncome'])} ${CurrencyHelper.currencyCode}\n'
        '- Gastos mensuales: ${CurrencyHelper.format(financialState['monthlyExpenses'])} ${CurrencyHelper.currencyCode}\n'
        '- Ahorros netos del mes: ${CurrencyHelper.format(financialState['monthlySavings'])} ${CurrencyHelper.currencyCode}\n'
        '- Metas del usuario: "$_userGoals"\n'
        '- Patrones de gasto: "$_userNotes"';
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
    
    // Recrear la sesión de chat si Gemma está activo
    if (_gemmaInitialized && _gemmaModel != null) {
      try {
        final state = await getFinancialState();
        _gemmaChat = await _gemmaModel!.createChat(
          systemInstruction: _buildSystemPrompt(state),
          maxOutputTokens: 512,
        );
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
    final box = Hive.box<Add_data>('data');
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
      final box = Hive.box<Add_data>('data');
      
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

  // --- ENVIAR MENSAJE Y PROCESAR RESPUESTA ---
  Future<void> sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty || _isGenerating) return;

    _isGenerating = true;

    // 1. Agregar mensaje del usuario a la lista
    final userChat = ChatMessage(role: 'user', content: userMessage, timestamp: DateTime.now());
    _messages.add(userChat);
    notifyListeners();
    await _saveHistory();

    // 2. Analizar transacciones para tener datos frescos
    await updateLearnedPatterns();
    final financialState = await getFinancialState();

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
    
    if (!_useLocalSimulator) {
      if (!_gemmaInitialized || _gemmaChat == null) {
        AppLogger.info('Gemma no inicializado, intentando cargar sobre la marcha...');
        await _tryLoadGemmaModel();
      }

      if (_gemmaInitialized && _gemmaChat != null) {
        // --- RESPUESTA REAL USANDO GEMMA ON-DEVICE ---
        try {
          // Construir el prompt enriquecido con contexto financiero
          String enrichedPrompt = userMessage;
          
          if (purchaseAnalysis != null) {
            enrichedPrompt += '\n\n[CONTEXTO DE HERRAMIENTA INTERNA - Análisis de compra]\n'
                'Artículo: "${purchaseAnalysis['itemName']}", Costo: ${CurrencyHelper.format(purchaseAnalysis['cost'])} ${CurrencyHelper.currencyCode}\n'
                'Diagnóstico: ${purchaseAnalysis['status']} — ${purchaseAnalysis['description']}\n'
                '[Usa este análisis como base para tu respuesta]';
          }
          
          // Enviar mensaje al modelo usando la API moderna
          await _gemmaChat!.addQueryChunk(Message.text(
            text: enrichedPrompt,
            isUser: true,
          ));
          
          // Obtener respuesta generada
          final response = await _gemmaChat!.generateChatResponse();
          if (response is TextResponse) {
            responseText = response.token.isNotEmpty ? response.token : 'No pude generar una respuesta en este momento. Intenta de nuevo.';
          } else if (response is ThinkingResponse) {
            responseText = response.content.isNotEmpty ? response.content : 'No pude generar una respuesta en este momento. Intenta de nuevo.';
          } else {
            responseText = response.toString();
          }
          
        } catch (e) {
          AppLogger.error('Error en inferencia Gemma (replegando a simulador)', error: e);
          responseText = '*(Nota: Ocurrió un error con Gemma IA. El simulador financiero respondió por seguridad.)*\n\n';
          responseText += _generateSimulatorResponse(userMessage, financialState, purchaseAnalysis);
        }
      } else {
        // No está inicializado — dar respuesta de error con instrucciones claras
        if (kIsWeb) {
          responseText = '⚠️ **Motor Gemma IA no disponible en Web.**\n\n'
              'Asegúrate de que el servidor de modelos esté corriendo (`make web`) y '
              'que el archivo `models/gemma.litertlm` esté accesible en el puerto 8081.\n\n'
              '_Usando el simulador financiero mientras tanto..._\n\n'
              '${_generateSimulatorResponse(userMessage, financialState, purchaseAnalysis)}';
        } else {
          responseText = '⚠️ **Gemma IA no configurado para este dispositivo.**\n\n'
              'El modelo (2.5 GB) debe descargarse una sola vez. Para configurarlo:\n\n'
              '1. Toca el ícono ⚙️ en la esquina superior de esta pantalla\n'
              '2. Ingresa la URL de descarga de tu modelo `.litertlm`\n'
              '3. Espera a que se complete la descarga (~5-20 min según tu red)\n\n'
              '_Mientras tanto, el simulador financiero está activo y funcional._\n\n'
              '${_generateSimulatorResponse(userMessage, financialState, purchaseAnalysis)}';
        }
      }
    } else {
      // --- RESPUESTA SIMULADA BASADA EN REGLAS FINANCIERAS ---
      await Future.delayed(const Duration(milliseconds: 800));
      responseText = _generateSimulatorResponse(userMessage, financialState, purchaseAnalysis);
    }

    // 5. Detectar aprendizaje implícito en el mensaje del usuario
    final RegExp goalKeywords = RegExp(r'(?:quiero|mi meta es|planeo|ahorrar para)\s+([a-zA-Záéíóúñ\s]{3,30})', caseSensitive: false);
    final goalMatch = goalKeywords.firstMatch(userMessage);
    if (goalMatch != null) {
      String extractedGoal = goalMatch.group(1)!.trim();
      await updateUserGoals('Ahorrar para: $extractedGoal');
    }

    // 6. Agregar respuesta del modelo a la lista
    final modelChat = ChatMessage(role: 'model', content: responseText, timestamp: DateTime.now());
    _messages.add(modelChat);
    _isGenerating = false;
    notifyListeners();
    await _saveHistory();
  }

  /// Genera una respuesta usando el motor de reglas financieras local (simulador)
  String _generateSimulatorResponse(
    String userMessage,
    Map<String, dynamic> financialState,
    Map<String, dynamic>? purchaseAnalysis,
  ) {
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

    // Procesamiento inteligente de intenciones
    final lowerMsg = userMessage.toLowerCase().trim();
    
    if (lowerMsg == 'hola' || lowerMsg == 'buenas' || lowerMsg == 'buenos dias' || lowerMsg == 'que tal' || lowerMsg == 'hola!') {
      return '¡Hola! 👋 Qué gusto saludarte. Como tu asesor financiero de IA, he estado analizando tus datos en tiempo real.\n\n'
          'Actualmente tienes **${CurrencyHelper.format(financialState['availableBalance'])} ${CurrencyHelper.currencyCode}** disponibles en total.\n\n'
          '¿En qué te gustaría que nos enfoquemos hoy?\n'
          '*   📊 *¿Cómo van mis gastos e ingresos de este mes?*\n'
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
}
