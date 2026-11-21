import 'package:flutter/material.dart';
import 'package:finazaap/providers/pin_provider.dart';
import 'package:finazaap/Screens/pin_code_screen.dart';
import 'package:finazaap/services/notification_service.dart';
import 'package:finazaap/services/data_management_service.dart';
import 'package:finazaap/features/notifications/domain/ports/notification_source_port.dart';
import 'package:finazaap/features/notifications/presentation/screens/pending_transactions_screen.dart';
import 'package:finazaap/features/notifications/services/bank_whitelist_service.dart';
import 'package:finazaap/features/notifications/services/notification_pipeline_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/utils/alert_helper.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/core/theme_notifier.dart';
import 'package:finazaap/services/ai_provider_config.dart';
import 'package:finazaap/widgets/moneo_header_bar.dart';
import 'package:finazaap/Screens/onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AiProviderConfigStore? aiConfigStore;

  const SettingsScreen({
    Key? key,
    this.aiConfigStore,
  }) : super(key: key);

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
  AiProviderConfigStore get _aiStore =>
      widget.aiConfigStore ?? AiProviderConfigStore.instance;
  AiEngineConfig _aiConfig = const AiEngineConfig();
  bool _isTestingAiConnection = false;
  AiProviderProbeResult? _lastAiProbeResult;
  List<String> _discoveredAiModels = const [];
  bool _isLoading = true;
  bool _pinEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _notificationsEnabled = false;
  bool _pendingReminderActivation = false;
  bool _bankCaptureEnabled = false;
  bool _autoAcceptFutureEnabled = false;
  bool _notificationAccessGranted = false;
  bool _listenerConnected = false;
  bool _batteryOptimizationIgnored = true;
  bool _restrictedSettingsBlocked = false;
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
    _aiStore.addListener(_onAiConfigChanged);
    _loadSettings();
  }

  @override
  void dispose() {
    _aiStore.removeListener(_onAiConfigChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onAiConfigChanged() {
    if (!mounted) return;
    setState(() {
      _aiConfig = _aiStore.current;
    });
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
    final restrictedBlocked =
        diagnostics['restrictedSettingsBlocked'] ?? false;
    final remindersPermGranted = await _notificationService.checkPermissionStatus();
    var activatedPendingReminders = false;
    if (_pendingReminderActivation && remindersPermGranted) {
      _pendingReminderActivation = false;
      await _notificationService.setEnabled(true);
      activatedPendingReminders = true;
    }
    if (!mounted) return;
    setState(() {
      _notificationAccessGranted = granted;
      _listenerConnected = diagnostics['listenerConnected'] ?? granted;
      _batteryOptimizationIgnored =
          diagnostics['batteryOptimizationIgnored'] ?? true;
      _restrictedSettingsBlocked = restrictedBlocked;
      _bankCaptureEnabled = _pipeline.isCaptureEnabled;
      if (activatedPendingReminders) {
        _notificationsEnabled = true;
      }
    });
    if (activatedPendingReminders) {
      AlertHelper.success(context, 'Recordatorios activados');
    }
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
    
    // Inicializar estado real de PIN (FlutterSecureStorage) y biometría
    try {
      await _pinProvider.ensureInitialized();
      await _pinProvider.checkBiometricAvailability();
    } catch (_) {}
    
    // Cargar configuración de notificaciones
    final hour = await _notificationService.getHour();
    final minute = await _notificationService.getMinute();
    AiEngineConfig aiCfg = _aiStore.current;
    try {
      aiCfg = await _aiStore.loadConfig();
    } catch (_) {}
    
    if (!mounted) return;
    setState(() {
      _aiConfig = aiCfg;
      _pinEnabled = _pinProvider.isPinEnabled;
      _biometricEnabled = _pinProvider.isBiometricEnabled;
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
      final result = await _notificationService.requestPermissionDetailed();

      if (!result.isGranted) {
        _pendingReminderActivation = true;
        if (mounted) {
          final openSettings = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Permiso de notificaciones requerido'),
              content: const Text(
                'Debes habilitar las notificaciones para la app en Ajustes de Android para activar los recordatorios de pagos.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Abrir Ajustes'),
                ),
              ],
            ),
          );
          if (openSettings == true) {
            await _whitelistService.openAppNotificationSettings();
          } else {
            _pendingReminderActivation = false;
            if (mounted) {
              AlertHelper.warning(
                context,
                'Debes conceder el permiso de notificaciones para activar los recordatorios',
              );
            }
          }
        }
        return; // No activar si no se concedió el permiso
      }
    }

    _pendingReminderActivation = false;
    setState(() {
      _notificationsEnabled = value;
    });
    await _notificationService.setEnabled(value);

    if (mounted) {
      AlertHelper.success(
        context,
        value ? 'Recordatorios activados' : 'Recordatorios desactivados',
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

  Future<void> _showNotificationDiagnosticsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appTheme.secondaryCardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final theme = sheetCtx.appTheme;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final entries = _pipeline.diagnosticLog;
            return SafeArea(
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.65,
                minChildSize: 0.4,
                maxChildSize: 0.9,
                builder: (_, scrollCtrl) => Column(
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
                      padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Diagnóstico de notificaciones',
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Solo apps permitidas · en memoria local (lote pendiente: ${_pipeline.bufferedBatchCount})',
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (entries.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                _pipeline.clearDiagnosticLog();
                                setSheetState(() {});
                                if (mounted) setState(() {});
                              },
                              child: Text(
                                'Limpiar',
                                style: TextStyle(color: theme.error),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: theme.borderSubtle),
                    Expanded(
                      child: entries.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Aún no se han recibido avisos en esta sesión. Cuando llegue una notificación de una app permitida (ej. Nequi, Rappi, Nu), aparecerá aquí su paquete, canal y resultado.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollCtrl,
                              itemCount: entries.length,
                              separatorBuilder: (_, __) =>
                                  Divider(height: 1, color: theme.borderSubtle),
                              itemBuilder: (_, idx) {
                                final e = entries[idx];
                                final hh = e.timestamp.hour
                                    .toString()
                                    .padLeft(2, '0');
                                final mm = e.timestamp.minute
                                    .toString()
                                    .padLeft(2, '0');
                                final ch = (e.channelId != null &&
                                        e.channelId!.isNotEmpty)
                                    ? ' · canal: ${e.channelId}'
                                    : '';
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    '${e.appName} [${e.outcome}] · $hh:$mm',
                                    style: TextStyle(
                                      color: theme.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${e.packageName}$ch\n${e.detail}',
                                    style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  isThreeLine: true,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.primaryBackground,
      body: Column(
        children: [
          MoneoHeaderBar.primaryTab(title: 'Ajustes'),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: context.appTheme.accent,
                    ),
                  )
                : ListView(
                    padding: MoneoLayoutMetrics.scrollBottomPadding(
                      context,
                      hasFab: false,
                      horizontal: 16,
                      top: 16,
                    ),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Divisa por defecto',
                                style: TextStyle(color: context.appTheme.textPrimary, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currencies.firstWhere((c) => c['code'] == _selectedCurrency)['name'] ?? _selectedCurrency,
                                style: TextStyle(color: context.appTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Semantics(
                          button: true,
                          identifier: 'default_currency_dropdown',
                          label: 'Selector de divisa por defecto: $_selectedCurrency',
                          child: Container(
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
                      ],
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

                const SizedBox(height: 16),

                Semantics(
                  button: true,
                  identifier: 'settings_open_onboarding',
                  label: 'Abrir guía inicial de Moneo',
                  child: Material(
                    color: context.appTheme.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: context.appTheme.borderSubtle),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      minVerticalPadding: 12,
                      leading: Icon(
                        Icons.explore_outlined,
                        color: context.appTheme.accent,
                      ),
                      title: Text(
                        'Guía inicial',
                        style: TextStyle(
                          color: context.appTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Revisar el recorrido inicial y configurar categorías o cuentas',
                        style: TextStyle(
                          color: context.appTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: context.appTheme.textSecondary,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const OnboardingScreen(
                              isReopened: true,
                              initialStep: 0,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

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
                        if (_restrictedSettingsBlocked) ...[
                          Divider(height: 1, color: context.appTheme.borderSubtle),
                          ListTile(
                            key: const Key('settings_restricted_settings_tile'),
                            leading: Icon(
                              Icons.admin_panel_settings_outlined,
                              color: context.appTheme.warning,
                            ),
                            title: Text(
                              'Desbloquear ajustes restringidos',
                              style: TextStyle(color: context.appTheme.textPrimary),
                            ),
                            subtitle: Text(
                              'En Info. de la app, toca menú (⋮) > "Permitir ajustes restringidos" si Android bloquea el acceso',
                              style: TextStyle(
                                color: context.appTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Icon(
                              Icons.open_in_new,
                              color: context.appTheme.warning,
                            ),
                            onTap: () =>
                                _whitelistService.openAppDetailsSettings(),
                          ),
                        ],
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
                      ListTile(
                        key: const Key('settings_notification_diagnostics_tile'),
                        leading: Icon(
                          Icons.troubleshoot_outlined,
                          color: context.appTheme.accent,
                        ),
                        title: Text(
                          'Diagnóstico de captura',
                          style: TextStyle(color: context.appTheme.textPrimary),
                        ),
                        subtitle: Text(
                          'Últimos ${_pipeline.diagnosticLog.length} avisos de apps permitidas (solo local)',
                          style: TextStyle(
                            color: context.appTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: context.appTheme.textSecondary,
                        ),
                        onTap: _showNotificationDiagnosticsSheet,
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
                
                const SizedBox(height: 24),

                // ═══════════════════════════════════════════════════════════════
                // SECCIÓN: MOTOR DE IA PRINCIPAL Y PROVEEDORES
                // ═══════════════════════════════════════════════════════════════
                _buildAiEngineSection(context),

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
                
                const SizedBox(height: 8),
              ],
            ),
          ),
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
        title: Text(
          'Importar datos',
          style: TextStyle(color: context.appTheme.textPrimary),
        ),
        content: Text(
          '⚠️ Los datos importados se agregarán a los existentes.\n\n'
          'Selecciona un archivo .json de respaldo de Moneo.\n\n'
          '¿Deseas continuar?',
          style: TextStyle(color: context.appTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: context.appTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appTheme.accent,
              foregroundColor: context.appTheme.buttonForeground,
            ),
            child: const Text('Seleccionar archivo'),
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
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: context.appTheme.error, size: 28),
            const SizedBox(width: 10),
            Text('¡Precaución!', style: TextStyle(color: context.appTheme.error)),
          ],
        ),
        content: Text(
          'Esta acción eliminará TODOS los datos:\n\n• Transacciones\n• Cuentas\n• Responsabilidades\n• Categorías\n\nEsta acción NO se puede deshacer.',
          style: TextStyle(color: context.appTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: context.appTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appTheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Continuar'),
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
        title: Text(
          'Confirmación final',
          style: TextStyle(color: context.appTheme.textPrimary),
        ),
        content: Text(
          '¿Estás COMPLETAMENTE seguro?\n\nEscribe "ELIMINAR" para confirmar.',
          style: TextStyle(color: context.appTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: context.appTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appTheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('ELIMINAR TODO'),
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

    final isDiurno = context.isDiurno;

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Tema $label',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => ThemeNotifier.setMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isDiurno && isSelected
              ? const Color(0xFFF0F6FF)
              : isSelected
                  ? context.appTheme.accent.withValues(alpha: 0.12)
                  : context.appTheme.cardBackground,
          borderRadius: BorderRadius.circular(isDiurno ? 16 : 12),
          border: Border.all(
            color: isSelected
                ? context.appTheme.accent
                : context.appTheme.borderSubtle,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isDiurno
              ? [
                  BoxShadow(
                    color: isSelected
                        ? context.appTheme.accent.withValues(alpha: 0.16)
                        : const Color(0x0A0B132B),
                    blurRadius: isSelected ? 12 : 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
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

  Widget _buildAiEngineSection(BuildContext context) {
    final t = context.appTheme;
    final cfg = _aiConfig;
    final activeKey = cfg.activePrimaryKey;
    final cloudKeys = cfg.apiKeys;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Motor de IA',
          style: TextStyle(
            color: t.accent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: t.cardBackground,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IA Principal activa',
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aplica a Notificaciones, Reportes y Chat de IA',
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    InputDecorator(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: t.darkBackground,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: t.borderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: t.borderSubtle),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<AiProviderId>(
                          key: const Key('settings_ai_primary_provider_dropdown'),
                          value: cfg.primaryProvider,
                          isExpanded: true,
                          dropdownColor: t.cardBackground,
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                          items: AiProviderId.values.map((provider) {
                            return DropdownMenuItem<AiProviderId>(
                              value: provider,
                              child: Text(
                                provider.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (next) async {
                            if (next == null) return;
                            await _aiStore.setPrimaryProvider(next);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: t.borderSubtle),
              ListTile(
                key: const Key('settings_ai_local_model_tile'),
                minVerticalPadding: 12,
                leading: Icon(Icons.memory_rounded, color: t.accent),
                title: Text(
                  'Modelo local (.litertlm)',
                  style: TextStyle(color: t.textPrimary),
                ),
                subtitle: Text(
                  cfg.primaryProvider == AiProviderId.localHuggingFace &&
                          (cfg.localHuggingFaceUrl?.isNotEmpty ?? false)
                      ? cfg.localHuggingFaceUrl!
                      : 'Gemma 4 E2B por defecto (o URL HuggingFace personalizada)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: t.textSecondary, fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right, color: t.textSecondary),
                onTap: _showHuggingFaceUrlDialog,
              ),
              Divider(height: 1, color: t.borderSubtle),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'API Keys Cloud (${cloudKeys.length})',
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Almacenadas cifradas en FlutterSecureStorage',
                              style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          key: const Key('settings_ai_add_key_button'),
                          onPressed: _showAddApiKeyDialog,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Agregar API Key'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: t.buttonBackground,
                            foregroundColor: t.buttonForeground,
                            minimumSize: const Size(48, 48),
                            tapTargetSize: MaterialTapTargetSize.padded,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (cloudKeys.isEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: t.darkBackground.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: t.borderSubtle),
                        ),
                        child: Text(
                          'No hay API Keys registradas. Agrega OpenRouter, NVIDIA NIM, OpenCode Zen, Gemini u OpenAI.',
                          style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      for (final entry in cloudKeys)
                        Container(
                          key: ValueKey('ai_key_card_${entry.id}'),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: t.darkBackground.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: activeKey?.id == entry.id
                                  ? t.accent
                                  : t.borderSubtle,
                              width: activeKey?.id == entry.id ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${entry.label} · ${entry.provider.displayName}',
                                      style: TextStyle(
                                        color: t.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (activeKey?.id == entry.id)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: t.accent.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Principal',
                                        style: TextStyle(
                                          color: t.accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${entry.maskedKey} • Modelo: ${entry.preferredModel ?? 'Automático gratuito'}',
                                style: TextStyle(
                                  color: t.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  TextButton(
                                    key: ValueKey('ai_key_set_primary_${entry.id}'),
                                    onPressed: () => _aiStore.setPrimaryProvider(
                                      entry.provider,
                                      keyId: entry.id,
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: t.accent,
                                      minimumSize: const Size(48, 48),
                                      tapTargetSize:
                                          MaterialTapTargetSize.padded,
                                    ),
                                    child: const Text('Usar como Principal'),
                                  ),
                                  TextButton(
                                    key: ValueKey('ai_key_toggle_${entry.id}'),
                                    onPressed: () => _aiStore.updateApiKey(
                                      entry.copyWith(isEnabled: !entry.isEnabled),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: t.textSecondary,
                                      minimumSize: const Size(48, 48),
                                      tapTargetSize:
                                          MaterialTapTargetSize.padded,
                                    ),
                                    child: Text(
                                      entry.isEnabled ? 'Desactivar' : 'Activar',
                                    ),
                                  ),
                                  TextButton(
                                    key: ValueKey('ai_key_delete_${entry.id}'),
                                    onPressed: () =>
                                        _aiStore.removeApiKey(entry.id),
                                    style: TextButton.styleFrom(
                                      foregroundColor: t.error,
                                      minimumSize: const Size(48, 48),
                                      tapTargetSize:
                                          MaterialTapTargetSize.padded,
                                    ),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: t.borderSubtle),
              SwitchListTile(
                key: const Key('settings_ai_auto_rotate_switch'),
                title: Text(
                  'Rotación automática gratuita ante límite (429)',
                  style: TextStyle(color: t.textPrimary, fontSize: 13.5),
                ),
                subtitle: Text(
                  'Rota automáticamente entre modelos gratuitos y llaves del proveedor activo',
                  style: TextStyle(color: t.textSecondary, fontSize: 11.5),
                ),
                value: cfg.autoRotateFreeModels,
                activeThumbColor: t.accent,
                onChanged: (value) async {
                  await _aiStore.saveConfig(
                    cfg.copyWith(autoRotateFreeModels: value),
                  );
                },
              ),
              Divider(height: 1, color: t.borderSubtle),
              SwitchListTile(
                key: const Key('settings_ai_cross_fallback_switch'),
                title: Text(
                  'Respaldo automático entre mis otras APIs',
                  style: TextStyle(color: t.textPrimary, fontSize: 13.5),
                ),
                subtitle: Text(
                  'Si el proveedor principal se agota, intenta con otra API Key activa',
                  style: TextStyle(color: t.textSecondary, fontSize: 11.5),
                ),
                value: cfg.crossProviderFallback,
                activeThumbColor: t.accent,
                onChanged: (value) async {
                  await _aiStore.saveConfig(
                    cfg.copyWith(crossProviderFallback: value),
                  );
                },
              ),
              Divider(height: 1, color: t.borderSubtle),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('settings_ai_test_connection_button'),
                      onPressed: _isTestingAiConnection ? null : _testAiConnection,
                      icon: _isTestingAiConnection
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: t.accent,
                              ),
                            )
                          : const Icon(Icons.wifi_tethering_rounded, size: 18),
                      label: const Text('Probar conexión / Ver modelos'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.accent,
                        minimumSize: const Size(48, 48),
                        tapTargetSize: MaterialTapTargetSize.padded,
                        side: BorderSide(color: t.accent.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    if (_lastAiProbeResult != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        key: const Key('settings_ai_probe_result_banner'),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (_lastAiProbeResult!.ok ? t.success : t.error)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _lastAiProbeResult!.message,
                              style: TextStyle(
                                color: _lastAiProbeResult!.ok
                                    ? t.success
                                    : t.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_discoveredAiModels.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Modelos: ${_discoveredAiModels.take(5).join(', ')}',
                                style: TextStyle(
                                  color: t.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _testAiConnection() async {
    setState(() {
      _isTestingAiConnection = true;
    });
    try {
      final cfg = _aiStore.current;
      final keyId = cfg.activePrimaryKey?.id;
      final probe = await _aiStore.testConnection(
        cfg.primaryProvider,
        keyId: keyId,
      );
      final models = probe.discoveredModels.isNotEmpty
          ? probe.discoveredModels
          : await _aiStore.fetchAvailableModels(
              cfg.primaryProvider,
              keyId: keyId,
            );
      if (!mounted) return;
      setState(() {
        _lastAiProbeResult = probe;
        _discoveredAiModels = models;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastAiProbeResult = AiProviderProbeResult(
          ok: false,
          message: 'Error inesperado al probar conexión: $e',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTestingAiConnection = false;
        });
      }
    }
  }

  Future<void> _showHuggingFaceUrlDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _HuggingFaceUrlDialog(
        initialUrl: _aiConfig.localHuggingFaceUrl ??
            AiProviderConfigStore.defaultGemmaUrl,
        aiStore: _aiStore,
      ),
    );
  }

  Future<void> _showAddApiKeyDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AddApiKeyDialog(aiStore: _aiStore),
    );
  }
}

class _HuggingFaceUrlDialog extends StatefulWidget {
  final String initialUrl;
  final AiProviderConfigStore aiStore;

  const _HuggingFaceUrlDialog({
    required this.initialUrl,
    required this.aiStore,
  });

  @override
  State<_HuggingFaceUrlDialog> createState() => _HuggingFaceUrlDialogState();
}

class _HuggingFaceUrlDialogState extends State<_HuggingFaceUrlDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return AlertDialog(
      backgroundColor: t.cardBackground,
      title: Text(
        'Modelo local (.litertlm)',
        style: TextStyle(color: t.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pega una URL de HuggingFace (.litertlm) o restaura Gemma 4 E2B por defecto.',
              style: TextStyle(color: t.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('ai_hf_url_input'),
              controller: _controller,
              style: TextStyle(color: t.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'URL .litertlm',
                labelStyle: TextStyle(color: t.textSecondary),
                filled: true,
                fillColor: t.darkBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await widget.aiStore.setPrimaryProvider(
              AiProviderId.localGemmaDefault,
            );
            if (context.mounted) Navigator.pop(context);
          },
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text('Restaurar Gemma 4'),
        ),
        ElevatedButton(
          onPressed: () async {
            final url = _controller.text.trim();
            if (url.isNotEmpty) {
              await widget.aiStore.setPrimaryProvider(
                AiProviderId.localHuggingFace,
                huggingFaceUrl: url,
              );
            }
            if (context.mounted) Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: t.buttonBackground,
            foregroundColor: t.buttonForeground,
            minimumSize: const Size(48, 48),
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _AddApiKeyDialog extends StatefulWidget {
  final AiProviderConfigStore aiStore;

  const _AddApiKeyDialog({required this.aiStore});

  @override
  State<_AddApiKeyDialog> createState() => _AddApiKeyDialogState();
}

class _AddApiKeyDialogState extends State<_AddApiKeyDialog> {
  AiProviderId _selectedProvider = AiProviderId.openRouter;
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  bool _setAsPrimary = true;
  bool _obscureSecret = true;
  String? _errorText;

  @override
  void dispose() {
    _labelController.dispose();
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final cloudProviders =
        AiProviderId.values.where((p) => p.isCloud).toList(growable: false);

    return AlertDialog(
      backgroundColor: t.cardBackground,
      title: Text(
        'Agregar API Key Cloud',
        style: TextStyle(color: t.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<AiProviderId>(
              key: const Key('ai_key_dialog_provider'),
              initialValue: _selectedProvider,
              isExpanded: true,
              dropdownColor: t.cardBackground,
              style: TextStyle(color: t.textPrimary),
              decoration: InputDecoration(
                labelText: 'Proveedor',
                labelStyle: TextStyle(color: t.textSecondary),
                filled: true,
                fillColor: t.darkBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: cloudProviders.map((p) {
                return DropdownMenuItem<AiProviderId>(
                  value: p,
                  child: Text(
                    p.displayName,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedProvider = value;
                });
              },
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('ai_key_dialog_label'),
              controller: _labelController,
              style: TextStyle(color: t.textPrimary),
              decoration: InputDecoration(
                labelText: 'Etiqueta (ej. Cuenta Principal)',
                labelStyle: TextStyle(color: t.textSecondary),
                filled: true,
                fillColor: t.darkBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('ai_key_dialog_secret'),
              controller: _keyController,
              obscureText: _obscureSecret,
              style: TextStyle(color: t.textPrimary),
              decoration: InputDecoration(
                labelText: 'API Key',
                errorText: _errorText,
                labelStyle: TextStyle(color: t.textSecondary),
                filled: true,
                fillColor: t.darkBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscureSecret = !_obscureSecret;
                    });
                  },
                  icon: Icon(
                    _obscureSecret
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: t.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('ai_key_dialog_model'),
              controller: _modelController,
              style: TextStyle(color: t.textPrimary),
              decoration: InputDecoration(
                labelText: 'Modelo preferido (opcional)',
                hintText: 'Automático gratuito',
                hintStyle: TextStyle(color: t.textHint),
                labelStyle: TextStyle(color: t.textSecondary),
                filled: true,
                fillColor: t.darkBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const Key('ai_key_dialog_set_primary'),
              contentPadding: EdgeInsets.zero,
              value: _setAsPrimary,
              activeColor: t.accent,
              title: Text(
                'Marcar como IA Principal',
                style: TextStyle(color: t.textPrimary, fontSize: 13),
              ),
              onChanged: (value) {
                setState(() {
                  _setAsPrimary = value ?? false;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          key: const Key('ai_key_dialog_save'),
          onPressed: () async {
            final rawKey = _keyController.text.trim();
            if (rawKey.isEmpty) {
              setState(() {
                _errorText = 'Ingresa una API Key válida';
              });
              return;
            }
            await widget.aiStore.addApiKey(
              provider: _selectedProvider,
              label: _labelController.text.trim(),
              rawApiKey: rawKey,
              preferredModel: _modelController.text.trim().isEmpty
                  ? null
                  : _modelController.text.trim(),
              setAsPrimary: _setAsPrimary,
            );
            if (context.mounted) Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: t.buttonBackground,
            foregroundColor: t.buttonForeground,
            minimumSize: const Size(48, 48),
          ),
          child: const Text('Guardar'),
        ),
      ],
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
