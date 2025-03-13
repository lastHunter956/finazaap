import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:finazaap/widgets/bottomnavigationbar.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/utlity.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  String _loadingMessage = "Inicializando aplicación...";
  bool _hasError = false;
  double _loadingProgress = 0.0;
  
  // Controladores para múltiples animaciones
  late AnimationController _logoScaleController;
  late Animation<double> _logoScaleAnimation;
  
  late AnimationController _loadingController;
  late Animation<double> _loadingAnimation;
  
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;
  
  late AnimationController _particlesController;
  late Animation<double> _particlesAnimation;

  // Lista de partículas para el fondo
  final List<Particle> _particles = List.generate(25, (_) => Particle());

  @override
  void initState() {
    super.initState();
    
    // Inicializa controladores de animación
    _logoScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _logoScaleAnimation = CurvedAnimation(
      parent: _logoScaleController,
      curve: Curves.elasticOut,
    );
    
    _loadingController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut),
    );
    
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat();
    
    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      _backgroundController
    );
    
    _particlesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 15000),
    )..repeat();
    
    _particlesAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      _particlesController
    );
    
    // Inicia la animación del logo después de un pequeño retraso
    Future.delayed(const Duration(milliseconds: 200), () {
      _logoScaleController.forward();
    });

    // Solo llama a este método
    _checkDataAvailability();
  }

  @override
  void dispose() {
    _logoScaleController.dispose();
    _loadingController.dispose();
    _backgroundController.dispose();
    _particlesController.dispose();
    super.dispose();
  }

  Future<void> _checkDataAvailability() async {
    try {
      // Iniciar con 10% para mostrar que el proceso ha comenzado
      setState(() {
        _loadingProgress = 0.1;
        _loadingMessage = "Inicializando aplicación...";
      });
      
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Verificar boxes de Hive
      final isDataBoxOpen = Hive.isBoxOpen('data');
      final isAccountsBoxOpen = Hive.isBoxOpen('accounts');
      
      // Actualizar a 20% después de la verificación inicial
      setState(() {
        _loadingProgress = 0.2;
      });
      
      if (!isDataBoxOpen) {
        setState(() {
          _loadingProgress = 0.3;
          _loadingMessage = "Cargando historial de transacciones...";
        });
        
        // Cargar data box
        await Hive.openBox<Add_data>('data');
        
        // Actualizar progreso
        setState(() {
          _loadingProgress = 0.5;
        });
        
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (!isAccountsBoxOpen) {
        setState(() {
          _loadingProgress = 0.6;
          _loadingMessage = "Preparando cuentas y balances...";
        });
        
        // Cargar accounts box
        await Hive.openBox<AccountItem>('accounts');
        
        // Actualizar progreso
        setState(() {
          _loadingProgress = 0.8;
        });
        
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Finalizar: todo listo
      setState(() {
        _loadingProgress = 0.9;
        _loadingMessage = "¡Todo listo!";
      });
      
      // Permitir que la animación finalice con un breve retraso
      await Future.delayed(const Duration(milliseconds: 400));
      
      // Alcanzar 100% justo antes de navegar
      setState(() {
        _loadingProgress = 1.0;
      });
      
      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        setState(() => _isLoading = false);

        // Transición con fade para ir a la pantalla principal
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const Bottom(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      print('Error al verificar datos: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _loadingMessage = "No se pudieron cargar los datos";
          // Mantener la barra en el último punto de progreso
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFF16151A),
      body: Stack(
        children: [
          // Fondo animado
          AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: Size(screenSize.width, screenSize.height),
                painter: BackgroundPainter(
                  progress: _backgroundAnimation.value,
                ),
              );
            },
          ),
          
          // Partículas flotantes
          AnimatedBuilder(
            animation: _particlesAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: Size(screenSize.width, screenSize.height),
                painter: ParticlesPainter(
                  particles: _particles,
                  progress: _particlesAnimation.value,
                ),
              );
            },
          ),
          
          // Contenido principal
          SafeArea(
            child: Column(
              children: [
                // Espacio superior
                const Spacer(),
                
                // Logo animado
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _logoScaleAnimation,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: const Color(0xFF368983).withOpacity(0.15),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF368983).withOpacity(0.2),
                                blurRadius: 30,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/Moneo_icon.png',
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.account_balance_wallet,
                                  size: 80,
                                  color: Color(0xFF368983),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Nombre de la aplicación
                      FadeTransition(
                        opacity: _logoScaleAnimation,
                        child: const Text(
                          'FINAZAAP',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Color(0xFF368983),
                                offset: Offset(0, 0),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 10),
                      
                      // Eslogan
                      FadeTransition(
                        opacity: _logoScaleAnimation,
                        child: const Text(
                          'Control financiero personalizado',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white60,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Espacio para el indicador de carga
                const Spacer(),
                
                // Indicador de progreso personalizado
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mensaje de carga
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          _loadingMessage,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      
                      // Barra de progreso estilizada
                      AnimatedBuilder(
                        animation: _loadingAnimation,
                        builder: (context, child) {
                          return Container(
                            height: 4,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Stack(
                                  children: [
                                    // Barra de progreso base
                                    Container(
                                      width: constraints.maxWidth * _loadingProgress,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFF368983),
                                            const Color(0xFF66BB6A),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    // Efecto de brillante que se mueve
                                    Positioned(
                                      left: constraints.maxWidth * 
                                        ((_loadingProgress - 0.1) + _loadingAnimation.value * 0.2)
                                          .clamp(0.0, _loadingProgress),
                                      child: Opacity(
                                        opacity: _loadingAnimation.value,
                                        child: Container(
                                          width: 20,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.white.withOpacity(0.0),
                                                Colors.white.withOpacity(0.5),
                                                Colors.white.withOpacity(0.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        }
                      ),
                      
                      // Botón de reintento en caso de error
                      if (_hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: Center(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _hasError = false;
                                  _isLoading = true;
                                  _loadingProgress = 0.0;
                                  _loadingMessage = "Reintentando...";
                                });
                                _checkDataAvailability();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF368983),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: const Text('Reintentar'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Créditos o info de versión
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'v2.0.1',
                    style: TextStyle(
                      color: Colors.white30,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Clase para representar una partícula flotante
class Particle {
  late double x;
  late double y;
  late double size;
  late double speed;
  late double opacity;
  
  Particle() {
    reset();
  }
  
  void reset() {
    x = math.Random().nextDouble() * 1.0;
    y = math.Random().nextDouble() * 1.0;
    size = 1.0 + math.Random().nextDouble() * 4.0;
    speed = 0.001 + math.Random().nextDouble() * 0.01;
    opacity = 0.1 + math.Random().nextDouble() * 0.4;
  }
  
  void update(double progress) {
    y -= speed;
    if (y < 0) {
      reset();
      y = 1.0;
    }
  }
}

// Pintor para el fondo con degradado
class BackgroundPainter extends CustomPainter {
  final double progress;
  
  BackgroundPainter({required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    
    // Gradiente principal
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF16151A),
          Color(0xFF1A1E2F),
          Color(0xFF1F263B),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect);
    
    canvas.drawRect(rect, paint);
    
    // Efecto de luz que se mueve
    final centerX = size.width * (0.3 + progress * 0.4);
    final centerY = size.height * (0.2 + progress * 0.2);
    
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          2.0 * centerX / size.width - 1.0, 
          2.0 * centerY / size.height - 1.0
        ),
        radius: 0.8,
        colors: [
          Color(0xFF368983).withOpacity(0.2),
          Color(0xFF368983).withOpacity(0.0),
        ],
        stops: [0.0, 1.0],
      ).createShader(rect);
    
    canvas.drawRect(rect, gradientPaint);
  }
  
  @override
  bool shouldRepaint(BackgroundPainter oldDelegate) => 
      oldDelegate.progress != progress;
}

// Pintor para las partículas flotantes
class ParticlesPainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;
  
  ParticlesPainter({required this.particles, required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    // Actualiza y dibuja cada partícula
    for (var particle in particles) {
      particle.update(progress);
      
      final Paint paint = Paint()
        ..color = Color(0xFF368983).withOpacity(particle.opacity);
      
      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        particle.size,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(ParticlesPainter oldDelegate) => true;
}
