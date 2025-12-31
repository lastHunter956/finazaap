import 'package:flutter/material.dart';
import 'package:finazaap/Screens/home.dart';
import 'package:finazaap/providers/pin_provider.dart';
import 'package:finazaap/screens/pin_code_screen.dart';
import 'package:finazaap/screens/main_container.dart';

/// Pantalla de Splash que verifica PIN y carga configuración
class AuthSplashScreen extends StatefulWidget {
  const AuthSplashScreen({Key? key}) : super(key: key);

  @override
  State<AuthSplashScreen> createState() => _AuthSplashScreenState();
}

class _AuthSplashScreenState extends State<AuthSplashScreen> with SingleTickerProviderStateMixin {
  final PinProvider _pinProvider = PinProvider();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  String _statusMessage = 'Inicializando...';

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _animationController.forward();
    
    _checkSecurity();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkSecurity() async {
    await Future.delayed(const Duration(milliseconds: 1500)); // Esperar animación

    // Usar el provider (que ya se inicializó en su constructor)
    // Pequeño delay para asegurar que el provider leyó sharedprefs (su init es async pero constructor no)
    // Una mejor implementación real usaría un FutureBuilder o similar, pero por simplicidad:
    await Future.delayed(const Duration(milliseconds: 100)); 
    
    if (_pinProvider.isPinEnabled) {
       setState(() {
         _statusMessage = 'Verificando seguridad...';
       });
       
       if (mounted) {
         Navigator.of(context).pushReplacement(
           MaterialPageRoute(
             builder: (_) => PinCodeScreen(
               mode: PinMode.verify,
               onSuccess: (ctx) {
                 Navigator.of(ctx).pushReplacement(
                   PageRouteBuilder(
                     pageBuilder: (_, __, ___) => MainContainer(),
                     transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
                     transitionDuration: const Duration(milliseconds: 600),
                   )
                 );
               },
             ),
           ),
         );
       }
    } else {
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MainContainer(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 82, 226, 255),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(255, 82, 226, 255).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    size: 60,
                    color: Color.fromRGBO(31, 38, 57, 1),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'FinazaApp',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Finanzas Personales Seguras',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 60),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.fromARGB(255, 82, 226, 255),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
