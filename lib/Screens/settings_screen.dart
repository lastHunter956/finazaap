import 'package:flutter/material.dart';
import 'package:finazaap/providers/pin_provider.dart';
import 'package:finazaap/screens/pin_code_screen.dart';
import 'package:finazaap/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/utils/alert_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PinProvider _pinProvider = PinProvider();
  final NotificationService _notificationService = NotificationService();
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
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color.fromARGB(255, 82, 226, 255),
              onPrimary: Colors.black,
              surface: Color.fromRGBO(42, 49, 67, 1),
              onSurface: Colors.white,
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
      appBar: AppBar(
        title: const Text('Ajustes', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(42, 49, 67, 1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ═══════════════════════════════════════════════════════════════
                // SECCIÓN: GENERAL
                // ═══════════════════════════════════════════════════════════════
                const Text(
                  'General',
                  style: TextStyle(
                    color: Color.fromARGB(255, 82, 226, 255),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(42, 49, 67, 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: const Text('Divisa por defecto', style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                      _currencies.firstWhere((c) => c['code'] == _selectedCurrency)['name'] ?? _selectedCurrency,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 82, 226, 255).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedCurrency,
                        dropdownColor: const Color.fromRGBO(42, 49, 67, 1),
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down, color: Color.fromARGB(255, 82, 226, 255)),
                        style: const TextStyle(color: Color.fromARGB(255, 82, 226, 255), fontWeight: FontWeight.bold),
                        items: _currencies.map((currency) {
                          return DropdownMenuItem<String>(
                            value: currency['code'],
                            child: Text('${currency['symbol']} ${currency['code']}'),
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
                // SECCIÓN: SEGURIDAD
                // ═══════════════════════════════════════════════════════════════
                const Text(
                  'Seguridad',
                  style: TextStyle(
                    color: Color.fromARGB(255, 82, 226, 255),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(42, 49, 67, 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Habilitar PIN', style: TextStyle(color: Colors.white)),
                        subtitle: const Text('Solicitar PIN al abrir la aplicación', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        value: _pinEnabled,
                        activeColor: const Color.fromARGB(255, 82, 226, 255),
                        onChanged: _togglePin,
                      ),
                      if (_pinEnabled) ...[
                        const Divider(height: 1, color: Colors.white12),
                        ListTile(
                          title: const Text('Cambiar PIN', style: TextStyle(color: Colors.white)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white),
                          onTap: _changePin,
                        ),
                        // Biometric toggle (only if available)
                        if (_biometricAvailable) ...[
                          const Divider(height: 1, color: Colors.white12),
                          SwitchListTile(
                            title: const Text('Desbloqueo Biométrico', style: TextStyle(color: Colors.white)),
                            subtitle: const Text(
                              'Usar huella o Face ID para desbloquear',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            value: _biometricEnabled,
                            activeColor: const Color.fromARGB(255, 82, 226, 255),
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
                const Text(
                  'Notificaciones',
                  style: TextStyle(
                    color: Color.fromARGB(255, 82, 226, 255),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(42, 49, 67, 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // Toggle principal
                      SwitchListTile(
                        title: const Text('Recordatorios de Pagos', style: TextStyle(color: Colors.white)),
                        subtitle: const Text(
                          'Recibir recordatorios de obligaciones',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        value: _notificationsEnabled,
                        activeColor: const Color.fromARGB(255, 82, 226, 255),
                        onChanged: _toggleNotifications,
                      ),
                      
                      // Opciones de configuración (solo si está habilitado)
                      if (_notificationsEnabled) ...[
                        const Divider(height: 1, color: Colors.white12),
                        
                        // Días de anticipación
                        ListTile(
                          title: const Text('Días de anticipación', style: TextStyle(color: Colors.white)),
                          subtitle: Text(
                            _daysBefore == 0 
                                ? 'Sin recordatorio previo'
                                : _daysBefore == 1
                                    ? '1 día antes'
                                    : '$_daysBefore días antes',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 82, 226, 255).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<int>(
                              value: _daysBefore,
                              dropdownColor: const Color.fromRGBO(42, 49, 67, 1),
                              underline: const SizedBox(),
                              icon: const Icon(Icons.arrow_drop_down, color: Color.fromARGB(255, 82, 226, 255)),
                              style: const TextStyle(color: Color.fromARGB(255, 82, 226, 255), fontWeight: FontWeight.bold),
                              items: List.generate(8, (i) => i).map((days) {
                                return DropdownMenuItem<int>(
                                  value: days,
                                  child: Text(
                                    days == 0 
                                        ? 'Ninguno' 
                                        : days == 1 
                                            ? '1 día'
                                            : '$days días',
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
                        
                        const Divider(height: 1, color: Colors.white12),
                        
                        // Notificar el mismo día
                        SwitchListTile(
                          title: const Text('Notificar el mismo día', style: TextStyle(color: Colors.white)),
                          subtitle: const Text(
                            'Recordatorio el día de vencimiento',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          value: _sameDay,
                          activeColor: const Color.fromARGB(255, 82, 226, 255),
                          onChanged: _setSameDay,
                        ),
                        
                        const Divider(height: 1, color: Colors.white12),
                        
                        // Hora de notificación
                        ListTile(
                          title: const Text('Hora de notificación', style: TextStyle(color: Colors.white)),
                          subtitle: const Text(
                            'Hora a la que recibirás recordatorios',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          trailing: GestureDetector(
                            onTap: _selectNotificationTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 82, 226, 255).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    color: Color.fromARGB(255, 82, 226, 255),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatTime(_notificationTime),
                                    style: const TextStyle(
                                      color: Color.fromARGB(255, 82, 226, 255),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        const Divider(height: 1, color: Colors.white12),
                        
                        // Botón de prueba
                        ListTile(
                          leading: const Icon(
                            Icons.notifications_active,
                            color: Color.fromARGB(255, 82, 226, 255),
                          ),
                          title: const Text(
                            'Probar notificación',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Enviar una notificación de prueba',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                          onTap: _sendTestNotification,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
