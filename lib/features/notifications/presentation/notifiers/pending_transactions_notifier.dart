import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:finazaap/features/notifications/adapters/mock_transaction_execution_adapter.dart';
import 'package:finazaap/features/notifications/domain/models/dedup_models.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/domain/models/spam_models.dart';
import 'package:finazaap/features/notifications/domain/models/transaction_classification.dart';
import 'package:finazaap/features/notifications/domain/ports/transaction_execution_port.dart';
import 'package:finazaap/features/notifications/services/learned_patterns_service.dart';
import 'package:finazaap/features/notifications/services/notification_box_encryption.dart';
import 'package:finazaap/features/notifications/services/spam_patterns_service.dart';
import 'package:finazaap/features/notifications/services/transaction_classifier.dart';
import 'package:finazaap/features/notifications/services/transaction_dedup_correlator.dart';

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

class _RecentPendingAction {
  final String id;
  final int roundedAmount;
  final int originalRoundedAmount;
  final DateTime timestamp;
  final DateTime actionAt;
  final String? merchantKey;
  final String? comercio;
  final String? accountName;
  final String? packageName;
  final String channel;
  final Set<String> packages;
  final Set<String> channels;

  _RecentPendingAction({
    required this.id,
    required this.roundedAmount,
    required this.originalRoundedAmount,
    required this.timestamp,
    required this.actionAt,
    this.merchantKey,
    this.comercio,
    this.accountName,
    this.packageName,
    required this.channel,
    required this.packages,
    required this.channels,
  });
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
  static const String executedBoxName = 'notification_executed_ids';
  static const String spamBoxName = 'notification_spam_items';
  static const Duration implicitLearnWindow = Duration(minutes: 30);
  static const int _maxRecentActions = 30;

  final Box<dynamic>? _injectedBox;
  final Box<dynamic>? _injectedExecutedBox;
  final Box<dynamic>? _injectedSpamBox;
  final String _boxName;
  final LearnedPatternsService _learnedPatternsService;
  final SpamPatternsService? _spamPatternsService;
  final TransactionExecutionPort _executionPort;
  final NotificationBoxEncryption? _boxEncryption;
  final TransactionDedupCorrelator _dedupCorrelator;

  List<PendingTransactionItem> _items = [];
  List<SpamNotificationItem> _spamItems = [];
  final Set<String> _inFlightIds = {};
  final Set<String> _memoryExecutedIds = {};
  final List<_RecentPendingAction> _recentConfirmations = [];
  final List<_RecentPendingAction> _recentDiscards = [];
  bool _isLoading = false;
  String? _errorMessage;

  PendingTransactionsNotifier({
    Box<dynamic>? box,
    Box<dynamic>? executedBox,
    Box<dynamic>? spamBox,
    String boxName = defaultBoxName,
    LearnedPatternsService? learnedPatternsService,
    SpamPatternsService? spamPatternsService,
    TransactionExecutionPort? executionPort,
    NotificationBoxEncryption? boxEncryption,
    TransactionDedupCorrelator? dedupCorrelator,
  })  : _injectedBox = box,
        _injectedExecutedBox = executedBox,
        _injectedSpamBox = spamBox,
        _boxName = boxName,
        _learnedPatternsService =
            learnedPatternsService ?? LearnedPatternsService(),
        _spamPatternsService = spamPatternsService,
        _executionPort = executionPort ?? MockTransactionExecutionAdapter(),
        _boxEncryption = boxEncryption,
        _dedupCorrelator = dedupCorrelator ?? TransactionDedupCorrelator();

  /// Lista de transacciones actualmente pendientes, ordenada de más reciente a más antigua.
  List<PendingTransactionItem> get items => List.unmodifiable(_items);

  /// Lista de notificaciones en cuarentena de Spam (máx. 5 días), más recientes primero.
  List<SpamNotificationItem> get spamItems => List.unmodifiable(_spamItems);

  /// Cantidad de elementos actualmente en la pestaña Spam.
  int get spamCount => _spamItems.length;

  /// Servicio de patrones de spam asociado (si está configurado).
  SpamPatternsService? get spamPatternsService => _spamPatternsService;

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

  /// Obtiene la caja Hive subyacente (cifrada si [_boxEncryption] está configurado).
  Future<Box<dynamic>> _getBox() async {
    if (_injectedBox != null) {
      return _injectedBox!;
    }
    if (_boxEncryption != null) {
      return _boxEncryption!.openEncryptedBox(_boxName);
    }
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<dynamic>(_boxName);
    }
    return await Hive.openBox<dynamic>(_boxName);
  }

  Future<Box<dynamic>?> _getExecutedBox() async {
    if (_injectedExecutedBox != null) return _injectedExecutedBox!;
    if (_injectedBox != null) return null; // En widget tests in-memory usa _memoryExecutedIds
    if (_boxEncryption != null) {
      return _boxEncryption!.openEncryptedBox(executedBoxName);
    }
    if (Hive.isBoxOpen(executedBoxName)) {
      return Hive.box<dynamic>(executedBoxName);
    }
    return Hive.openBox<dynamic>(executedBoxName);
  }

  Future<Box<dynamic>?> _getSpamBox() async {
    if (_injectedSpamBox != null) return _injectedSpamBox!;
    if (_injectedBox != null) return null; // En widget tests in-memory mantiene _spamItems en RAM
    if (_boxEncryption != null) {
      return _boxEncryption!.openEncryptedBox(spamBoxName);
    }
    if (Hive.isBoxOpen(spamBoxName)) {
      return Hive.box<dynamic>(spamBoxName);
    }
    return Hive.openBox<dynamic>(spamBoxName);
  }

  Future<bool> _isAlreadyExecuted(String id) async {
    if (_memoryExecutedIds.contains(id)) return true;
    final execBox = await _getExecutedBox();
    return execBox?.containsKey(id) ?? false;
  }

  Future<void> _markExecuted(String id, {String? txId}) async {
    _memoryExecutedIds.add(id);
    final execBox = await _getExecutedBox();
    if (execBox != null) {
      await execBox.put(id, {
        'executed_at': DateTime.now().toIso8601String(),
        if (txId != null) 'tx_id': txId,
      });
    }
  }

  /// Inicializa la bandeja cargando los ítems persistidos en Hive y reconciliando
  /// posibles estados intermedios (`executing`) tras un reinicio inesperado.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_injectedBox == null && _boxEncryption != null) {
        await _boxEncryption!.getOrCreateKey();
      }
      final results = await Future.wait<Box<dynamic>?>([
        _getBox(),
        _getSpamBox(),
      ]);
      final box = results[0]!;
      final preloadedSpamBox = results[1];
      final loaded = <PendingTransactionItem>[];
      final keysToDelete = <dynamic>[];

      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw is Map) {
          try {
            var item =
                PendingTransactionItem.fromJson(Map<String, dynamic>.from(raw));
            if (await _isAlreadyExecuted(item.id) ||
                item.executionStatus == 'executed') {
              keysToDelete.add(key);
              continue;
            }
            if (item.executionStatus == 'executing') {
              final nextFlags = <String>{
                ...item.flags,
                'recovery_check_required',
              }.toList();
              item = item.copyWith(
                executionStatus: 'pending',
                requiresReview: true,
                autoProcessable: false,
                flags: nextFlags,
              );
              await box.put(item.id, item.toJson());
            }
            loaded.add(item);
          } catch (_) {
            // Ignorar entradas corruptas
          }
        }
      }

      for (final key in keysToDelete) {
        await box.delete(key);
      }

      loaded.sort((a, b) => b.fecha.compareTo(a.fecha));
      _items = loaded;
      await _loadAndPruneSpamBox(preloadedBox: preloadedSpamBox);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Error al cargar transacciones pendientes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAndPruneSpamBox({
    DateTime? now,
    Box<dynamic>? preloadedBox,
  }) async {
    final reference = now ?? DateTime.now();
    final spamBox = preloadedBox ?? await _getSpamBox();
    if (spamBox == null) {
      _spamItems.removeWhere((s) => s.isExpired(now: reference));
      _spamItems.sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
      return;
    }

    final loaded = <SpamNotificationItem>[];
    final expiredKeys = <dynamic>[];
    for (final key in spamBox.keys) {
      final raw = spamBox.get(key);
      if (raw is Map) {
        try {
          final spamItem =
              SpamNotificationItem.fromJson(Map<String, dynamic>.from(raw));
          if (spamItem.isExpired(now: reference)) {
            expiredKeys.add(key);
          } else {
            loaded.add(spamItem);
          }
        } catch (_) {
          expiredKeys.add(key);
        }
      }
    }
    for (final key in expiredKeys) {
      await spamBox.delete(key);
    }
    if (expiredKeys.isNotEmpty) {
      await spamBox.compact();
    }
    loaded.sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    _spamItems = loaded;
  }

  /// Agrega una notificación a la pestaña **Spam** (máx. 5 días) y purga expiradas.
  Future<void> addSpamItem(SpamNotificationItem spamItem, {DateTime? now}) async {
    final reference = now ?? DateTime.now();
    final spamBox = await _getSpamBox();
    if (spamBox != null) {
      await spamBox.put(spamItem.id, spamItem.toJson());
    }

    final idx = _spamItems.indexWhere((s) => s.id == spamItem.id);
    if (idx >= 0) {
      _spamItems[idx] = spamItem;
    } else {
      _spamItems.insert(0, spamItem);
    }
    _spamItems.removeWhere((s) => s.isExpired(now: reference));
    _spamItems.sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    notifyListeners();
  }

  /// Purga todo elemento de Spam con más de 5 días de antigüedad y compacta Hive.
  Future<int> pruneExpiredSpam({DateTime? now}) async {
    final reference = now ?? DateTime.now();
    var removed = 0;

    final beforeMem = _spamItems.length;
    _spamItems.removeWhere((s) => s.isExpired(now: reference));
    removed = beforeMem - _spamItems.length;

    final spamBox = await _getSpamBox();
    if (spamBox != null) {
      final keysToDelete = <dynamic>[];
      for (final key in spamBox.keys) {
        final raw = spamBox.get(key);
        if (raw is Map) {
          try {
            final item =
                SpamNotificationItem.fromJson(Map<String, dynamic>.from(raw));
            if (item.isExpired(now: reference)) {
              keysToDelete.add(key);
            }
          } catch (_) {
            keysToDelete.add(key);
          }
        }
      }
      for (final key in keysToDelete) {
        await spamBox.delete(key);
      }
      if (keysToDelete.isNotEmpty) {
        await spamBox.compact();
      }
      if (keysToDelete.length > removed) {
        removed = keysToDelete.length;
      }
    }

    if (removed > 0) {
      notifyListeners();
    }
    return removed;
  }

  /// Reconfirma desde la pestaña Spam que el elemento es spam:
  /// consolida el patrón en `dismissed_patterns` y elimina la tarjeta de Spam.
  Future<bool> confirmSpamItem(String id) async {
    final idx = _spamItems.indexWhere((s) => s.id == id);
    if (idx < 0) return false;

    final spamItem = _spamItems[idx];
    if (_spamPatternsService != null) {
      try {
        await _spamPatternsService!.recordDismissal(
          packageName: spamItem.item.packageName ?? '',
          rawText: spamItem.item.rawText,
          channelId: spamItem.channelId ?? spamItem.item.channelId,
          forceConsolidate: true,
        );
      } catch (_) {}
    }

    final spamBox = await _getSpamBox();
    if (spamBox != null) {
      await spamBox.delete(id);
    }
    _spamItems.removeAt(idx);
    notifyListeners();
    return true;
  }

  /// Marca un ítem de la pestaña Spam como **"No es spam"**:
  /// degrada/desactiva la regla de spam que lo atrapó y lo mueve a **Pendientes**
  /// para que el usuario pueda confirmarlo o corregirlo.
  Future<PendingTransactionItem?> restoreFromSpam(String id) async {
    final idx = _spamItems.indexWhere((s) => s.id == id);
    if (idx < 0) return null;

    final spamItem = _spamItems[idx];
    if (_spamPatternsService != null) {
      try {
        await _spamPatternsService!.rescueFromSpam(
          matchedRuleKey: spamItem.matchedRuleKey,
          packageName: spamItem.item.packageName ?? '',
          rawText: spamItem.item.rawText,
        );
      } catch (_) {}
    }

    final spamBox = await _getSpamBox();
    if (spamBox != null) {
      await spamBox.delete(id);
    }
    _spamItems.removeAt(idx);

    final restoredClassification = spamItem.item.classification == 'spam'
        ? 'gasto'
        : spamItem.item.classification;
    final restored = spamItem.item.copyWith(
      classification: restoredClassification,
      moneoType: spamItem.item.moneoType ??
          TransactionClassification.resolveMoneoType(restoredClassification),
      requiresReview: true,
      autoProcessable: false,
      decisionSource: 'rescued_from_spam',
      strategicNote: 'Rescatada desde Spam ("No es spam"); revisa y confirma.',
    );

    await addPendingItem(restored);
    return restored;
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
    return _confirmInternal(id, recordHumanFeedback: true);
  }

  /// Acepta automáticamente un ítem elegible si el modo automático está activo.
  ///
  /// Nunca registra el movimiento en `learned_patterns` como etiqueta humana validada.
  Future<bool> autoAcceptIfEligible(PendingTransactionItem item) async {
    if (!item.isEligibleForAcceptAll) return false;
    await addPendingItem(item);
    return _confirmInternal(item.id, recordHumanFeedback: false);
  }

  Future<bool> _confirmInternal(
    String id, {
    required bool recordHumanFeedback,
  }) async {
    if (_inFlightIds.contains(id)) return false;

    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return false;

    final item = _items[index];

    if (await _isAlreadyExecuted(id)) {
      final box = await _getBox();
      await box.delete(item.id);
      _items.removeWhere((i) => i.id == id);
      notifyListeners();
      return false;
    }

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
      category: item.category,
      detail: item.comercio ?? item.rawText,
      date: item.fecha,
    );

    _inFlightIds.add(id);
    final box = await _getBox();
    try {
      await box.put(
        item.id,
        item.copyWith(executionStatus: 'executing').toJson(),
      );

      final result = await _executionPort.execute(request);
      if (!result.success) {
        await box.put(
          item.id,
          item.copyWith(executionStatus: 'pending').toJson(),
        );
        _errorMessage = result.errorMessage ?? 'Error al ejecutar la transacción';
        notifyListeners();
        return false;
      }

      await _markExecuted(item.id, txId: result.transactionId);

      final now = DateTime.now();
      try {
        await _dedupCorrelator.recordConfirmedItem(item, at: now);
      } catch (_) {}

      // Feedback loop: Solo confirmaciones humanas actualizan learned_patterns
      // evitando guardar nombres genéricos de banco como clave de comercio.
      if (recordHumanFeedback) {
        final merchant = item.comercio ?? item.merchantKey;
        if (merchant != null &&
            merchant.trim().isNotEmpty &&
            !TransactionClassifier.isGenericBankMerchant(merchant)) {
          try {
            await _learnedPatternsService.recordConfirmation(
              merchant: merchant,
              category: item.category ?? 'Otros',
              accountName: item.accountName,
              classification: item.classification,
              moneoType: resolvedType,
              alias: item.comercio,
              packageName: item.packageName,
              at: now,
            );
          } catch (_) {
            // La actualización de patrones no debe romper la confirmación de la tx
          }
        }
        await _recordConfirmedActionAndLearn(item, now: now);
      }

      await box.delete(item.id);
      _items.removeWhere((i) => i.id == id);
      _errorMessage = null;

      notifyListeners();
      return true;
    } finally {
      _inFlightIds.remove(id);
    }
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
    String? newDescription,
    DateTime? newDate,
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

    final effectiveDetail =
        (newDescription != null && newDescription.trim().isNotEmpty)
            ? newDescription.trim()
            : (item.comercio ?? item.rawText);

    final request = TransactionExecutionRequest(
      type: resolvedType,
      amount: effectiveAmount,
      accountName: newAccountName,
      destinationAccount: newDestinationAccount,
      category: newCategory,
      detail: effectiveDetail,
      date: newDate ?? item.fecha,
    );

    if (_inFlightIds.contains(id) || await _isAlreadyExecuted(id)) {
      return false;
    }

    _inFlightIds.add(id);
    final box = await _getBox();
    try {
      await box.put(
        item.id,
        item.copyWith(executionStatus: 'executing').toJson(),
      );

      final result = await _executionPort.execute(request);
      if (!result.success) {
        await box.put(
          item.id,
          item.copyWith(executionStatus: 'pending').toJson(),
        );
        _errorMessage = result.errorMessage ?? 'Error al ejecutar la corrección';
        notifyListeners();
        return false;
      }

      await _markExecuted(item.id, txId: result.transactionId);

      final now = DateTime.now();
      try {
        await _dedupCorrelator.recordConfirmedItem(
          item,
          at: now,
          overrideAmount: effectiveAmount,
          overrideAccountName: newAccountName,
          overrideDestinationAccount: newDestinationAccount,
          overrideDate: newDate ?? item.fecha,
        );
      } catch (_) {}

      // Feedback loop: Registrar corrección en learned_patterns con packageName y alias,
      // evitando contaminar el índice con nombres genéricos de banco.
      final originalMerchant = item.comercio ?? item.merchantKey;
      final editedDescription = newDescription?.trim();
      final hasSpecificOriginal = originalMerchant != null &&
          !TransactionClassifier.isGenericBankMerchant(originalMerchant);
      final hasSpecificEdited = editedDescription != null &&
          editedDescription.isNotEmpty &&
          !TransactionClassifier.isGenericBankMerchant(editedDescription);
      final merchantToLearn = hasSpecificOriginal
          ? originalMerchant
          : (hasSpecificEdited ? editedDescription : null);
      final aliasToLearn = (hasSpecificOriginal &&
              hasSpecificEdited &&
              editedDescription.toLowerCase() !=
                  originalMerchant.trim().toLowerCase())
          ? editedDescription
          : item.comercio;

      if (merchantToLearn != null && merchantToLearn.trim().isNotEmpty) {
        try {
          await _learnedPatternsService.recordCorrection(
            merchant: merchantToLearn,
            newCategory: newCategory,
            newAccountName: newAccountName,
            newClassification: newClassification,
            newMoneoType: resolvedType,
            alias: aliasToLearn,
            packageName: item.packageName,
            at: now,
          );
        } catch (_) {
          // La actualización de patrones no debe romper la corrección de la tx
        }
      }

      await _recordConfirmedActionAndLearn(
        item,
        overrideAmount: effectiveAmount,
        overrideDate: newDate ?? item.fecha,
        overrideDetail: effectiveDetail,
        overrideAccountName: newAccountName,
        now: now,
      );

      await box.delete(item.id);
      _items.removeWhere((i) => i.id == id);
      _errorMessage = null;

      notifyListeners();
      return true;
    } finally {
      _inFlightIds.remove(id);
    }
  }

  /// Descarta un ítem de la bandeja sin tocar saldos ni `learned_patterns`.
  ///
  /// - Registra la firma en `SpamPatternsService` (`dismissed_patterns`) para que
  ///   avisos similares futuros se filtren sin gastar IA.
  /// - Mueve el ítem a la pestaña **Spam** (máx. 5 días) por si el usuario desea
  ///   reconfirmarlo o rescatarlo ("No es spam").
  /// - Si otro movimiento del mismo monto redondeado dentro de `< 30 min` fue
  ///   confirmado/corregido recientemente desde otra app/canal, aprende
  ///   automáticamente una `DedupRule` multi-app para agrupar futuros avisos.
  Future<bool> discardItem(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return false;

    final item = _items[index];
    final box = await _getBox();
    await box.delete(id);
    _items.removeAt(index);
    _errorMessage = null;

    final learnedMultiAppDup = await _handleImplicitDiscardLearning(item);

    // Aprender patrón negativo solo si no fue el descarte de un duplicado multi-app
    // de una transacción recién confirmada (y nunca si era phishing/sospechosa).
    if (!learnedMultiAppDup &&
        _spamPatternsService != null &&
        item.classification != 'sospechosa') {
      final now = DateTime.now();
      String? ruleKey;
      try {
        final pattern = await _spamPatternsService!.recordDismissal(
          packageName: item.packageName ?? '',
          rawText: item.rawText,
          channelId: item.channelId,
          at: now,
        );
        ruleKey = pattern?.signatureKey;
      } catch (_) {}

      await addSpamItem(
        SpamNotificationItem(
          id: item.id,
          item: item,
          spamReason: 'Descartada por el usuario (se ignorarán similares)',
          spamSource: 'user_discard',
          matchedRuleKey: ruleKey,
          channelId: item.channelId,
          detectedAt: now,
        ),
        now: now,
      );
      return true;
    }

    notifyListeners();
    return true;
  }

  _RecentPendingAction _buildActionRecord(
    PendingTransactionItem item, {
    double? overrideAmount,
    DateTime? overrideDate,
    String? overrideDetail,
    String? overrideAccountName,
    required DateTime actionAt,
  }) {
    final packages = <String>{};
    if (item.packageName != null && item.packageName!.trim().isNotEmpty) {
      packages.add(item.packageName!.trim());
    }
    final channels = <String>{};
    if (item.channel.trim().isNotEmpty) {
      channels.add(item.channel.trim());
    }
    for (final ev in item.groupedEvents) {
      final pkg = ((ev['package_name'] ?? ev['packageName']) as String?)?.trim();
      if (pkg != null && pkg.isNotEmpty) packages.add(pkg);
      final ch = (ev['channel'] as String?)?.trim();
      if (ch != null && ch.isNotEmpty) channels.add(ch);
    }

    final effectiveAmount = overrideAmount ?? item.monto ?? 0.0;
    final originalAmount = item.monto ?? 0.0;
    return _RecentPendingAction(
      id: item.id,
      roundedAmount: effectiveAmount.round(),
      originalRoundedAmount: originalAmount.round(),
      timestamp: overrideDate ?? item.fecha,
      actionAt: actionAt,
      merchantKey: item.merchantKey,
      comercio: item.comercio ?? overrideDetail,
      accountName: overrideAccountName ?? item.accountName,
      packageName: item.packageName,
      channel: item.channel,
      packages: packages,
      channels: channels,
    );
  }

  void _pruneActionBuffer(List<_RecentPendingAction> buffer, DateTime now) {
    buffer.removeWhere(
      (entry) => now.difference(entry.actionAt).abs() > implicitLearnWindow,
    );
    while (buffer.length > _maxRecentActions) {
      buffer.removeAt(0);
    }
  }

  bool _withinImplicitWindow(_RecentPendingAction a, _RecentPendingAction b) {
    if (a.roundedAmount <= 0 || b.roundedAmount <= 0) return false;
    final sameAmount = a.roundedAmount == b.roundedAmount ||
        a.originalRoundedAmount == b.roundedAmount ||
        a.roundedAmount == b.originalRoundedAmount;
    if (!sameAmount) return false;
    if (a.timestamp.difference(b.timestamp).abs() >= implicitLearnWindow) {
      return false;
    }
    if (a.actionAt.difference(b.actionAt).abs() >= implicitLearnWindow) {
      return false;
    }
    return true;
  }

  bool _isDistinctSource(_RecentPendingAction a, _RecentPendingAction b) {
    if (a.packages.isNotEmpty && b.packages.isNotEmpty) {
      return a.packages.difference(b.packages).isNotEmpty ||
          b.packages.difference(a.packages).isNotEmpty ||
          a.channels.difference(b.channels).isNotEmpty ||
          b.channels.difference(a.channels).isNotEmpty;
    }
    return a.channels.difference(b.channels).isNotEmpty ||
        b.channels.difference(a.channels).isNotEmpty;
  }

  Future<void> _learnImplicitMultiAppRule(
    _RecentPendingAction confirmed,
    _RecentPendingAction discarded, {
    required DateTime at,
  }) async {
    confirmed.packages.addAll(discarded.packages);
    confirmed.channels.addAll(discarded.channels);

    final primaryMerchant = confirmed.merchantKey ??
        confirmed.comercio ??
        discarded.merchantKey ??
        discarded.comercio ??
        confirmed.accountName ??
        'movimiento';

    final mergedPackages = confirmed.packages.toList();
    final mergedChannels = confirmed.channels.toList();

    try {
      await _dedupCorrelator.learnMergeRule(
        merchant: primaryMerchant,
        channels: mergedChannels,
        packages: mergedPackages,
        at: at,
      );

      final secondary = discarded.comercio ?? discarded.merchantKey;
      if (secondary != null && secondary.trim().isNotEmpty) {
        final normPrimary =
            LearnedPatternsService.normalizeMerchant(primaryMerchant);
        final normSecondary =
            LearnedPatternsService.normalizeMerchant(secondary);
        if (normSecondary.isNotEmpty && normSecondary != normPrimary) {
          await _dedupCorrelator.learnMergeRule(
            merchant: secondary,
            channels: mergedChannels,
            packages: mergedPackages,
            at: at,
          );
        }
      }
    } catch (_) {
      // El aprendizaje implícito nunca debe interrumpir el flujo principal.
    }
  }

  Future<void> _recordConfirmedActionAndLearn(
    PendingTransactionItem item, {
    double? overrideAmount,
    DateTime? overrideDate,
    String? overrideDetail,
    String? overrideAccountName,
    required DateTime now,
  }) async {
    if (item.classification == 'sospechosa') return;
    final action = _buildActionRecord(
      item,
      overrideAmount: overrideAmount,
      overrideDate: overrideDate,
      overrideDetail: overrideDetail,
      overrideAccountName: overrideAccountName,
      actionAt: now,
    );
    _pruneActionBuffer(_recentConfirmations, now);
    _pruneActionBuffer(_recentDiscards, now);
    _recentConfirmations.add(action);

    for (final discard in _recentDiscards) {
      if (_withinImplicitWindow(action, discard) &&
          _isDistinctSource(action, discard)) {
        await _learnImplicitMultiAppRule(action, discard, at: now);
      }
    }
  }

  Future<bool> _handleImplicitDiscardLearning(
      PendingTransactionItem item) async {
    if (item.classification == 'sospechosa') return false;
    if ((item.monto ?? 0) <= 0) return false;

    final now = DateTime.now();
    final discardAction = _buildActionRecord(item, actionAt: now);
    _pruneActionBuffer(_recentConfirmations, now);
    _pruneActionBuffer(_recentDiscards, now);

    var learned = false;
    for (final confirmed in _recentConfirmations) {
      if (_withinImplicitWindow(confirmed, discardAction) &&
          _isDistinctSource(confirmed, discardAction)) {
        await _learnImplicitMultiAppRule(confirmed, discardAction, at: now);
        learned = true;
      }
    }

    _recentDiscards.add(discardAction);
    return learned;
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

  /// Agrupa manualmente N ítems pendientes en 1 ("estos N son uno") y guarda
  /// una regla de deduplicación reutilizable para futuras notificaciones.
  Future<PendingTransactionItem?> mergePendingItems(List<String> itemIds) async {
    if (itemIds.length < 2) return null;
    final selected = _items.where((i) => itemIds.contains(i.id)).toList();
    if (selected.length < 2) return null;

    var merged = selected.first;
    final channels = <String>{merged.channel};
    final packages = <String>{
      if (merged.packageName != null && merged.packageName!.trim().isNotEmpty)
        merged.packageName!.trim(),
    };
    for (final ev in merged.groupedEvents) {
      final pkg = ((ev['package_name'] ?? ev['packageName']) as String?)?.trim();
      if (pkg != null && pkg.isNotEmpty) packages.add(pkg);
      final ch = (ev['channel'] as String?)?.trim();
      if (ch != null && ch.isNotEmpty) channels.add(ch);
    }

    for (var i = 1; i < selected.length; i++) {
      final incoming = selected[i];
      channels.add(incoming.channel);
      if (incoming.packageName != null &&
          incoming.packageName!.trim().isNotEmpty) {
        packages.add(incoming.packageName!.trim());
      }
      for (final ev in incoming.groupedEvents) {
        final pkg =
            ((ev['package_name'] ?? ev['packageName']) as String?)?.trim();
        if (pkg != null && pkg.isNotEmpty) packages.add(pkg);
        final ch = (ev['channel'] as String?)?.trim();
        if (ch != null && ch.isNotEmpty) channels.add(ch);
      }
      final isTransferPair =
          (merged.classification == 'gasto' && incoming.classification == 'ingreso') ||
              (merged.classification == 'ingreso' && incoming.classification == 'gasto');
      final canTransfer = isTransferPair &&
          merged.accountName != null &&
          incoming.accountName != null &&
          merged.accountName != incoming.accountName;

      final correlation = canTransfer
          ? CorrelationResult(
              decision: CorrelationDecisionType.internalTransferPair,
              matchedPendingItemId: merged.id,
              similarityScore: 1.0,
              reason: 'Fusión manual de transferencia interna',
              proposedSourceAccount: merged.classification == 'gasto'
                  ? merged.accountName
                  : incoming.accountName,
              proposedDestinationAccount: merged.classification == 'gasto'
                  ? incoming.accountName
                  : merged.accountName,
            )
          : CorrelationResult(
              decision: CorrelationDecisionType.probabilisticDuplicate,
              matchedPendingItemId: merged.id,
              similarityScore: 1.0,
              reason: 'Fusión manual del usuario ("estos N son uno")',
            );

      merged = _dedupCorrelator.mergeIntoPendingItem(
        existing: merged,
        incoming: incoming,
        correlation: correlation,
      );
    }

    final box = await _getBox();
    await box.put(merged.id, merged.toJson());
    for (var i = 1; i < selected.length; i++) {
      await box.delete(selected[i].id);
      _items.removeWhere((item) => item.id == selected[i].id);
    }
    final idx = _items.indexWhere((item) => item.id == merged.id);
    if (idx >= 0) {
      _items[idx] = merged;
    }

    final merchantsToLearn = <String>{};
    for (final s in selected) {
      final m = s.comercio ?? s.merchantKey;
      if (m != null && m.trim().isNotEmpty) {
        merchantsToLearn.add(m);
      }
    }
    for (final merchant in merchantsToLearn) {
      await _dedupCorrelator.learnMergeRule(
        merchant: merchant,
        channels: channels.toList(),
        packages: packages.toList(),
      );
    }

    notifyListeners();
    return merged;
  }

  /// Separa un ítem previamente agrupado en sus movimientos individuales originales.
  Future<bool> splitMergedItem(String itemId) async {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx < 0) return false;
    final item = _items[idx];
    if (item.groupedEvents.length <= 1) return false;

    final restored = item.groupedEvents
        .map((raw) => PendingTransactionItem.fromJson(raw))
        .toList();

    final box = await _getBox();
    await box.delete(item.id);
    _items.removeAt(idx);

    final batch = <String, dynamic>{};
    for (final child in restored) {
      batch[child.id] = child.toJson();
      _items.add(child);
    }
    await box.putAll(batch);
    _items.sort((a, b) => b.fecha.compareTo(a.fecha));
    notifyListeners();
    return true;
  }

  /// Poda la caja `notification_executed_ids` por TTL (>90 días) y tope (500),
  /// ejecutando `box.compact()` si se eliminaron registros.
  Future<int> pruneExecutedHistory({
    DateTime? now,
    Duration maxAge = const Duration(days: 90),
    int maxEntries = 500,
  }) async {
    final execBox = await _getExecutedBox();
    if (execBox == null) return 0;

    final reference = now ?? DateTime.now();
    final keysToDelete = <dynamic>[];
    final surviving = <({dynamic key, DateTime executedAt})>[];

    for (final key in execBox.keys) {
      final raw = execBox.get(key);
      DateTime? executedAt;
      if (raw is Map && raw['executed_at'] is String) {
        executedAt = DateTime.tryParse(raw['executed_at'] as String);
      } else if (raw is String) {
        executedAt = DateTime.tryParse(raw);
      }

      if (executedAt == null || reference.difference(executedAt) > maxAge) {
        keysToDelete.add(key);
      } else {
        surviving.add((key: key, executedAt: executedAt));
      }
    }

    if (surviving.length > maxEntries) {
      surviving.sort((a, b) => b.executedAt.compareTo(a.executedAt));
      for (final overflow in surviving.skip(maxEntries)) {
        keysToDelete.add(overflow.key);
      }
    }

    for (final key in keysToDelete) {
      await execBox.delete(key);
    }
    if (keysToDelete.isNotEmpty) {
      await execBox.compact();
    }
    return keysToDelete.length;
  }

  /// Limpia todos los ítems de la bandeja y de la cuarentena de Spam (útil en pruebas y depuración).
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
    final spamBox = await _getSpamBox();
    if (spamBox != null) {
      await spamBox.clear();
    }
    _items.clear();
    _spamItems.clear();
    _recentConfirmations.clear();
    _recentDiscards.clear();
    _errorMessage = null;
    notifyListeners();
  }
}
