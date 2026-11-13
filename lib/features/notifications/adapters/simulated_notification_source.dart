import 'dart:async';

import '../domain/models/notification_event.dart';
import '../domain/ports/notification_source_port.dart';

/// Implementación en memoria y simulador de [NotificationSourcePort].
///
/// Permite inyectar eventos de notificación para pruebas unitarias, desarrollo
/// y demostraciones sin requerir el servicio nativo de Android ni permisos del sistema.
class SimulatedNotificationSource implements NotificationSourcePort {
  final StreamController<NotificationEvent> _controller =
      StreamController<NotificationEvent>.broadcast();

  bool _isListening = false;

  /// Indica si el simulador está actualmente en modo de escucha.
  bool get isListening => _isListening;

  @override
  Stream<NotificationEvent> get notificationStream => _controller.stream;

  @override
  Future<NotificationSourceStatus> checkStatus() async {
    return NotificationSourceStatus(
      isListening: _isListening,
      permissionStatus: NotificationPermissionStatus.granted,
      message: _isListening
          ? 'Simulador activo y emitiendo eventos'
          : 'Simulador pausado',
    );
  }

  @override
  Future<bool> startListening() async {
    _isListening = true;
    return true;
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
  }

  /// Emite un [NotificationEvent] hacia el flujo de notificaciones.
  ///
  /// Retorna `true` si el evento fue despachado exitosamente al stream.
  /// Retorna `false` si el simulador no está escuchando o si el stream está cerrado.
  bool emit(NotificationEvent event) {
    if (!_isListening || _controller.isClosed) {
      return false;
    }
    _controller.add(event);
    return true;
  }

  /// Crea y emite un evento crudo de forma simplificada para tests y mocks.
  NotificationEvent? emitRaw({
    required String packageName,
    required String title,
    required String body,
    DateTime? timestamp,
    String? id,
  }) {
    final event = NotificationEvent(
      id: id ?? 'sim_${DateTime.now().microsecondsSinceEpoch}',
      packageName: packageName,
      title: title,
      body: body,
      timestamp: timestamp ?? DateTime.now(),
    );

    final sent = emit(event);
    return sent ? event : null;
  }

  /// Cierra el stream subyacente y libera recursos.
  Future<void> dispose() async {
    _isListening = false;
    await _controller.close();
  }
}
