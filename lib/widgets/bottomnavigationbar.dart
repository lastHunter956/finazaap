import 'package:flutter/material.dart';
import 'package:finazaap/themes/app_theme_data.dart';

/// Widget placeholder para bottom navigation bar
/// 
/// NOTA: Este archivo fue creado automáticamente para resolver
/// el error de importación. Implementar funcionalidad completa según necesidad.
class BottomNavigationBarWidget extends StatelessWidget {
  const BottomNavigationBarWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.appTheme.cardBackground,
      child: const Center(
        child: Text(
          'Bottom Navigation Bar - Por implementar',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
