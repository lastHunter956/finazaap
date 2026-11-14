import 'dart:math';

import 'package:finazaap/utils/currency_helper.dart';
import '../domain/models/notification_event.dart';
import '../domain/models/notification_parse_result.dart';

/// Parser genérico de notificaciones bancarias para Moneo.
///
/// Convierte texto crudo de notificaciones en eventos [NotificationParseResult]
/// fuertemente tipados sin depender de plantillas rígidas por entidad bancaria.
///
/// Incluye:
/// - Detección anti-fraude incondicional (URLs, dominios acortados y TLDs de phishing).
/// - Detección de mensajes de seguridad y códigos OTP (no transaccionales).
/// - Extracción agnóstica de monto y validación cruzada de separadores (COP/USD/EUR).
/// - Extracción de tipo preliminar (gasto, ingreso, transferencia, desconocido).
/// - Extracción de comercio, cuenta/tarjeta y fecha.
/// - Cálculo de confianza y evaluación de invariantes (`requires_review`, `auto_processable`).
class NotificationParser {
  /// Expresión regular para detectar enlaces, esquemas web y acortadores sospechosos.
  static final RegExp _antiFraudLinkRegex = RegExp(
    r'(https?://\S+|www\.\S+|\b(?:bit\.ly|tinyurl\.com|t\.co|cutt\.ly|rb\.gy|wa\.me)/[^\s]*|[a-zA-Z0-9-]+\.(?:xyz|top|click)\b)',
    caseSensitive: false,
  );

  /// Expresión regular para detectar mensajes de seguridad o códigos de un solo uso (OTP).
  static final RegExp _otpRegex = RegExp(
    r'(c[oó]digo\s+(?:de\s+)?(?:seguridad|verificaci[oó]n|confirmaci[oó]n|acceso)|clave\s+din[aá]mica|clave\s+temporal|c[oó]digo\s+otp|\botp\b|token\s+de\s+seguridad|no\s+(?:lo\s+)?compartas\s+(?:con\s+nadie|este\s+c[oó]digo))',
    caseSensitive: false,
  );

  /// Marcadores explícitos de operación ya ejecutada/aprobada.
  static final RegExp _completedOperationRegex = RegExp(
    r'\b(pago\s+aprobado|pago\s+exitoso|pago\s+realizado|pago\s+confirmado|'
    r'pago\s+aplicado|pagaste|compra\s+aprobada|compraste|'
    r'transacci[oó]n\s+aprobada|transacci[oó]n\s+exitosa|'
    r'transferencia\s+exitosa|transferencia\s+aprobada|transferiste|'
    r'se\s+realiz[oó]\s+un\s+pago|hemos\s+debitado|d[eé]bito\s+realizado)\b',
    caseSensitive: false,
  );

  /// Marcadores de solicitud, recordatorio o pago pendiente aún no consumado.
  static final RegExp _pendingPaymentRequestRegex = RegExp(
    r'\b(tienes\s+un\s+pago|completa\s+tu\s+pago|realiza\s+tu\s+pago|'
    r'haz\s+tu\s+pago|pago\s+pendiente|por\s+pagar|fecha\s+l[ií]mite\s+de\s+pago|'
    r'pr[oó]ximo\s+pago|recordatorio\s+de\s+pago|cuota\s+pendiente|'
    r'solicitud\s+de\s+pago|autoriza\s+tu\s+pago|paga\s+(?:aqu[ií]|ahora|antes\s+de))\b',
    caseSensitive: false,
  );

  /// Distingue solicitudes/recordatorios de pago de operaciones ya completadas.
  static bool isPendingPaymentRequest(String text) {
    if (_completedOperationRegex.hasMatch(text)) {
      return false;
    }
    return _pendingPaymentRequestRegex.hasMatch(text);
  }

  /// Parsea un [NotificationEvent] en un resultado tipado [NotificationParseResult].
  NotificationParseResult parse(NotificationEvent event) {
    return parseRaw(
      title: event.title,
      body: event.body,
      packageName: event.packageName,
      timestamp: event.timestamp,
    );
  }

  /// Parsea texto crudo (título y cuerpo) directamente.
  NotificationParseResult parseRaw({
    required String title,
    required String body,
    String packageName = '',
    DateTime? timestamp,
  }) {
    final rawTitle = title.trim();
    final rawBody = body.trim();
    final cleanTitle =
        rawTitle.length > 200 ? rawTitle.substring(0, 200) : rawTitle;
    final cleanBody =
        rawBody.length > 1000 ? rawBody.substring(0, 1000) : rawBody;
    final fullRawText = cleanTitle.isEmpty
        ? cleanBody
        : cleanBody.isEmpty
            ? cleanTitle
            : '$cleanTitle. $cleanBody';

    final effectiveDate = timestamp ?? DateTime.now();

    // ─────────────────────────────────────────────────────────────────────────
    // ETAPA 1: ANTI-FRAUDE ESTRICTO (Enlaces y acortadores)
    // ─────────────────────────────────────────────────────────────────────────
    if (_containsSuspiciousLink(cleanTitle) ||
        _containsSuspiciousLink(cleanBody)) {
      return SuspiciousNotification(
        rawText: fullRawText,
        reason:
            'Se detectó un enlace o acortador sospechoso en la notificación',
        fecha: effectiveDate,
        flags: const ['anti_fraud_link_detected'],
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ETAPA 2: MENSAJES NO FINANCIEROS Y CÓDIGOS OTP
    // ─────────────────────────────────────────────────────────────────────────
    if (_isOtpOrSecurityMessage(fullRawText)) {
      return UnparseableNotification(
        rawText: fullRawText,
        reason:
            'Mensaje de seguridad o código de verificación no transaccional (OTP)',
        fecha: effectiveDate,
        flags: const ['non_transactional_text', 'otp_detected'],
      );
    }

    if (isPendingPaymentRequest(fullRawText)) {
      return UnparseableNotification(
        rawText: fullRawText,
        reason:
            'Solicitud o recordatorio de pago pendiente, no una operación completada',
        fecha: effectiveDate,
        flags: const ['non_transactional_text', 'payment_request_pending'],
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ETAPA 3: EXTRACCIÓN DE MONTO Y MONEDA CON VALIDACIÓN CRUZADA
    // ─────────────────────────────────────────────────────────────────────────
    final amountExtraction = _extractAmountAndCurrency(fullRawText);
    if (amountExtraction == null || amountExtraction.amount <= 0) {
      return UnparseableNotification(
        rawText: fullRawText,
        reason:
            'No se pudo identificar un monto financiero válido en la notificación',
        fecha: effectiveDate,
        flags: const ['non_transactional_text', 'missing_amount'],
      );
    }

    final double amount = amountExtraction.amount;
    final String currency = amountExtraction.currency;
    final bool isAmountAmbiguous = amountExtraction.isAmbiguous;

    // ─────────────────────────────────────────────────────────────────────────
    // ETAPA 4: EXTRACCIÓN DE TIPO (gasto, ingreso, transferencia, desconocido)
    // ─────────────────────────────────────────────────────────────────────────
    final String transactionType = _extractTransactionType(fullRawText);

    // ─────────────────────────────────────────────────────────────────────────
    // ETAPA 5: EXTRACCIÓN DE COMERCIO / ESTABLECIMIENTO
    // ─────────────────────────────────────────────────────────────────────────
    final String? merchant = _extractMerchant(fullRawText);

    // ─────────────────────────────────────────────────────────────────────────
    // ETAPA 6: EXTRACCIÓN DE CUENTA O TARJETA
    // ─────────────────────────────────────────────────────────────────────────
    final AccountHint? account = _extractAccountHint(fullRawText);

    // ─────────────────────────────────────────────────────────────────────────
    // ETAPA 7: FECHA DE LA TRANSACCIÓN
    // ─────────────────────────────────────────────────────────────────────────
    final (DateTime transactionDate, bool inferredDate) =
        _extractDate(fullRawText, fallback: effectiveDate);

    // ─────────────────────────────────────────────────────────────────────────
    // ETAPA 8: EVALUACIÓN DE CONFIANZA Y CUMPLIMIENTO DE INVARIANTES
    // ─────────────────────────────────────────────────────────────────────────
    final List<String> flags = [];
    if (inferredDate) flags.add('inferred_date');
    if (merchant == null) flags.add('missing_merchant');
    if (transactionType == 'desconocido') flags.add('unknown_transaction_type');
    if (isAmountAmbiguous) flags.add('ambiguous_amount_separator');

    double confidence = 0.90;

    if (transactionType == 'desconocido') {
      confidence -= 0.20;
    }

    if (merchant != null) {
      confidence += 0.03;
    } else {
      confidence -= 0.12;
    }

    if (account != null && account.last4 != null) {
      confidence += 0.02;
    }

    if (isAmountAmbiguous) {
      confidence = 0.50;
    }

    confidence = max(0.0, min(0.98, confidence));

    // Reglas e invariantes no negociables:
    // 1. Si confidence < 0.80 -> requiresReview = true
    // 2. Si requiresReview = true -> autoProcessable = false
    // 3. Si isAmountAmbiguous -> requiresReview = true, autoProcessable = false
    final bool requiresReview = confidence < 0.80 || isAmountAmbiguous;
    final bool autoProcessable = !requiresReview;

    return ParsedTransaction(
      tipo: transactionType,
      monto: amount,
      moneda: currency,
      comercio: merchant,
      fecha: transactionDate,
      cuenta: account,
      confidence: double.parse(confidence.toStringAsFixed(2)),
      requiresReview: requiresReview,
      autoProcessable: autoProcessable,
      flags: flags,
    );
  }

  /// Verifica si el texto contiene enlaces o acortadores sospechosos.
  bool _containsSuspiciousLink(String text) {
    if (text.isEmpty) return false;
    return _antiFraudLinkRegex.hasMatch(text);
  }

  /// Verifica si el texto es un código de un solo uso o alerta de seguridad.
  bool _isOtpOrSecurityMessage(String text) {
    return _otpRegex.hasMatch(text);
  }

  /// Extrae el monto y la divisa aplicando validación cruzada de separadores.
  _AmountResult? _extractAmountAndCurrency(String text) {
    // 1. Detectar divisa explícita o contexto configurado
    String currency = CurrencyHelper.currencyCode;
    if (RegExp(r'\bUSD\b|\bUS\$\b', caseSensitive: false).hasMatch(text)) {
      currency = 'USD';
    } else if (RegExp(r'\bEUR\b|€', caseSensitive: false).hasMatch(text)) {
      currency = 'EUR';
    } else if (RegExp(r'\bMXN\b', caseSensitive: false).hasMatch(text)) {
      currency = 'MXN';
    } else if (RegExp(r'\bPEN\b|S\/', caseSensitive: false).hasMatch(text)) {
      currency = 'PEN';
    } else if (RegExp(r'\bGBP\b|£', caseSensitive: false).hasMatch(text)) {
      currency = 'GBP';
    } else if (RegExp(r'\bCOP\b|\bCOL\$\b', caseSensitive: false)
        .hasMatch(text)) {
      currency = 'COP';
    }

    // 2. Extraer candidatos de montos numéricos asociados a monedas o conectores financieros
    final RegExp amountPattern = RegExp(
      r'(?:(?:\$|COP|USD|MXN|PEN|EUR|GBP|COL\$|US\$|S\/|€|£)\s*(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?))|'
      r'(?:(?:por|de|valor|monto|total|cargo|pago|retiro)\s+(?:de\s+)?(?:\$|COP|USD|MXN|PEN|EUR|GBP|COL\$|US\$|S\/|€|£)?\s*(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?))',
      caseSensitive: false,
    );

    final matches = amountPattern.allMatches(text);
    for (final match in matches) {
      final rawNum = (match.group(1) ?? match.group(2))?.trim();
      if (rawNum == null || rawNum.isEmpty) continue;

      // Descartar si el token coincide con años o horas comunes (ej. 2026, 14:30)
      if (rawNum.length == 4 &&
          (rawNum.startsWith('19') || rawNum.startsWith('20')) &&
          !text.contains('\$$rawNum')) {
        continue;
      }

      final parsed = _parseNumericToken(rawNum, currencyContext: currency);
      if (parsed != null && parsed.amount > 0) {
        return parsed;
      }
    }

    // Intento de fallback: buscar cualquier valor monetario con símbolo de moneda
    final fallbackPattern = RegExp(
      r'[\$€£]\s*(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)',
    );
    final fallbackMatch = fallbackPattern.firstMatch(text);
    if (fallbackMatch != null) {
      final rawNum = fallbackMatch.group(1)?.trim();
      if (rawNum != null && rawNum.isNotEmpty) {
        final parsed = _parseNumericToken(rawNum, currencyContext: currency);
        if (parsed != null && parsed.amount > 0) {
          return parsed;
        }
      }
    }

    return null;
  }

  /// Analiza y convierte una cadena numérica a double considerando separadores de miles y decimales.
  _AmountResult? _parseNumericToken(String token,
      {required String currencyContext}) {
    final hasDot = token.contains('.');
    final hasComma = token.contains(',');

    // Caso 1: Tiene tanto punto como coma (completamente inequívoco)
    if (hasDot && hasComma) {
      final firstDot = token.indexOf('.');
      final firstComma = token.indexOf(',');

      if (firstDot < firstComma) {
        // Formato Europeo/Latino: 1.250.000,50 (Punto miles, Coma decimales)
        final clean = token.replaceAll('.', '').replaceAll(',', '.');
        final value = double.tryParse(clean);
        return value != null
            ? _AmountResult(
                amount: value, currency: currencyContext, isAmbiguous: false)
            : null;
      } else {
        // Formato Americano: 1,250,000.50 (Coma miles, Punto decimales)
        final clean = token.replaceAll(',', '');
        final value = double.tryParse(clean);
        return value != null
            ? _AmountResult(
                amount: value, currency: currencyContext, isAmbiguous: false)
            : null;
      }
    }

    // Caso 2: Contiene únicamente puntos
    if (hasDot && !hasComma) {
      final dotCount = '.'.allMatches(token).length;

      // Múltiples puntos: 1.250.000 (claramente separadores de miles)
      if (dotCount >= 2) {
        final clean = token.replaceAll('.', '');
        final value = double.tryParse(clean);
        return value != null
            ? _AmountResult(
                amount: value, currency: currencyContext, isAmbiguous: false)
            : null;
      }

      // Un solo punto: ej. 45.000 vs 1.234 vs 45.50
      final parts = token.split('.');
      final decimalPart = parts[1];

      // Si tiene 1 o 2 dígitos tras el punto, es decimal (ej. 45.50 o 10.5)
      if (decimalPart.length == 1 || decimalPart.length == 2) {
        final value = double.tryParse(token);
        return value != null
            ? _AmountResult(
                amount: value, currency: currencyContext, isAmbiguous: false)
            : null;
      }

      // Si tiene exactamente 3 dígitos tras el punto:
      if (decimalPart.length == 3) {
        // En contexto COP/Latino con 2 o más dígitos enteros (ej. 45.000, 100.000):
        // En Colombia no existen transacciones con milésimas de peso; son miles.
        if (currencyContext == 'COP' && parts[0].length >= 2) {
          final clean = token.replaceAll('.', '');
          final value = double.tryParse(clean);
          return value != null
              ? _AmountResult(
                  amount: value, currency: currencyContext, isAmbiguous: false)
              : null;
        }

        // Caso ambiguo: 1.234 (puede ser $1,234 miles o 1.234 decimal en USD)
        // Se castiga la confianza según SKILL.md y se marca requires_review.
        final clean = token.replaceAll('.', '');
        final value = double.tryParse(clean);
        return value != null
            ? _AmountResult(
                amount: value, currency: currencyContext, isAmbiguous: true)
            : null;
      }
    }

    // Caso 3: Contiene únicamente comas
    if (hasComma && !hasDot) {
      final commaCount = ','.allMatches(token).length;

      // Múltiples comas: 1,250,000 (claramente separadores de miles americanos)
      if (commaCount >= 2) {
        final clean = token.replaceAll(',', '');
        final value = double.tryParse(clean);
        return value != null
            ? _AmountResult(
                amount: value, currency: currencyContext, isAmbiguous: false)
            : null;
      }

      // Una sola coma: ej. 123,45 vs 45,000
      final parts = token.split(',');
      final afterComma = parts[1];

      // 1 o 2 dígitos tras la coma: decimal europeo/latino (ej. 123,45)
      if (afterComma.length == 1 || afterComma.length == 2) {
        final clean = token.replaceAll(',', '.');
        final value = double.tryParse(clean);
        return value != null
            ? _AmountResult(
                amount: value, currency: currencyContext, isAmbiguous: false)
            : null;
      }

      // Exactamente 3 dígitos tras la coma: separador de miles americano (ej. 45,000)
      if (afterComma.length == 3) {
        final isAmericanCurrency =
            ['USD', 'MXN', 'PEN', 'GBP'].contains(currencyContext);
        final clean = token.replaceAll(',', '');
        final value = double.tryParse(clean);
        return value != null
            ? _AmountResult(
                amount: value,
                currency: currencyContext,
                isAmbiguous: !isAmericanCurrency,
              )
            : null;
      }
    }

    // Caso 4: Sin separadores (ej. 45000)
    final value = double.tryParse(token);
    if (value != null) {
      return _AmountResult(
          amount: value, currency: currencyContext, isAmbiguous: false);
    }

    return null;
  }

  /// Extrae el tipo preliminar de movimiento mediante heurística léxica agnóstica.
  String _extractTransactionType(String text) {
    final lower = text.toLowerCase();

    // 1. Transferencias entre cuentas propias
    if (lower.contains('transferencia entre cuentas') ||
        lower.contains('mismo titular') ||
        lower.contains('transferencia propia') ||
        lower.contains('entre tus cuentas')) {
      return 'transferencia';
    }

    // 2. Ingresos / Abonos
    final incomeKeywords = [
      'recibiste',
      'te transfirieron',
      'te consignaron',
      'depósito',
      'deposito',
      'abono',
      'consignación',
      'consignacion',
      'transferencia recibida',
      'acreditado',
      'pago recibido',
      'devolución',
      'devolucion',
      'reembolso',
      'te enviaron',
    ];
    for (final kw in incomeKeywords) {
      if (lower.contains(kw)) {
        return 'ingreso';
      }
    }

    // 3. Gastos / Egresos
    final expenseKeywords = [
      'compra',
      'compraste',
      'pago',
      'pagaste',
      'débito',
      'debito',
      'retiro',
      'transferiste',
      'enviaste',
      'cargo',
      'transferencia a',
      'transferencia enviada',
      'descuento',
    ];
    for (final kw in expenseKeywords) {
      if (lower.contains(kw)) {
        return 'gasto';
      }
    }

    return 'desconocido';
  }

  /// Extrae el nombre del comercio o establecimiento posterior a conectores comunes.
  String? _extractMerchant(String text) {
    final candidatePatterns = [
      RegExp(
        r'\b(?:en|establecimiento|comercio)\s+([A-Za-z0-9ÁÉÍÓÚáéíóúñÑüÜ\.\-&'
        r"'\s]{2,45})",
        caseSensitive: false,
      ),
      RegExp(
        r'\b(?:de|a|hacia)\s+([A-Za-z0-9ÁÉÍÓÚáéíóúñÑüÜ\.\-&'
        r"'\s]{2,45})",
        caseSensitive: false,
      ),
    ];

    for (final pattern in candidatePatterns) {
      for (final match in pattern.allMatches(text)) {
        String candidate = match.group(1)?.trim() ?? '';
        if (candidate.isEmpty) continue;

        // Recortar conectores o palabras de parada que siguen al nombre del comercio
        final stopWordsRegex = RegExp(
          r'\s+(?:con|desde|por|para|fecha|hora|tarjeta|cta|cuenta|exitosa|exitoso|aprobada|aprobado|rechazada|valor|saldo|ref|codigo|cod|en\s+tu|en\s+su|en\s+la|en\s+el|en\s+cuenta|el\s+\d|la\s+\d)\b.*$',
          caseSensitive: false,
        );
        candidate = candidate.replaceFirst(stopWordsRegex, '').trim();

        // Si fue capturado tras de/a/hacia, recortar conectores de destino como " en "
        if (candidate.toLowerCase().contains(' en ')) {
          candidate = candidate
              .split(RegExp(r'\s+en\s+', caseSensitive: false))
              .first
              .trim();
        }

        // Limpiar caracteres de puntuación al final
        candidate = candidate.replaceAll(RegExp(r'[\.,;:\*#-]+$'), '').trim();

        // Descartar si coincide con términos genéricos del sistema
        final genericTerms = {
          'tu',
          'su',
          'tu cuenta',
          'su cuenta',
          'cuenta',
          'tarjeta',
          'ahorros',
          'corriente',
          'nequi',
          'daviplata',
          'banco',
          'cajero',
          'clave',
          'linea',
          'tus cuentas',
          'mis cuentas',
        };
        if (genericTerms.contains(candidate.toLowerCase()) ||
            candidate.length < 2) {
          continue;
        }

        return candidate;
      }
    }

    return null;
  }

  /// Extrae los últimos 4 dígitos y el indicio del tipo de cuenta o tarjeta.
  AccountHint? _extractAccountHint(String text) {
    // 1. Extraer últimos 4 dígitos
    String? last4;
    final last4Pattern = RegExp(
      r'(?:tarjeta|cta|cuenta|terminad[ao] en|tc|\*+|x+|xxxx)\s*[:#]?\s*(\d{4})\b|'
      r'\*(\d{4})\b',
      caseSensitive: false,
    );
    final last4Match = last4Pattern.firstMatch(text);
    if (last4Match != null) {
      last4 = last4Match.group(1) ?? last4Match.group(2);
    }

    // 2. Extraer indicio del producto / cuenta
    String? hint;
    final lower = text.toLowerCase();
    if (lower.contains('tarjeta de crédito') ||
        lower.contains('crédito') ||
        lower.contains('credito') ||
        lower.contains('tc ')) {
      hint = 'tarjeta de crédito';
    } else if (lower.contains('ahorros') || lower.contains('cta de ahorros')) {
      hint = 'ahorros';
    } else if (lower.contains('corriente') || lower.contains('cta corriente')) {
      hint = 'corriente';
    } else if (lower.contains('débito') || lower.contains('debito')) {
      hint = 'débito';
    } else if (lower.contains('nequi') ||
        lower.contains('daviplata') ||
        lower.contains('dale') ||
        lower.contains('rappi') ||
        lower.contains('billetera')) {
      hint = 'billetera';
    }

    if (last4 == null && hint == null) {
      return null;
    }

    return AccountHint(last4: last4, hint: hint);
  }

  /// Extrae una fecha explícita del texto o devuelve la fecha inferida.
  (DateTime, bool) _extractDate(String text, {required DateTime fallback}) {
    // Formato DD/MM/YYYY o DD-MM-YYYY
    final dmyPattern = RegExp(r'\b(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})\b');
    final match = dmyPattern.firstMatch(text);
    if (match != null) {
      final day = int.tryParse(match.group(1) ?? '');
      final month = int.tryParse(match.group(2) ?? '');
      var year = int.tryParse(match.group(3) ?? '');
      if (day != null && month != null && year != null) {
        if (year < 100) year += 2000;
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          try {
            return (
              DateTime(year, month, day, fallback.hour, fallback.minute),
              false
            );
          } catch (_) {
            // Fecha inválida, continuar con fallback
          }
        }
      }
    }

    return (fallback, true);
  }
}

/// Alias para mantener coherencia con la denominación del plan arquitectónico.
typedef MoneoNotificationParser = NotificationParser;

class _AmountResult {
  final double amount;
  final String currency;
  final bool isAmbiguous;

  const _AmountResult({
    required this.amount,
    required this.currency,
    required this.isAmbiguous,
  });
}
