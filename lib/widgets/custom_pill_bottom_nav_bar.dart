import 'package:flutter/material.dart';

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
      NavItem(icon: Icons.search, activeIcon: Icons.search_rounded, label: 'Buscar'), 
      NavItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'Categorías'), // Explore/Categories
      NavItem(icon: Icons.insert_chart_outlined_rounded, activeIcon: Icons.insert_chart_rounded, label: 'Reportes'), // Stats
      NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Perfil'), 
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10, left: 10, right: 10, top: 10),
      height: 60, // Altura del contenedor total
      decoration: BoxDecoration(
        color: const Color(0xFF2A3143), // Color de fondo del navbar idéntico al fondo de la app
        borderRadius: BorderRadius.circular(35), // Pill shape extremo
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
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
                    ? const Color.fromARGB(255, 31, 38, 57) // Cyan activo
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icono
                  Icon(
                    isSelected ? item.activeIcon : item.icon,
                    color: isSelected 
                        ? const Color.fromARGB(255, 255, 255, 255) // Cyan para icono activo
                        : Colors.white.withOpacity(0.5), // Grey para inactivo
                    size: 24,
                  ),
                  
                  // Texto (solo visible si está seleccionado)
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: Color.fromARGB(255, 255, 255, 255), // Cyan para texto activo
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
