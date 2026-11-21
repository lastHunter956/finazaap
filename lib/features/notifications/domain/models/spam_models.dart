import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';

/// Estado de un patrón de Spam/descarte aprendido.
enum SpamPatternStatus {
  /// Descartado 1 vez por el usuario (activo para filtrar similares).
  activo('activo'),

  /// Reconfirmado como spam o descartado >= 2 veces (atajo 0-IA directo a Spam).
  consolidado('consolidado'),

  /// El usuario rescató una notificación ("No es spam") y desactivó la regla.
  desactivado('desactivado');

  final String wireValue;
  const SpamPatternStatus(this.wireValue);

  static SpamPatternStatus fromWire(String? value) {
    switch (value) {
      case 'consolidado':
        return SpamPatternStatus.consolidado;
      case 'desactivado':
        return SpamPatternStatus.desactivado;
      case 'activo':
      default:
        return SpamPatternStatus.activo;
    }
  }
}

/// Patrón de notificación ignorada/spam aprendido por feedback negativo del usuario.
class DismissedPattern {
  static const int consolidatedThreshold = 2;

  final String signatureKey;
  final String packageName;
  final String? channelId;
  final String templateText;
  final int confirmations;
  final int rescuedCount;
  final SpamPatternStatus status;
  final DateTime createdAt;
  final DateTime lastSeenAt;

  const DismissedPattern({
    required this.signatureKey,
    required this.packageName,
    this.channelId,
    required this.templateText,
    this.confirmations = 1,
    this.rescuedCount = 0,
    this.status = SpamPatternStatus.activo,
    required this.createdAt,
    required this.lastSeenAt,
  });

  bool get isActive => status != SpamPatternStatus.desactivado;
  bool get isConsolidated => status == SpamPatternStatus.consolidado;

  DismissedPattern reinforce({DateTime? at, String? newChannelId}) {
    final nextConfirmations = confirmations + 1;
    final nextStatus = nextConfirmations >= consolidatedThreshold
        ? SpamPatternStatus.consolidado
        : SpamPatternStatus.activo;
    return DismissedPattern(
      signatureKey: signatureKey,
      packageName: packageName,
      channelId: (channelId != null && channelId!.isNotEmpty)
          ? channelId
          : newChannelId,
      templateText: templateText,
      confirmations: nextConfirmations,
      rescuedCount: rescuedCount,
      status: nextStatus,
      createdAt: createdAt,
      lastSeenAt: at ?? DateTime.now(),
    );
  }

  DismissedPattern markRescued({DateTime? at}) {
    return DismissedPattern(
      signatureKey: signatureKey,
      packageName: packageName,
      channelId: channelId,
      templateText: templateText,
      confirmations: confirmations,
      rescuedCount: rescuedCount + 1,
      status: SpamPatternStatus.desactivado,
      createdAt: createdAt,
      lastSeenAt: at ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'signature_key': signatureKey,
        'package_name': packageName,
        if (channelId != null && channelId!.isNotEmpty) 'channel_id': channelId,
        'template_text': templateText,
        'confirmations': confirmations,
        'rescued_count': rescuedCount,
        'status': status.wireValue,
        'created_at': createdAt.toIso8601String(),
        'last_seen_at': lastSeenAt.toIso8601String(),
      };

  factory DismissedPattern.fromJson(Map<String, dynamic> json) {
    final confirmations = (json['confirmations'] as num?)?.toInt() ?? 1;
    final rescuedCount =
        (json['rescued_count'] ?? json['rescuedCount'] as num?)?.toInt() ?? 0;
    final rawStatus = json['status'] as String?;
    return DismissedPattern(
      signatureKey:
          (json['signature_key'] ?? json['signatureKey']) as String,
      packageName: (json['package_name'] ?? json['packageName'] ?? '') as String,
      channelId: (json['channel_id'] ?? json['channelId']) as String?,
      templateText:
          (json['template_text'] ?? json['templateText'] ?? '') as String,
      confirmations: confirmations,
      rescuedCount: rescuedCount,
      status: rawStatus != null
          ? SpamPatternStatus.fromWire(rawStatus)
          : (confirmations >= consolidatedThreshold
              ? SpamPatternStatus.consolidado
              : SpamPatternStatus.activo),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'] as String)
          : DateTime.now(),
    );
  }
}

/// Notificación retenida temporalmente en la pestaña **Spam** (máximo 5 días).
///
/// Nunca afecta saldos reales ni entra en "Aceptar todo".
class SpamNotificationItem {
  static const Duration retentionTtl = Duration(days: 5);

  final String id;
  final PendingTransactionItem item;
  final String spamReason;
  final String
      spamSource; // 'user_discard' | 'learned_spam' | 'ai_spam' | 'promo_filter'
  final String? matchedRuleKey;
  final String? channelId;
  final DateTime detectedAt;
  final DateTime expiresAt;

  SpamNotificationItem({
    required this.id,
    required this.item,
    required this.spamReason,
    required this.spamSource,
    this.matchedRuleKey,
    this.channelId,
    required this.detectedAt,
    DateTime? expiresAt,
  }) : expiresAt = expiresAt ?? detectedAt.add(retentionTtl);

  bool isExpired({DateTime? now}) {
    final ref = now ?? DateTime.now();
    return ref.isAfter(expiresAt) || ref.difference(detectedAt) > retentionTtl;
  }

  int remainingDays({DateTime? now}) {
    final ref = now ?? DateTime.now();
    final diff = expiresAt.difference(ref);
    if (diff.isNegative) return 0;
    final days = (diff.inHours / 24).ceil();
    return days.clamp(0, 5);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'item': item.toJson(),
        'spam_reason': spamReason,
        'spam_source': spamSource,
        if (matchedRuleKey != null) 'matched_rule_key': matchedRuleKey,
        if (channelId != null && channelId!.isNotEmpty) 'channel_id': channelId,
        'detected_at': detectedAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      };

  factory SpamNotificationItem.fromJson(Map<String, dynamic> json) {
    final detectedAt = json['detected_at'] != null
        ? DateTime.parse(json['detected_at'] as String)
        : DateTime.now();
    final expiresAt = json['expires_at'] != null
        ? DateTime.parse(json['expires_at'] as String)
        : detectedAt.add(retentionTtl);
    return SpamNotificationItem(
      id: json['id'] as String,
      item: PendingTransactionItem.fromJson(
        Map<String, dynamic>.from(json['item'] as Map),
      ),
      spamReason:
          (json['spam_reason'] ?? json['spamReason'] ?? 'Marcada como spam')
              as String,
      spamSource:
          (json['spam_source'] ?? json['spamSource'] ?? 'user_discard')
              as String,
      matchedRuleKey:
          (json['matched_rule_key'] ?? json['matchedRuleKey']) as String?,
      channelId: (json['channel_id'] ?? json['channelId']) as String?,
      detectedAt: detectedAt,
      expiresAt: expiresAt,
    );
  }
}

/// Resultado de evaluar si una notificación coincide con un patrón de Spam aprendido.
class SpamMatchResult {
  final DismissedPattern pattern;
  final double score;
  final bool matchedByChannel;

  const SpamMatchResult({
    required this.pattern,
    required this.score,
    this.matchedByChannel = false,
  });
}
