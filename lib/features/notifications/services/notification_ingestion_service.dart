import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../domain/models/notification_event.dart';
import '../domain/ports/notification_source_port.dart';
import 'bank_whitelist_service.dart';

/// Estado de procesamiento de un evento al pasar por la ingestión.
enum IngestionStatus {
  /// Evento aceptado y encolado para parsing y clasificación.
  accepted,

  /// Evento descartado porque su paquete no está en la whitelist.
  ignoredNotWhitelisted,

  /// Evento descartado por ser idéntico a otro recibido en la ventana de 5 minutos.
  ignoredDuplicate,
}

/// Resultado estructurado de evaluar un evento en [NotificationIngestionService].
class IngestionResult {
  final IngestionStatus status;
  final NotificationEvent event;
  final String dedupHash;
  final String? reason;

  const IngestionResult({
    required this.status,
    required this.event,
    required this.dedupHash,
    this.reason,
  });

  bool get isAccepted => status == IngestionStatus.accepted;
  bool get isDuplicate => status == IngestionStatus.ignoredDuplicate;
  bool get isNotWhitelisted => status == IngestionStatus.ignoredNotWhitelisted;

  @override
  String toString() =>
      'IngestionResult(status: $status, hash: ${dedupHash.substring(0, 8)}..., id: ${event.id})';
}

/// Servicio encargado de la ingestión, filtrado por whitelist y deduplicación SHA-256.
///
/// Garantiza que solo notificaciones de entidades autorizadas ingresen al sistema
/// y que ráfagas o reintentos idénticos dentro de una ventana de 5 minutos sean
/// descartados sin costo computacional para el parser ni la base de datos.
class NotificationIngestionService {
  final BankWhitelistService _whitelistService;
  final Duration dedupWindow;

  final StreamController<NotificationEvent> _ingestedController =
      StreamController<NotificationEvent>.broadcast();

  StreamSubscription<NotificationEvent>? _sourceSubscription;

  /// Cache en memoria de hashes procesados: dedupHash -> DateTime de recepción.
  final Map<String, DateTime> _seenHashes = {};

  int _ingestedCount = 0;
  int _discardedDuplicatesCount = 0;
  int _discardedNonWhitelistedCount = 0;

  NotificationIngestionService({
    required BankWhitelistService whitelistService,
    this.dedupWindow = const Duration(minutes: 5),
  }) : _whitelistService = whitelistService;

  /// Flujo continuo de notificaciones que superaron el filtrado y deduplicación.
  Stream<NotificationEvent> get ingestedStream => _ingestedController.stream;

  /// Whitelist activa utilizada por este servicio.
  BankWhitelistService get whitelistService => _whitelistService;

  /// Cantidad total de eventos aceptados exitosamente.
  int get ingestedCount => _ingestedCount;

  /// Cantidad de eventos descartados por duplicación temporal.
  int get discardedDuplicatesCount => _discardedDuplicatesCount;

  /// Cantidad de eventos descartados por pertenecer a paquetes fuera de la whitelist.
  int get discardedNonWhitelistedCount => _discardedNonWhitelistedCount;

  /// Cantidad total de eventos recibidos por el servicio.
  int get totalReceivedCount =>
      _ingestedCount +
      _discardedDuplicatesCount +
      _discardedNonWhitelistedCount;

  /// Conecta automáticamente este servicio al stream de un [NotificationSourcePort].
  void attachSource(NotificationSourcePort source) {
    detachSource();
    _sourceSubscription = source.notificationStream.listen((event) {
      ingest(event);
    });
  }

  /// Desconecta la escucha activa de la fuente conectada.
  void detachSource() {
    _sourceSubscription?.cancel();
    _sourceSubscription = null;
  }

  /// Calcula el hash determinista SHA-256 para la clave de deduplicación del evento.
  ///
  /// La clave se calcula agrupando en bloques temporales discretos de 5 minutos:
  /// `SHA256(packageName|title|body|bucket5Min)`
  String computeDedupHash(NotificationEvent event) {
    final key = event.deduplicationKey;
    final bytes = utf8.encode(key);
    return sha256.convert(bytes).toString();
  }

  /// Verifica si el evento es un duplicado dentro de la ventana configurada.
  bool isDuplicate(NotificationEvent event, {DateTime? now}) {
    _pruneExpiredHashes(referenceTime: now);
    final hash = computeDedupHash(event);
    return _seenHashes.containsKey(hash);
  }

  /// Procesa e ingiere un [NotificationEvent].
  ///
  /// Aplica en orden:
  /// 1. Validación contra [BankWhitelistService].
  /// 2. Deduplicación por hash SHA-256 temporal.
  /// 3. Emisión hacia [ingestedStream] si es aceptado.
  IngestionResult ingest(NotificationEvent event, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    _pruneExpiredHashes(referenceTime: currentTime);

    final hash = computeDedupHash(event);

    // 1. Filtrado de Whitelist
    if (!_whitelistService.isWhitelisted(event.packageName)) {
      _discardedNonWhitelistedCount++;
      return IngestionResult(
        status: IngestionStatus.ignoredNotWhitelisted,
        event: event,
        dedupHash: hash,
        reason:
            'Paquete "${event.packageName}" no autorizado en la whitelist bancaria',
      );
    }

    // 2. Deduplicación SHA-256
    if (_seenHashes.containsKey(hash)) {
      _discardedDuplicatesCount++;
      return IngestionResult(
        status: IngestionStatus.ignoredDuplicate,
        event: event,
        dedupHash: hash,
        reason:
            'Notificación duplicada detectada dentro de la ventana de ${dedupWindow.inMinutes} minutos',
      );
    }

    // 3. Registro y emisión exitosa
    _seenHashes[hash] = currentTime;
    _ingestedCount++;

    if (!_ingestedController.isClosed) {
      _ingestedController.add(event);
    }

    return IngestionResult(
      status: IngestionStatus.accepted,
      event: event,
      dedupHash: hash,
      reason: 'Evento validado y encolado correctamente',
    );
  }

  /// Elimina del cache hashes cuya antigüedad supere la ventana de deduplicación.
  void _pruneExpiredHashes({DateTime? referenceTime}) {
    final current = referenceTime ?? DateTime.now();
    _seenHashes.removeWhere((_, recordedAt) {
      return current.difference(recordedAt) > dedupWindow;
    });
  }

  /// Limpia manualmente el cache de hashes (útil en tests).
  void clearCache() {
    _seenHashes.clear();
  }

  /// Restablece los contadores métricos a cero.
  void resetStats() {
    _ingestedCount = 0;
    _discardedDuplicatesCount = 0;
    _discardedNonWhitelistedCount = 0;
  }

  /// Cierra el stream y cancela subscripciones activas.
  Future<void> dispose() async {
    detachSource();
    clearCache();
    await _ingestedController.close();
  }
}
