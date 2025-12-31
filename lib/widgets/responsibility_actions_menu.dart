import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class ResponsibilityActionsMenu extends StatefulWidget {
  final VoidCallback onAddResponsibility;
  final VoidCallback onPlanIncome;

  const ResponsibilityActionsMenu({
    Key? key,
    required this.onAddResponsibility,
    required this.onPlanIncome,
  }) : super(key: key);

  @override
  State<ResponsibilityActionsMenu> createState() => _ResponsibilityActionsMenuState();
}

class _ResponsibilityActionsMenuState extends State<ResponsibilityActionsMenu> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic),
    );
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _animatedDismiss() async {
    await _controller.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleOption(VoidCallback callback) async {
    HapticFeedback.mediumImpact();
    await _animatedDismiss();
    callback();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final menuWidth = screenWidth < 400 ? screenWidth * 0.85 : 320.0;
    
    const primaryColor = Color(0xFF3B82F6);
    const secondaryColor = Color(0xFF10B981);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WillPopScope(
        onWillPop: () async {
          await _animatedDismiss();
          return true;
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Backdrop
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: GestureDetector(
                    onTap: _animatedDismiss,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 12.0 * _fadeAnimation.value,
                        sigmaY: 12.0 * _fadeAnimation.value,
                      ),
                      child: Container(
                        color: const Color(0xFF1F2639).withOpacity(0.85 * _fadeAnimation.value),
                      ),
                    ),
                  ),
                );
              },
            ),
            
            // Menu
            Center(
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _scaleAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: menuWidth,
                  decoration: BoxDecoration(
                    color: const Color(0xFF222939),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                      BoxShadow(
                        color: primaryColor.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 0),
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1.5,
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF262D43), Color(0xFF1F2538)],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withOpacity(0.08),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.auto_awesome_rounded, color: primaryColor, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Acciones",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "Gestionar responsabilidades",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Options
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildOptionItem(
                              index: 0,
                              icon: Icons.add_task_rounded,
                              label: "Nueva Obligación",
                              subtitle: "Añadir un pago recurrente",
                              color: primaryColor,
                              onTap: () => _handleOption(widget.onAddResponsibility),
                            ),
                            const SizedBox(height: 12),
                            _buildOptionItem(
                              index: 1,
                              icon: Icons.analytics_rounded,
                              label: "Planificar Ingresos",
                              subtitle: "Distribuir presupuesto (50/30/20)",
                              color: secondaryColor,
                              onTap: () => _handleOption(widget.onPlanIncome),
                            ),
                          ],
                        ),
                      ),
                      
                      // Footer
                      InkWell(
                        onTap: _animatedDismiss,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(28),
                              bottomRight: Radius.circular(28),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "Cerrar",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem({
    required int index,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool isHovered = _hoveredIndex == index;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _hoveredIndex = index),
        onTapUp: (_) => setState(() => _hoveredIndex = null),
        onTapCancel: () => setState(() => _hoveredIndex = null),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isHovered ? color.withOpacity(0.12) : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHovered ? color.withOpacity(0.4) : Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isHovered ? color.withOpacity(0.2) : color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isHovered ? color : Colors.white.withOpacity(0.2),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
