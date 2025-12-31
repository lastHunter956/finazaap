// Reemplaza las importaciones conflictivas por estas líneas:
import 'package:flutter/material.dart';
import 'package:finazaap/utils/app_icons.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:finazaap/widgets/total_balance_widget.dart';
import 'package:finazaap/widgets/transaction_list_widget.dart';
import 'package:finazaap/widgets/floating_action_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:collection';
import 'package:finazaap/Screens/home.dart';
import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/data/model/add_date.dart';


void showTransactionOptions(Add_data transaction, BuildContext _context, Function(Add_data) _editTransaction, Function(Add_data) _confirmDeleteTransaction) {
  // Preparar datos de la transacción
  final bool isTransfer = transaction.IN == 'Transfer';
  final bool isIncome = transaction.IN == 'Income';
  final String transactionTitle = transaction.detail.isNotEmpty 
      ? transaction.detail 
      : (isTransfer ? 'Transferencia' : transaction.explain);
  final String formattedAmount = NumberFormat.currency(locale: 'es', symbol: '\$')
      .format(double.parse(transaction.amount));
  

  
  showGeneralDialog(
    context: _context,
    barrierDismissible: true,
    barrierLabel: "Opciones de transacción",
    barrierColor: Colors.black.withOpacity(0.7),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => Container(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuint,
      );
      
      return ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
        child: FadeTransition(
          opacity: animation,
          child: FutureBuilder<int?>(
            future: _getCategoryColor(transaction.IN, transaction.explain),
            builder: (context, snapshot) {
              // Definir color basado en el snapshot o defaults
              final Color defaultColor = isTransfer 
                  ? const Color(0xFF3D7AF0)  // Azul refinado
                  : (isIncome ? const Color(0xFF2E9E5B) : const Color(0xFFE53935));
                  
              final Color primaryColor = defaultColor; // Force default color (Red/Green)
              // Ignoramos snapshot.data para cumplir requerimiento de usar rojo/verde
              // final Color primaryColor = snapshot.data != null 
              //    ? Color(snapshot.data!) 
              //    : defaultColor;

              final Gradient backgroundGradient = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withOpacity(0.12),
                  primaryColor.withOpacity(0.04),
                ],
              );
              
              return Center(
                child: Material(
                  color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.88,
                constraints: BoxConstraints(
                  maxWidth: 400, // Limitar ancho máximo
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF222939),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      spreadRadius: -5,
                    ),
                    BoxShadow(
                      color: primaryColor.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 5),
                      spreadRadius: -2,
                    ),
                  ],
                  border: Border.all(
                    color: primaryColor.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ===== CABECERA =====
                              Container(
                                decoration: BoxDecoration(
                                  gradient: backgroundGradient,
                                ),
                                child: Stack(
                                  children: [
                                    // Decoración de fondo
                                    Positioned(
                                      right: -20,
                                      top: -20,
                                      child: CircleAvatar(
                                        radius: 60,
                                        backgroundColor: primaryColor.withOpacity(0.05),
                                      ),
                                    ),
                                    
                                    // Contenido de la cabecera
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                                      child: Column(
                                        children: [
                                          // Icono principal
                                          Container(
                                            height: 65,
                                            width: 65,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  primaryColor.withOpacity(0.2),
                                                  primaryColor.withOpacity(0.1),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(50),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: primaryColor.withOpacity(0.2),
                                                  blurRadius: 15,
                                                  spreadRadius: 0,
                                                ),
                                              ],
                                              border: Border.all(
                                                color: primaryColor.withOpacity(0.5),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Icon(
                                              transaction.iconCode != 0 
                                                  ? AppIcons.getIcon(transaction.iconCode)
                                                  : (isTransfer ? Icons.swap_horiz_rounded : 
                                                      (isIncome ? Icons.north_rounded : Icons.south_rounded)),
                                              size: 30,
                                              color: primaryColor,
                                            ),
                                          ),
                                          
                                          const SizedBox(height: 20),
                                          
                                          // Título de la transacción
                                          Text(
                                            transactionTitle,
                                            style: const TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.2,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          
                                          const SizedBox(height: 16),
                                          
                                          // Tipo de transacción
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14, 
                                              vertical: 6
                                            ),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: primaryColor.withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              isTransfer ? "Transferencia" : 
                                              (isIncome ? "Ingreso" : "Gasto"),
                                              style: TextStyle(
                                                color: primaryColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                          
                                          const SizedBox(height: 18),
                                          
                                          // Monto destacado
                                          Text(
                                            formattedAmount,
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w700,
                                              color: primaryColor,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          
                                          const SizedBox(height: 16),
                                          
                                          // Información de cuenta y categoría
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.05),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(0.1),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                // Sección de Cuenta (Siempre visible)
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        isTransfer ? "Ruta" : "Cuenta",
                                                        style: TextStyle(
                                                          color: Colors.white.withOpacity(0.6),
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            isTransfer ? Icons.compare_arrows_rounded : Icons.account_balance_wallet,
                                                            size: 16,
                                                            color: primaryColor.withOpacity(0.8),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              isTransfer ? transaction.explain : transaction.name,
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 14,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                
                                                // Sección de Categoría (Solo para Ingresos/Gastos)
                                                if (!isTransfer) ...[
                                                  const SizedBox(width: 12),
                                                  Container(
                                                    width: 1, 
                                                    height: 30, 
                                                    color: Colors.white.withOpacity(0.1)
                                                  ),
                                                  const SizedBox(width: 12),
                                                  
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          "Categoría",
                                                          style: TextStyle(
                                                            color: Colors.white.withOpacity(0.6),
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons.category_rounded, // O usar el icono específico
                                                              size: 16,
                                                              color: primaryColor.withOpacity(0.8),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Expanded(
                                                              child: Text(
                                                                transaction.explain,
                                                                style: const TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: 14,
                                                                  fontWeight: FontWeight.w600,
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          
                                          const SizedBox(height: 10),

                                          // Información de cuotas e intereses (si aplica)
                                          if ((transaction.installments != null && transaction.installments != '1' && transaction.installments!.isNotEmpty) || 
                                              (transaction.isInterestFree == true))
                                          Container(
                                            width: double.infinity,
                                            margin: const EdgeInsets.only(bottom: 10),
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.05),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(0.1),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                // Cuotas
                                                if (transaction.installments != null && transaction.installments != '1' && transaction.installments!.isNotEmpty)
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        "Cuotas",
                                                        style: TextStyle(
                                                          color: Colors.white.withOpacity(0.6),
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.layers_rounded,
                                                            size: 16,
                                                            color: Colors.blueAccent.withOpacity(0.8),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            "${transaction.installments}",
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                
                                                // Sin Intereses
                                                if (transaction.isInterestFree == true)
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        "Intereses",
                                                        style: TextStyle(
                                                          color: Colors.white.withOpacity(0.6),
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.check_circle_outline_rounded,
                                                            size: 16,
                                                            color: Colors.greenAccent.withOpacity(0.8),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          const Text(
                                                            "Sin interés",
                                                            style: TextStyle(
                                                              color: Colors.greenAccent,
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w600,
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
                                          
                                          // Fecha y hora
                                          Container(
                                            width: double.infinity,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.access_time_rounded,
                                                  size: 14,
                                                  color: Colors.white.withOpacity(0.5),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  DateFormat('dd/MM/yyyy - HH:mm').format(transaction.datetime),
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.5),
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // ===== ACCIONES =====
                              Container(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    // Botón Editar - Adaptable
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(18),
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.pop(context);
                                            _editTransaction(transaction);
                                          },
                                          borderRadius: BorderRadius.circular(18),
                                          splashColor: const Color(0xFFFFA726).withOpacity(0.2),
                                          highlightColor: const Color(0xFFFFA726).withOpacity(0.1),
                                          child: Ink(
                                            height: 75, // Solo fijar altura, ancho adaptable
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  const Color(0xFFFFA726).withOpacity(0.2),
                                                  const Color(0xFFFFA726).withOpacity(0.08),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(18),
                                              border: Border.all(
                                                color: const Color(0xFFFFA726).withOpacity(0.3),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.edit_rounded,
                                                  size: 24,
                                                  color: const Color(0xFFFFA726),
                                                ),
                                                const SizedBox(height: 6),
                                                const Text(
                                                  'Editar',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFFFFA726),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                            
                                    const SizedBox(width: 15), // Reducido el espacio entre botones
                                            
                                    // Botón Eliminar - Adaptable
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(18),
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.pop(context);
                                            _confirmDeleteTransaction(transaction);
                                          },
                                          borderRadius: BorderRadius.circular(18),
                                          splashColor: const Color(0xFFE53935).withOpacity(0.2),
                                          highlightColor: const Color(0xFFE53935).withOpacity(0.1),
                                          child: Ink(
                                            height: 75, // Solo fijar altura, ancho adaptable
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  const Color(0xFFE53935).withOpacity(0.2),
                                                  const Color(0xFFE53935).withOpacity(0.08),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(18),
                                              border: Border.all(
                                                color: const Color(0xFFE53935).withOpacity(0.3),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.delete_rounded,
                                                  size: 24,
                                                  color: const Color(0xFFE53935),
                                                ),
                                                const SizedBox(height: 6),
                                                const Text(
                                                  'Eliminar',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFFE53935),
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
                              ),
                            ],
                          ),
                        ),
                      ),                // ===== PIE DE DIÁLOGO =====
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Cerrar',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.3,
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
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
},
  );
}

Future<int?> _getCategoryColor(String type, String categoryName) async {
  if (type == 'Transfer') return null; // Use default transfer color
  
  try {
    // Import CategoryService is needed, assuming it's imported or available
    // We need to add import 'package:finazaap/data/category_service.dart';
    final categories = await CategoryService.getCategoriesWithMetadata(type);
    final category = categories.firstWhere(
      (cat) => cat['text'] == categoryName, 
      orElse: () => {},
    );
    
    if (category.isNotEmpty && category['color'] != null) {
      return category['color'] as int;
    }
  } catch (e) {
    debugPrint('Error loading category color: $e');
  }
  return null;
}