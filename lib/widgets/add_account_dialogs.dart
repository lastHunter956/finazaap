import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/widgets/account_dialogs.dart';

/// Diálogo para agregar una nueva cuenta
Future<AccountItem?> showAddAccountDialog(BuildContext context) async {
  IconData selectedIcon = Icons.account_balance_wallet;
  TextEditingController titleController = TextEditingController();
  TextEditingController subtitleController = TextEditingController();
  TextEditingController balanceController = TextEditingController();
  Color iconColor = const Color(0xFF3D7AF0);
  bool includeInTotal = true;

  return showDialog<AccountItem>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: const Color(0xFF222939),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                      spreadRadius: -8,
                    ),
                    BoxShadow(
                      color: iconColor.withOpacity(0.25),
                      blurRadius: 25,
                      offset: const Offset(0, 5),
                      spreadRadius: -10,
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
                      // Header con gradiente y animación suave
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              iconColor.withOpacity(0.18),
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
                            // Icono animado
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: iconColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: iconColor.withOpacity(0.5),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                    spreadRadius: -3,
                                  ),
                                ],
                              ),
                              child: Icon(
                                selectedIcon,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Nueva Cuenta',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Agrega fondos a tu plan financiero',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Formulario optimizado
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
                                    color: iconColor.withOpacity(0.7),
                                    size: 20,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Fila con tipo de cuenta y saldo
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tipo de cuenta (izquierda)
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      buildInputLabel('Tipo de cuenta'),
                                      buildInputField(
                                        child: TextField(
                                          controller: subtitleController,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Ej: Ahorros',
                                            hintStyle: TextStyle(
                                              color: Colors.white.withOpacity(0.3),
                                            ),
                                            border: InputBorder.none,
                                            prefixIcon: Icon(
                                              Icons.category_outlined,
                                              color: iconColor.withOpacity(0.7),
                                              size: 20,
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(width: 16),
                                
                                // Saldo (derecha)
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      buildInputLabel('Saldo inicial'),
                                      buildInputField(
                                        child: TextField(
                                          controller: balanceController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                          ],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: '0.00',
                                            hintStyle: TextStyle(
                                              color: Colors.white.withOpacity(0.3),
                                            ),
                                            border: InputBorder.none,
                                            prefixIcon: Icon(
                                              Icons.monetization_on_outlined,
                                              color: iconColor.withOpacity(0.7),
                                              size: 20,
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Personalización
                            buildInputLabel('Personalización'),
                            Row(
                              children: [
                                // Selector de icono
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    splashColor: iconColor.withOpacity(0.1),
                                    highlightColor: iconColor.withOpacity(0.05),
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
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: iconColor.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                selectedIcon,
                                                color: iconColor,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'Icono',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.7),
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Icon(
                                              Icons.arrow_forward_ios,
                                              color: Colors.white.withOpacity(0.4),
                                              size: 14,
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
                                    borderRadius: BorderRadius.circular(12),
                                    splashColor: iconColor.withOpacity(0.1),
                                    highlightColor: iconColor.withOpacity(0.05),
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
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: iconColor,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: iconColor.withOpacity(0.3),
                                                    blurRadius: 8,
                                                    spreadRadius: -2,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'Color',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.7),
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Icon(
                                              Icons.arrow_forward_ios,
                                              color: Colors.white.withOpacity(0.4),
                                              size: 14,
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

                            // Opción de incluir en total
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1F2B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                  width: 1,
                                ),
                              ),
                              child: CheckboxListTile(
                                title: const Text(
                                  'Incluir en saldo total',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  'La cuenta formará parte del saldo global',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12,
                                  ),
                                ),
                                value: includeInTotal,
                                activeColor: iconColor,
                                checkColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                onChanged: (bool? value) {
                                  setState(() {
                                    includeInTotal = value ?? true;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Botones de acción
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Row(
                          children: [
                            // Botón Cancelar
                            Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white70,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text(
                                  'Cancelar',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Botón Agregar
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: iconColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  if (titleController.text.isNotEmpty &&
                                      subtitleController.text.isNotEmpty &&
                                      balanceController.text.isNotEmpty) {
                                    Navigator.of(context).pop(AccountItem(
                                      icon: selectedIcon,
                                      title: titleController.text,
                                      subtitle: subtitleController.text,
                                      balance: balanceController.text,
                                      iconColor: iconColor,
                                      includeInTotal: includeInTotal,
                                    ));
                                  } else {
                                    // Feedback visual para campos vacíos
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Por favor completa todos los campos'),
                                        backgroundColor: Colors.redAccent.shade400,
                                        behavior: SnackBarBehavior.floating,
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
                                    Icon(Icons.add_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Crear Cuenta',
                                      style: TextStyle(fontWeight: FontWeight.w600),
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