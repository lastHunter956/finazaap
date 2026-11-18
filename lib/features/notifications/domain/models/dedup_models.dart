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

/// Regla de deduplicación aprendida cuando el usuario confirma "estos N son uno"
/// o confirma un movimiento y descarta sus avisos paralelos en otras apps.
class DedupRule {
  final String merchantKey;
  final List<String> channels;
  final List<String> packages;
  final int mergeWindowHours;
  final int confirmations;
  final DateTime createdAt;
  final DateTime lastUsedAt;

  const DedupRule({
    required this.merchantKey,
    this.channels = const [],
    this.packages = const [],
    this.mergeWindowHours = 48,
    this.confirmations = 1,
    required this.createdAt,
    required this.lastUsedAt,
  });

  bool get isMultiApp => packages.length >= 2 || channels.length >= 2;

  DedupRule increment({
    List<String>? extraChannels,
    List<String>? extraPackages,
    DateTime? at,
  }) {
    final mergedChannels = <String>{
      ...channels.where((c) => c.trim().isNotEmpty),
      if (extraChannels != null)
        ...extraChannels.map((c) => c.trim()).where((c) => c.isNotEmpty),
    }.toList();
    final mergedPackages = <String>{
      ...packages.where((p) => p.trim().isNotEmpty),
      if (extraPackages != null)
        ...extraPackages.map((p) => p.trim()).where((p) => p.isNotEmpty),
    }.toList();
    return DedupRule(
      merchantKey: merchantKey,
      channels: mergedChannels,
      packages: mergedPackages,
      mergeWindowHours: mergeWindowHours,
      confirmations: confirmations + 1,
      createdAt: createdAt,
      lastUsedAt: at ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'merchant_key': merchantKey,
        'channels': channels,
        'packages': packages,
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
        packages: json['packages'] is List
            ? List<String>.from(json['packages'] as List)
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

/// Registro ligero de un movimiento recientemente confirmado o corregido
/// para evitar re-crear duplicados tardíos (ej. Gmail o SMS) dentro de 48 h.
class RecentMovementRecord {
  final String id;
  final double amount;
  final int roundedAmount;
  final DateTime timestamp;
  final DateTime? recordedAt;
  final String? accountName;
  final String? destinationAccount;
  final String? referenceId;
  final String? merchantKey;
  final String? packageName;
  final String channel;
  final List<String> packages;

  const RecentMovementRecord({
    required this.id,
    double? amount,
    required this.roundedAmount,
    required this.timestamp,
    this.recordedAt,
    this.accountName,
    this.destinationAccount,
    this.referenceId,
    this.merchantKey,
    this.packageName,
    this.channel = 'app',
    this.packages = const [],
  }) : amount = amount ?? roundedAmount * 1.0;

  Set<String> get allPackages => {
        if (packageName != null && packageName!.trim().isNotEmpty)
          packageName!.trim(),
        ...packages.map((p) => p.trim()).where((p) => p.isNotEmpty),
      };

  RecentMovementRecord copyWith({
    String? id,
    double? amount,
    int? roundedAmount,
    DateTime? timestamp,
    DateTime? recordedAt,
    String? accountName,
    String? destinationAccount,
    String? referenceId,
    String? merchantKey,
    String? packageName,
    String? channel,
    List<String>? packages,
  }) {
    return RecentMovementRecord(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      roundedAmount: roundedAmount ?? this.roundedAmount,
      timestamp: timestamp ?? this.timestamp,
      recordedAt: recordedAt ?? this.recordedAt,
      accountName: accountName ?? this.accountName,
      destinationAccount: destinationAccount ?? this.destinationAccount,
      referenceId: referenceId ?? this.referenceId,
      merchantKey: merchantKey ?? this.merchantKey,
      packageName: packageName ?? this.packageName,
      channel: channel ?? this.channel,
      packages: packages ?? this.packages,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'rounded_amount': roundedAmount,
        'timestamp': timestamp.toIso8601String(),
        if (recordedAt != null) 'recorded_at': recordedAt!.toIso8601String(),
        if (accountName != null) 'account_name': accountName,
        if (destinationAccount != null)
          'destination_account': destinationAccount,
        if (referenceId != null) 'reference_id': referenceId,
        if (merchantKey != null) 'merchant_key': merchantKey,
        if (packageName != null) 'package_name': packageName,
        'channel': channel,
        if (packages.isNotEmpty) 'packages': packages,
      };

  factory RecentMovementRecord.fromJson(Map<String, dynamic> json) {
    final rounded =
        (json['rounded_amount'] ?? json['roundedAmount'] as num?)?.toInt() ?? 0;
    final parsedAmount = json['amount'] != null
        ? (json['amount'] as num).toDouble()
        : rounded.toDouble();
    final rawRecordedAt = json['recorded_at'] ?? json['recordedAt'];
    return RecentMovementRecord(
      id: json['id'] as String,
      amount: parsedAmount,
      roundedAmount: rounded,
      timestamp: DateTime.parse(json['timestamp'] as String),
      recordedAt:
          rawRecordedAt is String ? DateTime.tryParse(rawRecordedAt) : null,
      accountName: (json['account_name'] ?? json['accountName']) as String?,
      destinationAccount: (json['destination_account'] ??
          json['destinationAccount']) as String?,
      referenceId: (json['reference_id'] ?? json['referenceId']) as String?,
      merchantKey: (json['merchant_key'] ?? json['merchantKey']) as String?,
      packageName: (json['package_name'] ?? json['packageName']) as String?,
      channel: (json['channel'] as String?) ?? 'app',
      packages: json['packages'] is List
          ? List<String>.from(json['packages'] as List)
          : const [],
    );
  }
}

enum CorrelationDecisionType {
  /// Movimiento único: crear 1 nuevo ítem pendiente.
  unique,

  /// Duplicado determinista por referencia única (UTR / reference).
  exactDuplicate,

  /// Duplicado probabilístico (mismo monto exacto + ventana 48h + similitud >= 0.90)
  /// o coincidencia por regla multi-app aprendida.
  probabilisticDuplicate,

  /// Correlación de transferencia interna (débito en cuenta A + crédito en cuenta B).
  internalTransferPair,

  /// Duplicado tardío de una operación ya confirmada/corregida en el anillo de 48h.
  alreadyConfirmedDuplicate,
}

class CorrelationResult {
  final CorrelationDecisionType decision;
  final String? matchedPendingItemId;
  final String? matchedConfirmedMovementId;
  final double similarityScore;
  final String reason;
  final String? proposedSourceAccount;
  final String? proposedDestinationAccount;

  const CorrelationResult({
    required this.decision,
    this.matchedPendingItemId,
    this.matchedConfirmedMovementId,
    this.similarityScore = 0.0,
    required this.reason,
    this.proposedSourceAccount,
    this.proposedDestinationAccount,
  });

  bool get shouldIgnoreAsAlreadyConfirmed =>
      decision == CorrelationDecisionType.alreadyConfirmedDuplicate;

  bool get shouldMergeIntoExisting =>
      decision != CorrelationDecisionType.unique &&
      decision != CorrelationDecisionType.alreadyConfirmedDuplicate &&
      matchedPendingItemId != null;
}
