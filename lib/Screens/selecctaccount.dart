import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:finazaap/widgets/add_account_dialogs.dart';
import 'package:finazaap/widgets/edit_account_dialogs.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'dart:ui';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/transaction_service.dart';
import 'package:gradient_borders/gradient_borders.dart';

// Clase para dibujar líneas punteadas (MOVIDA AL INICIO)
class DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;
  
  DashedLinePainter({
    required this.color,
    this.dashWidth = 5,
    this.dashSpace = 3,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    
    double currentX = 0;
    
    while (currentX < size.width) {
      canvas.drawLine(
        Offset(currentX, 0),
        Offset(currentX + dashWidth, 0),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

  // Modificar el método para que retorne Future<void>
  Future<void> saveAccounts() async {
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

  void _editAccount(AccountItem oldAccount, AccountItem newAccount) async {
    try {
      // Actualizar la lista de cuentas
      setState(() {
        int index = accountItems.indexOf(oldAccount);
        if (index != -1) {
          accountItems[index] = newAccount;
        }
      });
      
      // Guardar los cambios en SharedPreferences
      await saveAccounts();
      
      // Actualizar todas las transacciones relacionadas con esta cuenta
      await TransactionService.updateTransactionsAfterAccountEdit(oldAccount.title, newAccount);
      
      // Mostrar confirmación al usuario
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta actualizada correctamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
      // CAMBIAR ESTO: Simplemente cerrar el diálogo sin hacer pushReplacement
      Navigator.pop(context);
      
      // Notificar que se actualizó el balance
      _updateTotalBalance();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar cuenta: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
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
          final newItem = await showAddAccountDialog(context);
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
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '', decimalDigits: 2);
    double balanceValue = double.tryParse(item.balance) ?? 0.0;
    
    // Definir la paleta de colores refinada
    final Color itemColor = item.iconColor;
    final Color surfaceColor = const Color(0xFF222939);
    final Color shadowColor = Color.alphaBlend(itemColor.withOpacity(0.1), Colors.black.withOpacity(0.3));
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            surfaceColor,
            Color.lerp(surfaceColor, itemColor.withOpacity(0.15), 0.3) ?? surfaceColor,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          // Sombra principal
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            offset: Offset(0, 4),
            blurRadius: 12,
            spreadRadius: -3,
          ),
          // Sombra de acento
          BoxShadow(
            color: shadowColor,
            offset: Offset(0, 2),
            blurRadius: 8,
            spreadRadius: -1,
          ),
        ],
        border: GradientBoxBorder(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.15),
              itemColor.withOpacity(0.2),
              Colors.white.withOpacity(0.05),
              Colors.transparent,
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          splashColor: itemColor.withOpacity(0.1),
          highlightColor: itemColor.withOpacity(0.05),
          onTap: () {
            _showAccountOptions(context, item);
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    // Ícono con diseño mejorado
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            itemColor,
                            Color.lerp(itemColor, Colors.black, 0.3) ?? itemColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: itemColor.withOpacity(0.45),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                            spreadRadius: -3,
                          ),
                        ],
                      ),
                      child: Icon(
                        item.icon,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    SizedBox(width: 18),
                    // Información de la cuenta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              if (!item.includeInTotal)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.red.shade800.withOpacity(0.2),
                                        Colors.redAccent.withOpacity(0.15),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: Colors.redAccent.withOpacity(0.3),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.visibility_off,
                                        size: 12,
                                        color: Colors.red.shade200,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Oculta',
                                        style: TextStyle(
                                          color: Colors.red.shade200,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 5),
                          Text(
                            item.subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18),
                // Separador con línea de puntos estilizada
                CustomPaint(
                  size: Size(double.infinity, 1),
                  painter: DashedLinePainter(
                    color: Colors.white.withOpacity(0.12),
                    dashWidth: 6,
                    dashSpace: 4,
                  ),
                ),
                SizedBox(height: 18),
                // Saldo con diseño mejorado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saldo disponible',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7), 
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            itemColor.withOpacity(0.22),
                            itemColor.withOpacity(0.13),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: itemColor.withOpacity(0.35),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: itemColor.withOpacity(0.15),
                            blurRadius: 8,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Text(
                        '${currencyFormat.format(balanceValue)} \$',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAccountOptions(BuildContext context, AccountItem account) {
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '', decimalDigits: 2);
    double balanceValue = double.tryParse(account.balance) ?? 0.0;
    
    // Colores base de la aplicación para mantener coherencia
    final Color primaryDark = const Color(0xFF1F2339); // Fondo principal
    final Color cardColor = const Color(0xFF222939);   // Color de tarjetas
    final Color accentColor = account.iconColor;       // Color de acento personalizado
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Opciones de cuenta",
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuart, // Curva más suave como en Home
        );
        
        return ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: animation,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.all(20),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cardColor,
                        Color.lerp(cardColor, accentColor.withOpacity(0.12), 0.25) ?? cardColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      // Sombra principal
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 25,
                        spreadRadius: -5,
                        offset: Offset(0, 10),
                      ),
                      // Sombra de acento - igual que en Home
                      BoxShadow(
                        color: accentColor.withOpacity(0.25),
                        blurRadius: 20,
                        spreadRadius: -10,
                        offset: Offset(0, 5),
                      ),
                    ],
                    border: GradientBoxBorder(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.13),
                          accentColor.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.3, 0.7, 1.0],
                      ),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cabecera con diseño de tarjeta premium
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accentColor.withOpacity(0.18),
                              accentColor.withOpacity(0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Icono con diseño premium como en Home
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        accentColor,
                                        Color.lerp(accentColor, Colors.black, 0.25) ?? accentColor,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withOpacity(0.45),
                                        blurRadius: 12,
                                        offset: const Offset(0, 3),
                                        spreadRadius: -3,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    account.icon,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                SizedBox(width: 18),
                                // Información de la cuenta
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        account.title,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Container(
                                            height: 6,
                                            width: 6,
                                            decoration: BoxDecoration(
                                              color: account.includeInTotal ? 
                                                  const Color(0xFF2ECC71) :  // Verde coherente con Home
                                                  const Color(0xFFE74C3C),   // Rojo coherente con Home
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (account.includeInTotal ? 
                                                      const Color(0xFF2ECC71) : 
                                                      const Color(0xFFE74C3C)).withOpacity(0.4),
                                                  blurRadius: 4,
                                                  spreadRadius: 0,
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            account.subtitle,
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.7),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            // Saldo con diseño tipo tarjeta de Home
                            Container(
                              padding: EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.25), // Color consistente con Home
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: accentColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.account_balance_wallet,
                                          size: 14,
                                          color: accentColor,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'SALDO DISPONIBLE',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 11,
                                          letterSpacing: 0.8,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              currencyFormat.format(balanceValue),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 28,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            SizedBox(width: 4),
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Text(
                                                '\$',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.8),
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!account.includeInTotal)
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE74C3C).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: const Color(0xFFE74C3C).withOpacity(0.2),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.visibility_off,
                                                color: const Color(0xFFE74C3C).withOpacity(0.9),
                                                size: 12,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'No incluida',
                                                style: TextStyle(
                                                  color: const Color(0xFFE74C3C).withOpacity(0.9),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Opciones con diseño igual al de Home
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2), // Consistente con Home
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Opción Editar - como en Home
                            _buildOptionButton(
                              context,
                              icon: Icons.edit_outlined,
                              text: 'Editar cuenta',
                              description: 'Modificar nombre, tipo, saldo o imagen',
                              color: const Color(0xFF3498DB), // Azul como en Home
                              onTap: () async {
                                Navigator.of(context).pop();
                                final editedAccount = await showEditAccountDialog(context, account);
                                if (editedAccount != null && editedAccount is AccountItem) {
                                  _editAccount(account, editedAccount);
                                }
                              },
                              showBorder: true,
                            ),
                            
                            // Opción Eliminar - como en Home
                            _buildOptionButton(
                              context,
                              icon: Icons.delete_outline,
                              text: 'Eliminar cuenta',
                              description: 'Eliminar permanentemente esta cuenta',
                              color: const Color(0xFFE74C3C), // Rojo como en Home
                              onTap: () {
                                Navigator.of(context).pop();
                                _showDeleteConfirmation(account);
                              },
                              showBorder: false,
                            ),
                            
                            // Botón Cancelar - como en Home
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white.withOpacity(0.7),
                                  backgroundColor: Colors.black.withOpacity(0.25),
                                  padding: EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.08),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                  'Cancelar',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                    fontSize: 16,
                                  ),
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
          ),
        );
      },
    );
  }

  Widget _buildOptionButton(
    BuildContext context,
    {
      required IconData icon,
      required String text,
      required String description,
      required Color color,
      required VoidCallback onTap,
      bool showBorder = true,
    }
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: showBorder
              ? Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
  
  void _showDeleteConfirmation(AccountItem account) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Eliminar cuenta",
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: animation,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.all(24),
                child: Container(
                  padding: EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF222232),
                        Color(0xFF1B1B29),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                        spreadRadius: -8,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.red.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                          size: 32,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '¿Eliminar esta cuenta?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'La cuenta "${account.title}" será eliminada permanentemente. Esta acción no se puede deshacer.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Las transacciones asociadas a esta cuenta ya no serán visibles.',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      Row(
                        children: [
                          // Botón Cancelar
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: Colors.white24),
                                ),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'Cancelar',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          // Botón Eliminar
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 2,
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                _deleteAccount(account);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Cuenta eliminada correctamente'),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                    margin: EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Text(
                                'Eliminar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

void main() {
  runApp(MyApp());
}
