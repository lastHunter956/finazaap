import 'package:flutter/material.dart';
import 'package:finazaap/widgets/bottomnavigationbar.dart'; // Asegúrate de que esta ruta sea correcta
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Color.fromRGBO(31, 38, 57, 1),
        scaffoldBackgroundColor: Color.fromRGBO(31, 38, 57, 1),
        dialogBackgroundColor: Color.fromRGBO(31, 38, 57, 1),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[850],
          labelStyle: TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white70),
            borderRadius: BorderRadius.circular(8.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blueAccent),
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}

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

class MyHomePage extends StatefulWidget {
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

  void loadAccounts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? accountsData = prefs.getStringList('accounts');
    if (accountsData != null) {
      setState(() {
        accountItems = accountsData
            .map((item) => AccountItem.fromJson(json.decode(item)))
            .toList();
      });
    }
  }

  void saveAccounts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> accountsData =
        accountItems.map((item) => json.encode(item.toJson())).toList();
    await prefs.setStringList('accounts', accountsData);
  }

  void addAccountItem(AccountItem item) {
    setState(() {
      accountItems.add(item);
    });
    saveAccounts();
  }

  void _updateAccountItem(AccountItem oldItem, AccountItem newItem) {
    setState(() {
      int index = accountItems.indexOf(oldItem);
      if (index != -1) {
        accountItems[index] = newItem;
        saveAccounts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calcular el saldo total
    double totalBalance = accountItems.fold<double>(
      0.0,
      (double sum, AccountItem item) =>
          sum + (double.tryParse(item.balance) ?? 0.0),
    );

    return Scaffold(
      backgroundColor:
          Color.fromRGBO(31, 38, 57, 1), // Color de fondo del Scaffold
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(31, 38, 57, 1),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Bottom()),
            );
          },
        ),
        title: Text('Cuentas', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Mostrar el saldo total
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
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            // Mostrar la lista de cuentas
            ...accountItems.map((item) => _buildAccountItem(item)).toList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newItem = await _showAddAccountDialog(context);
          if (newItem != null) {
            addAccountItem(newItem);
          }
        },
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.add),
      ),
    );
  }

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
          backgroundColor:
              Color.fromRGBO(31, 38, 57, 1), // Color de fondo del diálogo
          title: Text('Agregar Cuenta', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<IconData>(
                  decoration: InputDecoration(
                    labelText: 'Icono',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  dropdownColor: Color.fromRGBO(31, 38, 57, 1),
                  items: [
                    Icons.account_balance_wallet,
                    Icons.account_balance,
                    Icons.credit_card,
                    Icons.attach_money,
                    Icons.money,
                    Icons.savings,
                    Icons.trending_up,
                    Icons.trending_down,
                    Icons.account_balance_wallet,
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
                SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Título',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                  onChanged: (value) {
                    title = value;
                  },
                ),
                SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Subtítulo',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                  onChanged: (value) {
                    subtitle = value;
                  },
                ),
                SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Balance',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    balance = value;
                  },
                ),
                SizedBox(height: 10),
                TextButton(
                  child: Text('Seleccionar Color del Icono',
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
              child: Text('Cancelar', style: TextStyle(color: Colors.white70)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              child: Text('Agregar'),
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
          backgroundColor: Color.fromRGBO(31, 38, 57, 1),
          title: Text('Editar Cuenta', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<IconData>(
                  value: selectedIcon,
                  decoration: InputDecoration(
                    labelText: 'Icono',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  dropdownColor: Color.fromRGBO(31, 38, 57, 1),
                  items: [
                    Icons.account_balance_wallet,
                    Icons.account_balance,
                    Icons.credit_card,
                    Icons.attach_money,
                    Icons.money,
                    Icons.savings,
                    Icons.trending_up,
                    Icons.trending_down,
                    Icons.account_balance_wallet,
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
                SizedBox(height: 10),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Título',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: subtitleController,
                  decoration: InputDecoration(
                    labelText: 'Subtítulo',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: balanceController,
                  decoration: InputDecoration(
                    labelText: 'Balance',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 10),
                TextButton(
                  child: Text('Seleccionar Color del Icono',
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
              child: Text('Cancelar', style: TextStyle(color: Colors.white70)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              child: Text('Guardar'),
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

  Future<Color?> _showColorPickerDialog(
      BuildContext context, Color currentColor) async {
    Color pickerColor = currentColor;
    return showDialog<Color>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color.fromRGBO(31, 38, 57, 1),
          title: Text('Seleccione un color',
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
              child: Text('Cancelar', style: TextStyle(color: Colors.white70)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              child: Text('Seleccionar'),
              onPressed: () {
                Navigator.of(context).pop(pickerColor);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccountItem(AccountItem item) {
    return Card(
      color: Color.fromRGBO(31, 38, 57, 1),
      child: ListTile(
        leading: GestureDetector(
          onLongPress: () async {
            final editedItem = await _showEditAccountDialog(context, item);
            if (editedItem != null) {
              _updateAccountItem(item, editedItem);
            }
          },
          child: Icon(item.icon, color: item.iconColor),
        ),
        title: Text(
          item.title,
          style: TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          item.subtitle,
          style: TextStyle(color: Colors.white70),
        ),
        trailing: Text(
          '${item.balance} \$',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        onTap: () async {
          final editedItem = await _showEditAccountDialog(context, item);
          if (editedItem != null) {
            _updateAccountItem(item, editedItem);
          }
        },
      ),
    );
  }
}
