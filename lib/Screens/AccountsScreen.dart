import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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
          backgroundColor: Color.fromRGBO(31, 38, 57, 1),
          title: Text(
              index == null ? 'Agregar nueva categoria' : 'Actualizar ítem',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.category_outlined, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _textFieldController,
                      decoration: InputDecoration(
                        labelText: 'Ingrese el dato',
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(Icons.tag_faces, color: Colors.white),
                        onPressed: () async {
                          IconData? icon =
                              await _showIconPickerDialog(tabIndex);
                          setState(() {
                            selectedIcon = icon;
                          });
                        },
                      ),
                      Text('Establecer ícono',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(Icons.color_lens, color: Colors.white),
                        onPressed: () async {
                          Color? color = await _showColorPickerDialog();
                          setState(() {
                            if (color != null) {
                              selectedColor = color;
                            }
                          });
                        },
                      ),
                      Text('Establecer color',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancelar', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  Map<String, dynamic> newItem = {
                    'text': _textFieldController.text,
                    'icon': selectedIcon?.codePoint ?? Icons.add.codePoint,
                    'color': selectedColor.value,
                  };
                  if (tabIndex == 0) {
                    if (index == null) {
                      ingresos.add(newItem);
                    } else {
                      ingresos[index] = newItem;
                    }
                  } else {
                    if (index == null) {
                      gastos.add(newItem);
                    } else {
                      gastos[index] = newItem;
                    }
                  }
                  _saveData();
                });
                Navigator.pop(context);
              },
              child: Text(index == null ? 'Agregar' : 'Actualizar'),
            ),
          ],
        );
      },
    );
  }

  Future<IconData?> _showIconPickerDialog(int tabIndex) async {
    return showDialog<IconData>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color.fromRGBO(31, 38, 57, 1),
          title: Text('Seleccione un ícono',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 10,
              children: _buildIconButtons(tabIndex),
            ),
          ),
        );
      },
    );
  }

  Future<Color?> _showColorPickerDialog() async {
    Color pickerColor = selectedColor;
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
              onPressed: () {
                Navigator.pop(context, null);
              },
              child: Text('Cancelar', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, pickerColor);
              },
              child: Text('Seleccionar'),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildIconButtons(int tabIndex) {
    List<IconData> icons = tabIndex == 0
        ? IconProvider.getIncomeIcons()
        : IconProvider.getExpenseIcons();

    return icons.map((icon) {
      return IconButton(
        icon: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selectedColor,
          ),
          padding: EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context, icon),
      );
    }).toList();
  }

  void _showOptionsDialog(int tabIndex, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color.fromRGBO(31, 38, 57, 1),
          title: Text('Opciones', style: TextStyle(color: Colors.white)),
          content: Text('¿Qué desea hacer con este elemento?',
              style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showAddItemDialog(tabIndex,
                    initialData:
                        tabIndex == 0 ? ingresos[index] : gastos[index],
                    index: index);
              },
              child: Text('Editar', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (tabIndex == 0) {
                    ingresos.removeAt(index);
                  } else {
                    gastos.removeAt(index);
                  }
                  _saveData();
                });
                Navigator.pop(context);
              },
              child: Text('Borrar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Color.fromRGBO(31, 38, 57, 1),
        appBar: AppBar(
          title: Text('Categorías', style: TextStyle(color: Colors.white)),
          backgroundColor: Color.fromRGBO(31, 38, 57, 1),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[400], // Gris claro
            tabs: [
              Tab(text: 'Ingresos'),
              Tab(text: 'Gastos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Stack(
              children: [
                ListView.builder(
                  itemCount: ingresos.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: ingresos[index]['icon'] != null
                          ? Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: ingresos[index]['color'] != null
                                    ? Color(ingresos[index]['color'])
                                    : Colors.blue,
                              ),
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                IconData(ingresos[index]['icon'],
                                    fontFamily: 'MaterialIcons'),
                                color: Colors.white,
                                size: 24, // Tamaño reducido del ícono
                              ),
                            )
                          : null,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(ingresos[index]['text'] ?? '',
                              style: TextStyle(color: Colors.white)),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: const Color.fromARGB(255, 206, 101, 93)),
                            onPressed: () {
                              setState(() {
                                ingresos.removeAt(index);
                                _saveData();
                              });
                            },
                          ),
                        ],
                      ),
                      onLongPress: () {
                        _showOptionsDialog(0, index);
                      },
                    );
                  },
                ),
                Positioned(
                  bottom: 16.0,
                  right: 16.0,
                  child: FloatingActionButton(
                    onPressed: () {
                      _showAddItemDialog(0);
                    }, //marca
                    child: Icon(
                      Icons.add,
                      color: const Color.fromARGB(255, 19, 30, 49),
                    ),
                    tooltip: 'Agregar categoría',
                  ),
                ),
              ],
            ),
            Stack(
              children: [
                ListView.builder(
                  itemCount: gastos.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: gastos[index]['icon'] != null
                          ? Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: gastos[index]['color'] != null
                                    ? Color(gastos[index]['color'])
                                    : Colors.blue,
                              ),
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                IconData(gastos[index]['icon'],
                                    fontFamily: 'MaterialIcons'),
                                color: Colors.white,
                                size: 24, // Tamaño reducido del ícono
                              ),
                            )
                          : null,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(gastos[index]['text'] ?? '',
                              style: TextStyle(color: Colors.white)),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color:
                                    const Color.fromARGB(255, 168, 113, 108)),
                            onPressed: () {
                              setState(() {
                                gastos.removeAt(index);
                                _saveData();
                              });
                            },
                          ),
                        ],
                      ),
                      onLongPress: () {
                        _showOptionsDialog(1, index);
                      },
                    );
                  },
                ),
                Positioned(
                  bottom: 16.0,
                  right: 16.0,
                  child: FloatingActionButton(
                    onPressed: () {
                      _showAddItemDialog(1);
                    },
                    child: Icon(Icons.add),
                    tooltip: 'Agregar en Pestaña 2',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class IconProvider {
  static List<IconData> getIncomeIcons() {
    return [
      Icons.payment,
      Icons.shopping_cart,
      Icons.attach_money,
      Icons.business,
      Icons.work,
      Icons.account_balance,
      Icons.card_giftcard,
      Icons.card_membership,
      Icons.card_travel,
      Icons.credit_card,
      Icons.monetization_on,
      Icons.money,
      Icons.savings,
      Icons.trending_up,
      Icons.trending_down,
      Icons.account_balance_wallet,
      Icons.account_box,
      Icons.account_circle,
    ];
  }

  static List<IconData> getExpenseIcons() {
    return [
      Icons.shopping_cart,
      Icons.credit_card,
      Icons.money,
      Icons.restaurant,
      Icons.local_gas_station,
      Icons.local_hospital,
      Icons.hotel,
      Icons.flight,
      Icons.train,
      Icons.directions_bus,
      Icons.local_taxi,
      Icons.directions_car,
      Icons.directions_bike,
      Icons.motorcycle,
      Icons.subway,
      Icons.directions_boat,
      Icons.local_cafe,
      Icons.local_bar,
      Icons.wine_bar,
      Icons.local_drink,
    ];
  }
}
