import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finazaap/Screens/add.dart';
import 'package:finazaap/Screens/add_expense.dart';
import 'package:finazaap/Screens/transfer.dart';
import 'package:finazaap/themes/app_colors.dart';
import 'package:finazaap/themes/app_sizes.dart';
import 'package:finazaap/themes/app_theme_data.dart';

class FloatingActionMenuScreen extends StatefulWidget {
  const FloatingActionMenuScreen({Key? key}) : super(key: key);

  @override
  State<FloatingActionMenuScreen> createState() => _FloatingActionMenuScreenState();
}

class _FloatingActionMenuScreenState extends State<FloatingActionMenuScreen> with SingleTickerProviderStateMixin {
  // Controlador para animaciones
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Indicador de cuál elemento está siendo seleccionado
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    
    // Reducir duración de animación principal (de 600ms a 350ms)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350), // Más rápido
    );
    
    // Animaciones más rápidas para entrada del menú
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack), // Curva más suave
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.8, curve: Curves.easeOut),
    );
    
    // Iniciar la animación automáticamente
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tamaños de pantalla para diseño responsivo
    final screenWidth = MediaQuery.of(context).size.width;
    final menuWidth = screenWidth < 400 ? screenWidth * 0.85 : 320.0;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
             // Animar la salida al presionar el botón de regreso
            await _animatedDismiss();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Backdrop con blur estático y transición de opacidad sin recomputar shader por frame
            FadeTransition(
              opacity: _fadeAnimation,
              child: GestureDetector(
                onTap: _animatedDismiss,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                  child: Container(
                    color: context.appTheme.primaryBackground.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
            
            // Menú centrado con animaciones
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Container(
                        width: double.infinity,
                        constraints: BoxConstraints(maxWidth: menuWidth),
                        decoration: BoxDecoration(
                          color: context.appTheme.secondaryCardBackground,
                          borderRadius: BorderRadius.circular(
                            AppSizes.borderRadius2XLarge,
                          ),
                          boxShadow:
                              Theme.of(context).brightness == Brightness.light
                                  ? [
                                      BoxShadow(
                                        color: context.appTheme.textPrimary
                                            .withValues(alpha: 0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                          border: Border.all(
                            color: context.appTheme.borderVisible,
                            width: 1.2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppSizes.borderRadius2XLarge,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Encabezado
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: context.appTheme.cardBackground,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: context.appTheme.borderVisible,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: context.appTheme.accent
                                            .withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(
                                          AppSizes.borderRadiusMedium,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.add_rounded,
                                        color: AppColors.getReadableColor(
                                          context.appTheme.accent,
                                          context,
                                        ),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    // Texto con sombra sutil
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Nueva Operación",
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: context.appTheme.textPrimary,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          Text(
                                            "Selecciona una opción",
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: context.appTheme.textSecondary,
                                              fontSize: 12,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Opciones con animación secuencial
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                child: AnimatedBuilder(
                                  animation: _fadeAnimation,
                                  builder: (context, child) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Ingreso con retraso mínimo
                                        _buildAnimatedItem(
                                          index: 0,
                                          delay: 0.1, // Antes 0.3
                                          child: _buildActionItem(
                                            context: context,
                                            index: 0,
                                            icon: Icons.arrow_upward_rounded,
                                            label: 'Ingreso',
                                            color: AppColors.getReadableColor(
                                              context.appTheme.income,
                                              context,
                                            ),
                                            onTap: () => _navigateTo(const Add_Screen()),
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 12), // Reducido de 16 a 12
                                        
                                        // Transferencia con retraso mínimo
                                        _buildAnimatedItem(
                                          index: 1,
                                          delay: 0.15, // Antes 0.4
                                          child: _buildActionItem(
                                            context: context,
                                            index: 1,
                                            icon: Icons.sync_alt_rounded,
                                            label: 'Transferencia',
                                            color: AppColors.getReadableColor(
                                              context.appTheme.secondaryAccent,
                                              context,
                                            ),
                                            onTap: () => _navigateTo(const TransferScreen()),
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 12), // Reducido de 16 a 12
                                        
                                        // Egreso con retraso mínimo
                                        _buildAnimatedItem(
                                          index: 2,
                                          delay: 0.2, // Antes 0.5
                                          child: _buildActionItem(
                                            context: context,
                                            index: 2,
                                            icon: Icons.arrow_downward_rounded,
                                            label: 'Egreso',
                                            color: AppColors.getReadableColor(
                                              context.appTheme.expense,
                                              context,
                                            ),
                                            onTap: () => _navigateTo(const AddExpenseScreen()),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              
                              // Botón para cerrar
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: context.appTheme.darkBackground,
                                  border: Border(
                                    top: BorderSide(
                                      color: context.appTheme.borderVisible,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Semantics(
                                  button: true,
                                  label: 'Cerrar menú',
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _animatedDismiss,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minHeight: 48,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.close_rounded,
                                                color: context
                                                    .appTheme.textSecondary,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  'Cerrar',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: context
                                                        .appTheme.textSecondary,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Método para crear una animación de elemento con retraso
  Widget _buildAnimatedItem({
    required int index,
    required double delay,
    required Widget child,
  }) {
    // Crear una animación con retraso más corto
    final Animation<double> animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay, // Retraso reducido
        delay + 0.25, // Durar solo 250ms (antes 400ms)
        curve: Curves.easeOutCubic, // Curva más rápida
      ),
    );

    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 15 * (1 - animation.value)),
            child: child,
          );
        },
        child: child,
      ),
    );
  }

  // Método para crear cada opción del menú con efectos más elegantes
  Widget _buildActionItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    // Determinar si este elemento está siendo seleccionado
    final bool isHovered = _hoveredIndex == index;
    
    // Crear contenedor con efectos de estado
    return StatefulBuilder(
      builder: (context, setState) {
        return Semantics(
  label: label,
  button: true,
  hint: 'Navegar a $label',
  child: GestureDetector(
    onTapDown: (_) {
      setState(() {
        _hoveredIndex = index;
      });
    },
    onTapUp: (_) {
      setState(() {
        _hoveredIndex = null;
      });
    },
    onTapCancel: () {
      setState(() {
        _hoveredIndex = null;
      });
    },
    child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
              color: isHovered
                  ? color.withValues(alpha: 0.12)
                  : context.appTheme.cardBackground,
              border: Border.all(
                color: isHovered
                    ? color.withValues(alpha: 0.55)
                    : context.appTheme.borderVisible,
                width: isHovered ? 1.4 : 1,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Row(
                children: [
                  // Icono animado
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.all(isHovered ? 13 : 12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isHovered ? 0.2 : 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: color,
                        fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: isHovered ? 26 : 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Texto animado
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: context.appTheme.textPrimary,
                        fontSize: isHovered ? 16.5 : 16,
                        fontWeight: isHovered ? FontWeight.w700 : FontWeight.w600,
                        letterSpacing: isHovered ? 0.2 : 0,
                      ),
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Flecha con contraste garantizado
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isHovered
                          ? color.withValues(alpha: 0.15)
                          : context.appTheme.darkBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: isHovered ? color : context.appTheme.textSecondary,
                      size: 14,
                    ),
                  ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Método para manejar la navegación con animación
  void _navigateTo(Widget screen) async {
    // Vibración de feedback
    HapticFeedback.mediumImpact();
    
    // Animar la salida
    await _animatedDismiss();
    
    // Navegar a la pantalla indicada
    if (mounted) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => screen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutQuint,
                  ),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  // Método para animar la salida del menú
  Future<void> _animatedDismiss() async {
    // Animar hacia atrás
    await _controller.reverse();
    
    // Cerrar la pantalla
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}