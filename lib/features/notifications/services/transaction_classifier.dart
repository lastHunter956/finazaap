import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/features/notifications/domain/models/notification_parse_result.dart';
import 'package:finazaap/features/notifications/domain/models/transaction_classification.dart';
import 'package:finazaap/features/notifications/services/learned_patterns_service.dart';
import 'package:finazaap/features/notifications/services/gemma_classifier_adapter.dart';

/// Clasificador jerárquico estricto de notificaciones bancarias en Moneo.
///
/// Precedencia de etapas (orden estricto):
/// - Etapa 0: Anti-Fraude (bloqueo incondicional si hay links o urgencia).
/// - Etapa 1: Aprendizaje Local (`learned_patterns` en Hive).
/// - Etapa 2: Reglas Deterministas (palabras clave, indicios de cuenta, categorías).
/// - Etapa 3: Respaldo On-Device con Gemma (`flutter_gemma`) ante ambigüedad.
class TransactionClassifier {
  final LearnedPatternsService _patternsService;
  final GemmaClassifierAdapter _gemmaAdapter;
  final Future<List<AccountItem>> Function()? _accountsLoader;

  TransactionClassifier({
    LearnedPatternsService? patternsService,
    GemmaClassifierAdapter? gemmaAdapter,
    Future<List<AccountItem>> Function()? accountsLoader,
  })  : _patternsService = patternsService ?? LearnedPatternsService(),
        _gemmaAdapter = gemmaAdapter ?? GemmaClassifierAdapter(),
        _accountsLoader = accountsLoader;

  // ---------------------------------------------------------------------------
  // Expresiones regulares para señales de fraude y urgencia
  // ---------------------------------------------------------------------------
  static final RegExp _urgencyRegex = RegExp(
    r'(cuenta\s+bloqueada|suspensi[oó]n\s+inmediata|verifica\s+tu\s+identidad|'
    r'[uú]ltimo\s+aviso|actualiza\s+tus\s+datos(\s+ahora)?|evita\s+el\s+bloqueo|'
    r'haz\s+clic|ingresa\s+aqu[ií]|acceso\s+suspendido)',
    caseSensitive: false,
  );

  static final RegExp _linkRegex = RegExp(
    r'(https?://\S+|www\.\S+|\b(?:bit\.ly|tinyurl\.com|t\.co|cutt\.ly|rb\.gy|wa\.me)/\S+)',
    caseSensitive: false,
  );

  /// Verifica si una cadena de texto contiene indicios de phishing, URLs o ingeniería social.
  static bool hasFraudSignals(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    return _linkRegex.hasMatch(text) || _urgencyRegex.hasMatch(text);
  }

  /// Clasifica una notificación parseada aplicando la jerarquía estricta.
  Future<TransactionClassification> classify({
    required NotificationParseResult parseResult,
    String? rawText,
    List<AccountItem>? userAccounts,
  }) async {
    final text = rawText ?? _extractRawText(parseResult);

    // =========================================================================
    // ETAPA 0: Anti-Fraude (Bloqueo Absoluto)
    // =========================================================================
    final bool isMarkedSuspicious = parseResult is SuspiciousNotification ||
        parseResult.status == 'sospechosa' ||
        parseResult.flags.contains('anti_fraud_link_detected');

    final bool hasTextFraudSignals = hasFraudSignals(text) ||
        (parseResult is ParsedTransaction &&
            hasFraudSignals(parseResult.comercio));

    if (isMarkedSuspicious || hasTextFraudSignals) {
      return const TransactionClassification(
        classification: 'sospechosa',
        moneoType: null,
        category: null,
        accountName: null,
        destinationAccount: null,
        confidence: 0.0,
        requiresReview: true,
        createTransaction: false,
        decisionSource: 'anti_fraud',
      );
    }

    // Cargar cuentas del usuario para enriquecer matching
    final accounts = userAccounts ?? await _loadAccounts();

    // =========================================================================
    // ETAPA 1: Aprendizaje Local (Hive box "learned_patterns")
    // =========================================================================
    final merchant = _extractMerchant(parseResult);
    if (merchant != null && merchant.trim().isNotEmpty) {
      final pattern = await _patternsService.findPattern(merchant);
      if (pattern != null && pattern.confirmations >= 1) {
        final resolvedAccount = pattern.accountName ??
            _detectAccountName(parseResult, text, accounts);
        final isTransfer = pattern.classification == 'transferencia-propia';
        final destAccount = isTransfer
            ? _detectDestinationAccount(parseResult, text, accounts)
            : null;

        // Solo emitir transferencia-propia si la cuenta destino no es nula
        if (!isTransfer || destAccount != null) {
          final confidence =
              _confidenceFromConfirmations(pattern.confirmations);
          return TransactionClassification(
            classification: pattern.classification,
            moneoType: pattern.moneoType ??
                TransactionClassification.resolveMoneoType(
                    pattern.classification),
            category: pattern.category,
            accountName: resolvedAccount,
            destinationAccount: destAccount,
            confidence: confidence,
            requiresReview: false,
            createTransaction: true,
            decisionSource: 'learned_patterns',
          );
        }
      }
    }

    // =========================================================================
    // ETAPA 2: Reglas Deterministas (Sin LLM)
    // =========================================================================
    final deterministicResult = _evaluateDeterministicRules(
      parseResult: parseResult,
      rawText: text,
      accounts: accounts,
    );

    if (deterministicResult != null && deterministicResult.confidence >= 0.80) {
      return deterministicResult;
    }

    // =========================================================================
    // ETAPA 3: Respaldo On-Device con Gemma (flutter_gemma)
    // =========================================================================
    final double? amount =
        parseResult is ParsedTransaction ? parseResult.monto : null;

    final gemmaResult = await _gemmaAdapter.classify(
      rawText: text,
      merchant: merchant,
      amount: amount,
    );

    if (gemmaResult != null) {
      final isTransfer = gemmaResult.classification == 'transferencia-propia';
      final destAccount = isTransfer
          ? _detectDestinationAccount(parseResult, text, accounts)
          : null;

      // Transferencia propia exige destino no nulo
      if (!isTransfer || destAccount != null) {
        final bool reqReview = gemmaResult.confidence < 0.85;
        return TransactionClassification(
          classification: gemmaResult.classification,
          moneoType: TransactionClassification.resolveMoneoType(
            gemmaResult.classification,
          ),
          category:
              gemmaResult.category ?? deterministicResult?.category ?? 'Otros',
          accountName: deterministicResult?.accountName ??
              _detectAccountName(parseResult, text, accounts),
          destinationAccount: destAccount,
          confidence: gemmaResult.confidence,
          requiresReview: reqReview,
          createTransaction: !reqReview,
          decisionSource: 'gemma_fallback',
        );
      }
    }

    // Fallback cuando Gemma no está disponible, falla o da timeout
    final rawFallbackType = deterministicResult?.classification ?? 'gasto';
    final fallbackAccount = deterministicResult?.accountName ??
        _detectAccountName(parseResult, text, accounts);
    final fallbackDest = rawFallbackType == 'transferencia-propia'
        ? deterministicResult?.destinationAccount ??
            _detectDestinationAccount(parseResult, text, accounts)
        : null;

    // Si la hipótesis era transferencia pero no hay cuenta destino, degradar a 'gasto'
    final actualClassification =
        (rawFallbackType == 'transferencia-propia' && fallbackDest == null)
            ? 'gasto'
            : rawFallbackType;
    final actualMoneo =
        TransactionClassification.resolveMoneoType(actualClassification);

    return TransactionClassification(
      classification: actualClassification,
      moneoType: actualMoneo,
      category: deterministicResult?.category ?? 'Otros',
      accountName: fallbackAccount,
      destinationAccount:
          actualClassification == 'transferencia-propia' ? fallbackDest : null,
      confidence: (deterministicResult != null &&
              deterministicResult.confidence < 0.80 &&
              deterministicResult.confidence > 0.0)
          ? deterministicResult.confidence
          : 0.60,
      requiresReview: true,
      createTransaction: false,
      decisionSource: 'fallback_ambiguous',
    );
  }

  // ---------------------------------------------------------------------------
  // Evaluación de reglas deterministas
  // ---------------------------------------------------------------------------
  TransactionClassification? _evaluateDeterministicRules({
    required NotificationParseResult parseResult,
    required String rawText,
    required List<AccountItem> accounts,
  }) {
    final lowerText = rawText.toLowerCase();
    final parsedType = parseResult.tipo.toLowerCase();

    // 1. Transferencia entre cuentas propias
    final ownTransferResult = _checkOwnTransfer(
      parseResult: parseResult,
      lowerText: lowerText,
      accounts: accounts,
    );
    if (ownTransferResult != null) return ownTransferResult;

    // 2. Ingreso
    final isIncomeParsed = parsedType == 'ingreso';
    final hasIncomeKeywords = RegExp(
      r'\b(recibiste|abono|nomina|nómina|deposito|depósito|reembolso|rendimientos|consignacion|consignación|transferencia recibida|pago recibido|te transfirieron|te consignaron)\b',
      caseSensitive: false,
    ).hasMatch(lowerText);

    if (isIncomeParsed || hasIncomeKeywords) {
      final category = _resolveIncomeCategory(lowerText);
      final accountName = _detectAccountName(parseResult, rawText, accounts);
      final confidence = (isIncomeParsed && hasIncomeKeywords) ? 0.92 : 0.88;

      return TransactionClassification(
        classification: 'ingreso',
        moneoType: 'Income',
        category: category,
        accountName: accountName,
        destinationAccount: null,
        confidence: confidence,
        requiresReview: false,
        createTransaction: true,
        decisionSource: 'deterministic_rules',
      );
    }

    // 3. Gasto
    final isExpenseParsed = parsedType == 'gasto';
    final hasExpenseKeywords = RegExp(
      r'\b(compra|pago|debito|débito|retiro|suscripcion|suscripción|cargo|pagaste|compraste|consumo)\b',
      caseSensitive: false,
    ).hasMatch(lowerText);

    if (isExpenseParsed || hasExpenseKeywords) {
      final merchant = _extractMerchant(parseResult);
      final contextText = '$lowerText ${merchant?.toLowerCase() ?? ""}';
      final category = _resolveExpenseCategory(contextText);
      final accountName = _detectAccountName(parseResult, rawText, accounts);

      double confidence = 0.85;
      if (category != 'Otros') {
        confidence = 0.90;
      } else if (isExpenseParsed && hasExpenseKeywords) {
        confidence = 0.86;
      }

      return TransactionClassification(
        classification: 'gasto',
        moneoType: 'Expenses',
        category: category,
        accountName: accountName,
        destinationAccount: null,
        confidence: confidence,
        requiresReview: false,
        createTransaction: true,
        decisionSource: 'deterministic_rules',
      );
    }

    // 4. Si parseResult tenía un tipo pero no keywords claras
    if (parsedType == 'desconocido' || parseResult is UnparseableNotification) {
      return null;
    }

    // Hipótesis débil con baja confianza para forzar Etapa 3
    return TransactionClassification(
      classification: 'gasto',
      moneoType: 'Expenses',
      category: 'Otros',
      accountName: _detectAccountName(parseResult, rawText, accounts),
      destinationAccount: null,
      confidence: 0.50,
      requiresReview: true,
      createTransaction: false,
      decisionSource: 'deterministic_rules',
    );
  }

  // ---------------------------------------------------------------------------
  // Detección de transferencia propia
  // ---------------------------------------------------------------------------
  TransactionClassification? _checkOwnTransfer({
    required NotificationParseResult parseResult,
    required String lowerText,
    required List<AccountItem> accounts,
  }) {
    final isTransferType = parseResult.tipo.toLowerCase() == 'transferencia';
    final hasExplicitOwnKeywords = RegExp(
      r'(transferencia entre (tus|mis) cuentas|traslado entre cuentas|a tu cuenta|a tu propia cuenta)',
      caseSensitive: false,
    ).hasMatch(lowerText);

    // Buscar si 2 cuentas del usuario coinciden en el texto / indicios
    final matchedAccounts =
        _findMatchingUserAccounts(lowerText, parseResult, accounts);

    if (matchedAccounts.length >= 2) {
      final source = matchedAccounts[0].title;
      final dest = matchedAccounts[1].title;

      return TransactionClassification(
        classification: 'transferencia-propia',
        moneoType: 'Transfer',
        category: 'Transferencia',
        accountName: source,
        destinationAccount: dest,
        confidence: 0.92,
        requiresReview: false,
        createTransaction: true,
        decisionSource: 'deterministic_rules',
      );
    }

    if (hasExplicitOwnKeywords) {
      final source = _detectAccountName(parseResult, lowerText, accounts);
      final dest = _detectDestinationAccount(parseResult, lowerText, accounts);

      if (dest != null && dest != source) {
        return TransactionClassification(
          classification: 'transferencia-propia',
          moneoType: 'Transfer',
          category: 'Transferencia',
          accountName: source,
          destinationAccount: dest,
          confidence: 0.90,
          requiresReview: false,
          createTransaction: true,
          decisionSource: 'deterministic_rules',
        );
      }
    }

    // Si es transferencia pero hacia terceros, es un gasto
    if (isTransferType &&
        !hasExplicitOwnKeywords &&
        matchedAccounts.length < 2) {
      final accountName = _detectAccountName(parseResult, lowerText, accounts);
      return TransactionClassification(
        classification: 'gasto',
        moneoType: 'Expenses',
        category: 'Transferencia',
        accountName: accountName,
        destinationAccount: null,
        confidence: 0.88,
        requiresReview: false,
        createTransaction: true,
        decisionSource: 'deterministic_rules',
      );
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Asignación de categorías deterministas
  // ---------------------------------------------------------------------------
  String _resolveIncomeCategory(String text) {
    if (RegExp(r'\b(nomina|nómina|salario|sueldo|honorarios)\b')
        .hasMatch(text)) {
      return 'Salario';
    }
    if (RegExp(r'\b(rendimientos|intereses|dividendos)\b').hasMatch(text)) {
      return 'Inversiones';
    }
    if (RegExp(r'\b(reembolso|devolucion|devolución)\b').hasMatch(text)) {
      return 'Reembolso';
    }
    return 'Ingresos';
  }

  String _resolveExpenseCategory(String text) {
    if (RegExp(
            r'\b(exito|éxito|jumbo|d1|ara|olimpica|olímpica|carulla|restaurante|mcdonalds|rappi|uber eats|comida|panaderia|panadería|cafeteria|cafetería|starbucks|supermercado|mercado)\b')
        .hasMatch(text)) {
      return 'Alimentación';
    }
    if (RegExp(
            r'\b(uber|didi|cabify|gasolina|gasolinera|terpel|primax|peaje|metro|transmilenio|taxi|indriver)\b')
        .hasMatch(text)) {
      return 'Transporte';
    }
    if (RegExp(
            r'\b(claro|tigo|movistar|epm|enel|acueducto|energia|energía|gas natural|vanti|luz|agua|directv|etb)\b')
        .hasMatch(text)) {
      return 'Servicios';
    }
    if (RegExp(
            r'\b(netflix|spotify|hbo|disney|prime video|youtube|cinema|cine|playstation|steam|cinecolombia)\b')
        .hasMatch(text)) {
      return 'Entretenimiento';
    }
    if (RegExp(
            r'\b(farmacia|drogueria|droguería|cruz verde|pasteur|salud|medico|médico|clinica|clínica|hospital|optica|óptica)\b')
        .hasMatch(text)) {
      return 'Salud';
    }
    if (RegExp(
            r'\b(universidad|colegio|curso|udemy|platzi|libreria|librería)\b')
        .hasMatch(text)) {
      return 'Educación';
    }
    if (RegExp(r'\b(homecenter|easy|muebles|ferreteria|ferretería)\b')
        .hasMatch(text)) {
      return 'Hogar';
    }
    if (RegExp(r'\b(zara|falabella|h&m|bershka|pull&bear|arturo calle)\b')
        .hasMatch(text)) {
      return 'Ropa';
    }
    return 'Otros';
  }

  // ---------------------------------------------------------------------------
  // Utilidades auxiliares de detección
  // ---------------------------------------------------------------------------
  List<AccountItem> _findMatchingUserAccounts(
    String text,
    NotificationParseResult parseResult,
    List<AccountItem> accounts,
  ) {
    final matched = <AccountItem>[];
    for (final account in accounts) {
      final titleMatch = text.contains(account.title.toLowerCase());
      final subtitleClean = account.subtitle.replaceAll(RegExp(r'[^\d]'), '');
      final last4Match = subtitleClean.length >= 4 &&
          text.contains(subtitleClean.substring(subtitleClean.length - 4));

      if (titleMatch || last4Match) {
        matched.add(account);
      }
    }
    return matched;
  }

  String? _detectAccountName(
    NotificationParseResult parseResult,
    String text,
    List<AccountItem> accounts,
  ) {
    if (parseResult is ParsedTransaction && parseResult.cuenta != null) {
      final hint = parseResult.cuenta!;
      if (hint.last4 != null && hint.last4!.isNotEmpty) {
        for (final acc in accounts) {
          if (acc.subtitle.contains(hint.last4!) ||
              acc.title.contains(hint.last4!) ||
              acc.id.contains(hint.last4!)) {
            return acc.title;
          }
        }
      }
      if (hint.hint != null && hint.hint!.isNotEmpty) {
        for (final acc in accounts) {
          if (acc.title.toLowerCase().contains(hint.hint!.toLowerCase())) {
            return acc.title;
          }
        }
        return hint.last4 != null ? '${hint.hint} *${hint.last4}' : hint.hint;
      }
      if (hint.last4 != null) {
        return 'Cuenta *${hint.last4}';
      }
    }

    // Buscar en texto
    for (final acc in accounts) {
      if (text.toLowerCase().contains(acc.title.toLowerCase())) {
        return acc.title;
      }
    }

    return accounts.isNotEmpty ? accounts.first.title : null;
  }

  String? _detectDestinationAccount(
    NotificationParseResult parseResult,
    String text,
    List<AccountItem> accounts,
  ) {
    // Buscar patrones como "a tu cuenta Nequi", "a cuenta *1234", "a Nequi"
    final destRegex = RegExp(
      r'(?:a\s+(?:tu\s+)?(?:cuenta\s+)?|hacia\s+(?:cuenta\s+)?|destino\s+)([\w\s\*]+?)(?:desde|\.|$|,)',
      caseSensitive: false,
    );
    final match = destRegex.firstMatch(text);
    if (match != null) {
      final candidate = match.group(1)?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        for (final acc in accounts) {
          if (candidate.toLowerCase().contains(acc.title.toLowerCase())) {
            return acc.title;
          }
        }
        return candidate;
      }
    }

    // Si hay una segunda cuenta en la lista de cuentas del usuario
    final matched = _findMatchingUserAccounts(text, parseResult, accounts);
    if (matched.length >= 2) {
      return matched[1].title;
    }

    return null;
  }

  String? _extractMerchant(NotificationParseResult parseResult) {
    if (parseResult is ParsedTransaction &&
        parseResult.comercio != null &&
        parseResult.comercio!.trim().isNotEmpty) {
      return parseResult.comercio!.trim();
    }
    return null;
  }

  String _extractRawText(NotificationParseResult parseResult) {
    if (parseResult is SuspiciousNotification) {
      return parseResult.rawText;
    }
    if (parseResult is UnparseableNotification) {
      return parseResult.rawText;
    }
    if (parseResult is ParsedTransaction) {
      return '${parseResult.tipo} ${parseResult.comercio ?? ""} ${parseResult.monto ?? ""}';
    }
    return '';
  }

  double _confidenceFromConfirmations(int confirmations) {
    if (confirmations >= 5) return 0.98;
    if (confirmations >= 3) return 0.95;
    if (confirmations >= 2) return 0.92;
    return 0.88;
  }

  Future<List<AccountItem>> _loadAccounts() async {
    if (_accountsLoader != null) {
      try {
        return await _accountsLoader!();
      } catch (_) {}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = prefs.getStringList('accounts');
      if (accountsJson != null) {
        return accountsJson
            .map((item) => AccountItem.fromJson(json.decode(item)))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
