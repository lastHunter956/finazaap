import 'package:flutter/material.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/features/notifications/services/notification_pipeline_service.dart';

class CustomPillBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const CustomPillBottomNavBar({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    
    // Lista de ítems de navegación
    final List<NavItem> items = [
      NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Inicio'),
      NavItem(icon: Icons.credit_card_outlined, activeIcon: Icons.credit_card_rounded, label: 'Pagos'), 
      NavItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'Categorías'), // Explore/Categories
      NavItem(icon: Icons.insert_chart_outlined_rounded, activeIcon: Icons.insert_chart_rounded, label: 'Reportes'), // Stats
      NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Ajustes'), 
    ];

    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      margin: const EdgeInsets.only(bottom: 10, left: 10, right: 10, top: 10),
      height: 60, // Altura del contenedor total
      decoration: BoxDecoration(
        color: context.appTheme.cardBackground,
        borderRadius: BorderRadius.circular(35), // Pill shape extremo
        border: Border.all(
          color: context.appTheme.borderSubtle,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.3),
            blurRadius: isLight ? 18 : 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = selectedIndex == index;
          
          return GestureDetector(
            onTap: () => onItemSelected(index),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuint,
              width: isSelected ? 110 : 50, // Expandir si está seleccionado
              height: 50,
              decoration: BoxDecoration(
                color: isSelected
                    ? context.appTheme.primaryBackground
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icono (con badge en Ajustes si hay notificaciones pendientes)
                  if (index == 4)
                    ListenableBuilder(
                      listenable:
                          NotificationPipelineService.instance.pendingNotifier,
                      builder: (context, _) {
                        final count = NotificationPipelineService
                            .instance.pendingNotifier.count;
                        final iconWidget = Icon(
                          isSelected ? item.activeIcon : item.icon,
                          color: isSelected
                              ? context.appTheme.textPrimary
                              : context.appTheme.textHint,
                          size: 24,
                        );
                        if (count <= 0) return iconWidget;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            iconWidget,
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                key: const Key('nav_settings_pending_dot'),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: context.appTheme.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  else
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: isSelected
                          ? context.appTheme.textPrimary
                          : context.appTheme.textHint,
                      size: 24,
                    ),
                  
                  // Texto (solo visible si está seleccionado)
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: context.appTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ]
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
