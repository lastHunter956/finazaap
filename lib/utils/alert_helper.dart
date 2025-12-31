import 'package:flutter/material.dart';

/// Tipos de alerta disponibles
enum AlertType { success, error, warning, info }

class AlertHelper {
  /// Muestra una alerta profesional y estilizada
  static void show(
    BuildContext context, {
    required String message,
    AlertType type = AlertType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Configuración según el tipo
    Color backgroundColor;
    Color accentColor;
    IconData icon;
    
    switch (type) {
      case AlertType.success:
        backgroundColor = const Color(0xFF1E293B);
        accentColor = const Color(0xFF10B981);
        icon = Icons.check_circle_rounded;
        break;
      case AlertType.error:
        backgroundColor = const Color(0xFF1E293B);
        accentColor = const Color(0xFFEF4444);
        icon = Icons.error_rounded;
        break;
      case AlertType.warning:
        backgroundColor = const Color(0xFF1E293B);
        accentColor = const Color(0xFFF59E0B);
        icon = Icons.warning_rounded;
        break;
      case AlertType.info:
        backgroundColor = const Color(0xFF1E293B);
        accentColor = const Color(0xFF3B82F6);
        icon = Icons.info_rounded;
        break;
    }

    // Limpiar snackbars previos
    scaffoldMessenger.removeCurrentSnackBar();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: accentColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.all(16),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  // Métodos de conveniencia
  static void success(BuildContext context, String message) {
    show(context, message: message, type: AlertType.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message: message, type: AlertType.error);
  }

  static void warning(BuildContext context, String message) {
    show(context, message: message, type: AlertType.warning);
  }

  static void info(BuildContext context, String message) {
    show(context, message: message, type: AlertType.info);
  }
}
