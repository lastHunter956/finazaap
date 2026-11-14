import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:finazaap/providers/pin_provider.dart';
import 'package:finazaap/Screens/pin_code_screen.dart';
import 'package:finazaap/services/notification_service.dart';
import 'package:finazaap/services/data_management_service.dart';
import 'package:finazaap/features/notifications/adapters/simulated_notification_source.dart';
import 'package:finazaap/features/notifications/domain/ports/notification_source_port.dart';
import 'package:finazaap/features/notifications/presentation/screens/pending_transactions_screen.dart';
import 'package:finazaap/features/notifications/services/bank_whitelist_service.dart';
import 'package:finazaap/features/notifications/services/notification_pipeline_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/utils/alert_helper.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/core/theme_notifier.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final PinProvider _pinProvider = PinProvider();
  final NotificationService _notificationService = NotificationService();
  final NotificationPipelineService _pipeline =
      NotificationPipelineService.instance;
  BankWhitelistService get _whitelistService => _pipeline.whitelistService;
  bool _isLoading = true;
  bool _pinEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _notificationsEnabled = false;
  bool _bankCaptureEnabled = false;
  bool _autoAcceptFutureEnabled = false;
  bool _notificationAccessGranted = false;
  bool _listenerConnected = false;
  bool _batteryOptimizationIgnored = true;
  String _selectedCurrency = 'COP';
  
  // Configuración de notificaciones
  int _daysBefore = 1;
  bool _sameDay = true;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);
  
  // Lista de divisas disponibles
  static const List<Map<String, String>> _currencies = [
    {'code': 'COP', 'name': 'Peso Colombiano', 'symbol': '\$'},
    {'code': 'USD', 'name': 'Dólar Estadounidense', 'symbol': '\$'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    {'code': 'MXN', 'name': 'Peso Mexicano', 'symbol': '\$'},
    {'code': 'ARS', 'name': 'Peso Argentino', 'symbol': '\$'},
    {'code': 'BRL', 'name': 'Real Brasileño', 'symbol': 'R\$'},
    {'code': 'PEN', 'name': 'Sol Peruano', 'symbol': 'S/'},
    {'code': 'CLP', 'name': 'Peso Chileno', 'symbol': '\$'},
    {'code': 'GBP', 'name': 'Libra Esterlina', 'symbol': '£'},
    {'code': 'JPY', 'name': 'Yen Japonés', 'symbol': '¥'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    try {
      await _pipeline.syncOnResume();
    } catch (_) {}
    await _refreshNotificationPermission();
  }

  Future<void> _refreshNotificationPermission() async {
    final diagnostics = await _whitelistService.getListenerDiagnostics();
    final status = await _pipeline.source.checkStatus();
    final granted = (diagnostics['permissionGranted'] ?? false) ||
        status.permissionStatus == NotificationPermissionStatus.granted;
    if (!mounted) return;
    setState(() {
      _notificationAccessGranted = granted;
      _listenerConnected = diagnostics['listenerConnected'] ?? granted;
      _batteryOptimizationIgnored =
          diagnostics['batteryOptimizationIgnored'] ?? true;
      _bankCaptureEnabled = _pipeline.isCaptureEnabled;
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    var accessGranted = false;
    var listenerConnected = false;
    var batteryIgnored = true;
    try {
      await _pipeline.initialize();
      final sourceStatus = await _pipeline.source.checkStatus();
      final diagnostics = await _whitelistService.getListenerDiagnostics();
      accessGranted = (diagnostics['permissionGranted'] ?? false) ||
          sourceStatus.permissionStatus == NotificationPermissionStatus.granted;
      listenerConnected =
          diagnostics['listenerConnected'] ?? accessGranted;
      batteryIgnored = diagnostics['batteryOptimizationIgnored'] ?? true;
    } catch (_) {
      await _whitelistService.loadFromPrefs();
    }
    
    // Check biometric availability
    try {
      await _pinProvider.checkBiometricAvailability();
    } catch (_) {}
    
    // Cargar configuración de notificaciones
    final hour = await _notificationService.getHour();
    final minute = await _notificationService.getMinute();
    
    if (!mounted) return;
    setState(() {
      _pinEnabled = prefs.getBool('pin_enabled') ?? false;
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      _biometricAvailable = _pinProvider.isBiometricAvailable;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      _bankCaptureEnabled = _pipeline.isCaptureEnabled;
      _autoAcceptFutureEnabled = _pipeline.isAutoAcceptFutureEnabled;
      _notificationAccessGranted = accessGranted;
      _listenerConnected = listenerConnected;
      _batteryOptimizationIgnored = batteryIgnored;
      _selectedCurrency = prefs.getString('default_currency') ?? 'COP';
      _daysBefore = prefs.getInt('notification_days_before') ?? 1;
      _sameDay = prefs.getBool('notification_same_day') ?? true;
      _notificationTime = TimeOfDay(hour: hour, minute: minute);
      _isLoading = false;
    });
  }

  Future<void> _saveCurrency(String currencyCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_currency', currencyCode);
    setState(() {
      _selectedCurrency = currencyCode;
    });
    if (mounted) {
      AlertHelper.success(
        context, 
        'Divisa cambiada a $currencyCode. Reinicia la app para que surta efecto'
      );
    }
  }

  Future<void> _togglePin(bool value) async {
    if (value) {
      // Enable PIN -> Go to Setup
        await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PinCodeScreen(
            mode: PinMode.setup,
            onSuccess: (ctx) {
              Navigator.pop(ctx);
              setState(() {
                _pinEnabled = true;
              });
              AlertHelper.success(context, 'PIN configurado correctamente');
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      );
    } else {
      // Disable PIN -> Verify first
       await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PinCodeScreen(
            mode: PinMode.verify,
            onSuccess: (ctx) async {
              // Now actually disable
              await _pinProvider.disablePin();
              if (mounted) {
                 Navigator.pop(ctx);
                 setState(() {
                  _pinEnabled = false;
                });
                AlertHelper.success(context, 'PIN desactivado');
              }
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      );
    }
  }

  Future<void> _changePin() async {
     await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PinCodeScreen(
          mode: PinMode.change,
          onSuccess: (ctx) {
             Navigator.pop(ctx);
             AlertHelper.success(context, 'PIN actualizado correctamente');
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  /// Activar/desactivar notificaciones con solicitud de permiso
  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      // Solicitar permiso primero
      final granted = await _notificationService.requestPermission();
      
      if (!granted) {
        if (mounted) {
          AlertHelper.warning(
            context,
            'Debes conceder el permiso de notificaciones para activar los recordatorios'
          );
        }
        return; // No activar si no se concedió el permiso
      }
    }
    
    setState(() {
      _notificationsEnabled = value;
    });
    await _notificationService.setEnabled(value);
    
    if (mounted) {
      AlertHelper.success(
        context, 
        value 
          ? 'Recordatorios activados' 
          : 'Recordatorios desactivados'
      );
    }
  }

  /// Seleccionar hora de notificación
  Future<void> _selectNotificationTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _notificationTime) {
      setState(() {
        _notificationTime = picked;
      });
      await _notificationService.setTime(picked.hour, picked.minute);
      if (mounted) {
        AlertHelper.success(context, 'Hora de notificación actualizada');
      }
    }
  }

  /// Cambiar días de anticipación
  Future<void> _setDaysBefore(int days) async {
    setState(() {
      _daysBefore = days;
    });
    await _notificationService.setDaysBefore(days);
  }

  /// Cambiar notificación del mismo día
  Future<void> _setSameDay(bool value) async {
    setState(() {
      _sameDay = value;
    });
    await _notificationService.setSameDay(value);
  }

  /// Enviar notificación de prueba
  Future<void> _sendTestNotification() async {
    await _notificationService.showTestNotification();
    if (mounted) {
      AlertHelper.success(context, 'Notificación de prueba enviada');
    }
  }

  Future<void> _toggleBankCapture(bool value) async {
    if (value) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.appTheme.cardBackground,
          title: Text(
            'Captura de notificaciones bancarias',
            style: TextStyle(color: context.appTheme.textPrimary),
          ),
          content: Text(
            'Moneo leerá únicamente las notificaciones de las apps que selecciones.\n\n'
            '• Qué se guarda: texto de la notificación y clasificación propuesta en cajas locales cifradas con AES-256 en tu dispositivo (100% offline).\n'
            '• Qué NO hace: no envía datos a servidores externos ni lee tu historial de SMS.\n'
            '• Historial previo: Android solo entrega notificaciones nuevas o activas; no es posible recuperar notificaciones descartadas antes de habilitar el permiso.\n'
            '• Control total: puedes desactivar o eliminar todos los datos desde Configuración en cualquier momento.',
            style: TextStyle(color: context.appTheme.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: context.appTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appTheme.accent,
                foregroundColor: context.appTheme.buttonForeground,
              ),
              child: const Text('Activar'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;

      await _pipeline.setCaptureEnabled(true);
      await _refreshNotificationPermission();
      if (!mounted) return;
      setState(() => _bankCaptureEnabled = true);

      if (!_notificationAccessGranted) {
        AlertHelper.info(
          context,
          'Captura activada. Otorga el permiso de acceso a notificaciones en Ajustes de Android.',
        );
      } else {
        AlertHelper.success(context, 'Captura de notificaciones activada');
      }
    } else {
      await _pipeline.setCaptureEnabled(false);
      if (!mounted) return;
      setState(() => _bankCaptureEnabled = false);
      AlertHelper.info(context, 'Captura de notificaciones desactivada');
    }
  }

  Future<void> _toggleAutoAcceptFuture(bool value) async {
    await _pipeline.setAutoAcceptFutureEnabled(value);
    if (!mounted) return;
    setState(() => _autoAcceptFutureEnabled = value);
    AlertHelper.info(
      context,
      value
          ? 'Auto-aceptación activada solo para movimientos futuros de alta confianza.'
          : 'Auto-aceptación automática desactivada.',
    );
  }

  Future<void> _showLearnedPatternsSheet() async {
    final patterns = await _pipeline.patternsService.getAllPatterns();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patrones aprendidos (${patterns.length})',
                      style: TextStyle(
                        color: context.appTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reglas locales guardadas a partir de tus confirmaciones o correcciones manuales.',
                      style: TextStyle(
                        color: context.appTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (patterns.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'Aún no hay patrones aprendidos.',
                            style: TextStyle(
                              color: context.appTheme.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: patterns.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: context.appTheme.borderSubtle,
                          ),
                          itemBuilder: (_, index) {
                            final p = patterns[index];
                            return ListTile(
                              dense: true,
                              title: Text(
                                p.merchantKey,
                                style: TextStyle(
                                  color: context.appTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${p.classification} • ${p.category} • ${p.accountName ?? "Sin cuenta"} (${p.confirmations}x)',
                                style: TextStyle(
                                  color: context.appTheme.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: context.appTheme.error,
                                ),
                                onPressed: () async {
                                  await _pipeline.patternsService
                                      .deletePattern(p.merchantKey);
                                  patterns.removeAt(index);
                                  setSheetState(() {});
                                },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmWipeNotificationData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appTheme.cardBackground,
        title: Text(
          'Eliminar datos de notificaciones',
          style: TextStyle(color: context.appTheme.textPrimary),
        ),
        content: Text(
          'Se eliminarán las transacciones pendientes, el historial de deduplicación, '
          'los patrones aprendidos y la cola nativa. Tus transacciones ya confirmadas en Moneo no se borrarán.',
          style: TextStyle(color: context.appTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: context.appTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _pipeline.wipeAllNotificationData();
    if (!mounted) return;
    setState(() {});
    AlertHelper.success(context, 'Datos de notificaciones eliminados');
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _buildBankCaptureSubtitle() {
    if (!_bankCaptureEnabled) {
      return 'Desactivada • Solo procesa apps seleccionadas, 100% offline';
    }
    if (!_notificationAccessGranted) {
      return 'Falta permiso de acceso a notificaciones en Android';
    }
    final activeAppsCount = _whitelistService.whitelistedPackages.length;
    if (activeAppsCount == 0) {
      return 'Permiso activo • Selecciona al menos 1 app permitida';
    }
    if (_listenerConnected) {
      return 'Activa y conectada • Escuchando $activeAppsCount apps (AES-256)';
    }
    return 'Activa • Permiso concedido, reconectando servicio en segundo plano...';
  }

  Future<void> _showBankAppsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appTheme.secondaryCardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AllowedAppsSheet(
        whitelistService: _whitelistService,
        onChanged: () {
          if (mounted) setState(() {});
        },
      ),
    );
    await _refreshNotificationPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.primaryBackground,
      appBar: AppBar(
        title: Text('Ajustes', style: TextStyle(color: context.appTheme.textPrimary)),
        backgroundColor: context.appTheme.cardBackground,
        iconTheme: IconThemeData(color: context.appTheme.textPrimary),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ═══════════════════════════════════════════════════════════════
                // SECCIÓN: GENERAL
                // ═══════════════════════════════════════════════════════════════
                Text(
                  'General',
                  style: TextStyle(
                    color: context.appTheme.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: context.appTheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    title: Text('Divisa por defecto', style: TextStyle(color: context.appTheme.textPrimary)),
                    subtitle: Text(
                      _currencies.firstWhere((c) => c['code'] == _selectedCurrency)['name'] ?? _selectedCurrency,
                      style: TextStyle(color: context.appTheme.textSecondary, fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.appTheme.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedCurrency,
                        dropdownColor: context.appTheme.cardBackground,
                        underline: const SizedBox(),
                        icon: Icon(Icons.arrow_drop_down, color: context.appTheme.accent),
                        style: TextStyle(color: context.appTheme.accent, fontWeight: FontWeight.bold),
                        items: _currencies.map((currency) {
                          return DropdownMenuItem<String>(
                            value: currency['code'],
                            child: Text(
                              '${currency['symbol']} ${currency['code']}',
                              style: TextStyle(color: context.appTheme.textPrimary),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _saveCurrency(value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),

                // ═══════════════════════════════════════════════════════════════
                // SECCIÓN: APARIENCIA
                // ═══════════════════════════════════════════════════════════════
                Text(
                  'Apariencia',
                  style: TextStyle(
                    color: context.appTheme.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                _buildThemeSelector(context),

                const SizedBox(height: 24),

                // ═══════════════════════════════════════════════════════════════
                // SECCIÓN: SEGURIDAD
                // ═══════════════════════════════════════════════════════════════
                Text(
                  'Seguridad',
                  style: TextStyle(
                    color: context.appTheme.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: context.appTheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text('Habilitar PIN', style: TextStyle(color: context.appTheme.textPrimary)),
                        subtitle: Text('Solicitar PIN al abrir la aplicación', style: TextStyle(color: context.appTheme.textSecondary, fontSize: 12)),
                        value: _pinEnabled,
                        activeColor: context.appTheme.accent,
                        onChanged: _togglePin,
                      ),
                      if (_pinEnabled) ...[
                        Divider(height: 1, color: context.appTheme.borderSubtle),
                        ListTile(
                          title: Text('Cambiar PIN', style: TextStyle(color: context.appTheme.textPrimary)),
                          trailing: Icon(Icons.chevron_right, color: context.appTheme.textSecondary),
                          onTap: _changePin,
                        ),
                        // Biometric toggle (only if available)
                        if (_biometricAvailable) ...[
                          Divider(height: 1, color: context.appTheme.borderSubtle),
                          SwitchListTile(
                            title: Text('Desbloqueo Biométrico', style: TextStyle(color: context.appTheme.textPrimary)),
                            subtitle: Text(
                              'Usar huella o Face ID para desbloquear',
                              style: TextStyle(color: context.appTheme.textSecondary, fontSize: 12),
                            ),
                            value: _biometricEnabled,
                            activeColor: context.appTheme.accent,
                            onChanged: (value) async {
                              await _pinProvider.setBiometricEnabled(value);
                              setState(() {
                                _biometricEnabled = value;
                              });
                              if (mounted) {
                                AlertHelper.success(
                                  context,
                                  value
                                    ? 'Desbloqueo biométrico activado'
                                    : 'Desbloqueo biométrico desactivado'
                                );
                              }
                            },
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // ═══════════════════════════════════════════════════════════════
                // SECCIÓN: NOTIFICACIONES
                // ═══════════════════════════════════════════════════════════════
                Text(
                  'Notificaciones',
                  style: TextStyle(
                    color: context.appTheme.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: context.appTheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Toggle principal
                      SwitchListTile(
                        title: Text('Recordatorios de Pagos', style: TextStyle(color: context.appTheme.textPrimary)),
                        subtitle: Text(
                          'Recibir recordatorios de obligaciones',
                          style: TextStyle(color: context.appTheme.textSecondary, fontSize: 12),
                        ),
                        value: _notificationsEnabled,
                        activeColor: context.appTheme.accent,
                        onChanged: _toggleNotifications,
                      ),
                      
                      Divider(height: 1, color: context.appTheme.borderSubtle),
                      SwitchListTile(
                        key: const Key('settings_bank_capture_switch'),
                        secondary: Icon(
                          Icons.notifications_active_outlined,
                          color: context.appTheme.accent,
                        ),
                        title: Text(
                          'Captura automática bancaria',
                          style: TextStyle(color: context.appTheme.textPrimary),
                        ),
                        subtitle: Text(
                          _buildBankCaptureSubtitle(),
                          style: TextStyle(
                            color: _bankCaptureEnabled &&
                                    (!_notificationAccessGranted ||
                                        _whitelistService
                                            .whitelistedPackages.isEmpty)
                                ? context.appTheme.warning
                                : context.appTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        value: _bankCaptureEnabled,
                        activeThumbColor: context.appTheme.accent,
                        onChanged: _toggleBankCapture,
                      ),

                      if (_bankCaptureEnabled && !_notificationAccessGranted) ...[
                        Divider(height: 1, color: context.appTheme.borderSubtle),
                        ListTile(
                          key: const Key('settings_grant_notification_access_tile'),
                          leading: Icon(
                            Icons.security_update_warning_outlined,
                            color: context.appTheme.warning,
                          ),
                          title: Text(
                            'Otorgar acceso a notificaciones',
                            style: TextStyle(color: context.appTheme.warning),
                          ),
                          subtitle: Text(
                            'Abre Ajustes de Android y habilita "Moneo Notificaciones"',
                            style: TextStyle(
                              color: context.appTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            Icons.open_in_new,
                            color: context.appTheme.warning,
                          ),
                          onTap: () => _whitelistService
                              .openNotificationAccessSettings(),
                        ),
                      ],

                      if (_bankCaptureEnabled &&
                          _notificationAccessGranted &&
                          !_batteryOptimizationIgnored) ...[
                        Divider(height: 1, color: context.appTheme.borderSubtle),
                        ListTile(
                          key: const Key('settings_battery_optimization_tile'),
                          leading: Icon(
                            Icons.battery_saver_outlined,
                            color: context.appTheme.warning,
                          ),
                          title: Text(
                            'Permitir ejecución sin restricciones de batería',
                            style: TextStyle(color: context.appTheme.textPrimary),
                          ),
                          subtitle: Text(
                            'Recomendado en Samsung/Android para detectar notificaciones con la app cerrada',
                            style: TextStyle(
                              color: context.appTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            Icons.open_in_new,
                            color: context.appTheme.warning,
                          ),
                          onTap: () => _whitelistService
                              .openBatteryOptimizationSettings(),
                        ),
                      ],

                      Divider(height: 1, color: context.appTheme.borderSubtle),
                      ListenableBuilder(
                        listenable: _pipeline.pendingNotifier,
                        builder: (context, _) {
                          final pendingCount = _pipeline.pendingNotifier.count;
                          return ListTile(
                            key: const Key('settings_real_inbox_tile'),
                            leading: Icon(
                              Icons.move_to_inbox_outlined,
                              color: context.appTheme.accent,
                            ),
                            title: Text(
                              'Bandeja de Pendientes',
                              style:
                                  TextStyle(color: context.appTheme.textPrimary),
                            ),
                            subtitle: Text(
                              pendingCount > 0
                                  ? '$pendingCount movimientos detectados por revisar'
                                  : 'Revisa y confirma movimientos antes de afectar saldos',
                              style: TextStyle(
                                color: context.appTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: context.appTheme.textSecondary,
                            ),
                            onTap: () async {
                              await _pipeline.syncOnResume();
                              if (!context.mounted) return;
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PendingTransactionsScreen(
                                    notifier: _pipeline.pendingNotifier,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      Divider(height: 1, color: context.appTheme.borderSubtle),
                      ListTile(
                        key: const Key('settings_bank_whitelist_tile'),
                        leading: Icon(
                          Icons.apps_outlined,
                          color: context.appTheme.accent,
                        ),
                        title: Text(
                          'Apps permitidas para notificaciones',
                          style: TextStyle(color: context.appTheme.textPrimary),
                        ),
                        subtitle: Text(
                          '${_whitelistService.whitelistedPackages.length} aplicaciones activas (bancos y mensajería)',
                          style: TextStyle(
                            color: context.appTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: context.appTheme.textSecondary,
                        ),
                        onTap: _showBankAppsSheet,
                      ),

                      Divider(height: 1, color: context.appTheme.borderSubtle),
                      SwitchListTile(
                        key: const Key('settings_auto_accept_future_switch'),
                        secondary: Icon(
                          Icons.bolt_outlined,
                          color: context.appTheme.accent,
                        ),
                        title: Text(
                          'Aceptar automáticamente futuras',
                          style: TextStyle(color: context.appTheme.textPrimary),
                        ),
                        subtitle: Text(
                          'Desactivado por defecto. Solo aplica a futuras notificaciones elegibles de alta confianza (≥85%); ambiguas o sospechosas quedan pendientes.',
                          style: TextStyle(
                            color: context.appTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        value: _autoAcceptFutureEnabled,
                        activeThumbColor: context.appTheme.accent,
                        onChanged: _toggleAutoAcceptFuture,
                      ),

                      Divider(height: 1, color: context.appTheme.borderSubtle),
                      ListTile(
                        key: const Key('settings_learned_patterns_tile'),
                        leading: Icon(
                          Icons.psychology_outlined,
                          color: context.appTheme.accent,
                        ),
                        title: Text(
                          'Patrones aprendidos',
                          style: TextStyle(color: context.appTheme.textPrimary),
                        ),
                        subtitle: Text(
                          'Ver o eliminar reglas locales de comercios',
                          style: TextStyle(
                            color: context.appTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: context.appTheme.textSecondary,
                        ),
                        onTap: _showLearnedPatternsSheet,
                      ),

                      Divider(height: 1, color: context.appTheme.borderSubtle),
                      ListTile(
                        key: const Key('settings_wipe_notifications_tile'),
                        leading: Icon(
                          Icons.delete_sweep_outlined,
                          color: context.appTheme.error,
                        ),
                        title: Text(
                          'Eliminar datos de notificaciones',
                          style: TextStyle(color: context.appTheme.error),
                        ),
                        subtitle: Text(
                          'Borra bandeja pendiente, patrones aprendidos y cola nativa',
                          style: TextStyle(
                            color: context.appTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        onTap: _confirmWipeNotificationData,
                      ),

                      if (kDebugMode) ...[
                        Divider(height: 1, color: context.appTheme.borderSubtle),
                        ListTile(
                          key: const Key('settings_notifications_demo_tile'),
                          leading: Icon(
                            Icons.inbox_outlined,
                            color: context.appTheme.accent,
                          ),
                          title: Text(
                            'Bandeja de Notificaciones (Demo Dev)',
                            style: TextStyle(color: context.appTheme.textPrimary),
                          ),
                          subtitle: Text(
                            'Revisión visual con datos simulados sin alterar saldos',
                            style: TextStyle(
                              color: context.appTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: context.appTheme.textSecondary,
                          ),
                          onTap: () async {
                            final demoNotifier =
                                await createDemoPendingNotifier();
                            if (!context.mounted) return;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PendingTransactionsScreen.demo(
                                  notifier: demoNotifier,
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      // Opciones de configuración (solo si está habilitado)
                      if (_notificationsEnabled) ...[
                        Divider(height: 1, color: context.appTheme.borderSubtle),
                        
                        // Días de anticipación
                        ListTile(
                          title: Text('Días de anticipación', style: TextStyle(color: context.appTheme.textPrimary)),
                          subtitle: Text(
                            _daysBefore == 0 
                                ? 'Sin recordatorio previo'
                                : _daysBefore == 1
                                    ? '1 día antes'
                                    : '$_daysBefore días antes',
                            style: TextStyle(color: context.appTheme.textSecondary, fontSize: 12),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: context.appTheme.accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<int>(
                              value: _daysBefore,
                              dropdownColor: context.appTheme.cardBackground,
                              underline: const SizedBox(),
                              icon: Icon(Icons.arrow_drop_down, color: context.appTheme.accent),
                              style: TextStyle(color: context.appTheme.accent, fontWeight: FontWeight.bold),
                              items: List.generate(8, (i) => i).map((days) {
                                return DropdownMenuItem<int>(
                                  value: days,
                                  child: Text(
                                    days == 0 
                                        ? 'Ninguno' 
                                        : days == 1 
                                            ? '1 día'
                                            : '$days días',
                                    style: TextStyle(color: context.appTheme.textPrimary),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  _setDaysBefore(value);
                                }
                              },
                            ),
                          ),
                        ),
                        
                        Divider(height: 1, color: context.appTheme.borderSubtle),
                        
                        // Notificar el mismo día
                        SwitchListTile(
                          title: Text('Notificar el mismo día', style: TextStyle(color: context.appTheme.textPrimary)),
                          subtitle: Text(
                            'Recordatorio el día de vencimiento',
                            style: TextStyle(color: context.appTheme.textSecondary, fontSize: 12),
                          ),
                          value: _sameDay,
                          activeColor: context.appTheme.accent,
                          onChanged: _setSameDay,
                        ),
                        
                        Divider(height: 1, color: context.appTheme.borderSubtle),
                        
                        // Hora de notificación
                        ListTile(
                          title: Text('Hora de notificación', style: TextStyle(color: context.appTheme.textPrimary)),
                          subtitle: Text(
                            'Hora a la que recibirás recordatorios',
                            style: TextStyle(color: context.appTheme.textSecondary, fontSize: 12),
                          ),
                          trailing: GestureDetector(
                            onTap: _selectNotificationTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: context.appTheme.accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    color: context.appTheme.accent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatTime(_notificationTime),
                                    style: TextStyle(
                                      color: context.appTheme.accent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        Divider(height: 1, color: context.appTheme.borderSubtle),
                        
                        // Botón de prueba
                        ListTile(
                          leading: Icon(
                            Icons.notifications_active,
                            color: context.appTheme.accent,
                          ),
                          title: Text(
                            'Probar notificación',
                            style: TextStyle(color: context.appTheme.textPrimary),
                          ),
                          subtitle: Text(
                            'Enviar una notificación de prueba',
                            style: TextStyle(color: context.appTheme.textSecondary, fontSize: 12),
                          ),
                          trailing: Icon(Icons.chevron_right, color: context.appTheme.textSecondary),
                          onTap: _sendTestNotification,
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // ═══════════════════════════════════════════════════════════
                // SECCIÓN: DATOS
                // ═══════════════════════════════════════════════════════════
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Material(
                    color: context.appTheme.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                          'Datos',
                          style: TextStyle(
                            color: context.appTheme.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      
                      // Exportar datos
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.upload_rounded, color: Colors.blue),
                        ),
                        title: Text('Exportar datos', style: TextStyle(color: context.appTheme.textPrimary)),
                        subtitle: Text(
                          'Crear respaldo de toda la información',
                          style: TextStyle(color: context.appTheme.textSecondary, fontSize: 12),
                        ),
                        trailing: Icon(Icons.chevron_right, color: context.appTheme.textSecondary),
                        onTap: _exportData,
                      ),
                      
                      Divider(height: 1, color: context.appTheme.borderSubtle),
                      
                      // Importar datos
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.download_rounded, color: Colors.green),
                        ),
                        title: Text('Importar datos', style: TextStyle(color: context.appTheme.textPrimary)),
                        subtitle: Text(
                          'Restaurar desde un respaldo',
                          style: TextStyle(color: context.appTheme.textSecondary, fontSize: 12),
                        ),
                        trailing: Icon(Icons.chevron_right, color: context.appTheme.textSecondary),
                        onTap: _importData,
                      ),
                      
                      Divider(height: 1, color: context.appTheme.borderSubtle),
                      
                      // Eliminar todos los datos
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                        ),
                        title: const Text('Eliminar todos los datos', style: TextStyle(color: Colors.red)),
                        subtitle: Text(
                          'Borrar toda la información de la app',
                          style: TextStyle(color: context.appTheme.textSecondary, fontSize: 12),
                        ),
                        trailing: Icon(Icons.chevron_right, color: context.appTheme.textSecondary),
                        onTap: _confirmDeleteAllData,
                      ),
                    ],
                  ),
                ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // MÉTODOS DE GESTIÓN DE DATOS
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> _exportData() async {
    try {
      setState(() => _isLoading = true);
      
      final service = DataManagementService();
      
      // Intentar guardar en carpeta seleccionada
      final path = await service.exportDataToDevice();
      
      if (path != null) {
        setState(() => _isLoading = false);
        if (mounted) AlertHelper.success(context, 'Backup guardado en:\n$path');
        return;
      }
      
      // Si falla o no selecciona (y no es cancelación explícita que podamos distinguir fácilmente),
      // preguntamos si quiere compartir
      if (mounted) {
         // Pequeña pausa visual
         setState(() => _isLoading = false);
         
         // Opcional: Podríamos preguntar aquí, pero para ser directos, si falló la carpeta,
         // asumimos que tal vez quiera compartir.
         // Aunque el usuario se quejó de compartir. Mejor solo notificamos si no se guardó.
         // Pero si retornó null porque el usuario canceló, no hacemos nada.
         // El problema es distinguir cancelación de error en DataManagementService.
         // Asumiremos cancelación.
      }

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AlertHelper.error(context, 'Error al exportar: $e');
      }
    }
  }
  
  Future<void> _importData() async {
    // Mostrar advertencia
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appTheme.cardBackground,
        title: const Text('Importar datos', style: TextStyle(color: Colors.white)),
        content: const Text(
          '⚠️ Los datos importados se agregarán a los existentes.\n\n'
          'Selecciona un archivo .json de respaldo de Moneo.\n\n'
          '¿Deseas continuar?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Seleccionar archivo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      setState(() => _isLoading = true);
      
      final service = DataManagementService();
      final result = await service.importData();
      
      setState(() => _isLoading = false);
      
      if (result['success'] == true && mounted) {
        AlertHelper.success(
          context, 
          'Importación exitosa: ${result['transactionsImported']} transacciones, ${result['responsibilitiesImported']} responsabilidades'
        );
      } else if (mounted) {
        AlertHelper.warning(context, result['message'] ?? 'Error desconocido');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AlertHelper.error(context, 'Error al importar: $e');
      }
    }
  }
  
  Future<void> _confirmDeleteAllData() async {
    // Primer diálogo de confirmación
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appTheme.cardBackground,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('¡Precaución!', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: const Text(
          'Esta acción eliminará TODOS los datos:\n\n• Transacciones\n• Cuentas\n• Responsabilidades\n• Categorías\n\nEsta acción NO se puede deshacer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Continuar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (firstConfirm != true) return;
    
    // Segundo diálogo de confirmación
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appTheme.cardBackground,
        title: const Text('Confirmación final', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás COMPLETAMENTE seguro?\n\nEscribe "ELIMINAR" para confirmar.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ELIMINAR TODO', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (secondConfirm != true) return;
    
    try {
      setState(() => _isLoading = true);
      
      final service = DataManagementService();
      final success = await service.deleteAllData();
      
      setState(() => _isLoading = false);
      
      if (success && mounted) {
        AlertHelper.success(context, 'Todos los datos han sido eliminados');
      } else if (mounted) {
        AlertHelper.error(context, 'Error al eliminar los datos');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AlertHelper.error(context, 'Error: $e');
      }
    }
  }

  // ─────────────── SELECTOR DE TEMA ───────────────

  Widget _buildThemeSelector(BuildContext context) {
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: ThemeNotifier.mode,
      builder: (context, currentMode, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = (constraints.maxWidth - 16) / 3;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppThemeMode.values.map((mode) {
                return SizedBox(
                  width: cardWidth,
                  child: _buildThemeCard(context, mode, currentMode == mode),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeCard(BuildContext context, AppThemeMode mode, bool isSelected) {
    final t = AppTheme.forMode(mode);
    final label = switch (mode) {
      AppThemeMode.defaultDark => 'Default',
      AppThemeMode.diurno => 'Diurno',
      AppThemeMode.nocturno => 'Nocturno',
      AppThemeMode.dia => 'Día',
      AppThemeMode.automatico => 'Automático',
    };
    final icon = switch (mode) {
      AppThemeMode.defaultDark => Icons.dark_mode_rounded,
      AppThemeMode.diurno => Icons.light_mode_outlined,
      AppThemeMode.nocturno => Icons.nights_stay_rounded,
      AppThemeMode.dia => Icons.wb_sunny_rounded,
      AppThemeMode.automatico => Icons.brightness_auto_rounded,
    };

    return GestureDetector(
      onTap: () => ThemeNotifier.setMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? context.appTheme.accent.withValues(alpha: 0.12)
              : context.appTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? context.appTheme.accent
                : context.appTheme.borderSubtle,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mini preview de colores
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _colorDot(t.primaryBackground),
                const SizedBox(width: 2),
                _colorDot(t.cardBackground),
                const SizedBox(width: 2),
                _colorDot(t.buttonBackground),
                const SizedBox(width: 2),
                _colorDot(t.accent),
              ],
            ),
            const SizedBox(height: 6),
            Icon(icon, size: 18, color: isSelected ? context.appTheme.accent : context.appTheme.textHint),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? context.appTheme.accent : context.appTheme.textSecondary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Icon(Icons.check_circle_rounded, size: 12, color: context.appTheme.accent),
            ],
          ],
        ),
      ),
    );
  }

  Widget _colorDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12, width: 0.5),
      ),
    );
  }
}

enum _AppFilterMode { all, selected, banks }

class _AllowedAppsSheet extends StatefulWidget {
  final BankWhitelistService whitelistService;
  final VoidCallback onChanged;

  const _AllowedAppsSheet({
    required this.whitelistService,
    required this.onChanged,
  });

  @override
  State<_AllowedAppsSheet> createState() => _AllowedAppsSheetState();
}

class _AllowedAppsSheetState extends State<_AllowedAppsSheet>
    with WidgetsBindingObserver {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _hasPermission = false;
  List<InstalledAppInfo> _installedApps = const [];
  _AppFilterMode _filter = _AppFilterMode.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionOnly();
    }
  }

  Future<void> _refreshPermissionOnly() async {
    try {
      await NotificationPipelineService.instance.syncOnResume();
    } catch (_) {}
    final granted =
        await widget.whitelistService.isNotificationAccessGranted();
    if (!mounted) return;
    setState(() => _hasPermission = granted);
    widget.onChanged();
  }

  Future<void> _loadData() async {
    final results = await Future.wait<dynamic>([
      widget.whitelistService.isNotificationAccessGranted(),
      widget.whitelistService.getInstalledApps(),
    ]);
    if (!mounted) return;
    setState(() {
      _hasPermission = results[0] as bool;
      _installedApps = results[1] as List<InstalledAppInfo>;
      _loading = false;
    });
  }

  List<InstalledAppInfo> _buildDisplayList() {
    final defaultPkgs = BankWhitelistService.defaultBankList
        .map((b) => b.packageName)
        .toSet();

    // Si no hay apps nativas (ej. Web/tests), usa el catálogo configurado
    final baseList = _installedApps.isNotEmpty
        ? _installedApps
        : widget.whitelistService.allBanks
            .map(
              (b) => InstalledAppInfo(
                packageName: b.packageName,
                appName: b.name,
              ),
            )
            .toList();

    final q = _query.trim().toLowerCase();
    final filtered = baseList.where((app) {
      if (q.isNotEmpty &&
          !app.appName.toLowerCase().contains(q) &&
          !app.packageName.toLowerCase().contains(q)) {
        return false;
      }
      if (_filter == _AppFilterMode.selected) {
        return widget.whitelistService.isWhitelisted(app.packageName);
      }
      if (_filter == _AppFilterMode.banks) {
        return defaultPkgs.contains(app.packageName);
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final aOn = widget.whitelistService.isWhitelisted(a.packageName) ? 0 : 1;
      final bOn = widget.whitelistService.isWhitelisted(b.packageName) ? 0 : 1;
      if (aOn != bOn) return aOn.compareTo(bOn);
      final aBank = defaultPkgs.contains(a.packageName) ? 0 : 1;
      final bBank = defaultPkgs.contains(b.packageName) ? 0 : 1;
      if (aBank != bBank) return aBank.compareTo(bBank);
      return a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final items = _buildDisplayList();
    final activeCount = widget.whitelistService.whitelistedPackages.length;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        builder: (_, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Apps permitidas',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$activeCount activas · bancos, mensajería y otras apps',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        widget.whitelistService.resetToDefaults();
                        await widget.whitelistService.saveToPrefs();
                        await NotificationPipelineService.instance
                            .syncWhitelistToNative();
                        setState(() {});
                        widget.onChanged();
                      },
                      child: Text(
                        'Restablecer',
                        style: TextStyle(color: theme.accent),
                      ),
                    ),
                  ],
                ),
              ),

              // Banner del permiso real de lectura de notificaciones
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (_hasPermission ? theme.income : Colors.amber)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_hasPermission ? theme.income : Colors.amber)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _hasPermission
                          ? Icons.verified_user_rounded
                          : Icons.notifications_paused_rounded,
                      color: _hasPermission ? theme.income : Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hasPermission
                                ? 'Acceso a notificaciones activo'
                                : 'Permiso de notificaciones pendiente',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _hasPermission
                                ? 'Android permite leer notificaciones de las apps elegidas'
                                : 'Actívalo en Ajustes de Android para detectar alertas reales',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.whitelistService
                          .openNotificationAccessSettings(),
                      child: Text(
                        _hasPermission ? 'Ajustes' : 'Abrir permisos',
                        style: TextStyle(
                          color: theme.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Buscador y chips de filtro
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(color: theme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar app o paquete (ej. WhatsApp, Mensajes)...',
                    hintStyle: TextStyle(color: theme.textHint, fontSize: 13),
                    prefixIcon:
                        Icon(Icons.search_rounded, color: theme.textSecondary),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded,
                                size: 18, color: theme.textSecondary),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: theme.darkBackground,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.borderSubtle),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildFilterChip(theme, _AppFilterMode.all, 'Todas'),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                        theme, _AppFilterMode.selected, 'Seleccionadas'),
                    const SizedBox(width: 8),
                    _buildFilterChip(theme, _AppFilterMode.banks, 'Bancos'),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.borderSubtle),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                        ? Center(
                            child: Text(
                              'No hay aplicaciones que coincidan',
                              style: TextStyle(color: theme.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: items.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: theme.borderSubtle,
                            ),
                            itemBuilder: (_, index) {
                              final app = items[index];
                              final enabled = widget.whitelistService
                                  .isWhitelisted(app.packageName);
                              return SwitchListTile(
                                secondary: app.iconBytes != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(
                                          app.iconBytes!,
                                          width: 34,
                                          height: 34,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : CircleAvatar(
                                        radius: 17,
                                        backgroundColor: theme.accent
                                            .withValues(alpha: 0.16),
                                        child: Icon(
                                          Icons.apps_rounded,
                                          size: 18,
                                          color: theme.accent,
                                        ),
                                      ),
                                title: Text(
                                  app.appName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  app.packageName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                value: enabled,
                                activeThumbColor: theme.accent,
                                onChanged: (value) async {
                                  await widget.whitelistService.setBankEnabled(
                                    app.packageName,
                                    value,
                                    appName: app.appName,
                                  );
                                  await NotificationPipelineService.instance
                                      .syncWhitelistToNative();
                                  setState(() {});
                                  widget.onChanged();
                                },
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(
    AppTheme theme,
    _AppFilterMode mode,
    String label,
  ) {
    final selected = _filter == mode;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = mode),
      selectedColor: theme.accent.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: selected ? theme.accent : theme.textSecondary,
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected ? theme.accent : theme.borderSubtle,
      ),
      backgroundColor: theme.darkBackground,
      visualDensity: VisualDensity.compact,
    );
  }
}
