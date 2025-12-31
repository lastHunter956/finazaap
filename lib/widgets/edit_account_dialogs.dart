import 'package:flutter/material.dart';
import 'package:finazaap/utils/alert_helper.dart';
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
  // TextEditingController subtitleController = TextEditingController(text: item.subtitle); // Removed
  TextEditingController balanceController = TextEditingController(text: item.balance);
  
  // Initialize Credit Card controllers
  TextEditingController cutoffController = TextEditingController(text: item.cutoffDay?.toString() ?? '');
  TextEditingController paymentController = TextEditingController(text: item.paymentDay?.toString() ?? '');
  TextEditingController interestController = TextEditingController(text: item.interestRate?.toString() ?? '');

  Color iconColor = item.iconColor;
  bool includeInTotal = item.includeInTotal;

  // Lista predefinida de tipos de cuenta
  final List<String> accountTypes = [
    "Cuenta de Ahorros",
    "Cuenta Corriente",
    "Cuenta Nómina",
    "Cuenta Digital/Online",
    "Cuenta Joven/Infantil",
    "Cuenta a Plazo Fijo",
    "Cuenta AFC (Ahorro para la Vivienda)",
    "Tarjeta de Débito",
    "Tarjeta de Crédito"
  ];

  // Try to find the existing type in the list, otherwise default to first.
  String selectedAccountType = accountTypes.contains(item.subtitle)
      ? item.subtitle
      : accountTypes[0];


  return showDialog<dynamic>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          
          bool isCreditCard = selectedAccountType == "Tarjeta de Crédito";

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
                      // Header con gradiente (Fijo arriba)
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
                            Expanded(
                              child: Column(
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
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Cuerpo con Scroll
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          physics: const BouncingScrollPhysics(),
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

                              // Saldo y Tipo de cuenta
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            buildInputLabel(isCreditCard ? 'Cupo total' : 'Saldo actual'),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1A1F2B).withOpacity(0.9),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: iconColor.withOpacity(0.2)),
                                              ),
                                              child: TextField(
                                                controller: balanceController,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                                decoration: InputDecoration(
                                                  hintText: '0.00',
                                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                                                  border: InputBorder.none,
                                                  prefixIcon: Icon(isCreditCard ? Icons.credit_card : Icons.monetization_on_outlined, color: iconColor, size: 20),
                                                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                                                  suffixText: '\$',
                                                  suffixStyle: TextStyle(color: iconColor, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            buildInputLabel('Tipo'),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1A1F2B).withOpacity(0.9),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: iconColor.withOpacity(0.2)),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: selectedAccountType,
                                                  isExpanded: true,
                                                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: iconColor.withOpacity(0.7), size: 20),
                                                  dropdownColor: const Color(0xFF2A3143),
                                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                                  items: accountTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                                                  onChanged: (v) => v != null ? setState(() => selectedAccountType = v) : null,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              ),

                              if (isCreditCard) ...[
                                const SizedBox(height: 16),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        SizedBox(
                                          width: (constraints.maxWidth - 24) / 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              buildInputLabel('Corte'),
                                              _buildSmallInput(cutoffController, '1-31', Icons.calendar_today, iconColor),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: (constraints.maxWidth - 24) / 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              buildInputLabel('Pago'),
                                              _buildSmallInput(paymentController, '1-31', Icons.payment, iconColor),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: (constraints.maxWidth - 24) / 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              buildInputLabel('% Mes'),
                                              _buildSmallInput(interestController, '2.5', Icons.percent, iconColor),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                ),
                              ],

                              const SizedBox(height: 16),
                              buildInputLabel('Personalización'),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  // Selector de icono
                                  SizedBox(
                                    width: 150,
                                    child: InkWell(
                                      onTap: () async {
                                        IconData? icon = await showIconPickerDialog(context, iconColor);
                                        if (icon != null) setState(() => selectedIcon = icon);
                                      },
                                      child: buildInputField(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                          child: Row(
                                            children: [
                                              Icon(selectedIcon, color: iconColor, size: 20),
                                              const SizedBox(width: 8),
                                              const Text('Icono', style: TextStyle(color: Colors.white, fontSize: 14)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Selector de color
                                  SizedBox(
                                    width: 150,
                                    child: InkWell(
                                      onTap: () async {
                                        Color? pickedColor = await showColorPickerDialog(context, iconColor);
                                        if (pickedColor != null) setState(() => iconColor = pickedColor);
                                      },
                                      child: buildInputField(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text('Color', style: TextStyle(color: Colors.white, fontSize: 14)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),
                              // Switch de Incluir en Total
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1F2B).withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: includeInTotal ? iconColor.withOpacity(0.3) : Colors.white.withOpacity(0.08)),
                                ),
                                child: SwitchListTile(
                                  value: includeInTotal,
                                  onChanged: (v) => setState(() => includeInTotal = v),
                                  activeColor: iconColor,
                                  title: const Text('Incluir en saldo total', style: TextStyle(color: Colors.white, fontSize: 14)),
                                  subtitle: Text(
                                    includeInTotal ? 'Suma al total general' : 'No afecta al total',
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                  ),
                                  secondary: Icon(includeInTotal ? Icons.visibility : Icons.visibility_off, color: includeInTotal ? iconColor : Colors.white.withOpacity(0.3)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Botones de acción (Fijos abajo)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  foregroundColor: Colors.white70,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: iconColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  if (titleController.text.isNotEmpty) {
                                    Navigator.of(context).pop(AccountItem(
                                      id: item.id,
                                      icon: selectedIcon,
                                      title: titleController.text,
                                      subtitle: selectedAccountType,
                                      balance: balanceController.text.isEmpty ? "0" : balanceController.text,
                                      iconColor: iconColor,
                                      includeInTotal: includeInTotal,
                                      creditLimit: isCreditCard ? balanceController.text : null,
                                      cutoffDay: isCreditCard && cutoffController.text.isNotEmpty ? int.tryParse(cutoffController.text) : null,
                                      paymentDay: isCreditCard && paymentController.text.isNotEmpty ? int.tryParse(paymentController.text) : null,
                                      interestRate: isCreditCard && interestController.text.isNotEmpty ? double.tryParse(interestController.text) : null,
                                    ));
                                  } else {
                                    AlertHelper.warning(context, 'Ingresa un nombre');
                                  }
                                },
                                child: const Text('Guardar Cambios', style: TextStyle(fontWeight: FontWeight.bold)),
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
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w600,
        fontSize: 13,
        letterSpacing: 0.5,
      ),
    ),
  );
}

Widget _buildSmallInput(TextEditingController controller, String hint, IconData icon, Color color) {
  return Container(
    height: 48,
    decoration: BoxDecoration(
      color: const Color(0xFF1A1F2B).withOpacity(0.9),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
        border: InputBorder.none,
        prefixIcon: Icon(icon, color: color.withOpacity(0.7), size: 16),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );
}