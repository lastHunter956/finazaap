import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:finazaap/features/notifications/domain/models/notification_event.dart';
import 'package:finazaap/features/notifications/domain/ports/notification_source_port.dart';

/// Adaptador real de Android para [NotificationSourcePort] conectado a
/// `MoneoNotificationListenerService` mediante MethodChannel y EventChannel.
class AndroidNotificationSource implements NotificationSourcePort {
  static const MethodChannel _methodChannel =
      MethodChannel('com.example.finazaap/notifications_apps');
  static const EventChannel _eventChannel =
      EventChannel('com.example.finazaap/notifications_events');

  final StreamController<NotificationEvent> _controller =
      StreamController<NotificationEvent>.broadcast();

  StreamSubscription<dynamic>? _eventSubscription;
  bool _isListening = false;

  @override
  Stream<NotificationEvent> get notificationStream => _controller.stream;

  bool get isListening => _isListening;

  @override
  Future<NotificationSourceStatus> checkStatus() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const NotificationSourceStatus(
        isListening: false,
        permissionStatus: NotificationPermissionStatus.notSupported,
        message: 'Captura de notificaciones disponible solo en Android.',
      );
    }

    try {
      final granted = await _methodChannel.invokeMethod<bool>(
            'isNotificationAccessGranted',
          ) ??
          false;

      if (!granted) {
        _isListening = false;
        return const NotificationSourceStatus(
          isListening: false,
          permissionStatus: NotificationPermissionStatus.denied,
          message: 'Permiso de acceso a notificaciones denegado o revocado.',
        );
      }

      return NotificationSourceStatus(
        isListening: _isListening,
        permissionStatus: NotificationPermissionStatus.granted,
        message: _isListening
            ? 'Escucha activa de notificaciones bancarias.'
            : 'Permiso concedido. Escucha en pausa.',
      );
    } catch (_) {
      return const NotificationSourceStatus(
        isListening: false,
        permissionStatus: NotificationPermissionStatus.notSupported,
        message: 'Canal nativo de notificaciones no disponible.',
      );
    }
  }

  /// Consulta diagnósticos nativos del listener (permiso, conexión activa y batería).
  Future<Map<String, bool>> getListenerDiagnostics() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const {
        'permissionGranted': false,
        'listenerConnected': false,
        'batteryOptimizationIgnored': true,
      };
    }

    try {
      final raw = await _methodChannel.invokeMapMethod<String, dynamic>(
        'getListenerDiagnostics',
      );
      if (raw != null) {
        return {
          'permissionGranted': raw['permissionGranted'] as bool? ?? false,
          'listenerConnected': raw['listenerConnected'] as bool? ?? false,
          'batteryOptimizationIgnored':
              raw['batteryOptimizationIgnored'] as bool? ?? true,
        };
      }
    } catch (_) {}

    final status = await checkStatus();
    final granted = status.permissionStatus == NotificationPermissionStatus.granted;
    return {
      'permissionGranted': granted,
      'listenerConnected': granted,
      'batteryOptimizationIgnored': true,
    };
  }

  /// Sincroniza con la capa nativa si la captura está habilitada y qué paquetes
  /// seleccionó el usuario.
  Future<void> syncConfig({
    required bool enabled,
    required List<String> allowedPackages,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _methodChannel.invokeMethod<bool>('syncCaptureConfig', {
        'enabled': enabled,
        'allowedPackages': allowedPackages,
      });
    } catch (_) {
      // No propagar en entornos sin canal nativo
    }
  }

  @override
  Future<bool> startListening() async {
    final status = await checkStatus();
    if (status.permissionStatus != NotificationPermissionStatus.granted) {
      _isListening = false;
      return false;
    }

    _eventSubscription ??= _eventChannel.receiveBroadcastStream().listen(
      (dynamic raw) {
        final event = _parseNativeMap(raw);
        if (event != null) {
          _controller.add(event);
          _ackIds([event.id]);
        }
      },
      onError: (_) {
        // Mantener estabilidad ante errores transitorios del canal
      },
    );

    _isListening = true;
    await drainPendingEvents(includeActive: true);
    return true;
  }

  /// Drena notificaciones encoladas en almacenamiento nativo y opcionalmente
  /// consulta notificaciones activas en la barra de estado.
  Future<int> drainPendingEvents({bool includeActive = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return 0;

    try {
      if (includeActive) {
        await _methodChannel.invokeMethod<List<dynamic>>(
          'fetchActiveNotifications',
        );
      }

      final rawList = await _methodChannel.invokeMethod<List<dynamic>>(
        'peekQueuedNotifications',
      );
      if (rawList == null || rawList.isEmpty) return 0;

      final ackedIds = <String>[];
      for (final item in rawList) {
        final event = _parseNativeMap(item);
        if (event != null) {
          _controller.add(event);
          ackedIds.add(event.id);
        }
      }

      if (ackedIds.isNotEmpty) {
        await _ackIds(ackedIds);
      }
      return ackedIds.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _ackIds(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _methodChannel.invokeMethod<int>('ackQueuedNotifications', {
        'ids': ids,
      });
    } catch (_) {}
  }

  Future<void> clearNativeQueue() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _methodChannel.invokeMethod<bool>('clearNativeQueue');
    } catch (_) {}
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  NotificationEvent? _parseNativeMap(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final packageName = (map['packageName'] ?? '').toString().trim();
    if (packageName.isEmpty) return null;

    final id = (map['id'] ?? '').toString().trim();
    final title = (map['title'] ?? '').toString();
    final body = (map['body'] ?? '').toString();
    final tsMs = (map['timestampMs'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
    String? optStr(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    final rawLines = map['textLines'];
    final textLines = rawLines is Iterable
        ? rawLines
            .map((e) => e?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty)
            .toList()
        : const <String>[];

    return NotificationEvent(
      id: id.isNotEmpty ? id : '${packageName}_$tsMs',
      packageName: packageName,
      title: title,
      body: body,
      timestamp: DateTime.fromMillisecondsSinceEpoch(tsMs),
      channelId: optStr(map['channelId']),
      category: optStr(map['category']),
      subText: optStr(map['subText']),
      summaryText: optStr(map['summaryText']),
      tickerText: optStr(map['tickerText']),
      textLines: textLines,
      isOngoing: map['isOngoing'] == true,
      isGroupSummary: map['isGroupSummary'] == true,
    );
  }

  void dispose() {
    _eventSubscription?.cancel();
    _controller.close();
  }
}
