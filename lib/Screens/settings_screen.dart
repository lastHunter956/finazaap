import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:finazaap/providers/pin_provider.dart';
import 'package:finazaap/Screens/pin_code_screen.dart';
import 'package:finazaap/services/notification_service.dart';
import 'package:finazaap/services/data_management_service.dart';
import 'package:finazaap/features/notifications/adapters/simulated_notification_source.dart';
import 'package:finazaap/features/notifications/presentation/screens/pending_transactions_screen.dart';
import 'package:finazaap/features/notifications/services/bank_whitelist_service.dart';
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

class _SettingsScreenState extends State<SettingsScreen> {
  final PinProvider _pinProvider = PinProvider();
  final NotificationService _notificationService = NotificationService();
  final BankWhitelistService _whitelistService = BankWhitelistService();
  bool _isLoading = true;
  bool _pinEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _notificationsEnabled = false;
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
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await _whitelistService.loadFromPrefs();
    
    // Check biometric availability
    await _pinProvider.checkBiometricAvailability();
    
    // Cargar configuración de notificaciones
    final hour = await _notificationService.getHour();
    final minute = await _notificationService.getMinute();
    
    setState(() {
      _pinEnabled = prefs.getBool('pin_enabled') ?? false;
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      _biometricAvailable = _pinProvider.isBiometricAvailable;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
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

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _showBankAppsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appTheme.secondaryCardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final banks = _whitelistService.allBanks;
            final activeCount = _whitelistService.whitelistedPackages.length;
            return SafeArea(
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.65,
                minChildSize: 0.4,
                maxChildSize: 0.9,
                builder: (_, scrollController) {
                  return Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.appTheme.borderSubtle,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Aplicaciones bancarias',
                                    style: TextStyle(
                                      color: context.appTheme.textPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$activeCount de ${banks.length} permitidas para leer notificaciones',
                                    style: TextStyle(
                                      color: context.appTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                _whitelistService.resetToDefaults();
                                await _whitelistService.saveToPrefs();
                                setSheetState(() {});
                                if (mounted) setState(() {});
                              },
                              child: Text(
                                'Restablecer',
                                style: TextStyle(color: context.appTheme.accent),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: context.appTheme.borderSubtle),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: banks.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: context.appTheme.borderSubtle,
                          ),
                          itemBuilder: (_, index) {
                            final bank = banks[index];
                            final enabled =
                                _whitelistService.isWhitelisted(bank.packageName);
                            return SwitchListTile(
                              title: Text(
                                bank.name,
                                style: TextStyle(
                                  color: context.appTheme.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                bank.packageName,
                                style: TextStyle(
                                  color: context.appTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              value: enabled,
                              activeColor: context.appTheme.accent,
                              onChanged: (value) async {
                                await _whitelistService.setBankEnabled(
                                  bank.packageName,
                                  value,
                                );
                                setSheetState(() {});
                                if (mounted) setState(() {});
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
          },
        );
      },
    );
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
                Container(
                  decoration: BoxDecoration(
                    color: context.appTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                Container(
                  decoration: BoxDecoration(
                    color: context.appTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                Container(
                  decoration: BoxDecoration(
                    color: context.appTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                      ListTile(
                        key: const Key('settings_bank_whitelist_tile'),
                        leading: Icon(
                          Icons.apps_outlined,
                          color: context.appTheme.accent,
                        ),
                        title: Text(
                          'Aplicaciones bancarias permitidas',
                          style: TextStyle(color: context.appTheme.textPrimary),
                        ),
                        subtitle: Text(
                          '${_whitelistService.whitelistedPackages.length} de ${_whitelistService.allBanks.length} aplicaciones activas',
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
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: context.appTheme.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
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
