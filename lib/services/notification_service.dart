import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/data/model/responsibility.dart';

/// Servicio singleton para manejar notificaciones locales de responsabilidades
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String _prefsKey = 'notifications_enabled';

  /// Inicializar el plugin de notificaciones
  Future<void> init() async {
    if (_isInitialized) return;

    // Inicializar zonas horarias
    tz_data.initializeTimeZones();

    // Configuración para Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuración para iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _isInitialized = true;
    print('✅ NotificationService inicializado');
  }

  /// Verificar si las notificaciones están habilitadas
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  /// Habilitar/deshabilitar notificaciones
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);

    if (enabled) {
      await scheduleAllNotifications();
    } else {
      await cancelAllNotifications();
    }
  }

  /// Programar notificaciones para todas las responsabilidades
  Future<void> scheduleAllNotifications() async {
    try {
      await ResponsibilityService.init();
      final responsibilities = ResponsibilityService.getAllResponsibilities();
      
      // Cancelar las existentes primero
      await cancelAllNotifications();
      
      for (var r in responsibilities) {
        await _scheduleForResponsibility(r);
      }
      
      print('✅ Programadas ${responsibilities.length * 2} notificaciones');
    } catch (e) {
      print('❌ Error programando notificaciones: $e');
    }
  }

  /// Programar notificaciones para una responsabilidad específica
  Future<void> _scheduleForResponsibility(Responsibility r) async {
    final now = DateTime.now();
    final dueDay = r.safeDueDay;
    
    // Calcular la próxima fecha de vencimiento
    DateTime dueDate = DateTime(now.year, now.month, dueDay);
    if (dueDate.isBefore(now)) {
      // Si ya pasó este mes, programar para el próximo
      dueDate = DateTime(now.year, now.month + 1, dueDay);
    }
    
    // Notificación 1 día antes (a las 9:00 AM)
    final dayBefore = dueDate.subtract(const Duration(days: 1));
    if (dayBefore.isAfter(now)) {
      await _scheduleNotification(
        id: r.safeId.hashCode,
        title: '⏰ Recordatorio de Pago',
        body: '${r.safeName} vence mañana. No olvides pagarlo.',
        scheduledDate: DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 9, 0),
      );
    }
    
    // Notificación el mismo día (a las 8:00 AM)
    if (dueDate.isAfter(now)) {
      await _scheduleNotification(
        id: r.safeId.hashCode + 1000000, // Offset para evitar colisiones
        title: '🔔 ¡Pago Vence Hoy!',
        body: '${r.safeName} vence hoy. Recuerda realizar el pago.',
        scheduledDate: DateTime(dueDate.year, dueDate.month, dueDate.day, 8, 0),
      );
    }
  }

  /// Programar una notificación específica
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'responsibility_reminders',
      'Recordatorios de Pagos',
      channelDescription: 'Notificaciones para recordar pagos pendientes',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use inexact alarms to avoid SCHEDULE_EXACT_ALARM permission issues on Android 12+
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Cancelar todas las notificaciones programadas
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
    print('🗑️ Todas las notificaciones canceladas');
  }
}
