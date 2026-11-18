import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/data/monthly_summary_cache.dart';
import 'package:finazaap/features/notifications/domain/models/learned_pattern.dart';
import 'package:finazaap/features/notifications/domain/models/notification_parse_result.dart';
import 'package:finazaap/features/notifications/domain/models/transaction_classification.dart';
import 'package:finazaap/features/notifications/services/learned_patterns_service.dart';
import 'package:finazaap/features/notifications/services/gemma_classifier_adapter.dart';
import 'package:finazaap/features/notifications/services/notification_parser.dart';
import 'package:finazaap/utils/currency_helper.dart';

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
  final MonthlySummaryCache? _summaryCache;

  TransactionClassifier({
    LearnedPatternsService? patternsService,
    GemmaClassifierAdapter? gemmaAdapter,
    Future<List<AccountItem>> Function()? accountsLoader,
    MonthlySummaryCache? summaryCache,
  })  : _patternsService = patternsService ?? LearnedPatternsService(),
        _gemmaAdapter = gemmaAdapter ?? GemmaClassifierAdapter(),
        _accountsLoader = accountsLoader,
        _summaryCache = summaryCache;

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
    String? packageName,
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

    // Defensa en profundidad: solicitudes/recordatorios de pago no son movimientos
    final bool isPendingRequest =
        (parseResult is UnparseableNotification &&
                parseResult.flags.contains('payment_request_pending')) ||
            NotificationParser.isPendingPaymentRequest(text);
    if (isPendingRequest) {
      return const TransactionClassification(
        classification: 'gasto',
        moneoType: null,
        category: null,
        accountName: null,
        destinationAccount: null,
        confidence: 0.0,
        requiresReview: true,
        createTransaction: false,
        decisionSource: 'payment_request_pending',
      );
    }

    // Cargar cuentas del usuario para enriquecer matching
    final accounts = userAccounts ?? await _loadAccounts();

    // =========================================================================
    // ETAPA 1: Aprendizaje Local (Hive box "learned_patterns")
    // =========================================================================
    final merchant = _extractMerchant(parseResult);
    if (merchant != null && merchant.trim().isNotEmpty) {
      var pattern = await _patternsService.findPattern(merchant);
      var matchedSemantically = false;
      if (pattern == null && !_patternsService.isKnownEmpty) {
        pattern = await _patternsService.findBestSemanticMatch(
          merchant,
          packageName: packageName,
          minScore: 0.88,
        );
        matchedSemantically = pattern != null;
      }

      final patternStatus = pattern?.effectiveStatus();
      if (pattern != null &&
          pattern.confirmations >= 1 &&
          patternStatus != PatternStatus.obsoleto &&
          !(matchedSemantically &&
              patternStatus == PatternStatus.enRevision)) {
        final resolvedAccount = pattern.accountName ??
            _detectAccountName(
              parseResult,
              text,
              accounts,
              packageName: packageName,
            );
        final isTransfer = pattern.classification == 'transferencia-propia';
        final destAccount = isTransfer
            ? _detectDestinationAccount(parseResult, text, accounts)
            : null;

        // Solo emitir transferencia-propia si la cuenta destino no es nula
        if (!isTransfer || destAccount != null) {
          final isInRevision = patternStatus == PatternStatus.enRevision;
          final confidence = isInRevision
              ? 0.82
              : _confidenceFromConfirmations(pattern.confirmations);
          final reason = matchedSemantically
              ? 'Patrón similar "${pattern.merchantKey}" (${pattern.confirmations} conf.) → ${pattern.category}'
              : isInRevision
                  ? 'Patrón "${pattern.merchantKey}" en revisión → ${pattern.category}'
                  : 'Patrón aprendido "${pattern.merchantKey}" (${pattern.confirmations} conf.) → ${pattern.category}';
          return TransactionClassification(
            classification: pattern.classification,
            moneoType: pattern.moneoType ??
                TransactionClassification.resolveMoneoType(
                    pattern.classification),
            category: pattern.category,
            accountName: resolvedAccount,
            destinationAccount: destAccount,
            confidence: confidence,
            requiresReview: isInRevision,
            createTransaction: !isInRevision,
            decisionSource: 'learned_patterns',
            strategicNote: _buildStrategicNote(
              reason: reason,
              classification: pattern.classification,
              category: pattern.category,
              referenceDate: parseResult.fecha,
            ),
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
      packageName: packageName,
    );

    if (deterministicResult != null &&
        (deterministicResult.confidence >= 0.80 ||
            deterministicResult.decisionSource ==
                'ambiguous_account_or_destination')) {
      if (deterministicResult.strategicNote != null &&
          deterministicResult.strategicNote!.trim().isNotEmpty) {
        return deterministicResult;
      }
      final reason = deterministicResult.decisionSource ==
              'ambiguous_account_or_destination'
          ? 'Cuenta origen o destino ambigua; requiere confirmación'
          : deterministicResult.classification == 'transferencia-propia'
              ? 'Transferencia propia detectada por reglas locales'
              : 'Regla determinista → ${deterministicResult.category ?? 'Otros'}';
      return deterministicResult.copyWith(
        strategicNote: _buildStrategicNote(
          reason: reason,
          classification: deterministicResult.classification,
          category: deterministicResult.category,
          referenceDate: parseResult.fecha,
        ),
      );
    }

    // =========================================================================
    // ETAPA 3: Respaldo On-Device con Gemma (flutter_gemma)
    // =========================================================================
    final double? amount =
        parseResult is ParsedTransaction ? parseResult.monto : null;
    List<String> fewShot = const [];
    try {
      fewShot = await _patternsService.getFewShotExamples(
        limit: 3,
        query: merchant ?? text,
      );
    } catch (_) {
      fewShot = const [];
    }

    final gemmaResult = await _gemmaAdapter.classify(
      rawText: text,
      merchant: merchant,
      amount: amount,
      fewShotExamples: fewShot,
    );

    if (gemmaResult != null) {
      final isTransfer = gemmaResult.classification == 'transferencia-propia';
      final destAccount = isTransfer
          ? _detectDestinationAccount(parseResult, text, accounts)
          : null;

      // Transferencia propia exige destino no nulo
      if (!isTransfer || destAccount != null) {
        final bool reqReview = gemmaResult.confidence < 0.85;
        final resolvedCategory =
            gemmaResult.category ?? deterministicResult?.category ?? 'Otros';
        final gemmaNote = gemmaResult.strategicNote?.trim();
        final strategicNote = (gemmaNote != null && gemmaNote.isNotEmpty)
            ? gemmaNote
            : _buildStrategicNote(
                reason: 'Clasificado por asistente IA → $resolvedCategory',
                classification: gemmaResult.classification,
                category: resolvedCategory,
                referenceDate: parseResult.fecha,
              );
        return TransactionClassification(
          classification: gemmaResult.classification,
          moneoType: TransactionClassification.resolveMoneoType(
            gemmaResult.classification,
          ),
          category: resolvedCategory,
          accountName: deterministicResult?.accountName ??
              _detectAccountName(parseResult, text, accounts),
          destinationAccount: destAccount,
          confidence: gemmaResult.confidence,
          requiresReview: reqReview,
          createTransaction: !reqReview,
          decisionSource: 'gemma_fallback',
          strategicNote: strategicNote,
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
    final fallbackCategory = deterministicResult?.category ?? 'Otros';

    return TransactionClassification(
      classification: actualClassification,
      moneoType: actualMoneo,
      category: fallbackCategory,
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
      strategicNote: _buildStrategicNote(
        reason:
            'Clasificación tentativa ($fallbackCategory) sin confirmación; requiere revisión',
        classification: actualClassification,
        category: fallbackCategory,
        referenceDate: parseResult.fecha,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Evaluación de reglas deterministas
  // ---------------------------------------------------------------------------
  TransactionClassification? _evaluateDeterministicRules({
    required NotificationParseResult parseResult,
    required String rawText,
    required List<AccountItem> accounts,
    String? packageName,
  }) {
    final lowerText = rawText.toLowerCase();
    final parsedType = parseResult.tipo.toLowerCase();

    // 1. Transferencia entre cuentas propias
    final ownTransferResult = _checkOwnTransfer(
      parseResult: parseResult,
      lowerText: lowerText,
      accounts: accounts,
      packageName: packageName,
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
      final resolution = _resolveSourceAccount(
        parseResult,
        rawText,
        accounts,
        packageName: packageName,
      );
      final baseConfidence = (isIncomeParsed && hasIncomeKeywords) ? 0.92 : 0.88;
      final needsReview = resolution.isAmbiguous;

      return TransactionClassification(
        classification: 'ingreso',
        moneoType: 'Income',
        category: category,
        accountName: resolution.accountName,
        destinationAccount: null,
        confidence: needsReview ? 0.65 : baseConfidence,
        requiresReview: needsReview,
        createTransaction: !needsReview,
        decisionSource: needsReview
            ? 'ambiguous_account_or_destination'
            : 'deterministic_rules',
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
      final resolution = _resolveSourceAccount(
        parseResult,
        rawText,
        accounts,
        packageName: packageName,
      );

      double confidence = 0.85;
      if (category != 'Otros') {
        confidence = 0.90;
      } else if (isExpenseParsed && hasExpenseKeywords) {
        confidence = 0.86;
      }
      final needsReview = resolution.isAmbiguous;

      return TransactionClassification(
        classification: 'gasto',
        moneoType: 'Expenses',
        category: category,
        accountName: resolution.accountName,
        destinationAccount: null,
        confidence: needsReview ? 0.65 : confidence,
        requiresReview: needsReview,
        createTransaction: !needsReview,
        decisionSource: needsReview
            ? 'ambiguous_account_or_destination'
            : 'deterministic_rules',
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
      accountName: _detectAccountName(
        parseResult,
        rawText,
        accounts,
        packageName: packageName,
      ),
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
    String? packageName,
  }) {
    final isTransferType = parseResult.tipo.toLowerCase() == 'transferencia';
    final hasExplicitOwnKeywords = RegExp(
      r'(transferencia entre (tus|mis) cuentas|traslado entre cuentas|a tu cuenta|a tu propia cuenta|hacia tu cuenta)',
      caseSensitive: false,
    ).hasMatch(lowerText);

    final matchedAccounts =
        _findMatchingUserAccounts(lowerText, parseResult, accounts);

    if (hasExplicitOwnKeywords) {
      var sourceRes = _resolveSourceAccount(
        parseResult,
        lowerText,
        accounts,
        packageName: packageName,
      );
      if ((sourceRes.accountName == null || sourceRes.isAmbiguous) &&
          (packageName == null || packageName.trim().isEmpty)) {
        final explicitSource = _detectSourceFromClause(lowerText, accounts);
        if (explicitSource != null) {
          sourceRes = _AccountResolution(explicitSource);
        }
      }
      final dest = _detectDestinationAccount(
        parseResult,
        lowerText,
        accounts,
        excludeAccount: sourceRes.accountName,
      );

      if (sourceRes.accountName != null &&
          !sourceRes.isAmbiguous &&
          dest != null &&
          dest != sourceRes.accountName) {
        return TransactionClassification(
          classification: 'transferencia-propia',
          moneoType: 'Transfer',
          category: 'Transferencia',
          accountName: sourceRes.accountName,
          destinationAccount: dest,
          confidence: 0.90,
          requiresReview: false,
          createTransaction: true,
          decisionSource: 'deterministic_rules',
        );
      }

      return TransactionClassification(
        classification: 'gasto',
        moneoType: 'Expenses',
        category: 'Transferencia',
        accountName: sourceRes.accountName,
        destinationAccount: null,
        confidence: 0.65,
        requiresReview: true,
        createTransaction: false,
        decisionSource: 'ambiguous_account_or_destination',
      );
    }

    // Dos nombres de bancos/cuentas en el texto sin evidencia explícita de
    // transferencia propia: no auto-aprobar transferencia ni gasto definitivo.
    if (matchedAccounts.length >= 2) {
      final sourceRes = _resolveSourceAccount(
        parseResult,
        lowerText,
        accounts,
        packageName: packageName,
      );
      return TransactionClassification(
        classification: 'gasto',
        moneoType: 'Expenses',
        category: 'Otros',
        accountName: sourceRes.accountName,
        destinationAccount: null,
        confidence: 0.65,
        requiresReview: true,
        createTransaction: false,
        decisionSource: 'ambiguous_account_or_destination',
      );
    }

    // Si es transferencia pero hacia terceros, es un gasto
    if (isTransferType) {
      final sourceRes = _resolveSourceAccount(
        parseResult,
        lowerText,
        accounts,
        packageName: packageName,
      );
      final needsReview = sourceRes.isAmbiguous;
      return TransactionClassification(
        classification: 'gasto',
        moneoType: 'Expenses',
        category: 'Transferencia',
        accountName: sourceRes.accountName,
        destinationAccount: null,
        confidence: needsReview ? 0.65 : 0.88,
        requiresReview: needsReview,
        createTransaction: !needsReview,
        decisionSource: needsReview
            ? 'ambiguous_account_or_destination'
            : 'deterministic_rules',
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
    List<AccountItem> accounts, {
    String? packageName,
  }) {
    return _resolveSourceAccount(
      parseResult,
      text,
      accounts,
      packageName: packageName,
    ).accountName;
  }

  _AccountResolution _resolveSourceAccount(
    NotificationParseResult parseResult,
    String text,
    List<AccountItem> accounts, {
    String? packageName,
  }) {
    if (accounts.isEmpty) {
      return const _AccountResolution(null, isAmbiguous: true);
    }

    final hint = parseResult is ParsedTransaction ? parseResult.cuenta : null;

    // 1. Últimos 4 dígitos: solo es inequívoco si coincide exactamente 1 producto
    if (hint != null && hint.last4 != null && hint.last4!.isNotEmpty) {
      final matchesByLast4 = accounts
          .where((acc) =>
              acc.subtitle.contains(hint.last4!) ||
              acc.title.contains(hint.last4!) ||
              acc.id.contains(hint.last4!))
          .toList();
      if (matchesByLast4.length == 1) {
        return _AccountResolution(matchesByLast4.first.title);
      }
      if (matchesByLast4.length > 1) {
        return const _AccountResolution(null, isAmbiguous: true);
      }
    }

    // 2. Evidencia de procedencia por packageName (no suficiente si hay varios productos)
    final provenanceTokens = _provenanceTokensForPackage(packageName);
    if (provenanceTokens.isNotEmpty) {
      final bankMatches = accounts.where((acc) {
        final combined = '${acc.title} ${acc.subtitle}'.toLowerCase();
        return provenanceTokens.any(combined.contains);
      }).toList();

      if (bankMatches.length == 1) {
        return _AccountResolution(bankMatches.first.title);
      }

      if (bankMatches.length > 1) {
        final productHint = hint?.hint?.toLowerCase();
        if (productHint != null && productHint.isNotEmpty) {
          final narrowed = bankMatches.where((acc) {
            final combined = '${acc.title} ${acc.subtitle}'.toLowerCase();
            if (productHint.contains('crédito') || productHint.contains('credito')) {
              final hasLimit = acc.creditLimit != null &&
                  (double.tryParse(acc.creditLimit!) ?? 0) > 0;
              return combined.contains('crédito') ||
                  combined.contains('credito') ||
                  combined.contains('tc') ||
                  hasLimit;
            }
            return combined.contains(productHint);
          }).toList();

          if (narrowed.length == 1) {
            return _AccountResolution(narrowed.first.title);
          }
        }
        // Varios productos del mismo banco sin desambiguación inequívoca -> revisar
        return const _AccountResolution(null, isAmbiguous: true);
      }

      // El paquete emisor es conocido, pero no hay cuenta registrada asociada
      return const _AccountResolution(null, isAmbiguous: true);
    }

    // 3. Sin packageName (ej. llamadas directas): buscar indicio o título en texto
    if (hint != null && hint.hint != null && hint.hint!.isNotEmpty) {
      final hintMatches = accounts
          .where((acc) =>
              acc.title.toLowerCase().contains(hint.hint!.toLowerCase()))
          .toList();
      if (hintMatches.length == 1) {
        return _AccountResolution(hintMatches.first.title);
      }
      if (hintMatches.length > 1) {
        return const _AccountResolution(null, isAmbiguous: true);
      }
    }

    final lowerText = text.toLowerCase();
    final titleMatches = accounts
        .where((acc) => lowerText.contains(acc.title.toLowerCase()))
        .toList();
    if (titleMatches.length == 1) {
      return _AccountResolution(titleMatches.first.title);
    }

    // Nunca usar accounts.first como fallback sin evidencia
    return const _AccountResolution(null, isAmbiguous: true);
  }

  List<String> _provenanceTokensForPackage(String? packageName) {
    if (packageName == null || packageName.trim().isEmpty) {
      return const [];
    }
    final pkg = packageName.toLowerCase();
    const known = <String, List<String>>{
      'com.nu.production': ['nu'],
      'com.bancolombia': ['bancolombia'],
      'com.nequi': ['nequi'],
      'com.davivienda': ['davivienda'],
      'com.daviplata': ['daviplata'],
      'com.bancodeoccidente': ['banco de occidente', 'occidente'],
      'com.bbva': ['bbva'],
      'com.scotiabank': ['scotiabank', 'colpatria'],
      'com.colpatria': ['colpatria', 'scotiabank'],
      'com.bancobogota': ['banco de bogota', 'banco de bogotá', 'bogota'],
      'com.avvillas': ['av villas', 'avvillas'],
      'com.bancopopular': ['banco popular', 'popular'],
      'com.rappi': ['rappi', 'rappipay'],
      'com.dale': ['dale'],
      'com.lulo': ['lulo'],
    };
    for (final entry in known.entries) {
      if (pkg.startsWith(entry.key) || pkg.contains(entry.key)) {
        return entry.value;
      }
    }
    return const [];
  }

  String? _detectDestinationAccount(
    NotificationParseResult parseResult,
    String text,
    List<AccountItem> accounts, {
    String? excludeAccount,
  }) {
    // Buscar patrones como "a tu cuenta Nequi *1234", "hacia tu cuenta Nequi"
    final destRegex = RegExp(
      r'(?:a\s+(?:tu\s+)?(?:propia\s+)?(?:cuenta\s+)?|hacia\s+(?:tu\s+)?(?:cuenta\s+)?|destino\s+)([\w\s\*]+?)(?:desde|\.|$|,)',
      caseSensitive: false,
    );
    final match = destRegex.firstMatch(text);
    if (match != null) {
      final candidate = match.group(1)?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        final lowerCandidate = candidate.toLowerCase();
        final byTitle = accounts
            .where((acc) =>
                acc.title != excludeAccount &&
                lowerCandidate.contains(acc.title.toLowerCase()))
            .toList();
        if (byTitle.length == 1) {
          return byTitle.first.title;
        }
        final digitsMatch = RegExp(r'\*(\d{4})\b').firstMatch(candidate);
        if (digitsMatch != null) {
          final last4 = digitsMatch.group(1)!;
          final byLast4 = accounts
              .where((acc) =>
                  acc.title != excludeAccount &&
                  (acc.subtitle.contains(last4) || acc.title.contains(last4)))
              .toList();
          if (byLast4.length == 1) {
            return byLast4.first.title;
          }
        }
      }
    }

    return null;
  }

  String? _detectSourceFromClause(String text, List<AccountItem> accounts) {
    final sourceRegex = RegExp(
      r'\bdesde\s+(?:tu\s+)?(?:cuenta\s+)?([\w\s\*]+?)(?:\s+hacia|\s+a\s+|\.|,|$)',
      caseSensitive: false,
    );
    final match = sourceRegex.firstMatch(text);
    if (match == null) return null;
    final candidate = match.group(1)?.trim();
    if (candidate == null || candidate.isEmpty) return null;

    final lowerCandidate = candidate.toLowerCase();
    final byTitle = accounts
        .where((acc) => lowerCandidate.contains(acc.title.toLowerCase()))
        .toList();
    if (byTitle.length == 1) {
      return byTitle.first.title;
    }

    final digitsMatch = RegExp(r'\*(\d{4})\b').firstMatch(candidate);
    if (digitsMatch != null) {
      final last4 = digitsMatch.group(1)!;
      final byLast4 = accounts
          .where((acc) =>
              acc.subtitle.contains(last4) || acc.title.contains(last4))
          .toList();
      if (byLast4.length == 1) {
        return byLast4.first.title;
      }
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

  String _buildStrategicNote({
    required String reason,
    required String classification,
    String? category,
    required DateTime referenceDate,
  }) {
    final buffer = StringBuffer(reason);
    final cat = category?.trim();
    if (cat != null &&
        cat.isNotEmpty &&
        (classification == 'gasto' || classification == 'ingreso')) {
      final monthlyTotal = _readCategoryMonthTotalSafe(
        classification: classification,
        category: cat,
        referenceDate: referenceDate,
      );
      if (monthlyTotal != null) {
        if (monthlyTotal == 0.0) {
          buffer.write('. Sin acumulado previo en $cat este mes');
        } else {
          try {
            final formatted = CurrencyHelper.format(monthlyTotal);
            buffer.write('. Acumulado del mes en $cat: $formatted');
          } catch (_) {
            buffer.write(
              '. Acumulado del mes en $cat: ${monthlyTotal.toStringAsFixed(0)}',
            );
          }
        }
      }
    }
    return '$buffer.';
  }

  double? _readCategoryMonthTotalSafe({
    required String classification,
    required String category,
    required DateTime referenceDate,
  }) {
    try {
      if (_summaryCache == null) {
        if (!Hive.isBoxOpen('data')) return null;
        final dataBox = Hive.box<Add_data>('data');
        if (dataBox.isEmpty) return 0.0;
      }
      final cache = _summaryCache ?? MonthlySummaryCache.instance;
      final summary = cache.getMonthSummary(
        referenceDate.year,
        referenceDate.month,
      );
      if (classification == 'gasto') {
        return summary.expensesByCategory[category] ?? 0.0;
      }
      if (classification == 'ingreso') {
        return summary.incomeByCategory[category] ?? 0.0;
      }
    } catch (_) {
      // Caja 'data' cerrada o con tipo distinto en pruebas unitarias aisladas.
    }
    return null;
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

class _AccountResolution {
  final String? accountName;
  final bool isAmbiguous;

  const _AccountResolution(this.accountName, {this.isAmbiguous = false});
}
