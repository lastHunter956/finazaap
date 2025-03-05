import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/services.dart';

class AccountsScreen extends StatefulWidget {
  @override
  _AccountsScreenState createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<Map<String, dynamic>> ingresos = [];
  List<Map<String, dynamic>> gastos = [];
  Color selectedColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      ingresos = (prefs.getStringList('ingresos') ?? [])
          .map((item) => json.decode(item) as Map<String, dynamic>)
          .toList();
      gastos = (prefs.getStringList('gastos') ?? [])
          .map((item) => json.decode(item) as Map<String, dynamic>)
          .toList();
    });
  }

  void _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
        'ingresos', ingresos.map((item) => json.encode(item)).toList());
    prefs.setStringList(
        'gastos', gastos.map((item) => json.encode(item)).toList());
  }

  void _showAddItemDialog(int tabIndex,
      {Map<String, dynamic>? initialData, int? index}) {
    TextEditingController _textFieldController =
        TextEditingController(text: initialData?['text']);
    TextEditingController _balanceController = TextEditingController(
        text: initialData?['balance']?.toString() ?? '');
    IconData? selectedIcon = initialData?['icon'] != null
        ? IconData(initialData!['icon'], fontFamily: 'MaterialIcons')
        : null;
    selectedColor = initialData?['color'] != null
        ? Color(initialData!['color'])
        : Colors.blue;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
          title: Text(
            initialData == null ? 'Agregar' : 'Editar',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _textFieldController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
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
                  controller: _balanceController,
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
                    setState(() {
                      selectedIcon = value;
                    });
                  },
                  iconEnabledColor: Colors.white70,
                ),
                const SizedBox(height: 10),
                TextButton(
                  child: const Text('Seleccionar Color del Icono',
                      style: TextStyle(color: Colors.white70)),
                  onPressed: () async {
                    Color? pickedColor =
                        await _showColorPickerDialog(context, selectedColor);
                    if (pickedColor != null) {
                      setState(() {
                        selectedColor = pickedColor;
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
                if (_textFieldController.text.isNotEmpty &&
                    _balanceController.text.isNotEmpty &&
                    selectedIcon != null) {
                  final newItem = {
                    'text': _textFieldController.text,
                    'balance': double.parse(_balanceController.text),
                    'icon': selectedIcon!.codePoint,
                    'color': selectedColor.value,
                  };
                  setState(() {
                    if (initialData == null) {
                      if (tabIndex == 0) {
                        ingresos.add(newItem);
                      } else {
                        gastos.add(newItem);
                      }
                    } else {
                      if (tabIndex == 0) {
                        ingresos[index!] = newItem;
                      } else {
                        gastos[index!] = newItem;
                      }
                    }
                  });
                  _saveData();
                  Navigator.of(context).pop();
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
    return Scaffold(
      backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
        title: const Text('Cuentas', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: const [
                      Tab(text: 'Ingresos'),
                      Tab(text: 'Gastos'),
                    ],
                    indicatorColor: Colors.blueAccent,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildListView(ingresos, 0),
                        _buildListView(gastos, 1),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddItemDialog(0);
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> items, int tabIndex) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          color: const Color.fromRGBO(31, 38, 57, 1),
          child: ListTile(
            leading: Icon(
              IconData(item['icon'], fontFamily: 'MaterialIcons'),
              color: Color(item['color']),
            ),
            title: Text(
              item['text'],
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              '${item['balance']} \$',
              style: const TextStyle(color: Colors.white70),
            ),
            onTap: () {
              _showAddItemDialog(tabIndex, initialData: item, index: index);
            },
          ),
        );
      },
    );
  }
}