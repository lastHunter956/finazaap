import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finazaap/Screens/add.dart';
import 'package:finazaap/Screens/add_expense.dart';
import 'package:finazaap/Screens/transfer.dart';
import 'package:finazaap/themes/app_colors.dart';
import 'package:finazaap/themes/app_sizes.dart';
import 'package:finazaap/themes/app_theme_data.dart';

class FloatingActionMenuScreen extends StatefulWidget {
  const FloatingActionMenuScreen({super.key});

  @override
  State<FloatingActionMenuScreen> createState() =>
      _FloatingActionMenuScreenState();
}

class _FloatingActionMenuScreenState extends State<FloatingActionMenuScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  // Indicador de cuál elemento está siendo presionado
  int? _hoveredIndex;
  bool _hasStartedAnimation = false;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasStartedAnimation) {
      _hasStartedAnimation = true;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _animatedDismiss();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Scrim limpio sin BackdropFilter para mantener 60fps estables
            FadeTransition(
              opacity: _fadeAnimation,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _animatedDismiss,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.45),
                ),
              ),
            ),

            // Hoja flotante anclada en zona del pulgar (bottom sheet ergonómico)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 420),
                        decoration: BoxDecoration(
                          color: t.secondaryCardBackground,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.36 : 0.12,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: t.borderVisible,
                            width: 1.2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Drag handle superior (36x4) y encabezado
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  10,
                                  20,
                                  16,
                                ),
                                decoration: BoxDecoration(
                                  color: t.cardBackground,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: t.borderVisible,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 4,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: t.borderVisible,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: t.accent
                                                .withValues(alpha: 0.16),
                                            borderRadius: BorderRadius.circular(
                                              AppSizes.borderRadiusMedium,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.add_rounded,
                                            color: AppColors.getReadableColor(
                                              t.accent,
                                              context,
                                            ),
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 15),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Nueva Operación",
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: t.textPrimary,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                              Text(
                                                "Selecciona una opción",
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: t.textSecondary,
                                                  fontSize: 12,
                                                  letterSpacing: 0.1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Opciones con animación secuencial rápida
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 20,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildAnimatedItem(
                                      delay: 0.05,
                                      child: _buildActionItem(
                                        context: context,
                                        index: 0,
                                        icon: Icons.arrow_upward_rounded,
                                        label: 'Ingreso',
                                        color: AppColors.getReadableColor(
                                          t.income,
                                          context,
                                        ),
                                        onTap: () =>
                                            _navigateTo(const Add_Screen()),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildAnimatedItem(
                                      delay: 0.12,
                                      child: _buildActionItem(
                                        context: context,
                                        index: 1,
                                        icon: Icons.sync_alt_rounded,
                                        label: 'Transferencia',
                                        color: AppColors.getReadableColor(
                                          t.secondaryAccent,
                                          context,
                                        ),
                                        onTap: () =>
                                            _navigateTo(const TransferScreen()),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildAnimatedItem(
                                      delay: 0.19,
                                      child: _buildActionItem(
                                        context: context,
                                        index: 2,
                                        icon: Icons.arrow_downward_rounded,
                                        label: 'Egreso',
                                        color: AppColors.getReadableColor(
                                          t.expense,
                                          context,
                                        ),
                                        onTap: () => _navigateTo(
                                          const AddExpenseScreen(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Botón para cerrar
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: t.darkBackground,
                                  border: Border(
                                    top: BorderSide(
                                      color: t.borderVisible,
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
                                                color: t.textSecondary,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  'Cerrar',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: t.textSecondary,
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

  // Método para crear una animación de elemento con retraso corto
  Widget _buildAnimatedItem({
    required double delay,
    required Widget child,
  }) {
    final Animation<double> animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay,
        (delay + 0.55).clamp(0.0, 1.0).toDouble(),
        curve: Curves.easeOutCubic,
      ),
    );

    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 10 * (1 - animation.value)),
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
    // Crear contenedor con efectos de estado
    return MoneoPressableScale(
      pressedScale: 0.98,
      child: StatefulBuilder(
        builder: (context, setState) {
          final bool isHovered = _hoveredIndex == index;
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
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(AppSizes.borderRadiusLarge),
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
                          color:
                              color.withValues(alpha: isHovered ? 0.2 : 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: color,
                            fontWeight:
                                isHovered ? FontWeight.bold : FontWeight.normal,
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
                            fontWeight:
                                isHovered ? FontWeight.w700 : FontWeight.w600,
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
                          color: isHovered
                              ? color
                              : context.appTheme.textSecondary,
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
      ),
    );
  }

  // Método para manejar la navegación con animación
  void _navigateTo(Widget screen) async {
    HapticFeedback.mediumImpact();

    await _animatedDismiss();

    if (mounted) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => screen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 240),
        ),
      );
    }
  }

  // Método para animar la salida del menú
  Future<void> _animatedDismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;

    if (!MediaQuery.disableAnimationsOf(context)) {
      await _controller.reverse();
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}