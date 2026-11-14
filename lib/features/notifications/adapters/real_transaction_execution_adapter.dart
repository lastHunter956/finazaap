import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/transaction_service.dart';
import 'package:finazaap/features/notifications/domain/ports/transaction_execution_port.dart';

typedef ProcessTransactionFn = Future<bool> Function({
  required String type,
  required double amount,
  required String accountName,
  String? destinationAccount,
  bool isNewTransaction,
  bool recordInHive,
  String? detail,
});

/// Adaptador real que conecta [TransactionExecutionPort] con [TransactionService]
/// y la caja Hive `'data'`, reutilizando la única fuente de verdad de saldos.
class RealTransactionExecutionAdapter implements TransactionExecutionPort {
  final ProcessTransactionFn _processTransaction;
  final Box<Add_data>? _injectedDataBox;

  RealTransactionExecutionAdapter({
    ProcessTransactionFn? processTransaction,
    Box<Add_data>? dataBox,
  })  : _processTransaction =
            processTransaction ?? TransactionService.processTransaction,
        _injectedDataBox = dataBox;

  @override
  Future<bool> executeTransaction({
    required String type,
    required double amount,
    required String accountName,
    String? destinationAccount,
    String? detail,
    DateTime? date,
  }) async {
    final result = await execute(
      TransactionExecutionRequest(
        type: type,
        amount: amount,
        accountName: accountName,
        destinationAccount: destinationAccount,
        detail: detail,
        date: date,
      ),
    );
    return result.success;
  }

  @override
  Future<TransactionExecutionResult> execute(
    TransactionExecutionRequest request,
  ) async {
    if (request.type != 'Expenses' &&
        request.type != 'Income' &&
        request.type != 'Transfer') {
      return const TransactionExecutionResult.failure(
        errorMessage: 'Tipo de transacción contable no válido.',
      );
    }

    if (request.amount <= 0 || request.amount.isNaN || request.amount.isInfinite) {
      return const TransactionExecutionResult.failure(
        errorMessage: 'El monto de la transacción debe ser mayor a cero.',
      );
    }

    final account = request.accountName.trim();
    if (account.isEmpty) {
      return const TransactionExecutionResult.failure(
        errorMessage: 'Se requiere una cuenta válida para registrar el movimiento.',
      );
    }

    if (request.type == 'Transfer') {
      final dest = request.destinationAccount?.trim() ?? '';
      if (dest.isEmpty || dest == account) {
        return const TransactionExecutionResult.failure(
          errorMessage:
              'La transferencia requiere una cuenta destino distinta a la origen.',
        );
      }
    }

    try {
      final balanceUpdated = await _processTransaction(
        type: request.type,
        amount: request.amount,
        accountName: account,
        destinationAccount: request.destinationAccount?.trim(),
        isNewTransaction: true,
        recordInHive: false,
        detail: request.detail,
      );

      if (!balanceUpdated) {
        return const TransactionExecutionResult.failure(
          errorMessage:
              'No se encontró la cuenta seleccionada o no se pudo actualizar el saldo.',
        );
      }

      final box = await _getDataBox();
      final isTransfer = request.type == 'Transfer';
      final tx = Add_data(
        request.type,
        request.amount.toString(),
        request.date ?? DateTime.now(),
        (request.detail != null && request.detail!.trim().isNotEmpty)
            ? request.detail!.trim()
            : (isTransfer ? 'Transferencia detectada' : 'Movimiento detectado'),
        isTransfer
            ? '$account > ${request.destinationAccount!.trim()}'
            : (request.category?.trim().isNotEmpty == true
                ? request.category!.trim()
                : 'Otros'),
        isTransfer ? '' : account,
        _iconForType(request.type),
        '1',
        false,
      );

      final key = await box.add(tx);
      return TransactionExecutionResult.success(transactionId: 'hive_$key');
    } catch (e) {
      return TransactionExecutionResult.failure(
        errorMessage: 'Error registrando transacción en Moneo: $e',
      );
    }
  }

  Future<Box<Add_data>> _getDataBox() async {
    if (_injectedDataBox != null) return _injectedDataBox!;
    if (Hive.isBoxOpen('data')) {
      return Hive.box<Add_data>('data');
    }
    return Hive.openBox<Add_data>('data');
  }

  int _iconForType(String type) {
    switch (type) {
      case 'Income':
        return Icons.arrow_downward_rounded.codePoint;
      case 'Transfer':
        return Icons.sync_alt_rounded.codePoint;
      default:
        return Icons.receipt_long_rounded.codePoint;
    }
  }
}
