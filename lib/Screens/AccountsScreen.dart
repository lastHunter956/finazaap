import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/services.dart';
import 'package:finazaap/icon_lists.dart'; // Importa el archivo de listas de iconos
import 'dart:ui';

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

  /// Confirma la eliminación de una categoría
  void _confirmRemoveItem(int tabIndex, int index) {
    // Obtener los datos del ítem a eliminar para mostrar en el diálogo
    final item = tabIndex == 0 ? ingresos[index] : gastos[index];
    final itemName = item['text'];
    final itemIcon = IconData(item['icon'], fontFamily: 'MaterialIcons');
    final itemColor = Color(item['color']);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
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
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono de advertencia
                  Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 65,
                          height: 65,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_rounded,
                            color: Color(0xFFE53935),
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Detalles de la categoría a eliminar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                    child: Column(
                      children: [
                        const Text(
                          '¿Eliminar categoría?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        
                        // Mostrar la categoría a eliminar
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: itemColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  itemIcon,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  itemName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        Text(
                          'Esta acción no se puede deshacer. La categoría será eliminada permanentemente.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Botones de acción
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // Botón Cancelar
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                              ),
                            ),
                            child: const Text('Cancelar'),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Botón Eliminar
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.delete_outline, size: 18),
                                SizedBox(width: 8),
                                Text('Eliminar'),
                              ],
                            ),
                            onPressed: () {
                              // Eliminar el ítem
                              _removeItem(tabIndex, index);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ],
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

  /// Diálogo para agregar/editar categoría
  void _showAddItemDialog(int tabIndex, {Map<String, dynamic>? initialData, int? index}) {
    // Controladores y variables temporales
    TextEditingController _textFieldController = TextEditingController(text: initialData?['text']);
    
    IconData? tempIcon = initialData?['icon'] != null
        ? IconData(initialData!['icon'], fontFamily: 'MaterialIcons')
        : Icons.category;
    
    Color tempColor = initialData?['color'] != null
        ? Color(initialData!['color'])
        : Colors.blue;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cabecera del diálogo
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.1),
                                Colors.white.withOpacity(0.05),
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
                              // Icono con color seleccionado en círculo
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: tempColor.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: tempColor.withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  tempIcon,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Título principal
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      initialData == null ? 'Nueva Categoría' : 'Editar Categoría',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _currentTabIndex == 0 ? 'Categoría de ingresos' : 'Categoría de gastos',
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

                        // Cuerpo del diálogo
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nombre de la categoría
                              _buildInputLabel('Nombre de la categoría'),
                              _buildInputField(
                                child: TextField(
                                  controller: _textFieldController,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Introduce un nombre...',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                    border: InputBorder.none,
                                    prefixIcon: const Icon(
                                      Icons.label_outline_rounded,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Selector de icono
                              _buildInputLabel('Icono'),
                              InkWell(
                                onTap: () async {
                                  IconData? icon = await showDialog<IconData>(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        backgroundColor: const Color(0xFF1A1F2B),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: const Text(
                                          'Selecciona un icono',
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
                                                for (var iconData in categoryIcons)
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
                                    setModalState(() {
                                      tempIcon = icon;
                                    });
                                  }
                                },
                                child: _buildInputField(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: tempColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            tempIcon,
                                            color: tempColor,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          'Cambiar icono',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontSize: 16,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: Colors.white.withOpacity(0.5),
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Selector de color
                              _buildInputLabel('Color'),
                              InkWell(
                                onTap: () async {
                                  Color? pickedColor = await _showColorPickerDialog(context, tempColor);
                                  if (pickedColor != null) {
                                    setModalState(() {
                                      tempColor = pickedColor;
                                    });
                                  }
                                },
                                child: _buildInputField(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: tempColor,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: tempColor.withOpacity(0.3),
                                                blurRadius: 8,
                                                spreadRadius: -2,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          'Cambiar color',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontSize: 16,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: Colors.white.withOpacity(0.5),
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Botones de acción
                        Container(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: Row(
                            children: [
                              // Botón Cancelar
                              Expanded(
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancelar',
                                    style: TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Botón Guardar
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: tempColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        initialData == null ? Icons.add_rounded : Icons.check_rounded,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        initialData == null ? 'Crear categoría' : 'Guardar cambios',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  onPressed: () {
                                    if (_textFieldController.text.isNotEmpty && tempIcon != null) {
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
    return Scaffold(
      // Fondo principal
      backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
      // AppBar añadido
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(42, 49, 67, 1),
        elevation: 0,
        toolbarHeight: 80, 
        title: const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
        'Categorías',
        style: TextStyle(
          color: Colors.white,
          fontSize: 25,
          fontWeight: FontWeight.bold,
        ),
          ),
        ),
        centerTitle: true,
        
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blueAccent,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(text: 'Ingresos'),
            Tab(text: 'Gastos'),
          ],
        ),
      ),
      // Contenido de cada pestaña
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildListView(ingresos, 0),
          _buildListView(gastos, 1),
        ],
      ),
      // Botón flotante para agregar categoría
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 82, 226, 255),
        child: const Icon(Icons.add, color: Color.fromRGBO(31, 38, 57, 1)),
        onPressed: () {
          _showAddItemDialog(_currentTabIndex);
        },
      ),
    );
  }

  /// Lista de categorías (Ingresos o Gastos) con diseño premium similar a cuentas
  Widget _buildListView(List<Map<String, dynamic>> items, int tabIndex) {
    return items.isEmpty
        ? _buildEmptyState(tabIndex)
        : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final color = Color(item['color']);
              final icon = IconData(item['icon'], fontFamily: 'MaterialIcons');
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                  // Sombra CORREGIDA - ahora aparece por FUERA como en cuentas
                  boxShadow: [
                    
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1), // Segunda sombra más suave
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    splashColor: color.withOpacity(0.1),
                    highlightColor: color.withOpacity(0.05),
                    onTap: () {
                      _showAddItemDialog(
                        tabIndex,
                        initialData: item,
                        index: index,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Row(
                        children: [
                          // Icono con diseño premium
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  color,
                                  Color.lerp(color, Colors.black, 0.2) ?? color,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                  spreadRadius: -3,
                                ),
                              ],
                            ),
                            child: Icon(
                              icon,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          
                          const SizedBox(width: 18),
                          
                          // Nombre de categoría
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['text'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tabIndex == 0 ? 'Categoría de ingresos' : 'Categoría de gastos',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Iconos de acciones
                          Row(
                            children: [
                              // Botón editar
                              IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 22,
                                ),
                                onPressed: () {
                                  _showAddItemDialog(
                                    tabIndex,
                                    initialData: item,
                                    index: index,
                                  );
                                },
                                splashRadius: 24,
                                tooltip: 'Editar',
                              ),
                              // Botón eliminar
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 22,
                                ),
                                onPressed: () {
                                  _confirmRemoveItem(tabIndex, index);
                                },
                                splashRadius: 24,
                                tooltip: 'Eliminar',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
  }

  // Widget para mostrar cuando no hay categorías
  Widget _buildEmptyState(int tabIndex) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tabIndex == 0 ? Icons.savings_outlined : Icons.category_outlined,
            size: 70,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 20),
          Text(
            tabIndex == 0 
                ? 'No hay categorías de ingresos' 
                : 'No hay categorías de gastos',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pulsa el botón + para crear una categoría',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 82, 226, 255),
              foregroundColor: const Color.fromRGBO(31, 38, 57, 1),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text(
              'Crear categoría',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              _showAddItemDialog(tabIndex);
            },
          ),
        ],
      ),
    );
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
      child: child,
    );
  }
}