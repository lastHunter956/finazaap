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
      requestAlertPermission: false,
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
  Future<bool> requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      final bool? granted = await androidPlugin.requestNotificationsPermission();
      print('🔔 Permiso de notificaciones Android: $granted');
      return granted ?? false;
    }

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

    return true;
  }

  /// Verificar estado del permiso de notificaciones
  Future<bool> checkPermissionStatus() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      final bool? areEnabled = await androidPlugin.areNotificationsEnabled();
      return areEnabled ?? false;
    }

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

  Future<int> getDaysBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsKeyDaysBefore) ?? _defaultDaysBefore;
  }

  Future<void> setDaysBefore(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKeyDaysBefore, days.clamp(0, 7));
    if (await isEnabled()) {
      await scheduleAllNotifications();
    }
  }

  Future<bool> getSameDay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeySameDay) ?? _defaultSameDay;
  }

  Future<void> setSameDay(bool sameDay) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeySameDay, sameDay);
    if (await isEnabled()) {
      await scheduleAllNotifications();
    }
  }

  Future<int> getHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsKeyHour) ?? _defaultHour;
  }

  Future<int> getMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsKeyMinute) ?? _defaultMinute;
  }

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
      
      await cancelAllNotifications();
      
      final daysBefore = await getDaysBefore();
      final sameDay = await getSameDay();
      final hour = await getHour();
      final minute = await getMinute();
      
      print('📅 Configuración: daysBefore=$daysBefore, sameDay=$sameDay, hora=$hour:$minute');
      print('📋 Responsabilidades encontradas: ${responsibilities.length}');
      
      int scheduledCount = 0;
      int immediateCount = 0;
      
      for (var r in responsibilities) {
        final now = DateTime.now();
        // Solo notificar responsabilidades NO pagadas
        if (!r.isPaidInMonth(now.month, now.year)) {
          final result = await _scheduleForResponsibility(
            r, 
            daysBefore: daysBefore,
            sameDay: sameDay,
            hour: hour,
            minute: minute,
          );
          scheduledCount += result['scheduled'] ?? 0;
          immediateCount += result['immediate'] ?? 0;
        } else {
          print('  ⏭️ ${r.safeName}: ya pagada este mes, omitiendo');
        }
      }
      
      print('✅ Programadas $scheduledCount notificaciones, enviadas $immediateCount inmediatas');
    } catch (e) {
      print('❌ Error programando notificaciones: $e');
    }
  }

  /// Programar notificaciones para una responsabilidad específica
  Future<Map<String, int>> _scheduleForResponsibility(
    Responsibility r, {
    required int daysBefore,
    required bool sameDay,
    required int hour,
    required int minute,
  }) async {
    final now = DateTime.now();
    int scheduled = 0;
    int immediate = 0;

    // Calcular próxima fecha de vencimiento usando la lógica centralizada del modelo
    final daysUntil = r.getDaysUntilDue();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = today.add(Duration(days: daysUntil));
    
    print('  📌 ${r.safeName}: vence en $daysUntil días (${dueDate.toString().substring(0, 10)})');

    final bool isDueToday = (daysUntil == 0);
    
    // ═══════════════════════════════════════════════════════════════════════
    // Notificación días antes
    // ═══════════════════════════════════════════════════════════════════════
    if (daysBefore > 0) {
      final reminderDate = dueDate.subtract(Duration(days: daysBefore));
      final scheduledDateTime = DateTime(reminderDate.year, reminderDate.month, reminderDate.day, hour, minute);
      
      final bool isReminderToday = (reminderDate.year == today.year && 
                                    reminderDate.month == today.month && 
                                    reminderDate.day == today.day);
      
      if (scheduledDateTime.isAfter(now)) {
        // Futuro: programar
        await _scheduleNotification(
          id: r.safeId.hashCode,
          title: '⏰ Recordatorio de Pago',
          body: daysBefore == 1 
              ? '${r.safeName} vence mañana. No olvides pagarlo.'
              : '${r.safeName} vence en $daysBefore días. No olvides pagarlo.',
          scheduledDate: scheduledDateTime,
        );
        print('    ✓ Recordatorio ($daysBefore días antes): programado para ${scheduledDateTime.toString().substring(0, 16)}');
        scheduled++;
      } else if (isReminderToday) {
        // Es hoy pero la hora ya pasó: enviar inmediatamente SOLO si no se ha enviado hoy
        if (!await _hasNotifiedToday('${r.safeId}_before')) {
          await _showImmediateNotification(
            id: r.safeId.hashCode,
            title: '⏰ Recordatorio de Pago',
            body: daysBefore == 1 
                ? '${r.safeName} vence mañana. No olvides pagarlo.'
                : '${r.safeName} vence en $daysBefore días. No olvides pagarlo.',
          );
          await _markAsNotifiedToday('${r.safeId}_before');
          print('    ⚡ Recordatorio ($daysBefore días antes): enviado inmediatamente (hora ya pasó)');
          immediate++;
        } else {
           print('    ✓ Recordatorio ($daysBefore días antes): ya enviado hoy, omitiendo');
        }
      } else {
        print('    ✗ Recordatorio ($daysBefore días antes): fecha ya pasada completamente');
      }
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // Notificación el mismo día
    // ═══════════════════════════════════════════════════════════════════════
    if (sameDay) {
      final scheduledDateTime = DateTime(dueDate.year, dueDate.month, dueDate.day, hour, minute);
      
      if (scheduledDateTime.isAfter(now)) {
        // Futuro: programar
        await _scheduleNotification(
          id: r.safeId.hashCode + 1, // ID diferente
          title: '📅 ¡Pago Recurrente Hoy!',
          body: 'El pago de ${r.safeName} vence hoy. ¡Evita recargos!',
          scheduledDate: scheduledDateTime,
        );
        print('    ✓ Recordatorio (Mismo día): programado para ${scheduledDateTime.toString().substring(0, 16)}');
        scheduled++;
      } else if (isDueToday) {
        // Es hoy pero la hora ya pasó: enviar inmediatamente SOLO si no se ha enviado hoy
        if (!await _hasNotifiedToday('${r.safeId}_today')) {
          await _showImmediateNotification(
            id: r.safeId.hashCode + 1,
            title: '📅 ¡Pago Recurrente Hoy!',
            body: 'El pago de ${r.safeName} vence hoy. ¡Evita recargos!',
          );
          await _markAsNotifiedToday('${r.safeId}_today');
          print('    ⚡ Recordatorio (Mismo día): enviado inmediatamente (hora ya pasó)');
          immediate++;
        } else {
          print('    ✓ Recordatorio (Mismo día): ya enviado hoy, omitiendo');
        }
      } else {
        print('    ✗ Recordatorio (mismo día): fecha ya pasada completamente');
      }
    }
    
    return {'scheduled': scheduled, 'immediate': immediate};
  }
  
  // Helpers para control de notificaciones duplicadas
  Future<bool> _hasNotifiedToday(String uniqueId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return prefs.getBool('notif_sent_${uniqueId}_$today') ?? false;
  }
  
  Future<void> _markAsNotifiedToday(String uniqueId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setBool('notif_sent_${uniqueId}_$today', true);
  }

  /// Programar una notificación para el futuro
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

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
  
  /// Mostrar una notificación inmediatamente
  Future<void> _showImmediateNotification({
    required int id,
    required String title,
    required String body,
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

    await _plugin.show(id, title, body, details);
  }

  /// Cancelar todas las notificaciones programadas
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
    print('🗑️ Todas las notificaciones canceladas');
  }

  /// Mostrar una notificación de prueba
  Future<void> showTestNotification() async {
    await _showImmediateNotification(
      id: 0,
      title: '🔔 Notificación de Prueba',
      body: 'Las notificaciones están funcionando correctamente.',
    );
  }
  
  /// Debug: listar todas las notificaciones programadas
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _plugin.pendingNotificationRequests();
  }
}
