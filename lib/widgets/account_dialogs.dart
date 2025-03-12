import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:ui';
import 'package:finazaap/icon_lists.dart';

// Método helper para etiquetas de campos
Widget buildInputLabel(String label) {
  return Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      label,
      style: TextStyle(
        color: Colors.white.withOpacity(0.7),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

// Método helper para campos de entrada
Widget buildInputField({required Widget child}) {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFF1A1F2B),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.white.withOpacity(0.08),
        width: 1,
      ),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: child,
  );
}

/// Selector de iconos mejorado
Future<IconData?> showIconPickerDialog(BuildContext context, Color accentColor) async {
  return showDialog<IconData>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (BuildContext context) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 500),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2B),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: -5,
                ),
                BoxShadow(
                  color: accentColor.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 2),
                  spreadRadius: -8,
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.category_outlined,
                          color: accentColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Seleccionar Icono',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Grid de iconos
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var iconData in accountIcons)
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.of(context).pop(iconData);
                            },
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFF222939),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                  width: 1.0,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  iconData,
                                  color: accentColor,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Botón cerrar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                  ),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Selector de colores mejorado
Future<Color?> showColorPickerDialog(BuildContext context, Color currentColor) async {
  Color tempColor = currentColor;
  return showDialog<Color>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (BuildContext context) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2B),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
                BoxShadow(
                  color: tempColor.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                  spreadRadius: -8,
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título con vista previa del color
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: tempColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: tempColor.withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: -4,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Elige un color',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Personaliza tu cuenta',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Paleta de colores
                    BlockPicker(
                      pickerColor: tempColor,
                      onColorChanged: (color) {
                        setState(() {
                          tempColor = color;
                        });
                      },
                      availableColors: const [
                        Color(0xFFE53935), // Rojo
                        Color(0xFFD81B60), // Rosa
                        Color(0xFF8E24AA), // Púrpura
                        Color(0xFF5E35B1), // Púrpura profundo
                        Color(0xFF3949AB), // Índigo
                        Color(0xFF1E88E5), // Azul
                        Color(0xFF039BE5), // Azul claro
                        Color(0xFF00ACC1), // Cian
                        Color(0xFF00897B), // Verde azulado
                        Color(0xFF43A047), // Verde
                        Color(0xFF7CB342), // Verde claro
                        Color(0xFFC0CA33), // Lima
                        Color(0xFFFDD835), // Amarillo
                        Color(0xFFFFB300), // Ámbar
                        Color(0xFFFB8C00), // Naranja
                        Color(0xFFF4511E), // Naranja profundo
                        Color(0xFF6D4C41), // Marrón
                        Color(0xFF757575), // Gris
                        Color(0xFF546E7A), // Azul grisáceo
                        Color(0xFF37474F), // Negro azulado
                      ],
                      itemBuilder: (color, isCurrentColor, changeColor) {
                        return Container(
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                spreadRadius: -2,
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              )
                            ],
                            border: isCurrentColor
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: changeColor,
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 210),
                                opacity: isCurrentColor ? 1 : 0,
                                child: const Center(
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Botones de acción
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Botón de cancelar
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Botón de selección
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(tempColor),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tempColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.check_rounded, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Aplicar',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}