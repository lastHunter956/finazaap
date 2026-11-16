import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Canal de origen inferido de una notificación bancaria.
enum NotificationChannel {
  app('app'),
  sms('sms'),
  correo('correo');

  final String wireValue;
  const NotificationChannel(this.wireValue);

  static NotificationChannel fromWire(String? value) {
    switch (value) {
      case 'sms':
        return NotificationChannel.sms;
      case 'correo':
        return NotificationChannel.correo;
      case 'app':
      default:
        return NotificationChannel.app;
    }
  }
}

/// Representación normalizada de un movimiento candidato previo a su creación/agrupación.
class NormalizedNotificationMovement {
  final String id;
  final double amount;
  final int roundedAmount;
  final String currency;
  final DateTime timestamp;
  final String dateKey; // YYYY-MM-DD
  final String normalizedMerchant;
  final String merchantHash;
  final String type; // 'debito' | 'credito' | 'transferencia' | 'desconocido'
  final String? inferredAccount;
  final String? destinationAccount;
  final NotificationChannel channel;
  final String? referenceId;
  final String rawText;
  final String packageName;

  const NormalizedNotificationMovement({
    required this.id,
    required this.amount,
    required this.roundedAmount,
    this.currency = 'COP',
    required this.timestamp,
    required this.dateKey,
    required this.normalizedMerchant,
    required this.merchantHash,
    required this.type,
    this.inferredAccount,
    this.destinationAccount,
    this.channel = NotificationChannel.app,
    this.referenceId,
    required this.rawText,
    this.packageName = '',
  });

  /// Clave de blocking: `(fecha YYYY-MM-DD, monto redondeado, hash de comercio)`.
  String get blockingKey => '$dateKey|$roundedAmount|$merchantHash';

  static String formatDateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String computeMerchantHash(String normalizedMerchant) {
    if (normalizedMerchant.isEmpty) return 'none';
    final digest = sha256.convert(utf8.encode(normalizedMerchant)).toString();
    return digest.substring(0, 12);
  }
}

/// Regla de deduplicación aprendida cuando el usuario confirma "estos N son uno".
class DedupRule {
  final String merchantKey;
  final List<String> channels;
  final int mergeWindowHours;
  final int confirmations;
  final DateTime createdAt;
  final DateTime lastUsedAt;

  const DedupRule({
    required this.merchantKey,
    this.channels = const [],
    this.mergeWindowHours = 48,
    this.confirmations = 1,
    required this.createdAt,
    required this.lastUsedAt,
  });

  DedupRule increment({List<String>? extraChannels, DateTime? at}) {
    final mergedChannels = <String>{
      ...channels,
      if (extraChannels != null) ...extraChannels,
    }.toList();
    return DedupRule(
      merchantKey: merchantKey,
      channels: mergedChannels,
      mergeWindowHours: mergeWindowHours,
      confirmations: confirmations + 1,
      createdAt: createdAt,
      lastUsedAt: at ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'merchant_key': merchantKey,
        'channels': channels,
        'merge_window_hours': mergeWindowHours,
        'confirmations': confirmations,
        'created_at': createdAt.toIso8601String(),
        'last_used_at': lastUsedAt.toIso8601String(),
      };

  factory DedupRule.fromJson(Map<String, dynamic> json) => DedupRule(
        merchantKey: (json['merchant_key'] ?? json['merchantKey']) as String,
        channels: json['channels'] is List
            ? List<String>.from(json['channels'] as List)
            : const [],
        mergeWindowHours:
            (json['merge_window_hours'] ?? json['mergeWindowHours'] as num?)
                    ?.toInt() ??
                48,
        confirmations: (json['confirmations'] as num?)?.toInt() ?? 1,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        lastUsedAt: json['last_used_at'] != null
            ? DateTime.parse(json['last_used_at'] as String)
            : DateTime.now(),
      );
}

enum CorrelationDecisionType {
  /// Movimiento único: crear 1 nuevo ítem pendiente.
  unique,

  /// Duplicado determinista por referencia única (UTR / reference).
  exactDuplicate,

  /// Duplicado probabilístico (mismo monto exacto + ventana 48h + similitud >= 0.90).
  probabilisticDuplicate,

  /// Correlación de transferencia interna (débito en cuenta A + crédito en cuenta B).
  internalTransferPair,
}

class CorrelationResult {
  final CorrelationDecisionType decision;
  final String? matchedPendingItemId;
  final double similarityScore;
  final String reason;
  final String? proposedSourceAccount;
  final String? proposedDestinationAccount;

  const CorrelationResult({
    required this.decision,
    this.matchedPendingItemId,
    this.similarityScore = 0.0,
    required this.reason,
    this.proposedSourceAccount,
    this.proposedDestinationAccount,
  });

  bool get shouldMergeIntoExisting =>
      decision != CorrelationDecisionType.unique &&
      matchedPendingItemId != null;
}
