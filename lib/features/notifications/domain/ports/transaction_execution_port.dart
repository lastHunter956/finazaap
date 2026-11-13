class TransactionExecutionRequest {
  final String type; // 'Expenses', 'Income', 'Transfer'
  final double amount;
  final String accountName;
  final String? destinationAccount;
  final String? detail;
  final DateTime? date;

  const TransactionExecutionRequest({
    required this.type,
    required this.amount,
    required this.accountName,
    this.destinationAccount,
    this.detail,
    this.date,
  });

  TransactionExecutionRequest copyWith({
    String? type,
    double? amount,
    String? accountName,
    String? destinationAccount,
    String? detail,
    DateTime? date,
  }) {
    return TransactionExecutionRequest(
      type: type ?? this.type,
      amount: amount ?? this.amount,
      accountName: accountName ?? this.accountName,
      destinationAccount: destinationAccount ?? this.destinationAccount,
      detail: detail ?? this.detail,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'amount': amount,
        'account_name': accountName,
        'destination_account': destinationAccount,
        'detail': detail,
        'date': date?.toIso8601String(),
      };

  factory TransactionExecutionRequest.fromJson(
    Map<String, dynamic> json,
  ) =>
      TransactionExecutionRequest(
        type: json['type'] as String,
        amount: (json['amount'] as num).toDouble(),
        accountName: (json['account_name'] ?? json['accountName']) as String,
        destinationAccount: (json['destination_account'] ??
            json['destinationAccount']) as String?,
        detail: json['detail'] as String?,
        date: json['date'] != null
            ? DateTime.parse(json['date'] as String)
            : null,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionExecutionRequest &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          amount == other.amount &&
          accountName == other.accountName &&
          destinationAccount == other.destinationAccount &&
          detail == other.detail &&
          date == other.date;

  @override
  int get hashCode =>
      type.hashCode ^
      amount.hashCode ^
      accountName.hashCode ^
      (destinationAccount?.hashCode ?? 0) ^
      (detail?.hashCode ?? 0) ^
      (date?.hashCode ?? 0);

  @override
  String toString() =>
      'TransactionExecutionRequest(type: $type, amount: $amount, account: $accountName, detail: $detail)';
}

class TransactionExecutionResult {
  final bool success;
  final String? transactionId;
  final String? errorMessage;

  const TransactionExecutionResult({
    required this.success,
    this.transactionId,
    this.errorMessage,
  });

  const TransactionExecutionResult.success({String? transactionId})
      : this(success: true, transactionId: transactionId);

  const TransactionExecutionResult.failure({required String errorMessage})
      : this(success: false, errorMessage: errorMessage);

  Map<String, dynamic> toJson() => {
        'success': success,
        'transaction_id': transactionId,
        'error_message': errorMessage,
      };

  factory TransactionExecutionResult.fromJson(
    Map<String, dynamic> json,
  ) =>
      TransactionExecutionResult(
        success: json['success'] as bool,
        transactionId:
            (json['transaction_id'] ?? json['transactionId']) as String?,
        errorMessage:
            (json['error_message'] ?? json['errorMessage']) as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionExecutionResult &&
          runtimeType == other.runtimeType &&
          success == other.success &&
          transactionId == other.transactionId &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      success.hashCode ^
      (transactionId?.hashCode ?? 0) ^
      (errorMessage?.hashCode ?? 0);

  @override
  String toString() =>
      'TransactionExecutionResult(success: $success, transactionId: $transactionId, error: $errorMessage)';
}

/// Puerto abstracto para la ejecución de transacciones aprobadas.
/// Desacopla la lógica de negocio de notificaciones de la persistencia real
/// en TransactionService (archivo protegido) y permite mocks en pruebas.
abstract class TransactionExecutionPort {
  /// Ejecuta una transacción directamente con parámetros primitivos.
  Future<bool> executeTransaction({
    required String type,
    required double amount,
    required String accountName,
    String? destinationAccount,
    String? detail,
    DateTime? date,
  });

  /// Ejecuta una transacción encapsulada en una solicitud tipada.
  Future<TransactionExecutionResult> execute(
    TransactionExecutionRequest request,
  );
}
