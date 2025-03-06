import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/services.dart';

class AccountsScreen extends StatefulWidget {
  @override
  _AccountsScreenState createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> ingresos = [];
  List<Map<String, dynamic>> gastos = [];
  Color selectedColor = Colors.blue;
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  /// Elimina un ítem de ingresos/gastos y guarda
  void _removeItem(int tabIndex, int index) {
    setState(() {
      if (tabIndex == 0) {
        ingresos.removeAt(index);
      } else {
        gastos.removeAt(index);
      }
    });
    _saveData();
  }

  /// Diálogo para agregar/editar categoría
  void _showAddItemDialog(int tabIndex,
      {Map<String, dynamic>? initialData, int? index}) {
    // Controlador para el texto
    TextEditingController _textFieldController =
        TextEditingController(text: initialData?['text']);

    // Ícono seleccionado
    IconData? tempIcon = initialData?['icon'] != null
        ? IconData(initialData!['icon'], fontFamily: 'MaterialIcons')
        : Icons.category;

    // Color seleccionado
    Color tempColor = initialData?['color'] != null
        ? Color(initialData!['color'])
        : Colors.blue;

    showDialog(
      context: context,
      barrierDismissible: false, // Para forzar "Cancelar" o "Guardar"
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                initialData == null ? 'Agregar Categoría' : 'Editar Categoría',
                style: const TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Vista previa (círculo con ícono blanco)
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: tempColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        tempIcon,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Nombre de la categoría
                    TextField(
                      controller: _textFieldController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la categoría',
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
                    const SizedBox(height: 16),
                    // Seleccionar ícono
                    ListTile(
                      leading: Icon(tempIcon, color: Colors.white),
                      title: const Text('Seleccionar ícono',
                          style: TextStyle(color: Colors.white)),
                      onTap: () async {
                        IconData? icon = await showDialog<IconData>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor:
                                  const Color.fromRGBO(31, 38, 57, 1),
                              title: const Text(
                                'Elige un ícono',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: SingleChildScrollView(
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    for (var iconData in [
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
                                      Icons.card_giftcard,
                                      Icons.home,
                                      Icons.shopping_cart,
                                    ])
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).pop(iconData);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white24,
                                            borderRadius:
                                                BorderRadius.circular(8),
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
                          setModalState(() {
                            tempIcon = icon;
                          });
                        }
                      },
                    ),
                    // Seleccionar color
                    ListTile(
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: tempColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: const Text('Seleccionar color',
                          style: TextStyle(color: Colors.white)),
                      onTap: () async {
                        Color? pickedColor =
                            await _showColorPickerDialog(context, tempColor);
                        if (pickedColor != null) {
                          setModalState(() {
                            tempColor = pickedColor;
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
                      style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Guardar'),
                  onPressed: () {
                    if (_textFieldController.text.isNotEmpty &&
                        tempIcon != null) {
                      final newItem = {
                        'text': _textFieldController.text,
                        'icon': tempIcon?.codePoint,
                        'color': tempColor.value,
                      };
                      setState(() {
                        if (initialData == null) {
                          // Nuevo
                          if (tabIndex == 0) {
                            ingresos.add(newItem);
                          } else {
                            gastos.add(newItem);
                          }
                        } else {
                          // Editar
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
      },
    );
  }

  /// Diálogo para seleccionar color
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
    return Scaffold(
      // Fondo principal
      backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
      body: Column(
        children: [
          // Encabezado que cubre el título y las pestañas
          Container(
            width: double.infinity,
            color: const Color.fromRGBO(42, 49, 67, 1),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Título centrado
                const Text(
                  'Categorias',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                // TabBar dentro del contenedor
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blueAccent,
                  labelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  tabs: const [
                    Tab(text: 'Ingresos'),
                    Tab(text: 'Gastos'),
                  ],
                ),
              ],
            ),
          ),
          // Contenido de cada pestaña
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildListView(ingresos, 0),
                _buildListView(gastos, 1),
              ],
            ),
          ),
        ],
      ),
      // Botón flotante para agregar categoría
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
        onPressed: () {
          _showAddItemDialog(_currentTabIndex);
        },
      ),
    );
  }

  /// Lista de categorías (Ingresos o Gastos)
  Widget _buildListView(List<Map<String, dynamic>> items, int tabIndex) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Column(
          children: [
            InkWell(
              onTap: () {
                _showAddItemDialog(
                  tabIndex,
                  initialData: item,
                  index: index,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                child: Row(
                  children: [
                    // Círculo con ícono blanco
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(item['color']),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        IconData(item['icon'], fontFamily: 'MaterialIcons'),
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Nombre de la categoría
                    Expanded(
                      child: Text(
                        item['text'],
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
            
                    const SizedBox(width: 4),
                    // Botón para borrar (fuera del área tactil de edición)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_outlined, color: Colors.white),
                      onPressed: () {
                        _removeItem(tabIndex, index);
                      },
                    ),
                  ],
                ),
              ),
            ),
            Divider(
              color: Colors.white24,
              height: 1,
              thickness: 1,
              indent: 16,
              endIndent: 16,
            ),
          ],
        );
      },
    );
  }
}
