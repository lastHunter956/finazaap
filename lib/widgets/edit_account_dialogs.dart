import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:finazaap/utils/alert_helper.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/widgets/account_dialogs.dart';
import 'package:finazaap/themes/theme.dart';
import 'package:finazaap/utils/app_icons.dart';

/// Muestra el diálogo de edición de cuenta asegurando un manejo de estado correcto.
Future<dynamic> showEditAccountDialog(BuildContext context, AccountItem item) async {
  return showDialog<dynamic>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (context) => EditAccountDialog(item: item),
  );
}

class EditAccountDialog extends StatefulWidget {
  final AccountItem item;

  const EditAccountDialog({Key? key, required this.item}) : super(key: key);

  @override
  State<EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends State<EditAccountDialog> {
  late TextEditingController titleController;
  late TextEditingController balanceController;
  
  // Controladores Tarjeta de Crédito
  late TextEditingController cutoffController;
  late TextEditingController paymentController;
  late TextEditingController interestController;

  late IconData selectedIcon;
  late Color iconColor;
  late bool includeInTotal;
  late String selectedAccountType;

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

  // Listas para selección (replicadas de CategoriesScreen)
  final List<IconData> _availableIcons = AppIcons.allIcons;
  final List<Color> _availableColors = const [
    Colors.redAccent, Colors.pinkAccent, Colors.purpleAccent, Colors.deepPurpleAccent,
    Colors.indigoAccent, Colors.blueAccent, Colors.lightBlueAccent, Colors.cyanAccent,
    Colors.tealAccent, Colors.greenAccent, Colors.lightGreenAccent, Colors.limeAccent,
    Colors.yellowAccent, Colors.amberAccent, Colors.orangeAccent, Colors.deepOrangeAccent,
    Colors.blueGrey, Colors.grey,
  ];

  // Scroll Controller
  final ScrollController _scrollController = ScrollController();
  bool _showScrollIndicator = false;

  @override
  void initState() {
    super.initState();
    // Inicializar estado con los valores del item
    titleController = TextEditingController(text: widget.item.title);
    balanceController = TextEditingController(text: widget.item.balance);
    cutoffController = TextEditingController(text: widget.item.cutoffDay?.toString() ?? '');
    paymentController = TextEditingController(text: widget.item.paymentDay?.toString() ?? '');
    interestController = TextEditingController(text: widget.item.interestRate?.toString() ?? '');
    
    selectedIcon = widget.item.icon;
    iconColor = widget.item.iconColor;
    includeInTotal = widget.item.includeInTotal;
    
    // Determinar tipo de cuenta
    selectedAccountType = accountTypes.contains(widget.item.subtitle)
        ? widget.item.subtitle
        : accountTypes[0];

    // Verificar si necesitamos mostrar el indicador de scroll después del layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScroll();
    });
    
    _scrollController.addListener(_checkScroll);
  }

  void _checkScroll() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    
    // Mostrar indicador si hay contenido scrolleable y no estamos al final
    final show = maxScroll > 0 && currentScroll < maxScroll - 20;
    
    if (show != _showScrollIndicator) {
      setState(() {
        _showScrollIndicator = show;
      });
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    balanceController.dispose();
    cutoffController.dispose();
    paymentController.dispose();
    interestController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isCreditCard = selectedAccountType == "Tarjeta de Crédito";

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600), // Aumentado un poco el ancho y alto máximo
          decoration: BoxDecoration(
            color: AppColors.secondaryCardBackground,
            borderRadius: BorderRadius.circular(AppSizes.borderRadius2XLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 25,
                offset: const Offset(0, 10),
                spreadRadius: -5,
              ),
              BoxShadow(
                color: AppColors.secondaryAccent.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 2),
                spreadRadius: -3,
              ),
            ],
            border: Border.all(
              color: AppColors.borderSubtle,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.borderRadius2XLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header (Compacto)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                        color: AppColors.borderSubtle,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              iconColor.withOpacity(0.22),
                              iconColor.withOpacity(0.13),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                              spreadRadius: -2,
                            ),
                          ],
                          border: Border.all(
                            color: iconColor.withOpacity(0.35),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          selectedIcon,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Editar Cuenta',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Cuerpo con Scroll
                Flexible(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSizes.padding2XLarge),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        // Título
                        _buildInputLabel('Nombre de la cuenta'),
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInputLabel(isCreditCard ? 'Cupo total' : 'Saldo actual'),
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
                                  _buildInputLabel('Tipo'),
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
                                        dropdownColor: AppColors.cardBackground,
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
                                        _buildInputLabel('Corte'),
                                        _buildSmallInput(cutoffController, '1-31', Icons.calendar_today, iconColor),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: (constraints.maxWidth - 24) / 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildInputLabel('Pago'),
                                        _buildSmallInput(paymentController, '1-31', Icons.payment, iconColor),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: (constraints.maxWidth - 24) / 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildInputLabel('% Mes'),
                                        _buildSmallInput(interestController, '2.5', Icons.percent, iconColor),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }
                          ),
                        ],
                        
                        const SizedBox(height: 20),
                        Divider(color: Colors.white.withOpacity(0.05)),
                        const SizedBox(height: 16),

                        // --- SELECTORES HORIZONTALES (Color e Icono) ---

                        // Selector de Color
                        _buildSectionHeader('Color'),
                        SizedBox(
                          height: 55,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _availableColors.length,
                            itemBuilder: (context, index) {
                              final color = _availableColors[index];
                              final isSelected = color.value == iconColor.value;
                              return GestureDetector(
                                onTap: () => setState(() => iconColor = color),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 14),
                                  width: isSelected ? 48 : 40,
                                  height: isSelected ? 48 : 40,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
                                    boxShadow: isSelected 
                                      ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 10, spreadRadius: 1)] 
                                      : [],
                                  ),
                                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 24) : null,
                                ),
                              );
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 24),

                        // Selector de Icono
                        _buildSectionHeader('Icono'),
                        SizedBox(
                          height: 60,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _availableIcons.length,
                            itemBuilder: (context, index) {
                              final icon = _availableIcons[index];
                              final isSelected = icon == selectedIcon;
                              return GestureDetector(
                                onTap: () => setState(() => selectedIcon = icon),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 14),
                                  width: 52,
                                  decoration: BoxDecoration(
                                    color: isSelected ? iconColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected ? iconColor : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    icon,
                                    color: isSelected ? iconColor : Colors.white.withOpacity(0.5),
                                    size: 26,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 24),
                        
                        // Switch (ahora con divider antes)
                        // Switch de Incluir en Total
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1F2B).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: includeInTotal ? iconColor.withOpacity(0.3) : AppColors.borderSubtle),
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
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      opacity: _showScrollIndicator ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: IgnorePointer(
                        ignoring: !_showScrollIndicator,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppSizes.borderRadius2XLarge)),
                          ),
                          alignment: Alignment.bottomCenter,
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Desliza para ver más",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 10,
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white.withOpacity(0.6),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

                // Botones de acción
                Container(
                  padding: const EdgeInsets.all(AppSizes.padding2XLarge),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.borderSubtle)),
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
                                id: widget.item.id,
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
  }

  Widget _buildInputLabel(String text) {
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildInputLabel(title),
          Padding(
            padding: const EdgeInsets.only(bottom: 6, right: 4),
            child: Text(
              'Desplázate para ver más >>',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
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
}