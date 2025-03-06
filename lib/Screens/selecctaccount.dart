import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finazaap/widgets/bottomnavigationbar.dart'; // Asegúrate de que esta ruta sea correcta
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class AccountItem {
  IconData icon;
  String title;
  String subtitle;
  String balance;
  Color iconColor;

  AccountItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.balance,
    required this.iconColor,
  });

  Map<String, dynamic> toJson() => {
        'icon': icon.codePoint,
        'title': title,
        'subtitle': subtitle,
        'balance': balance,
        'iconColor': iconColor.value,
      };

  factory AccountItem.fromJson(Map<String, dynamic> json) => AccountItem(
        icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
        title: json['title'],
        subtitle: json['subtitle'],
        balance: json['balance'],
        iconColor: Color(json['iconColor']),
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

  @override
  void initState() {
    super.initState();
    loadAccounts();
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
      (sum, item) => sum + (double.tryParse(item.balance) ?? 0.0),
    );

    // Notificar siempre, incluso si el valor no ha cambiado
    widget.onBalanceUpdated(totalBalance);

    // Opcional: actualizar la UI para mostrar el saldo en esta pantalla también
    setState(() {}); // Solo si necesitas refrescar la UI
  }

  // Diálogo para agregar una nueva cuenta
  Future<AccountItem?> _showAddAccountDialog(BuildContext context) async {
    IconData? selectedIcon;
    String title = '';
    String subtitle = '';
    String balance = '';
    Color iconColor = Colors.white;

    return showDialog<AccountItem>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
          title: const Text('Agregar Cuenta',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<IconData>(
                  decoration: InputDecoration(
                    labelText: 'Icono',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white70),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  dropdownColor: const Color.fromRGBO(31, 38, 57, 1),
                  items: [
                    Icons.account_balance_wallet,
                    Icons.account_balance,
                    Icons.credit_card,
                    Icons.attach_money,
                    Icons.money,
                    Icons.savings,
                    Icons.trending_up,
                    Icons.trending_down,
                    Icons.account_box,
                    Icons.account_circle,
                  ]
                      .map((iconData) => DropdownMenuItem<IconData>(
                            value: iconData,
                            child: Icon(iconData, color: Colors.white70),
                          ))
                      .toList(),
                  onChanged: (value) {
                    selectedIcon = value;
                  },
                  iconEnabledColor: Colors.white70,
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                      borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    title = value;
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Subtítulo',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                      borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    subtitle = value;
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Balance',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                      borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (value) {
                    balance = value;
                  },
                ),
                const SizedBox(height: 10),
                TextButton(
                  child: const Text('Seleccionar Color del Icono',
                      style: TextStyle(color: Colors.white70)),
                  onPressed: () async {
                    Color? pickedColor =
                        await _showColorPickerDialog(context, iconColor);
                    if (pickedColor != null) {
                      setState(() {
                        iconColor = pickedColor;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white70)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: const Text('Agregar'),
              onPressed: () {
                if (selectedIcon != null &&
                    title.isNotEmpty &&
                    subtitle.isNotEmpty &&
                    balance.isNotEmpty) {
                  Navigator.of(context).pop(AccountItem(
                    icon: selectedIcon!,
                    title: title,
                    subtitle: subtitle,
                    balance: balance,
                    iconColor: iconColor,
                  ));
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Diálogo para editar una cuenta existente
  Future<AccountItem?> _showEditAccountDialog(
      BuildContext context, AccountItem item) async {
    IconData? selectedIcon = item.icon;
    TextEditingController titleController =
        TextEditingController(text: item.title);
    TextEditingController subtitleController =
        TextEditingController(text: item.subtitle);
    TextEditingController balanceController =
        TextEditingController(text: item.balance);
    Color iconColor = item.iconColor;

    return showDialog<AccountItem>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
          title: const Text('Editar Cuenta',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<IconData>(
                  value: selectedIcon,
                  decoration: InputDecoration(
                    labelText: 'Icono',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white70),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  dropdownColor: const Color.fromRGBO(31, 38, 57, 1),
                  items: [
                    Icons.account_balance_wallet,
                    Icons.account_balance,
                    Icons.credit_card,
                    Icons.attach_money,
                    Icons.money,
                    Icons.savings,
                    Icons.trending_up,
                    Icons.trending_down,
                    Icons.account_box,
                    Icons.account_circle,
                  ]
                      .map((iconData) => DropdownMenuItem<IconData>(
                            value: iconData,
                            child: Icon(iconData, color: Colors.white70),
                          ))
                      .toList(),
                  onChanged: (value) {
                    selectedIcon = value;
                  },
                  iconEnabledColor: Colors.white70,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                      borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: subtitleController,
                  decoration: const InputDecoration(
                    labelText: 'Subtítulo',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                      borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: balanceController,
                  decoration: const InputDecoration(
                    labelText: 'Balance',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                      borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton(
                  child: const Text('Seleccionar Color del Icono',
                      style: TextStyle(color: Colors.white70)),
                  onPressed: () async {
                    Color? pickedColor =
                        await _showColorPickerDialog(context, iconColor);
                    if (pickedColor != null) {
                      setState(() {
                        iconColor = pickedColor;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white70)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: const Text('Guardar'),
              onPressed: () {
                if (selectedIcon != null &&
                    titleController.text.isNotEmpty &&
                    subtitleController.text.isNotEmpty &&
                    balanceController.text.isNotEmpty) {
                  Navigator.of(context).pop(AccountItem(
                    icon: selectedIcon!,
                    title: titleController.text,
                    subtitle: subtitleController.text,
                    balance: balanceController.text,
                    iconColor: iconColor,
                  ));
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Diálogo para seleccionar color mediante un ColorPicker
  Future<Color?> _showColorPickerDialog(
      BuildContext context, Color currentColor) async {
    Color pickerColor = currentColor;
    return showDialog<Color>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
          title: const Text('Seleccione un color',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (Color color) {
                pickerColor = color;
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white70)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: const Text('Seleccionar'),
              onPressed: () {
                Navigator.of(context).pop(pickerColor);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalBalance = accountItems.fold<double>(
      0.0,
      (sum, item) => sum + (double.tryParse(item.balance) ?? 0.0),
    );

    return Scaffold(
      backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            _updateTotalBalance(); // Actualiza el saldo total
            // Usa Navigator.pop en lugar de push para volver a la pantalla anterior
            Navigator.pop(context);
          },
        ),
        title: const Text('Cuentas', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Mostrar saldo total
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Saldo total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '${totalBalance.toStringAsFixed(2)} \$',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            // Lista de cuentas
            ...accountItems.map((item) => _buildAccountItem(item)).toList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newItem = await _showAddAccountDialog(context);
          if (newItem != null) {
            _saveAccount(newItem); // Aquí se llama a _saveAccount
          }
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAccountItem(AccountItem item) {
    return Card(
      color: const Color.fromRGBO(31, 38, 57, 1),
      child: ListTile(
        leading: GestureDetector(
          onLongPress: () async {
            final editedItem = await _showEditAccountDialog(context, item);
            if (editedItem != null) {
              _editAccount(item, editedItem);
            }
          },
          child: Icon(item.icon, color: item.iconColor),
        ),
        title: Text(
          item.title,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          '${item.balance} \$',
          style: const TextStyle(color: Colors.white70),
        ),
        onTap: () async {
          final editedItem = await _showEditAccountDialog(context, item);
          if (editedItem != null) {
            _editAccount(item, editedItem);
          }
        },
      ),
    );
  }
}

void main() {
  runApp(MyApp());
}