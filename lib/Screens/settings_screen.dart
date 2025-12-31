import 'package:flutter/material.dart';
import 'package:finazaap/providers/pin_provider.dart';
import 'package:finazaap/screens/pin_code_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/utils/alert_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PinProvider _pinProvider = PinProvider();
  bool _isLoading = true;
  bool _pinEnabled = false;
  String _selectedCurrency = 'COP';
  
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
    setState(() {
      _pinEnabled = prefs.getBool('pin_enabled') ?? false;
      _selectedCurrency = prefs.getString('default_currency') ?? 'COP';
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
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
