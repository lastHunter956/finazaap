import '../models/notification_event.dart';

enum NotificationPermissionStatus { granted, denied, notSupported }

class NotificationSourceStatus {
  final bool isListening;
  final NotificationPermissionStatus permissionStatus;
  final String? message;

  const NotificationSourceStatus({
    required this.isListening,
    required this.permissionStatus,
    this.message,
  });

  NotificationSourceStatus copyWith({
    bool? isListening,
    NotificationPermissionStatus? permissionStatus,
    String? message,
  }) {
    return NotificationSourceStatus(
      isListening: isListening ?? this.isListening,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      message: message ?? this.message,
    );
  }

  Map<String, dynamic> toJson() => {
    'is_listening': isListening,
    'permission_status': permissionStatus.name,
    'message': message,
  };

  factory NotificationSourceStatus.fromJson(Map<String, dynamic> json) =>
      NotificationSourceStatus(
        isListening:
            (json['is_listening'] ?? json['isListening']) as bool? ?? false,
        permissionStatus: NotificationPermissionStatus.values.firstWhere(
          (e) =>
              e.name == (json['permission_status'] ?? json['permissionStatus']),
          orElse: () => NotificationPermissionStatus.notSupported,
        ),
        message: json['message'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationSourceStatus &&
          runtimeType == other.runtimeType &&
          isListening == other.isListening &&
          permissionStatus == other.permissionStatus &&
          message == other.message;

  @override
  int get hashCode =>
      isListening.hashCode ^
      permissionStatus.hashCode ^
      (message?.hashCode ?? 0);

  @override
  String toString() =>
      'NotificationSourceStatus(isListening: $isListening, permissionStatus: $permissionStatus, message: $message)';
}

/// Puerto abstracto para la fuente de notificaciones bancarias.
/// Permite desacoplar implementaciones nativas (Android NotificationListenerService)
/// de simuladores o mocks para testing sin depender de dart:io ni APIs de plataforma.
abstract class NotificationSourcePort {
  /// Flujo continuo de eventos de notificación crudos entrantes.
  Stream<NotificationEvent> get notificationStream;

  /// Consulta el estado actual del puerto y los permisos del sistema.
  Future<NotificationSourceStatus> checkStatus();

  /// Inicia la escucha de eventos.
  Future<bool> startListening();

  /// Detiene la escucha de eventos.
  Future<void> stopListening();
}
