class AccountHint {
  final String? last4;
  final String? hint;

  const AccountHint({this.last4, this.hint});

  AccountHint copyWith({String? last4, String? hint}) {
    return AccountHint(last4: last4 ?? this.last4, hint: hint ?? this.hint);
  }

  Map<String, dynamic> toJson() => {'last4': last4, 'hint': hint};

  factory AccountHint.fromJson(Map<String, dynamic> json) => AccountHint(
        last4: json['last4'] as String?,
        hint: json['hint'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountHint &&
          runtimeType == other.runtimeType &&
          last4 == other.last4 &&
          hint == other.hint;

  @override
  int get hashCode => last4.hashCode ^ hint.hashCode;

  @override
  String toString() => 'AccountHint(last4: $last4, hint: $hint)';
}

sealed class NotificationParseResult {
  const NotificationParseResult();

  String get status;
  String get tipo;
  double get confidence;
  bool get requiresReview;
  bool get autoProcessable;
  DateTime get fecha;
  List<String> get flags;

  Map<String, dynamic> toJson();

  factory NotificationParseResult.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String?;
    switch (status) {
      case 'parsed':
        return ParsedTransaction.fromJson(json);
      case 'sospechosa':
        return SuspiciousNotification.fromJson(json);
      case 'unparseable':
      default:
        return UnparseableNotification.fromJson(json);
    }
  }
}

class ParsedTransaction extends NotificationParseResult {
  @override
  final String tipo;
  final double? monto;
  final String moneda;
  final String? comercio;
  @override
  final DateTime fecha;
  final AccountHint? cuenta;
  @override
  final double confidence;
  @override
  final bool requiresReview;
  @override
  final bool autoProcessable;
  @override
  final List<String> flags;

  const ParsedTransaction({
    required this.tipo,
    this.monto,
    this.moneda = 'COP',
    this.comercio,
    required this.fecha,
    this.cuenta,
    required this.confidence,
    required this.requiresReview,
    required this.autoProcessable,
    this.flags = const [],
  });

  @override
  String get status => 'parsed';

  ParsedTransaction copyWith({
    String? tipo,
    double? monto,
    String? moneda,
    String? comercio,
    DateTime? fecha,
    AccountHint? cuenta,
    double? confidence,
    bool? requiresReview,
    bool? autoProcessable,
    List<String>? flags,
  }) {
    return ParsedTransaction(
      tipo: tipo ?? this.tipo,
      monto: monto ?? this.monto,
      moneda: moneda ?? this.moneda,
      comercio: comercio ?? this.comercio,
      fecha: fecha ?? this.fecha,
      cuenta: cuenta ?? this.cuenta,
      confidence: confidence ?? this.confidence,
      requiresReview: requiresReview ?? this.requiresReview,
      autoProcessable: autoProcessable ?? this.autoProcessable,
      flags: flags ?? this.flags,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'status': status,
        'tipo': tipo,
        'monto': monto,
        'moneda': moneda,
        'comercio': comercio,
        'fecha': fecha.toIso8601String(),
        'cuenta': cuenta?.toJson(),
        'confidence': confidence,
        'requires_review': requiresReview,
        'auto_processable': autoProcessable,
        'flags': flags,
      };

  factory ParsedTransaction.fromJson(Map<String, dynamic> json) {
    AccountHint? accountHint;
    if (json['cuenta'] is Map<String, dynamic>) {
      accountHint = AccountHint.fromJson(
        json['cuenta'] as Map<String, dynamic>,
      );
    }

    return ParsedTransaction(
      tipo: (json['tipo'] as String?) ?? 'desconocido',
      monto: json['monto'] != null ? (json['monto'] as num).toDouble() : null,
      moneda: (json['moneda'] as String?) ?? 'COP',
      comercio: json['comercio'] as String?,
      fecha: json['fecha'] != null
          ? DateTime.parse(json['fecha'] as String)
          : DateTime.now(),
      cuenta: accountHint,
      confidence: json['confidence'] != null
          ? (json['confidence'] as num).toDouble()
          : 0.0,
      requiresReview:
          (json['requires_review'] ?? json['requiresReview']) as bool? ?? true,
      autoProcessable:
          (json['auto_processable'] ?? json['autoProcessable']) as bool? ??
              false,
      flags: json['flags'] != null
          ? List<String>.from(json['flags'] as List)
          : const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedTransaction &&
          runtimeType == other.runtimeType &&
          tipo == other.tipo &&
          monto == other.monto &&
          moneda == other.moneda &&
          comercio == other.comercio &&
          fecha == other.fecha &&
          cuenta == other.cuenta &&
          confidence == other.confidence &&
          requiresReview == other.requiresReview &&
          autoProcessable == other.autoProcessable;

  @override
  int get hashCode =>
      tipo.hashCode ^
      monto.hashCode ^
      moneda.hashCode ^
      comercio.hashCode ^
      fecha.hashCode ^
      cuenta.hashCode ^
      confidence.hashCode ^
      requiresReview.hashCode ^
      autoProcessable.hashCode;

  @override
  String toString() =>
      'ParsedTransaction(status: $status, tipo: $tipo, monto: $monto, comercio: $comercio, confidence: $confidence)';
}

class SuspiciousNotification extends NotificationParseResult {
  final String rawText;
  final String reason;
  @override
  final DateTime fecha;
  @override
  final List<String> flags;

  const SuspiciousNotification({
    required this.rawText,
    required this.reason,
    required this.fecha,
    this.flags = const ['anti_fraud_link_detected'],
  });

  @override
  String get status => 'sospechosa';

  @override
  String get tipo => 'sospechosa';

  @override
  double get confidence => 0.0;

  @override
  bool get requiresReview => true;

  @override
  bool get autoProcessable => false;

  SuspiciousNotification copyWith({
    String? rawText,
    String? reason,
    DateTime? fecha,
    List<String>? flags,
  }) {
    return SuspiciousNotification(
      rawText: rawText ?? this.rawText,
      reason: reason ?? this.reason,
      fecha: fecha ?? this.fecha,
      flags: flags ?? this.flags,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'status': status,
        'tipo': tipo,
        'monto': null,
        'comercio': null,
        'fecha': fecha.toIso8601String(),
        'cuenta': null,
        'confidence': confidence,
        'requires_review': requiresReview,
        'auto_processable': autoProcessable,
        'flags': flags,
        'raw_text': rawText,
        'reason': reason,
      };

  factory SuspiciousNotification.fromJson(Map<String, dynamic> json) {
    return SuspiciousNotification(
      rawText: (json['raw_text'] ?? json['rawText'] ?? '') as String,
      reason: (json['reason'] ?? 'Notificación sospechosa detectada') as String,
      fecha: json['fecha'] != null
          ? DateTime.parse(json['fecha'] as String)
          : DateTime.now(),
      flags: json['flags'] != null
          ? List<String>.from(json['flags'] as List)
          : const ['anti_fraud_link_detected'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuspiciousNotification &&
          runtimeType == other.runtimeType &&
          rawText == other.rawText &&
          reason == other.reason &&
          fecha == other.fecha;

  @override
  int get hashCode => rawText.hashCode ^ reason.hashCode ^ fecha.hashCode;

  @override
  String toString() =>
      'SuspiciousNotification(reason: $reason, fecha: $fecha, flags: $flags)';
}

class UnparseableNotification extends NotificationParseResult {
  final String rawText;
  final String reason;
  @override
  final DateTime fecha;
  @override
  final List<String> flags;

  const UnparseableNotification({
    required this.rawText,
    required this.reason,
    required this.fecha,
    this.flags = const ['non_transactional_text'],
  });

  @override
  String get status => 'unparseable';

  @override
  String get tipo => 'desconocido';

  @override
  double get confidence => 0.0;

  @override
  bool get requiresReview => true;

  @override
  bool get autoProcessable => false;

  UnparseableNotification copyWith({
    String? rawText,
    String? reason,
    DateTime? fecha,
    List<String>? flags,
  }) {
    return UnparseableNotification(
      rawText: rawText ?? this.rawText,
      reason: reason ?? this.reason,
      fecha: fecha ?? this.fecha,
      flags: flags ?? this.flags,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'status': status,
        'tipo': tipo,
        'monto': null,
        'comercio': null,
        'fecha': fecha.toIso8601String(),
        'cuenta': null,
        'confidence': confidence,
        'requires_review': requiresReview,
        'auto_processable': autoProcessable,
        'flags': flags,
        'raw_text': rawText,
        'reason': reason,
      };

  factory UnparseableNotification.fromJson(Map<String, dynamic> json) {
    return UnparseableNotification(
      rawText: (json['raw_text'] ?? json['rawText'] ?? '') as String,
      reason: (json['reason'] ?? 'Texto no transaccional') as String,
      fecha: json['fecha'] != null
          ? DateTime.parse(json['fecha'] as String)
          : DateTime.now(),
      flags: json['flags'] != null
          ? List<String>.from(json['flags'] as List)
          : const ['non_transactional_text'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnparseableNotification &&
          runtimeType == other.runtimeType &&
          rawText == other.rawText &&
          reason == other.reason &&
          fecha == other.fecha;

  @override
  int get hashCode => rawText.hashCode ^ reason.hashCode ^ fecha.hashCode;

  @override
  String toString() =>
      'UnparseableNotification(reason: $reason, fecha: $fecha, flags: $flags)';
}
