import 'package:flutter/material.dart';
import 'package:finazaap/providers/pin_provider.dart';
import 'package:finazaap/screens/pin_code_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PinProvider _pinProvider = PinProvider();
  bool _isLoading = true;
  bool _pinEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Fix: Read directly from SharedPreferences to avoid race condition with Provider init
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pinEnabled = prefs.getBool('pin_enabled') ?? false;
      _isLoading = false;
    });
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PIN configurado correctamente')),
              );
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN desactivado')),
                );
              }
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      );
    }
  }

  Future<void> _changePin() async {
    // Change PIN -> Verify old -> Setup new (handled by PinCodeScreen internal logic or manual flow)
    // Let's use the PinCodeScreen mode 'change' logic if I implemented it, 
    // or just Verify then Setup.
    
    // Using simple flow: Verify first, then Setup.
     await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PinCodeScreen(
          mode: PinMode.change, // My PinCodeScreen handles verification then setup transition
          onSuccess: (ctx) {
             Navigator.pop(ctx); // Close pin screen
             ScaffoldMessenger.of(context).showSnackBar( // Use outer context for SnackBar
                const SnackBar(content: Text('PIN actualizado correctamente')),
             );
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
        title: const Text('Configuración', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(42, 49, 67, 1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
