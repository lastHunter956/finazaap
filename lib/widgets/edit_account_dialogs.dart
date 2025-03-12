import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:finazaap/icon_lists.dart';
import '../Screens/selecctaccount.dart'; // Para la clase AccountItem
import 'package:finazaap/data/models/account_item.dart'; // Importar la clase compartida
import 'package:finazaap/widgets/account_dialogs.dart';

Future<dynamic> showEditAccountDialog(BuildContext context, AccountItem item) async {
  IconData selectedIcon = item.icon;
  TextEditingController titleController = TextEditingController(text: item.title);
  TextEditingController subtitleController = TextEditingController(text: item.subtitle);
  TextEditingController balanceController = TextEditingController(text: item.balance);
  Color iconColor = item.iconColor;
  bool includeInTotal = item.includeInTotal;

  return showDialog<dynamic>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: const Color(0xFF222939),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                      spreadRadius: -5,
                    ),
                    BoxShadow(
                      color: const Color(0xFF4A80F0).withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 2),
                      spreadRadius: -3,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header con gradiente
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              iconColor.withOpacity(0.15),
                              iconColor.withOpacity(0.05),
                            ],
                          ),
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
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: iconColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: iconColor.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                selectedIcon,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Editar Cuenta',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Formulario
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Título
                            buildInputLabel('Nombre de la cuenta'),
                            buildInputField(
                              child: TextField(
                                controller: titleController,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Ej: Cuenta Principal',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  border: InputBorder.none,
                                  prefixIcon: Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: iconColor.withOpacity(0.8),
                                    size: 20,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Saldo y Tipo de cuenta en la misma fila
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Columna del Saldo
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      buildInputLabel('Saldo actual'),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              const Color(0xFF1A1F2B).withOpacity(0.95),
                                              const Color(0xFF1A1F2B).withOpacity(0.85),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.25),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                              spreadRadius: -2,
                                            ),
                                          ],
                                          border: Border.all(
                                            color: iconColor.withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: TextField(
                                          controller: balanceController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                          ],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Ej: 1000.00',
                                            hintStyle: TextStyle(
                                              color: Colors.white.withOpacity(0.3),
                                              fontSize: 15,
                                              fontWeight: FontWeight.normal,
                                            ),
                                            border: InputBorder.none,
                                            // Icono sin símbolo de peso, solo el icono de moneda
                                            prefixIcon: Padding(
                                              padding: const EdgeInsets.only(left: 14, right: 8),
                                              child: Icon(
                                                Icons.monetization_on_outlined,
                                                color: iconColor,
                                                size: 22,
                                              ),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                                            // Símbolo de peso simplificado sin container
                                            suffixText: '\$',
                                            suffixStyle: TextStyle(
                                              color: iconColor,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                
                                // Columna del Tipo de cuenta
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      buildInputLabel('Tipo'),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              const Color(0xFF1A1F2B).withOpacity(0.95),
                                              const Color(0xFF1A1F2B).withOpacity(0.85),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.25),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                              spreadRadius: -2,
                                            ),
                                          ],
                                          border: Border.all(
                                            color: iconColor.withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: TextField(
                                          controller: subtitleController,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.normal,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Ej: Corriente',
                                            hintStyle: TextStyle(
                                              color: Colors.white.withOpacity(0.3),
                                              fontSize: 15,
                                            ),
                                            border: InputBorder.none,
                                            // Icono simplificado sin container
                                            prefixIcon: Padding(
                                              padding: const EdgeInsets.only(left: 14, right: 8),
                                              child: Icon(
                                                Icons.account_balance_outlined,
                                                color: iconColor,
                                                size: 22,
                                              ),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Selector de icono y color
                            buildInputLabel('Personalización'),
                            Row(
                              children: [
                                // Selector de icono
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      IconData? icon = await showIconPickerDialog(context, iconColor);
                                      if (icon != null) {
                                        setState(() {
                                          selectedIcon = icon;
                                        });
                                      }
                                    },
                                    child: buildInputField(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
                                        child: Row(
                                          children: [
                                            Icon(
                                              selectedIcon,
                                              color: iconColor,
                                              size: 22,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Icono',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.9),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Selector de color
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      Color? pickedColor = await showColorPickerDialog(context, iconColor);
                                      if (pickedColor != null) {
                                        setState(() {
                                          iconColor = pickedColor;
                                        });
                                      }
                                    },
                                    child: buildInputField(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 22,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                color: iconColor,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: iconColor.withOpacity(0.4),
                                                    blurRadius: 4,
                                                    spreadRadius: 0,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Color',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.9),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Opción de incluir en total con diseño refinado
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF1A1F2B).withOpacity(0.95),
                                    const Color(0xFF1A1F2B).withOpacity(0.85),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: includeInTotal ? iconColor.withOpacity(0.25) : Colors.white.withOpacity(0.08),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                leading: Icon(
                                  includeInTotal ? Icons.visibility : Icons.visibility_off,
                                  color: includeInTotal ? iconColor : Colors.white.withOpacity(0.5),
                                  size: 24,
                                ),
                                title: Text(
                                  'Incluir en saldo total',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  includeInTotal ? 'El saldo se sumará al total general' : 'El saldo no afectará al total',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: Switch(
                                  value: includeInTotal,
                                  activeColor: iconColor,
                                  activeTrackColor: iconColor.withOpacity(0.3),
                                  inactiveThumbColor: Colors.grey.shade400,
                                  inactiveTrackColor: Colors.grey.shade800.withOpacity(0.5),
                                  onChanged: (value) {
                                    setState(() {
                                      includeInTotal = value;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Botones de acción
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: Row(
                          children: [
                            // Botón Cancelar
                            Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.black.withOpacity(0.15),
                                  foregroundColor: Colors.white.withOpacity(0.8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.1),
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
                            const SizedBox(width: 16),
                            // Botón Guardar
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: iconColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  if (titleController.text.isNotEmpty) {
                                    Navigator.of(context).pop(AccountItem(
                                      icon: selectedIcon,
                                      title: titleController.text,
                                      subtitle: subtitleController.text,
                                      balance: balanceController.text.isEmpty ? "0" : balanceController.text,
                                      iconColor: iconColor,
                                      includeInTotal: includeInTotal,
                                    ));
                                  } else {
                                    // Mostrar error
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Por favor ingresa un nombre para la cuenta'),
                                        backgroundColor: Colors.red.shade800,
                                        behavior: SnackBarBehavior.floating,
                                        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.check, size: 18),
                                    SizedBox(width: 10),
                                    Text(
                                      'Guardar Cambios',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
    },
  );
}

Widget buildInputLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
    ),
  );
}