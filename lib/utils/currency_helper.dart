import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

/// Helper class para formatear cantidades con la divisa configurada por el usuario
class CurrencyHelper {
  static String _cachedCurrency = 'COP';
  
  /// Configuración Maestra de Monedas
  /// Define explícitamente cómo debe verse cada moneda, independiente del locale del dispositivo
  static const Map<String, Map<String, dynamic>> _currencyConfig = {
    // ════════════════════════════════════════════════════════════════════════════
    // GRUPO 1: Formato "Americano" (Coma para miles, Punto para decimales)
    // Ejemplo: $1,234.56
    // ════════════════════════════════════════════════════════════════════════════
    'USD': {
      'locale': 'en_US', 
      'symbol': '\$', 
      'position': 'left', 
      'space': false, 
      'decimals': 2
    },
    'MXN': {
      'locale': 'en_US', // Forzamos en_US para garantizar , y .
      'symbol': '\$', 
      'position': 'left', 
      'space': false, 
      'decimals': 2
    },
    'PEN': {
      'locale': 'en_US', 
      'symbol': 'S/', 
      'position': 'left', 
      'space': true, // S/ 1,234.56
      'decimals': 2
    },
    'GBP': {
      'locale': 'en_GB', 
      'symbol': '£', 
      'position': 'left', 
      'space': false, 
      'decimals': 2
    },

    // ════════════════════════════════════════════════════════════════════════════
    // GRUPO 2: Formato "Latino/Europeo" (Punto para miles, Coma para decimales)
    // Ejemplo: $ 1.234,56
    // ════════════════════════════════════════════════════════════════════════════
    'COP': {
      'locale': 'es_AR', // Forzamos es_AR que garantiza . y , (es_CO a veces varía)
      'symbol': '\$', 
      'position': 'left', 
      'space': true, 
      'decimals': 2
    },
    'ARS': {
      'locale': 'es_AR', 
      'symbol': '\$', 
      'position': 'left', 
      'space': true, 
      'decimals': 2
    },
    'BRL': {
      'locale': 'pt_BR', 
      'symbol': 'R\$', 
      'position': 'left', 
      'space': true, 
      'decimals': 2
    },
    'UYU': {
      'locale': 'es_UY', // o es_AR
      'symbol': '\$U', 
      'position': 'left', 
      'space': true, 
      'decimals': 2
    },
    'VES': {
      'locale': 'es_VE', // o es_AR
      'symbol': 'Bs.', 
      'position': 'left', 
      'space': true, 
      'decimals': 2
    },
    'CLP': {
      'locale': 'es_CL', // o es_AR
      'symbol': '\$', 
      'position': 'left', 
      'space': true, 
      'decimals': 0 // Sin decimales
    },
    'EUR': {
      'locale': 'es_ES', 
      'symbol': '€', 
      'position': 'right', // Euro va a la derecha: 1.234,56 €
      'space': true, 
      'decimals': 2
    },
    
    // Otros
    'JPY': {
      'locale': 'ja_JP', 
      'symbol': '¥', 
      'position': 'left', 
      'space': false, 
      'decimals': 0
    },
  };
  
  /// Carga la divisa desde SharedPreferences y actualiza el cache
  static Future<void> loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedCurrency = prefs.getString('default_currency') ?? 'COP';
  }

  /// Lista inmutable de códigos de moneda soportados.
  static List<String> get supportedCurrencies =>
      List<String>.unmodifiable(_currencyConfig.keys);

  /// Indica si [code] corresponde a una moneda soportada.
  static bool isSupported(String? code) {
    if (code == null) return false;
    return _currencyConfig.containsKey(code.trim().toUpperCase());
  }

  /// Normaliza un código de moneda o retorna [fallback] (por defecto la moneda activa).
  static String normalizeCode(String? code, {String? fallback}) {
    if (code != null) {
      final upper = code.trim().toUpperCase();
      if (_currencyConfig.containsKey(upper)) {
        return upper;
      }
    }
    if (fallback != null && fallback.trim().isNotEmpty) {
      final upperFallback = fallback.trim().toUpperCase();
      if (_currencyConfig.containsKey(upperFallback)) {
        return upperFallback;
      }
    }
    return _cachedCurrency;
  }

  static Map<String, dynamic> _configFor(String? currencyCode) {
    final code = normalizeCode(currencyCode);
    return _currencyConfig[code] ?? _currencyConfig['USD']!;
  }

  /// Obtiene el código de la divisa actual
  static String get currencyCode => _cachedCurrency;

  /// Obtiene el símbolo de la divisa actual
  static String get currencySymbol => symbolFor(_cachedCurrency);

  /// Obtiene el símbolo para una moneda específica sin mutar el estado global.
  static String symbolFor(String? currencyCode) {
    final code = normalizeCode(currencyCode);
    final config = _currencyConfig[code];
    return config != null ? config['symbol'] as String : '\$';
  }

  /// Obtiene los decimales configurados para una moneda específica.
  static int decimalDigitsFor(String? currencyCode) {
    return _configFor(currencyCode)['decimals'] as int;
  }

  /// Indica si se puede transferir entre dos cuentas sin tasa de conversión aprobada.
  static bool canTransferWithoutConversion(
    String? fromCurrency,
    String? toCurrency,
  ) {
    return normalizeCode(fromCurrency) == normalizeCode(toCurrency);
  }

  /// Formatea una cantidad usando la divisa global activa.
  static String format(double amount, {bool showSymbol = true, int? decimalDigits}) {
    return formatFor(
      amount,
      _cachedCurrency,
      showSymbol: showSymbol,
      decimalDigits: decimalDigits,
    );
  }

  /// Formatea una cantidad para una moneda explícita sin mutar el estado global.
  static String formatFor(
    double amount,
    String? currencyCode, {
    bool showSymbol = true,
    int? decimalDigits,
  }) {
    final config = _configFor(currencyCode);

    final locale = config['locale'] as String;
    final symbol = config['symbol'] as String;
    final position = config['position'] as String; // 'left' or 'right'
    final space = config['space'] as bool;
    final defaultDecimals = config['decimals'] as int;

    final digits = decimalDigits ?? defaultDecimals;

    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: '',
      decimalDigits: digits,
    );

    final String formattedNumber = formatter.format(amount).trim();

    if (!showSymbol) return formattedNumber;

    final spacer = space ? ' ' : '';

    if (position == 'left') {
      return '$symbol$spacer$formattedNumber';
    } else {
      return '$formattedNumber$spacer$symbol';
    }
  }

  /// Formatea desde String usando la divisa global activa.
  static String formatString(String amountStr, {bool showSymbol = true, int? decimalDigits}) {
    return formatStringFor(
      amountStr,
      _cachedCurrency,
      showSymbol: showSymbol,
      decimalDigits: decimalDigits,
    );
  }

  /// Formatea desde String para una moneda explícita.
  static String formatStringFor(
    String amountStr,
    String? currencyCode, {
    bool showSymbol = true,
    int? decimalDigits,
  }) {
    final amount = double.tryParse(amountStr) ?? 0.0;
    return formatFor(
      amount,
      currencyCode,
      showSymbol: showSymbol,
      decimalDigits: decimalDigits,
    );
  }

  /// Formatea compacto (1M, 10K) usando la divisa global activa.
  static String formatCompact(double amount, {bool showSymbol = true}) {
    return formatCompactFor(amount, _cachedCurrency, showSymbol: showSymbol);
  }

  /// Formatea compacto (1M, 10K) para una moneda explícita.
  static String formatCompactFor(
    double amount,
    String? currencyCode, {
    bool showSymbol = true,
  }) {
    final config = _configFor(currencyCode);
    final locale = config['locale'] as String;
    final symbol = config['symbol'] as String;

    final formatter = NumberFormat.compactCurrency(
      locale: locale,
      symbol: showSymbol ? symbol : '',
    );

    return formatter.format(amount);
  }

  // Getter legacy para compatibilidad si alguien lo usa
  static NumberFormat getFormatter({bool showSymbol = true, int? decimalDigits}) {
    // Advertencia: Este método retorna un formatter estándar y podría no respetar
    // exactamenta la posición forzada en format(). Usar format() preferiblemente.
    final config = _configFor(_cachedCurrency);
    return NumberFormat.currency(
      locale: config['locale'] as String,
      symbol: showSymbol ? config['symbol'] as String : '',
      decimalDigits: decimalDigits ?? config['decimals'] as int,
    );
  }

  static const List<String> _commaDecimalCurrencies = [
    'COP',
    'ARS',
    'BRL',
    'UYU',
    'VES',
    'CLP',
    'EUR',
  ];

  /// Indica si la divisa actual usa '.' para miles y ',' para decimales
  static bool get usesCommaDecimal => usesCommaDecimalFor(_cachedCurrency);

  /// Indica si [currencyCode] usa '.' para miles y ',' para decimales.
  static bool usesCommaDecimalFor(String? currencyCode) {
    return _commaDecimalCurrencies.contains(normalizeCode(currencyCode));
  }

  /// Limpia un string de cantidad usando la divisa global activa.
  static String cleanAmountString(String amountStr) {
    return cleanAmountStringFor(amountStr, currencyCode: _cachedCurrency);
  }

  /// Limpia un string de cantidad para una moneda específica sin mutar el estado global.
  static String cleanAmountStringFor(String amountStr, {String? currencyCode}) {
    String clean = amountStr.trim();
    if (usesCommaDecimalFor(currencyCode)) {
      // Remover puntos (miles) y reemplazar coma por punto (decimal)
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // Remover comas (miles)
      clean = clean.replaceAll(',', '');
    }
    return clean;
  }
}

/// Acumulador de totales separados por código de moneda explícito.
/// Nunca suma monedas distintas ni inventa tasas de conversión.
class MultiCurrencyTotals {
  final String fallbackCurrency;
  final Map<String, double> _totals = {};

  MultiCurrencyTotals({
    String? fallbackCurrency,
    Map<String, double>? initial,
  }) : fallbackCurrency = CurrencyHelper.normalizeCode(fallbackCurrency) {
    if (initial != null) {
      initial.forEach((code, amount) => add(code, amount));
    }
  }

  /// Agrega [amount] al bucket de [currencyCode] sin mezclar monedas distintas.
  void add(String? currencyCode, double amount) {
    final normalized = CurrencyHelper.normalizeCode(
      currencyCode,
      fallback: fallbackCurrency,
    );
    _totals[normalized] = (_totals[normalized] ?? 0.0) + amount;
  }

  /// Fusiona otro acumulador respetando la separación por moneda.
  void addAll(MultiCurrencyTotals other) {
    other._totals.forEach((code, amount) {
      _totals[code] = (_totals[code] ?? 0.0) + amount;
    });
  }

  bool get isEmpty => _totals.isEmpty;
  bool get isNotEmpty => _totals.isNotEmpty;
  bool get isMultiCurrency => _totals.length > 1;
  int get currencyCount => _totals.length;

  /// Códigos presentes en orden determinista (moneda principal primero si existe, luego alfabético).
  List<String> get currencies {
    final keys = _totals.keys.toList();
    keys.sort((a, b) {
      if (a == fallbackCurrency && b != fallbackCurrency) return -1;
      if (b == fallbackCurrency && a != fallbackCurrency) return 1;
      return a.compareTo(b);
    });
    return List<String>.unmodifiable(keys);
  }

  /// Mapa inmutable de totales por moneda.
  Map<String, double> get byCurrency => Map<String, double>.unmodifiable({
        for (final code in currencies) code: _totals[code]!,
      });

  /// Total acumulado para [currencyCode] (0.0 si no está presente).
  double totalFor(String currencyCode) {
    final normalized = CurrencyHelper.normalizeCode(
      currencyCode,
      fallback: fallbackCurrency,
    );
    return _totals[normalized] ?? 0.0;
  }

  /// Formatea el total de una moneda específica.
  String formatEntry(
    String currencyCode, {
    bool includeCode = true,
    bool compact = false,
  }) {
    final normalized = CurrencyHelper.normalizeCode(
      currencyCode,
      fallback: fallbackCurrency,
    );
    final value = _totals[normalized] ?? 0.0;
    final formatted = compact
        ? CurrencyHelper.formatCompactFor(value, normalized)
        : CurrencyHelper.formatFor(value, normalized);
    return includeCode ? '$formatted $normalized' : formatted;
  }

  /// Retorna una línea formateada por cada moneda presente.
  List<String> formatLines({
    bool includeCodeWhenSingle = false,
    bool compact = false,
  }) {
    final includeCode = isMultiCurrency || includeCodeWhenSingle;
    return currencies
        .map((code) => formatEntry(code, includeCode: includeCode, compact: compact))
        .toList(growable: false);
  }

  /// Resumen en una línea separando monedas con [separator].
  String formatSummary({
    String separator = ' · ',
    bool includeCodeWhenSingle = false,
    bool compact = false,
  }) {
    if (_totals.isEmpty) {
      final zero = compact
          ? CurrencyHelper.formatCompactFor(0.0, fallbackCurrency)
          : CurrencyHelper.formatFor(0.0, fallbackCurrency);
      return includeCodeWhenSingle ? '$zero $fallbackCurrency' : zero;
    }
    return formatLines(
      includeCodeWhenSingle: includeCodeWhenSingle,
      compact: compact,
    ).join(separator);
  }
}

/// Formateador dinámico para campos de texto monetarios
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final String? currencyCode;

  ThousandsSeparatorInputFormatter({this.currencyCode});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final isCommaDecimal = currencyCode != null
        ? CurrencyHelper.usesCommaDecimalFor(currencyCode)
        : CurrencyHelper.usesCommaDecimal;
    final thousandSeparator = isCommaDecimal ? '.' : ',';
    final decimalSeparator = isCommaDecimal ? ',' : '.';

    if (newValue.text == decimalSeparator) {
      return newValue;
    }

    final escapedDecimal = RegExp.escape(decimalSeparator);
    // Permitir opcionalmente un signo negativo al principio
    final isNegative = newValue.text.startsWith('-');
    final cleanRegex = RegExp('[^0-9$escapedDecimal]');
    
    String cleanText = newValue.text.replaceAll(cleanRegex, '');
    if (isNegative) {
      cleanText = '-' + cleanText;
    }

    final occurrences = decimalSeparator.allMatches(cleanText).length;
    if (occurrences > 1) {
      return oldValue;
    }

    final parts = cleanText.split(decimalSeparator);
    String integerPart = parts[0];
    final String? decimalPart = parts.length > 1 ? parts[1] : null;

    final hasSign = integerPart.startsWith('-');
    String digitsOnly = hasSign ? integerPart.substring(1) : integerPart;

    if (digitsOnly.length > 1 && digitsOnly.startsWith('0')) {
      digitsOnly = int.parse(digitsOnly).toString();
    }

    if (digitsOnly.isNotEmpty) {
      final chars = digitsOnly.split('');
      final buffer = StringBuffer();
      for (int i = 0; i < chars.length; i++) {
        if (i > 0 && (chars.length - i) % 3 == 0) {
          buffer.write(thousandSeparator);
        }
        buffer.write(chars[i]);
      }
      digitsOnly = buffer.toString();
    }

    String formattedText = (hasSign ? '-' : '') + digitsOnly;
    if (decimalPart != null) {
      formattedText += decimalSeparator + decimalPart;
    }

    int newSelectionStart = newValue.selection.start;
    int cleanCharsInNewValue = 0;
    for (int i = 0; i < newSelectionStart && i < newValue.text.length; i++) {
      if (newValue.text[i] != thousandSeparator) {
        cleanCharsInNewValue++;
      }
    }

    int targetCursor = 0;
    int cleanCount = 0;
    while (targetCursor < formattedText.length && cleanCount < cleanCharsInNewValue) {
      if (formattedText[targetCursor] != thousandSeparator) {
        cleanCount++;
      }
      targetCursor++;
    }

    if (targetCursor > formattedText.length) {
      targetCursor = formattedText.length;
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: targetCursor),
    );
  }
}
