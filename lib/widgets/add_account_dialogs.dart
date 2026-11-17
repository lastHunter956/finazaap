import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:finazaap/utils/alert_helper.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/widgets/account_dialogs.dart';
import 'package:finazaap/themes/theme.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/widgets/moneo_appearance_pickers_row.dart';

Future<AccountItem?> showAddAccountDialog(BuildContext context) async {
  return showDialog<AccountItem>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (context) => const AddAccountDialog(),
  );
}

class AddAccountDialog extends StatefulWidget {
  const AddAccountDialog({Key? key}) : super(key: key);

  @override
  State<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<AddAccountDialog> {
  // Controladores
  final TextEditingController titleController = TextEditingController();
  final TextEditingController balanceController = TextEditingController();
  final TextEditingController cutoffController = TextEditingController();
  final TextEditingController paymentController = TextEditingController();
  final TextEditingController interestController = TextEditingController();

  // Estado
  IconData selectedIcon = Icons.account_balance_wallet;
  Color iconColor = const Color(0xFF3D7AF0); // Azul por defecto
  bool includeInTotal = true;
  
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
  late String selectedAccountType;

  // Scroll Controller
  final ScrollController _scrollController = ScrollController();
  bool _showScrollIndicator = false;

  @override
  void initState() {
    super.initState();
    selectedAccountType = accountTypes[0];

    // Verificar scroll post-layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScroll();
    });
    _scrollController.addListener(_checkScroll);
  }

  void _checkScroll() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    
    // Mostrar si hay más contenido abajo
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
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 450, maxHeight: 650),
          decoration: BoxDecoration(
            color: context.appTheme.secondaryCardBackground,
            borderRadius: BorderRadius.circular(AppSizes.borderRadius2XLarge),
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
              color: context.appTheme.borderSubtle,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.borderRadius2XLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.light
                        ? AppColors.getReadableColor(iconColor, context).withOpacity(0.08)
                        : null,
                    gradient: Theme.of(context).brightness == Brightness.light
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              iconColor.withOpacity(0.18),
                              iconColor.withOpacity(0.05),
                            ],
                          ),
                    border: Border(
                      bottom: BorderSide(
                        color: context.appTheme.borderSubtle,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.light
                              ? AppColors.getReadableColor(iconColor, context)
                              : null,
                          gradient: Theme.of(context).brightness == Brightness.light
                              ? null
                              : LinearGradient(
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
                              color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.light ? 0.12 : 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                              spreadRadius: -2,
                            ),
                          ],
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.light
                                ? AppColors.getReadableColor(iconColor, context)
                                : iconColor.withOpacity(0.35),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          selectedIcon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nueva Cuenta',
                              style: TextStyle(
                                color: context.appTheme.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Define los detalles',
                              style: TextStyle(
                                color: context.appTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Cuerpo Scrollable con Indicador
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
                              context: context,
                              child: TextField(
                                controller: titleController,
                                style: TextStyle(
                                  color: context.appTheme.textPrimary,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Ej: Cuenta Principal',
                                  hintStyle: TextStyle(
                                    color: context.appTheme.textHint,
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
        
                            // Tipo de cuenta en su propia fila
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('Tipo de cuenta'),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: context.appTheme.darkBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(context).brightness == Brightness.light
                                          ? context.appTheme.borderSubtle
                                          : Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedAccountType,
                                      isExpanded: true,
                                      icon: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: iconColor.withOpacity(0.7),
                                      ),
                                      dropdownColor: AppColors.cardBackground,
                                      style: TextStyle(
                                        color: context.appTheme.textPrimary,
                                        fontSize: 13,
                                      ),
                                      items: accountTypes.map((String type) {
                                        return DropdownMenuItem<String>(
                                          value: type,
                                          child: Text(
                                            type,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            selectedAccountType = newValue;
                                            if (newValue == "Tarjeta de Crédito") {
                                              includeInTotal = false;
                                            }
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Saldo inicial / Cupo total en su propia fila con ancho completo
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel(isCreditCard ? 'Cupo total' : 'Saldo inicial'),
                                buildInputField(
                                  context: context,
                                  child: TextField(
                                    controller: balanceController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      ThousandsSeparatorInputFormatter(),
                                    ],
                                    style: TextStyle(
                                      color: context.appTheme.textPrimary,
                                      fontSize: 15,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '0.00',
                                      hintStyle: TextStyle(
                                        color: context.appTheme.textHint,
                                      ),
                                      border: InputBorder.none,
                                      prefixIcon: Icon(
                                        isCreditCard ? Icons.credit_card : Icons.monetization_on_outlined,
                                        color: iconColor.withOpacity(0.7),
                                        size: 20,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            // Logic SPECIFIC for Credit Card
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
                            Divider(color: context.appTheme.darkBackground),
                            const SizedBox(height: 16),
        
                            // --- SELECTORES DE APARIENCIA (Color e Ícono) ---
                            _buildInputLabel('Apariencia'),
                            MoneoAppearancePickersRow(
                              selectedColor: iconColor,
                              selectedIcon: selectedIcon,
                              onColorChanged: (color) =>
                                  setState(() => iconColor = color),
                              onIconChanged: (icon) =>
                                  setState(() => selectedIcon = icon),
                            ),

                            const SizedBox(height: 24),
        
                            // Opción de incluir en total
                            Container(
                              decoration: BoxDecoration(
                                color: context.appTheme.secondaryCardBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: context.appTheme.borderSubtle,
                                  width: 1,
                                ),
                              ),
                              child: Material(
                                type: MaterialType.transparency,
                                child: SwitchListTile(
                                value: isCreditCard ? false : includeInTotal,
                                activeColor: iconColor,
                                title: Text(
                                  'Incluir en saldo total',
                                  style: TextStyle(
                                    color: isCreditCard
                                        ? context.appTheme.textSecondary
                                        : context.appTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  isCreditCard
                                      ? 'Excluida: el cupo de TC no es dinero propio'
                                      : 'Forma parte del saldo global',
                                  style: TextStyle(
                                    color: context.appTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                onChanged: isCreditCard
                                    ? null
                                    : (bool value) {
                                        setState(() {
                                          includeInTotal = value;
                                        });
                                      },
                                secondary: Icon(
                                  Icons.visibility_outlined,
                                  color: iconColor.withOpacity(0.8),
                                ),
                              ),
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
                                    context.appTheme.secondaryCardBackground.withOpacity(0.95),
                                  ],
                                ),
                              ),
                              alignment: Alignment.bottomCenter,
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Desliza para ver más",
                                    style: TextStyle(
                                      color: context.appTheme.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: context.appTheme.textSecondary,
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
                    color: context.appTheme.secondaryCardBackground,
                    border: Border(top: BorderSide(color: context.appTheme.darkBackground)),
                  ),
                  child: Row(
                    children: [
                      // Botón Cancelar
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            foregroundColor: Theme.of(context).brightness == Brightness.light
                                ? context.appTheme.textPrimary
                                : context.appTheme.textSecondary,
                            backgroundColor: Theme.of(context).brightness == Brightness.light
                                ? context.appTheme.darkBackground
                                : Colors.white.withOpacity(0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: context.appTheme.borderSubtle,
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
                            final trimmedTitle = titleController.text.trim();
                            final cleanBalance = CurrencyHelper.cleanAmountString(balanceController.text);
                            if (trimmedTitle.contains(' > ')) {
                              AlertHelper.warning(context, 'El nombre no puede contener " > "');
                              return;
                            }
                            if (trimmedTitle.isEmpty || cleanBalance.isEmpty) {
                              AlertHelper.warning(context, 'Por favor completa todos los campos requeridos');
                              return;
                            }
                            final parsedBalance = double.tryParse(cleanBalance);
                            if (parsedBalance == null) {
                              AlertHelper.warning(context, 'El monto debe ser un número válido');
                              return;
                            }
                            if (isCreditCard && parsedBalance <= 0) {
                              AlertHelper.warning(context, 'El monto debe ser mayor a 0');
                              return;
                            }
                            if (!isCreditCard && parsedBalance < 0) {
                              AlertHelper.warning(context, 'El saldo inicial no puede ser negativo');
                              return;
                            }
                            Navigator.of(context).pop(AccountItem(
                              icon: selectedIcon,
                              title: trimmedTitle,
                              subtitle: selectedAccountType,
                              balance: cleanBalance,
                              iconColor: iconColor,
                              includeInTotal: isCreditCard ? false : includeInTotal,
                              creditLimit: isCreditCard ? cleanBalance : null,
                              cutoffDay: isCreditCard && cutoffController.text.isNotEmpty ? int.tryParse(cutoffController.text) : null,
                              paymentDay: isCreditCard && paymentController.text.isNotEmpty ? int.tryParse(paymentController.text) : null,
                              interestRate: isCreditCard && interestController.text.isNotEmpty ? double.tryParse(interestController.text) : null,
                            ));
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_rounded, size: 18),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Crear Cuenta',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w600),
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
  }

  Widget _buildInputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: context.appTheme.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSmallInput(TextEditingController controller, String hint, IconData icon, Color color) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: context.appTheme.darkBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appTheme.borderSubtle),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: context.appTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: context.appTheme.textHint, fontSize: 12),
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: color.withOpacity(0.7), size: 16),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}