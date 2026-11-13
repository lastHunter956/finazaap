import 'dart:async';
import 'package:finazaap/features/notifications/domain/ports/transaction_execution_port.dart';

/// Adaptador simulado en memoria para [TransactionExecutionPort].
///
/// Permite probar el flujo de confirmación, corrección y aislamiento contable
/// de transacciones sin interactuar con [TransactionService] (archivo protegido).
class MockTransactionExecutionAdapter implements TransactionExecutionPort {
  bool shouldSucceed;
  String? nextErrorMessage;
  final List<TransactionExecutionRequest> executedRequests = [];

  MockTransactionExecutionAdapter({
    this.shouldSucceed = true,
    this.nextErrorMessage,
  });

  /// Cantidad de transacciones ejecutadas y registradas.
  int get executionCount => executedRequests.length;

  /// Última solicitud ejecutada, o null si la lista está vacía.
  TransactionExecutionRequest? get lastExecutedRequest =>
      executedRequests.isNotEmpty ? executedRequests.last : null;

  @override
  Future<bool> executeTransaction({
    required String type,
    required double amount,
    required String accountName,
    String? destinationAccount,
    String? detail,
    DateTime? date,
  }) async {
    final request = TransactionExecutionRequest(
      type: type,
      amount: amount,
      accountName: accountName,
      destinationAccount: destinationAccount,
      detail: detail,
      date: date,
    );
    final result = await execute(request);
    return result.success;
  }

  @override
  Future<TransactionExecutionResult> execute(
    TransactionExecutionRequest request,
  ) async {
    if (!shouldSucceed) {
      return TransactionExecutionResult.failure(
        errorMessage:
            nextErrorMessage ?? 'Fallo simulado en la ejecución de transacción',
      );
    }

    executedRequests.add(request);
    return TransactionExecutionResult.success(
      transactionId: 'mock_tx_${executedRequests.length}',
    );
  }

  /// Limpia las solicitudes ejecutadas y restablece el estado predeterminado.
  void clear() {
    executedRequests.clear();
    shouldSucceed = true;
    nextErrorMessage = null;
  }
}
