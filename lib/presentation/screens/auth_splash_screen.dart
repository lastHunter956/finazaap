import 'package:flutter/material.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/providers/pin_provider.dart';
import 'package:finazaap/Screens/pin_code_screen.dart';
import 'package:finazaap/Screens/main_container.dart';
import 'package:finazaap/Screens/onboarding_screen.dart';
import 'package:finazaap/services/onboarding_service.dart';

/// Pantalla de Splash Premium con logo de la app
class AuthSplashScreen extends StatefulWidget {
  const AuthSplashScreen({Key? key}) : super(key: key);

  @override
  State<AuthSplashScreen> createState() => _AuthSplashScreenState();
}

class _AuthSplashScreenState extends State<AuthSplashScreen> with TickerProviderStateMixin {
  final PinProvider _pinProvider = PinProvider();
  
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  
  String _statusMessage = 'Inicializando...';

  @override
  void initState() {
    super.initState();
    
    // Fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    // Scale animation for logo
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    
    // Pulse animation for loading indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _scaleController.forward();
    });
    
    _checkSecurity();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkSecurity() async {
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 300)),
      _pinProvider.ensureInitialized(),
    ]);
    if (!mounted) return;

    if (_pinProvider.isPinEnabled) {
       setState(() {
         _statusMessage = 'Verificando seguridad...';
       });
       
       if (_pinProvider.isBiometricEnabled) {
         setState(() {
           _statusMessage = 'Autenticando...';
         });
         
         final biometricSuccess = await _pinProvider.authenticateWithBiometrics();
         if (biometricSuccess) {
           _navigateToHome();
           return;
         }
       }
       
       if (mounted) {
         Navigator.of(context).pushReplacement(
           MaterialPageRoute(
             builder: (_) => PinCodeScreen(
               mode: PinMode.verify,
               onSuccess: (ctx) async {
                 final showOnboarding =
                     await OnboardingService.shouldShowOnboarding();
                 final lastStep = showOnboarding
                     ? await OnboardingService.getLastStep()
                     : 0;
                 if (!ctx.mounted) return;
                 Navigator.of(ctx).pushReplacement(
                   PageRouteBuilder(
                     pageBuilder: (_, __, ___) => showOnboarding
                         ? OnboardingScreen(initialStep: lastStep)
                         : MainContainer(),
                     transitionsBuilder: (_, animation, __, child) =>
                         FadeTransition(opacity: animation, child: child),
                     transitionDuration: const Duration(milliseconds: 600),
                   ),
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

  Future<void> _navigateToHome() async {
    final showOnboarding = await OnboardingService.shouldShowOnboarding();
    final lastStep = showOnboarding ? await OnboardingService.getLastStep() : 0;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => showOnboarding
            ? OnboardingScreen(initialStep: lastStep)
            : MainContainer(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              context.appTheme.cardBackground,
              context.appTheme.primaryBackground,
              context.appTheme.darkBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  
                  // Logo con animación
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: [
                          BoxShadow(
                            color: isLight 
                                ? context.appTheme.accent.withOpacity(0.15) 
                                : const Color.fromARGB(255, 82, 226, 255).withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(isLight ? 0.08 : 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(35),
                        child: Image.asset(
                          'assets/images/Moneo_icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 82, 226, 255),
                                borderRadius: BorderRadius.circular(35),
                              ),
                              child: Icon(
                                Icons.account_balance_wallet,
                                size: 70,
                                color: context.appTheme.primaryBackground,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Título
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: isLight
                          ? [
                              context.appTheme.textPrimary,
                              context.appTheme.accent,
                            ]
                          : [
                              Colors.white,
                              const Color.fromARGB(255, 82, 226, 255),
                            ],
                    ).createShader(bounds),
                    child: const Text(
                      'Moneo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Subtítulo
                  Text(
                    'Finanzas Personales Seguras',
                    style: TextStyle(
                      color: isLight 
                          ? context.appTheme.textSecondary 
                          : Colors.white.withOpacity(0.6),
                      fontSize: 14,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  
                  const Spacer(flex: 2),
                  
                  // Indicador de carga animado
                  FadeTransition(
                    opacity: _pulseAnimation,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isLight 
                                  ? context.appTheme.accent 
                                  : const Color.fromARGB(255, 82, 226, 255).withOpacity(0.8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            color: isLight 
                                ? context.appTheme.textSecondary 
                                : Colors.white.withOpacity(0.5),
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
