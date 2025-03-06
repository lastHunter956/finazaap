import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finazaap/widgets/bottomnavigationbar.dart'; // Asegúrate de que esta ruta sea correcta
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:finazaap/icon_lists.dart';
import 'package:intl/intl.dart';

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
  IconData selectedIcon = Icons.account_balance_wallet; // Default
  TextEditingController titleController = TextEditingController();
  TextEditingController subtitleController = TextEditingController();
  TextEditingController balanceController = TextEditingController();
  Color iconColor = Colors.blue; // Default
  bool includeInTotal = true; // Por defecto, incluir en el saldo total

  return showDialog<AccountItem>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Center(
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      selectedIcon,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Agregar Cuenta',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ],
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Campo de título
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, color: Colors.white70),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Título',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white70),
                              borderRadius: BorderRadius.all(Radius.circular(8.0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blueAccent),
                              borderRadius: BorderRadius.all(Radius.circular(8.0)),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Campo de subtítulo
                  Row(
                    children: [
                      Icon(Icons.turned_in_not, color: Colors.white70),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: subtitleController,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de cuenta',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white70),
                              borderRadius: BorderRadius.all(Radius.circular(8.0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blueAccent),
                              borderRadius: BorderRadius.all(Radius.circular(8.0)),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Campo de balance
                  Row(
                    children: [
                      Icon(Icons.monetization_on_outlined, color: Colors.white70),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: balanceController,
                          decoration: const InputDecoration(
                            labelText: 'Saldo',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white70),
                              borderRadius: BorderRadius.all(Radius.circular(8.0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blueAccent),
                              borderRadius: BorderRadius.all(Radius.circular(8.0)),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Seleccionar ícono y color
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          leading: Icon(Icons.insert_emoticon, color: Colors.white),
                          title: const Text('Icono', style: TextStyle(color: Colors.white)),
                          onTap: () async {
                            IconData? icon = await showDialog<IconData>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
                                  title: const Text(
                                    'Elige un ícono',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: SingleChildScrollView(
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        for (var iconData in accountIcons)
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.of(context).pop(iconData);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white24,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                iconData,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                            if (icon != null) {
                              setState(() {
                                selectedIcon = icon;
                              });
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          leading: Icon(Icons.color_lens, color: Colors.white),
                          title: const Text('Color', style: TextStyle(color: Colors.white)),
                          onTap: () async {
                            Color? pickedColor = await _showColorPickerDialog(context, iconColor);
                            if (pickedColor != null) {
                              setState(() {
                                iconColor = pickedColor;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Checkbox para incluir en el saldo total
                  CheckboxListTile(
                    title: const Text(
                      'Incluir cuenta en el saldo total',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: includeInTotal,
                    activeColor: Colors.blueAccent,
                    checkColor: Colors.white,
                    onChanged: (bool? value) {
                      setState(() {
                        includeInTotal = value ?? true;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                child: const Text('Agregar'),
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
                      includeInTotal: includeInTotal, // Guardar este valor
                    ));
                  }
                },
              ),
            ],
          );
        },
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
    builder: (context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Center(
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      selectedIcon,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Editar Cuenta',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ],
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Campo de título
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, color: Colors.white70),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Título',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white70),
                              borderRadius: BorderRadius.all(Radius.circular(8.0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blueAccent),
                              borderRadius: BorderRadius.all(Radius.circular(8.0)),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Campo de subtítulo
                  Row(
                    children: [
                      Icon(Icons.turned_in_not, color: Colors.white70),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: subtitleController,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de cuenta',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white70),
                              borderRadius: BorderRadius.all(Radius.circular(8.0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blueAccent),
                              borderRadius: BorderRadius.all(Radius.circular(8.0)),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Campo de balance
                  Row(
                    children: [
                      Icon(Icons.monetization_on_outlined, color: Colors.white70),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: balanceController,
                          decoration: const InputDecoration(
                            labelText: 'Saldo',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white70),
                              borderRadius: BorderRadius.all(Radius.circular(8.0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blueAccent),
                              borderRadius: BorderRadius.all(Radius.circular(8.0)),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Seleccionar ícono y color
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          leading: Icon(Icons.insert_emoticon, color: Colors.white),
                          title: const Text('Icono', style: TextStyle(color: Colors.white)),
                          onTap: () async {
                            IconData? icon = await showDialog<IconData>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
                                  title: const Text(
                                    'Elige un ícono',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: SingleChildScrollView(
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        for (var iconData in accountIcons)
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.of(context).pop(iconData);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white24,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                iconData,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                            if (icon != null) {
                              setState(() {
                                selectedIcon = icon;
                              });
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          leading: Icon(Icons.color_lens, color: Colors.white),
                          title: const Text('Color', style: TextStyle(color: Colors.white)),
                          onTap: () async {
                            Color? pickedColor = await _showColorPickerDialog(context, iconColor);
                            if (pickedColor != null) {
                              setState(() {
                                iconColor = pickedColor;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Checkbox para incluir en el saldo total
                  CheckboxListTile(
                    title: const Text(
                      'Incluir cuenta en el saldo total',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: includeInTotal,
                    activeColor: Colors.blueAccent,
                    checkColor: Colors.white,
                    onChanged: (bool? value) {
                      setState(() {
                        includeInTotal = value ?? true;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                onPressed: () {
                  // Mostrar diálogo de confirmación antes de eliminar
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
                        title: const Text('Confirmar eliminación', style: TextStyle(color: Colors.white)),
                        content: const Text(
                          '¿Estás seguro de que deseas eliminar esta cuenta? Esta acción no se puede deshacer.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
                            onPressed: () {
                              Navigator.of(dialogContext).pop(); // Cierra el diálogo de confirmación
                            },
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            child: const Text('Eliminar'),
                            onPressed: () {
                              Navigator.of(dialogContext).pop(); // Cierra el diálogo de confirmación
                              Navigator.of(context).pop('delete'); // Indica que se eliminará
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                child: const Text('Guardar'),
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
                      includeInTotal: includeInTotal, // Guardar este valor
                    ));
                  }
                },
              ),
            ],
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
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
          title: const Text(
            'Selecciona un color',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: tempColor,
              onColorChanged: (Color color) {
                tempColor = color;
              },
              availableColors: [
                Colors.red,
                Colors.pink,
                Colors.purple,
                Colors.deepPurple,
                Colors.indigo,
                Colors.blue,
                Colors.lightBlue,
                Colors.cyan,
                Colors.teal,
                Colors.green,
                Colors.lightGreen,
                Colors.lime,
                Colors.yellow,
                Colors.amber,
                Colors.orange,
                Colors.deepOrange,
                Colors.brown,
                Colors.grey,
                Colors.blueGrey,
                Colors.black,
              ],
            ),
          ),
          actions: [
            TextButton(
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Seleccionar'),
              onPressed: () {
                Navigator.of(context).pop(tempColor);
              },
            ),
          ],
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

void main() {
  runApp(MyApp());
}
