class PendingTransactionItem {
  final String id;
  final String? notificationId;
  final String rawText;
  final String? merchantKey;
  final String? comercio;
  final double? monto;
  final String moneda;
  final DateTime fecha;
  final String
      classification; // 'gasto', 'ingreso', 'transferencia-propia', 'sospechosa'
  final String? moneoType; // 'Expenses', 'Income', 'Transfer', null
  final String? category;
  final String? accountName;
  final String? destinationAccount;
  final double confidence;
  final bool requiresReview;
  final bool autoProcessable;
  final String decisionSource;
  final List<String> flags;
  final DateTime createdAt;
  final String executionStatus; // 'pending' | 'executing' | 'executed'
  final String? referenceId;
  final String channel; // 'app' | 'sms' | 'correo'
  final String? packageName;
  final String? channelId;
  final List<Map<String, dynamic>> groupedEvents;
  final String? strategicNote;

  const PendingTransactionItem({
    required this.id,
    this.notificationId,
    required this.rawText,
    this.merchantKey,
    this.comercio,
    this.monto,
    this.moneda = 'COP',
    required this.fecha,
    required this.classification,
    this.moneoType,
    this.category,
    this.accountName,
    this.destinationAccount,
    required this.confidence,
    required this.requiresReview,
    required this.autoProcessable,
    required this.decisionSource,
    this.flags = const [],
    required this.createdAt,
    this.executionStatus = 'pending',
    this.referenceId,
    this.channel = 'app',
    this.packageName,
    this.channelId,
    this.groupedEvents = const [],
    this.strategicNote,
  });

  int get groupedCount => groupedEvents.isEmpty ? 1 : groupedEvents.length;
  bool get isGrouped => groupedEvents.length > 1;

  /// Determina si cumple todos los invariantes para aprobación masiva en lote ("Aceptar todo").
  bool get isEligibleForAcceptAll {
    if (classification == 'sospechosa') return false;
    if (requiresReview) return false;
    if (confidence < 0.85) return false;
    if (accountName == null || accountName!.trim().isEmpty) return false;
    if (classification == 'transferencia-propia' &&
        (destinationAccount == null || destinationAccount!.trim().isEmpty)) {
      return false;
    }
    return true;
  }

  PendingTransactionItem copyWith({
    String? id,
    String? notificationId,
    String? rawText,
    String? merchantKey,
    String? comercio,
    double? monto,
    String? moneda,
    DateTime? fecha,
    String? classification,
    String? moneoType,
    String? category,
    String? accountName,
    String? destinationAccount,
    double? confidence,
    bool? requiresReview,
    bool? autoProcessable,
    String? decisionSource,
    List<String>? flags,
    DateTime? createdAt,
    String? executionStatus,
    String? referenceId,
    String? channel,
    String? packageName,
    String? channelId,
    List<Map<String, dynamic>>? groupedEvents,
    String? strategicNote,
  }) {
    return PendingTransactionItem(
      id: id ?? this.id,
      notificationId: notificationId ?? this.notificationId,
      rawText: rawText ?? this.rawText,
      merchantKey: merchantKey ?? this.merchantKey,
      comercio: comercio ?? this.comercio,
      monto: monto ?? this.monto,
      moneda: moneda ?? this.moneda,
      fecha: fecha ?? this.fecha,
      classification: classification ?? this.classification,
      moneoType: moneoType ?? this.moneoType,
      category: category ?? this.category,
      accountName: accountName ?? this.accountName,
      destinationAccount: destinationAccount ?? this.destinationAccount,
      confidence: confidence ?? this.confidence,
      requiresReview: requiresReview ?? this.requiresReview,
      autoProcessable: autoProcessable ?? this.autoProcessable,
      decisionSource: decisionSource ?? this.decisionSource,
      flags: flags ?? this.flags,
      createdAt: createdAt ?? this.createdAt,
      executionStatus: executionStatus ?? this.executionStatus,
      referenceId: referenceId ?? this.referenceId,
      channel: channel ?? this.channel,
      packageName: packageName ?? this.packageName,
      channelId: channelId ?? this.channelId,
      groupedEvents: groupedEvents ?? this.groupedEvents,
      strategicNote: strategicNote ?? this.strategicNote,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'notification_id': notificationId,
        'raw_text': rawText,
        'merchant_key': merchantKey,
        'comercio': comercio,
        'monto': monto,
        'moneda': moneda,
        'fecha': fecha.toIso8601String(),
        'classification': classification,
        'moneo_type': moneoType,
        'category': category,
        'account_name': accountName,
        'destination_account': destinationAccount,
        'confidence': confidence,
        'requires_review': requiresReview,
        'auto_processable': autoProcessable,
        'decision_source': decisionSource,
        'flags': flags,
        'created_at': createdAt.toIso8601String(),
        'execution_status': executionStatus,
        if (referenceId != null) 'reference_id': referenceId,
        'channel': channel,
        if (packageName != null) 'package_name': packageName,
        if (channelId != null) 'channel_id': channelId,
        if (groupedEvents.isNotEmpty) 'grouped_events': groupedEvents,
        if (strategicNote != null) 'strategic_note': strategicNote,
      };

  factory PendingTransactionItem.fromJson(
    Map<String, dynamic> json,
  ) =>
      PendingTransactionItem(
        id: json['id'] as String,
        notificationId:
            (json['notification_id'] ?? json['notificationId']) as String?,
        rawText: (json['raw_text'] ?? json['rawText'] ?? '') as String,
        merchantKey: (json['merchant_key'] ?? json['merchantKey']) as String?,
        comercio: json['comercio'] as String?,
        monto: json['monto'] != null ? (json['monto'] as num).toDouble() : null,
        moneda: (json['moneda'] as String?) ?? 'COP',
        fecha: json['fecha'] != null
            ? DateTime.parse(json['fecha'] as String)
            : DateTime.now(),
        classification: (json['classification'] as String?) ?? 'desconocido',
        moneoType: (json['moneo_type'] ?? json['moneoType']) as String?,
        category: json['category'] as String?,
        accountName: (json['account_name'] ?? json['accountName']) as String?,
        destinationAccount: (json['destination_account'] ??
            json['destinationAccount']) as String?,
        confidence: json['confidence'] != null
            ? (json['confidence'] as num).toDouble()
            : 0.0,
        requiresReview:
            (json['requires_review'] ?? json['requiresReview']) as bool? ??
                true,
        autoProcessable:
            (json['auto_processable'] ?? json['autoProcessable']) as bool? ??
                false,
        decisionSource:
            (json['decision_source'] ?? json['decisionSource']) as String? ??
                'deterministic_rules',
        flags: json['flags'] != null
            ? List<String>.from(json['flags'] as List)
            : const [],
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : (json['createdAt'] != null
                ? DateTime.parse(json['createdAt'] as String)
                : DateTime.now()),
        executionStatus: (json['execution_status'] ??
                json['executionStatus']) as String? ??
            'pending',
        referenceId: (json['reference_id'] ?? json['referenceId']) as String?,
        channel: (json['channel'] as String?) ?? 'app',
        packageName: (json['package_name'] ?? json['packageName']) as String?,
        channelId: (json['channel_id'] ?? json['channelId']) as String?,
        groupedEvents: (json['grouped_events'] is List)
            ? (json['grouped_events'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : const [],
        strategicNote:
            (json['strategic_note'] ?? json['strategicNote']) as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingTransactionItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          merchantKey == other.merchantKey &&
          monto == other.monto &&
          fecha == other.fecha &&
          classification == other.classification &&
          accountName == other.accountName;

  @override
  int get hashCode =>
      id.hashCode ^
      (merchantKey?.hashCode ?? 0) ^
      (monto?.hashCode ?? 0) ^
      fecha.hashCode ^
      classification.hashCode ^
      (accountName?.hashCode ?? 0);

  @override
  String toString() =>
      'PendingTransactionItem(id: $id, comercio: $comercio, monto: $monto, '
      'classification: $classification, confidence: $confidence, requiresReview: $requiresReview)';
}
