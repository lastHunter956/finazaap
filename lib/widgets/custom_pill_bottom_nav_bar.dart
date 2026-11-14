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
    final isDiurno = context.isDiurno;

    return SafeArea(
      top: false,
      child: LiquidGlassSurface(
        height: isDiurno ? 62 : 60,
        margin: EdgeInsets.only(
          bottom: isDiurno ? 12 : 10,
          left: isDiurno ? 14 : 10,
          right: isDiurno ? 14 : 10,
          top: isDiurno ? 6 : 10,
        ),
        borderRadius: BorderRadius.circular(35),
        blurSigma: 22.0,
        fallbackColor: context.appTheme.cardBackground,
        fallbackBorderColor: context.appTheme.borderSubtle,
        fallbackBoxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.3),
            blurRadius: isLight ? 18 : 15,
            offset: const Offset(0, 5),
          ),
        ],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = selectedIndex == index;
            final unselectedColor =
                isDiurno ? context.appTheme.textSecondary : context.appTheme.textHint;
            final selectedIconColor =
                isDiurno ? context.appTheme.accent : context.appTheme.textPrimary;

            return GestureDetector(
              onTap: () => onItemSelected(index),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutQuint,
                width: isSelected ? 112 : 50,
                height: 48,
                decoration: BoxDecoration(
                  color: !isSelected
                      ? Colors.transparent
                      : isDiurno
                          ? null
                          : context.appTheme.primaryBackground,
                  gradient: isSelected && isDiurno
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.96),
                            const Color(0xFFEAF2FF),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(24),
                  border: isSelected && isDiurno
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.95),
                          width: 1.2,
                        )
                      : null,
                  boxShadow: isSelected && isDiurno
                      ? const [
                          BoxShadow(
                            color: Color(0x1F0062CC),
                            blurRadius: 12,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
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
                                ? selectedIconColor
                                : unselectedColor,
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
                            ? selectedIconColor
                            : unselectedColor,
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
