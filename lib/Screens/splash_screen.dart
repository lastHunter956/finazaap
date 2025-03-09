import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:finazaap/widgets/bottomnavigationbar.dart';
import 'package:finazaap/data/model/add_date.dart'; // Importar Add_data
import 'package:finazaap/data/utlity.dart'; // Importar AccountItem

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;
  String _loadingMessage = "Inicializando...";
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _checkDataAvailability();
  }

  Future<void> _checkDataAvailability() async {
    try {
      // Verificar si las boxes de Hive están abiertas
      final isDataBoxOpen = Hive.isBoxOpen('data');
      final isAccountsBoxOpen = Hive.isBoxOpen('accounts');

      if (!isDataBoxOpen) {
        setState(() => _loadingMessage = "Cargando transacciones...");
        // Especificar el tipo correcto
        await Hive.openBox<Add_data>('data');
      }

      if (!isAccountsBoxOpen) {
        setState(() => _loadingMessage = "Cargando cuentas...");
        // Especificar el tipo correcto
        await Hive.openBox<AccountItem>('accounts');
      }

      // Simulamos un pequeño retraso para mostrar la animación
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        setState(() => _isLoading = false);

        // Navegar a la pantalla principal
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const Bottom()),
        );
      }
    } catch (e) {
      print('Error al verificar datos: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _loadingMessage = "Error al cargar datos: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF16151A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Por esto:
            Image.asset(
              'assets/images/Moneo_icon.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback en caso de error
                return Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF368983).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    size: 60,
                    color: Color(0xFF368983),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            if (_isLoading && !_hasError)
              const CircularProgressIndicator(
                color: Color(0xFF368983),
              ),
            const SizedBox(height: 20),
            Text(
              _loadingMessage,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            if (_hasError)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _isLoading = true;
                    _loadingMessage = "Reintentando...";
                  });
                  _checkDataAvailability();
                },
                child: const Text('Reintentar'),
              ),
          ],
        ),
      ),
    );
  }
}
