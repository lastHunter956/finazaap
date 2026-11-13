import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:finazaap/features/notifications/adapters/mock_transaction_execution_adapter.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/domain/models/transaction_classification.dart';
import 'package:finazaap/features/notifications/domain/ports/transaction_execution_port.dart';
import 'package:finazaap/features/notifications/services/learned_patterns_service.dart';

/// Resumen estructurado del resultado de ejecutar la aprobación masiva ("Aceptar todo").
class BatchApprovalSummary {
  final int acceptedCount;
  final int remainingCount;
  final List<PendingTransactionItem> acceptedItems;
  final List<PendingTransactionItem> remainingItems;

  const BatchApprovalSummary({
    required this.acceptedCount,
    required this.remainingCount,
    this.acceptedItems = const [],
    this.remainingItems = const [],
  });

  @override
  String toString() =>
      'BatchApprovalSummary(accepted: $acceptedCount, remaining: $remainingCount)';
}

/// Gestor de estado de la bandeja de transacciones pendientes en Moneo.
///
/// Invariantes fundamentales:
/// 1. **Aislamiento contable:** Mientras un ítem reside en esta bandeja (respaldada
///    exclusivamente en la caja Hive `pending_notifications`), NO modifica saldos
///    reales ni registros en la caja `'data'`.
/// 2. **Ejecución bajo demanda:** Solo las acciones explícitas [confirmItem],
///    [correctItem] o los ítems elegibles de [acceptAll] despachan transacciones
///    hacia [TransactionExecutionPort].
/// 3. **Feedback loop:** Confirmar incrementa el conteo de confianza en
///    [LearnedPatternsService]; Corregir sobreescribe la regla con `confirmations = 1`;
///    Descartar no altera ni saldos ni patrones aprendidos.
/// 4. **Aceptar todo seguro:** Solo aprueba ítems con `isEligibleForAcceptAll`
///    (`confidence >= 0.85`, `!requiresReview`, no sospechosas y con cuentas válidas).
class PendingTransactionsNotifier extends ChangeNotifier {
  static const String defaultBoxName = 'pending_notifications';

  final Box<dynamic>? _injectedBox;
  final String _boxName;
  final LearnedPatternsService _learnedPatternsService;
  final TransactionExecutionPort _executionPort;

  List<PendingTransactionItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  PendingTransactionsNotifier({
    Box<dynamic>? box,
    String boxName = defaultBoxName,
    LearnedPatternsService? learnedPatternsService,
    TransactionExecutionPort? executionPort,
  })  : _injectedBox = box,
        _boxName = boxName,
        _learnedPatternsService =
            learnedPatternsService ?? LearnedPatternsService(),
        _executionPort = executionPort ?? MockTransactionExecutionAdapter();

  /// Lista de transacciones actualmente pendientes, ordenada de más reciente a más antigua.
  List<PendingTransactionItem> get items => List.unmodifiable(_items);

  /// Indica si la bandeja está cargando datos de persistencia.
  bool get isLoading => _isLoading;

  /// Mensaje de error de la última operación, o null si fue exitosa.
  String? get errorMessage => _errorMessage;

  /// Cantidad total de transacciones en la bandeja.
  int get count => _items.length;

  /// Cantidad de transacciones aptas para ser aprobadas en lote con "Aceptar todo".
  int get eligibleCount =>
      _items.where((item) => item.isEligibleForAcceptAll).length;

  /// Cantidad de transacciones que requieren revisión manual obligatoria.
  int get manualReviewCount => count - eligibleCount;

  /// Servicio de patrones aprendidos asociado a esta bandeja.
  LearnedPatternsService get learnedPatternsService => _learnedPatternsService;

  /// Puerto de ejecución utilizado por este notifier.
  TransactionExecutionPort get executionPort => _executionPort;

  /// Obtiene la caja Hive subyacente.
  Future<Box<dynamic>> _getBox() async {
    if (_injectedBox != null) {
      return _injectedBox!;
    }
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<dynamic>(_boxName);
    }
    return await Hive.openBox<dynamic>(_boxName);
  }

  /// Inicializa la bandeja cargando los ítems persistidos en Hive.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final box = await _getBox();
      final loaded = <PendingTransactionItem>[];

      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw is Map) {
          try {
            loaded.add(
              PendingTransactionItem.fromJson(Map<String, dynamic>.from(raw)),
            );
          } catch (_) {
            // Ignorar entradas corruptas
          }
        }
      }

      loaded.sort((a, b) => b.fecha.compareTo(a.fecha));
      _items = loaded;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Error al cargar transacciones pendientes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Agrega un nuevo ítem a la bandeja y lo persiste en la caja Hive.
  Future<void> addPendingItem(PendingTransactionItem item) async {
    final box = await _getBox();
    await box.put(item.id, item.toJson());

    final index = _items.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      _items[index] = item;
    } else {
      _items.insert(0, item);
    }
    _items.sort((a, b) => b.fecha.compareTo(a.fecha));

    notifyListeners();
  }

  /// Agrega múltiples ítems en lote.
  Future<void> addPendingItems(List<PendingTransactionItem> newItems) async {
    if (newItems.isEmpty) return;

    final box = await _getBox();
    final batchMap = <String, dynamic>{};
    for (final item in newItems) {
      batchMap[item.id] = item.toJson();
    }
    await box.putAll(batchMap);

    for (final item in newItems) {
      final index = _items.indexWhere((i) => i.id == item.id);
      if (index >= 0) {
        _items[index] = item;
      } else {
        _items.add(item);
      }
    }
    _items.sort((a, b) => b.fecha.compareTo(a.fecha));

    notifyListeners();
  }

  /// Confirma una transacción pendiente válida.
  ///
  /// - Rechaza confirmación directa de transacciones 'sospechosa' (requieren corrección).
  /// - Ejecuta el movimiento mediante [TransactionExecutionPort].
  /// - Al ser exitoso, incrementa confirmaciones en [LearnedPatternsService] y
  ///   remueve el ítem de la caja `pending_notifications`.
  Future<bool> confirmItem(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return false;

    final item = _items[index];

    // Invariante de seguridad: Prohibido auto-confirmar o confirmar directamente sospechosas
    if (item.classification == 'sospechosa') {
      _errorMessage =
          'No se puede confirmar directamente una notificación sospechosa. Debe ser corregida o descartada.';
      notifyListeners();
      return false;
    }

    if (item.accountName == null || item.accountName!.trim().isEmpty) {
      _errorMessage =
          'La transacción requiere una cuenta asignada antes de confirmarse.';
      notifyListeners();
      return false;
    }

    if (item.monto == null || item.monto! <= 0) {
      _errorMessage = 'El monto de la transacción no es válido.';
      notifyListeners();
      return false;
    }

    if (item.classification == 'transferencia-propia' &&
        (item.destinationAccount == null ||
            item.destinationAccount!.trim().isEmpty)) {
      _errorMessage =
          'Las transferencias propias requieren especificar la cuenta de destino.';
      notifyListeners();
      return false;
    }

    final resolvedType = item.moneoType ??
        TransactionClassification.resolveMoneoType(item.classification) ??
        'Expenses';

    final request = TransactionExecutionRequest(
      type: resolvedType,
      amount: item.monto!,
      accountName: item.accountName!,
      destinationAccount: item.destinationAccount,
      detail: item.comercio ?? item.rawText,
      date: item.fecha,
    );

    final result = await _executionPort.execute(request);
    if (!result.success) {
      _errorMessage = result.errorMessage ?? 'Error al ejecutar la transacción';
      notifyListeners();
      return false;
    }

    // Feedback loop: Registrar confirmación en learned_patterns
    final merchant = item.comercio ?? item.merchantKey;
    if (merchant != null && merchant.trim().isNotEmpty) {
      try {
        await _learnedPatternsService.recordConfirmation(
          merchant: merchant,
          category: item.category ?? 'Otros',
          accountName: item.accountName,
          classification: item.classification,
          moneoType: resolvedType,
          at: DateTime.now(),
        );
      } catch (_) {
        // La actualización de patrones no debe romper la confirmación de la tx
      }
    }

    final box = await _getBox();
    await box.delete(item.id);
    _items.removeAt(index);
    _errorMessage = null;

    notifyListeners();
    return true;
  }

  /// Aplica una corrección explícita del usuario a una transacción pendiente.
  ///
  /// - Ejecuta el movimiento con los nuevos parámetros elegidos por el usuario.
  /// - Actualiza la regla en [LearnedPatternsService] fijando `confirmations = 1` y
  ///   actualizando `lastCorrectedAt`.
  /// - Remueve el ítem de la bandeja tras la persistencia contable.
  Future<bool> correctItem({
    required String id,
    required String newClassification,
    required String newCategory,
    required String newAccountName,
    String? newDestinationAccount,
    double? newAmount,
  }) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return false;

    final item = _items[index];
    final effectiveAmount = newAmount ?? item.monto ?? 0.0;

    if (effectiveAmount <= 0) {
      _errorMessage = 'El monto debe ser superior a cero.';
      notifyListeners();
      return false;
    }

    if (newClassification == 'transferencia-propia' &&
        (newDestinationAccount == null ||
            newDestinationAccount.trim().isEmpty)) {
      _errorMessage =
          'Las transferencias requieren especificar la cuenta de destino.';
      notifyListeners();
      return false;
    }

    final resolvedType =
        TransactionClassification.resolveMoneoType(newClassification) ??
            'Expenses';

    final request = TransactionExecutionRequest(
      type: resolvedType,
      amount: effectiveAmount,
      accountName: newAccountName,
      destinationAccount: newDestinationAccount,
      detail: item.comercio ?? item.rawText,
      date: item.fecha,
    );

    final result = await _executionPort.execute(request);
    if (!result.success) {
      _errorMessage = result.errorMessage ?? 'Error al ejecutar la corrección';
      notifyListeners();
      return false;
    }

    // Feedback loop: Registrar corrección en learned_patterns
    final merchant = item.comercio ?? item.merchantKey ?? 'comercio';
    if (merchant.trim().isNotEmpty) {
      try {
        await _learnedPatternsService.recordCorrection(
          merchant: merchant,
          newCategory: newCategory,
          newAccountName: newAccountName,
          newClassification: newClassification,
          newMoneoType: resolvedType,
          at: DateTime.now(),
        );
      } catch (_) {
        // La actualización de patrones no debe romper la corrección de la tx
      }
    }

    final box = await _getBox();
    await box.delete(item.id);
    _items.removeAt(index);
    _errorMessage = null;

    notifyListeners();
    return true;
  }

  /// Descarta un ítem de la bandeja sin tocar saldos ni patrones aprendidos.
  Future<bool> discardItem(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return false;

    final box = await _getBox();
    await box.delete(id);
    _items.removeAt(index);
    _errorMessage = null;

    notifyListeners();
    return true;
  }

  /// Ejecuta la aprobación masiva ("Aceptar todo") respetando el filtro estricto de alta confianza.
  ///
  /// Solo se procesan los ítems que cumplen `item.isEligibleForAcceptAll`:
  /// - `classification != 'sospechosa'`
  /// - `!requiresReview`
  /// - `confidence >= 0.85`
  /// - `accountName != null && accountName.isNotEmpty`
  /// - Si es transferencia propia: `destinationAccount != null && destinationAccount.isNotEmpty`
  ///
  /// Los ítems de baja confianza o marcados como sospechosos permanecen intactos
  /// en la bandeja para revisión manual.
  Future<BatchApprovalSummary> acceptAll() async {
    final eligible = _items.where((i) => i.isEligibleForAcceptAll).toList();
    final accepted = <PendingTransactionItem>[];

    for (final item in eligible) {
      final success = await confirmItem(item.id);
      if (success) {
        accepted.add(item);
      }
    }

    final summary = BatchApprovalSummary(
      acceptedCount: accepted.length,
      remainingCount: _items.length,
      acceptedItems: List.unmodifiable(accepted),
      remainingItems: List.unmodifiable(_items),
    );

    return summary;
  }

  /// Limpia todos los ítems de la bandeja (útil en pruebas y depuración).
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
    _items.clear();
    _errorMessage = null;
    notifyListeners();
  }
}
