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

  // Keys de preferencias
  static const String _prefsKeyEnabled = 'notifications_enabled';
  static const String _prefsKeyDaysBefore = 'notification_days_before';
  static const String _prefsKeySameDay = 'notification_same_day';
  static const String _prefsKeyHour = 'notification_hour';
  static const String _prefsKeyMinute = 'notification_minute';

  // Valores por defecto
  static const int _defaultDaysBefore = 1;
  static const bool _defaultSameDay = true;
  static const int _defaultHour = 9;
  static const int _defaultMinute = 0;

  /// Inicializar el plugin de notificaciones
  Future<void> init() async {
    if (_isInitialized) return;

    // Inicializar zonas horarias
    tz_data.initializeTimeZones();

    // Configuración para Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuración para iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // Lo solicitamos manualmente
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _isInitialized = true;
    print('✅ NotificationService inicializado');
  }

  /// Solicitar permiso de notificaciones
  /// Retorna true si el permiso fue concedido
  Future<bool> requestPermission() async {
    // Para Android 13+ (API 33+)
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      final bool? granted = await androidPlugin.requestNotificationsPermission();
      print('🔔 Permiso de notificaciones Android: $granted');
      return granted ?? false;
    }

    // Para iOS
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    
    if (iosPlugin != null) {
      final bool? granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      print('🔔 Permiso de notificaciones iOS: $granted');
      return granted ?? false;
    }

    return true; // Para otras plataformas
  }

  /// Verificar estado del permiso de notificaciones
  Future<bool> checkPermissionStatus() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      final bool? areEnabled = await androidPlugin.areNotificationsEnabled();
      return areEnabled ?? false;
    }

    // Para iOS y otras plataformas, asumimos que está habilitado si el servicio está inicializado
    return true;
  }

  /// Verificar si las notificaciones están habilitadas en la app
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeyEnabled) ?? false;
  }

  /// Habilitar/deshabilitar notificaciones
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyEnabled, enabled);

    if (enabled) {
      await scheduleAllNotifications();
    } else {
      await cancelAllNotifications();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GETTERS Y SETTERS DE CONFIGURACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtener días de anticipación configurados
  Future<int> getDaysBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsKeyDaysBefore) ?? _defaultDaysBefore;
  }

  /// Establecer días de anticipación
  Future<void> setDaysBefore(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKeyDaysBefore, days.clamp(0, 7));
    if (await isEnabled()) {
      await scheduleAllNotifications();
    }
  }

  /// Obtener si notificar el mismo día
  Future<bool> getSameDay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeySameDay) ?? _defaultSameDay;
  }

  /// Establecer si notificar el mismo día
  Future<void> setSameDay(bool sameDay) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeySameDay, sameDay);
    if (await isEnabled()) {
      await scheduleAllNotifications();
    }
  }

  /// Obtener hora configurada
  Future<int> getHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsKeyHour) ?? _defaultHour;
  }

  /// Obtener minuto configurado
  Future<int> getMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsKeyMinute) ?? _defaultMinute;
  }

  /// Establecer hora y minuto de notificación
  Future<void> setTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKeyHour, hour.clamp(0, 23));
    await prefs.setInt(_prefsKeyMinute, minute.clamp(0, 59));
    if (await isEnabled()) {
      await scheduleAllNotifications();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROGRAMACIÓN DE NOTIFICACIONES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Programar notificaciones para todas las responsabilidades
  Future<void> scheduleAllNotifications() async {
    try {
      await ResponsibilityService.init();
      final responsibilities = ResponsibilityService.getAllResponsibilities();
      
      // Cancelar las existentes primero
      await cancelAllNotifications();
      
      // Cargar configuración
      final daysBefore = await getDaysBefore();
      final sameDay = await getSameDay();
      final hour = await getHour();
      final minute = await getMinute();
      
      int scheduledCount = 0;
      for (var r in responsibilities) {
        scheduledCount += await _scheduleForResponsibility(
          r, 
          daysBefore: daysBefore,
          sameDay: sameDay,
          hour: hour,
          minute: minute,
        );
      }
      
      print('✅ Programadas $scheduledCount notificaciones');
    } catch (e) {
      print('❌ Error programando notificaciones: $e');
    }
  }

  /// Programar notificaciones para una responsabilidad específica
  /// Retorna el número de notificaciones programadas
  Future<int> _scheduleForResponsibility(
    Responsibility r, {
    required int daysBefore,
    required bool sameDay,
    required int hour,
    required int minute,
  }) async {
    final now = DateTime.now();
    final dueDay = r.safeDueDay;
    int count = 0;
    
    // Calcular la próxima fecha de vencimiento
    DateTime dueDate = DateTime(now.year, now.month, dueDay);
    if (dueDate.isBefore(now)) {
      // Si ya pasó este mes, programar para el próximo
      dueDate = DateTime(now.year, now.month + 1, dueDay);
    }
    
    // Notificación días antes (si daysBefore > 0)
    if (daysBefore > 0) {
      final dayBefore = dueDate.subtract(Duration(days: daysBefore));
      if (dayBefore.isAfter(now)) {
        await _scheduleNotification(
          id: r.safeId.hashCode,
          title: '⏰ Recordatorio de Pago',
          body: daysBefore == 1 
              ? '${r.safeName} vence mañana. No olvides pagarlo.'
              : '${r.safeName} vence en $daysBefore días. No olvides pagarlo.',
          scheduledDate: DateTime(dayBefore.year, dayBefore.month, dayBefore.day, hour, minute),
        );
        count++;
      }
    }
    
    // Notificación el mismo día
    if (sameDay && dueDate.isAfter(now)) {
      await _scheduleNotification(
        id: r.safeId.hashCode + 1000000, // Offset para evitar colisiones
        title: '🔔 ¡Pago Vence Hoy!',
        body: '${r.safeName} vence hoy. Recuerda realizar el pago.',
        scheduledDate: DateTime(dueDate.year, dueDate.month, dueDate.day, hour, minute),
      );
      count++;
    }
    
    return count;
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

  /// Mostrar una notificación de prueba inmediata
  Future<void> showTestNotification() async {
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

    await _plugin.show(
      0,
      '🔔 Notificación de Prueba',
      'Las notificaciones están funcionando correctamente.',
      details,
    );
  }
}
