import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finazaap/widgets/bottomnavigationbar.dart'; // Asegúrate de que esta ruta sea correcta
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:finazaap/icon_lists.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

class AccountItem {
  IconData icon;
  String title;
  String subtitle;
  String balance;
  Color iconColor;
  bool includeInTotal; // Nueva propiedad

  AccountItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.balance,
    required this.iconColor,
    this.includeInTotal = true, // Por defecto, incluir en el saldo total
  });

  Map<String, dynamic> toJson() => {
        'icon': icon.codePoint,
        'title': title,
        'subtitle': subtitle,
        'balance': balance,
        'iconColor': iconColor.value,
        'includeInTotal': includeInTotal,
      };

  factory AccountItem.fromJson(Map<String, dynamic> json) => AccountItem(
        icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
        title: json['title'],
        subtitle: json['subtitle'],
        balance: json['balance'],
        iconColor: Color(json['iconColor']),
        includeInTotal: json['includeInTotal'] ??
            true, // Por defecto true para cuentas antiguas
      );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finazaap',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color.fromRGBO(31, 38, 57, 1),
        scaffoldBackgroundColor: const Color.fromRGBO(31, 38, 57, 1),
        dialogBackgroundColor: const Color.fromRGBO(31, 38, 57, 1),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[850],
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white70),
            borderRadius: BorderRadius.circular(8.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.blueAccent),
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
      home: MyHomePage(
        onBalanceUpdated: (balance) {
          // Aquí puedes manejar el saldo total actualizado (por ejemplo, mostrarlo en otra parte de la app)
          print("Saldo total actualizado: $balance");
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final Function(double) onBalanceUpdated;

  MyHomePage({required this.onBalanceUpdated});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<AccountItem> accountItems = [];
  bool _hideBalance = false; // Variable para controlar la visibilidad del saldo

  @override
  void initState() {
    super.initState();
    loadAccounts();
  }

  void _deleteAccount(AccountItem account) {
    setState(() {
      accountItems.remove(account);
    });
    saveAccounts();
  }

  // Carga las cuentas desde SharedPreferences
  void loadAccounts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? accountsData = prefs.getStringList('accounts');
    if (accountsData != null) {
      setState(() {
        accountItems = accountsData
            .map((item) => AccountItem.fromJson(json.decode(item)))
            .toList();
      });
      _updateTotalBalance(); // Esta llamada es crucial
    } else {
      // Si no hay datos, actualiza el balance a cero
      widget.onBalanceUpdated(0.0);
    }
  }

  // Guarda las cuentas en SharedPreferences y actualiza el saldo total
  void saveAccounts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> accountsData =
        accountItems.map((item) => json.encode(item.toJson())).toList();
    await prefs.setStringList('accounts', accountsData);
    _updateTotalBalance();
  }

  void _saveAccount(AccountItem account) {
    setState(() {
      accountItems.add(account);
    });
    saveAccounts();
  }

  void _editAccount(AccountItem oldAccount, AccountItem newAccount) {
    setState(() {
      int index = accountItems.indexOf(oldAccount);
      if (index != -1) {
        accountItems[index] = newAccount;
      }
    });
    saveAccounts();
  }

  // Calcula el saldo total y llama al callback correspondiente
  void _updateTotalBalance() {
    double totalBalance = accountItems.fold<double>(
      0.0,
      (sum, item) =>
          sum +
          (item.includeInTotal ? (double.tryParse(item.balance) ?? 0.0) : 0.0),
    );

    // Notificar siempre, incluso si el valor no ha cambiado
    widget.onBalanceUpdated(totalBalance);

    // Actualizar la UI para mostrar el saldo en esta pantalla también
    setState(() {});
  }

  // Diálogo para agregar una nueva cuenta
  Future<AccountItem?> _showAddAccountDialog(BuildContext context) async {
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
                            _buildInputLabel('Nombre de la cuenta'),
                            _buildInputField(
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
                                      _buildInputLabel('Tipo de cuenta'),
                                      _buildInputField(
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
                                      _buildInputLabel('Saldo inicial'),
                                      _buildInputField(
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
                            _buildInputLabel('Personalización'),
                            Row(
                              children: [
                                // Selector de icono
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    splashColor: iconColor.withOpacity(0.1),
                                    highlightColor: iconColor.withOpacity(0.05),
                                    onTap: () async {
                                      IconData? icon = await _showIconPickerDialog(context, iconColor);
                                      if (icon != null) {
                                        setState(() {
                                          selectedIcon = icon;
                                        });
                                      }
                                    },
                                    child: _buildInputField(
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
                                      Color? pickedColor = await _showColorPickerDialog(context, iconColor);
                                      if (pickedColor != null) {
                                        setState(() {
                                          iconColor = pickedColor;
                                        });
                                      }
                                    },
                                    child: _buildInputField(
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

// Método para selector de iconos mejorado
Future<IconData?> _showIconPickerDialog(BuildContext context, Color accentColor) async {
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

// Diálogo para editar una cuenta existente
Future<dynamic> _showEditAccountDialog(BuildContext context, AccountItem item) async {
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
                            _buildInputLabel('Nombre de la cuenta'),
                            _buildInputField(
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
                                  prefixIcon: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Tipo de cuenta
                            _buildInputLabel('Tipo de cuenta'),
                            _buildInputField(
                              child: TextField(
                                controller: subtitleController,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Ej: Cuenta Corriente',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  border: InputBorder.none,
                                  prefixIcon: const Icon(
                                    Icons.category_outlined,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Saldo
                            _buildInputLabel('Saldo actual'),
                            _buildInputField(
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
                                  hintText: 'Ej: 1000.00',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  border: InputBorder.none,
                                  prefixIcon: const Icon(
                                    Icons.monetization_on_outlined,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Selector de icono
                            _buildInputLabel('Personalización'),
                            Row(
                              children: [
                                // Selector de icono
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      IconData? icon = await showDialog<IconData>(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            backgroundColor: const Color(0xFF1A1F2B),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            title: const Text(
                                              'Elige un icono',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            content: Container(
                                              width: double.maxFinite,
                                              child: SingleChildScrollView(
                                                child: Wrap(
                                                  spacing: 12,
                                                  runSpacing: 12,
                                                  children: [
                                                    for (var iconData in accountIcons)
                                                      GestureDetector(
                                                        onTap: () => Navigator.of(context).pop(iconData),
                                                        child: Container(
                                                          padding: const EdgeInsets.all(12),
                                                          decoration: BoxDecoration(
                                                            color: Color(0xFF222939),
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Icon(
                                                            iconData,
                                                            color: Colors.white,
                                                            size: 24,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(),
                                                child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                      if (icon != null) {
                                        setState(() {
                                          selectedIcon = icon;
                                        });
                                      }
                                    },
                                    child: _buildInputField(
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
                                            const Text(
                                              'Icono',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
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
                                      Color? pickedColor = await _showColorPickerDialog(context, iconColor);
                                      if (pickedColor != null) {
                                        setState(() {
                                          iconColor = pickedColor;
                                        });
                                      }
                                    },
                                    child: _buildInputField(
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
                                            const Text(
                                              'Color',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
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
                                  }
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.add_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Crear Cuenta',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
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

  // Diálogo para seleccionar color mediante un ColorPicker
  Future<Color?> _showColorPickerDialog(
      BuildContext context, Color currentColor) async {
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
                      
                      // Paleta de colores mejorada
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

  @override
  Widget build(BuildContext context) {
    // Modificar este cálculo para respetar includeInTotal
    double totalBalance = accountItems.fold<double>(
      0.0,
      (sum, item) =>
          sum +
          (item.includeInTotal ? (double.tryParse(item.balance) ?? 0.0) : 0.0),
    );

    // Formateador de moneda
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '',
      decimalDigits: 2,
    );

    return Scaffold(
      backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
      // Eliminamos el AppBar predeterminado
      appBar: null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contenedor personalizado para el título y flecha de retroceso
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(42, 49, 67, 1),
              
              ),
              child: Row(
                children: [
                  // Botón de retroceso
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      _updateTotalBalance();
                      Navigator.pop(context);
                    },
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                  SizedBox(width: 16),
                  // Título
                  Text(
                    'Cuentas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // El resto del contenido en un SingleChildScrollView
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sección de saldo total con espacio reducido y botón de ojo
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saldo total',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(height: 5),
                          Row(
                            children: [
                              // Texto formateado con el formato de moneda
                              Text(
                                _hideBalance
                                    ? '******** \$'
                                    : '${currencyFormat.format(totalBalance)} \$',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 16),
                              // Botón de ojo para mostrar/ocultar
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _hideBalance = !_hideBalance;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _hideBalance
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Divisor entre el saldo y las cuentas
                    Divider(
                      color: Colors.transparent,
                      thickness: 1,
                      height: 32,
                      indent: 16,
                      endIndent: 16,
                    ),

                    // Lista de cuentas
                    ...accountItems
                        .map((item) => _buildAccountItem(item))
                        .toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newItem = await _showAddAccountDialog(context);
          if (newItem != null) {
            _saveAccount(newItem);
          }
        },
        backgroundColor: Color.fromARGB(255, 82, 226, 255),
        child: const Icon(Icons.add, color: Color.fromRGBO(31, 38, 57, 1)),
      ),
    );
  }

  Widget _buildAccountItem(AccountItem item) {
    // Formateador de moneda
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '',
      decimalDigits: 2,
    );

    // Convertir el balance a double para formatearlo
    double balanceValue = double.tryParse(item.balance) ?? 0.0;

    return Card(
    margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    color: const Color.fromRGBO(42, 49, 67, 1),
    elevation: 4,
    child: Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
          leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: item.iconColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                item.icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            title: Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (!item.includeInTotal)
                    Tooltip(
                      message: 'No incluida en el saldo total',
                      child: Icon(
                        Icons.visibility_off,
                        color: Colors.white38,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.subtitle,
                  style: const TextStyle(color: Colors.white70),
                ),
                // Línea divisoria blanca
                Divider(
                  color: Colors.white30,
                  thickness: 0.5,
                  height: 16,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Saldo:',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      // Texto formateado con el formato de moneda
                      Text(
                        '${currencyFormat.format(balanceValue)} \$',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () async {
            final result = await _showEditAccountDialog(context, item);
            // Aquí está el problema - necesitamos verificar si el resultado es 'delete'
            if (result == 'delete') {
              _deleteAccount(item); // Eliminar la cuenta
            } else if (result != null && result is AccountItem) {
              _editAccount(item, result); // Actualizar la cuenta
            }
          },
          ),
        ],
      ),
    );
  }
}

// Método helper para etiquetas de campos
Widget _buildInputLabel(String label) {
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
Widget _buildInputField({required Widget child}) {
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

void main() {
  runApp(MyApp());
}
