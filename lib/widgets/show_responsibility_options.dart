import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/icon_lists.dart';
import 'package:finazaap/data/credit_card_calculator.dart';
import 'package:finazaap/utils/currency_helper.dart';

void showResponsibilityOptions({
  required BuildContext context,
  required Responsibility responsibility,
  required Function(Responsibility) onEdit,
  required Function(Responsibility) onDelete,
  required Function(Responsibility) onPay,
  required int selectedMonth,
  required int selectedYear,
}) {
  final bool isPaid = responsibility.safeIsPaid;
  final bool isCard = responsibility.safeCategory == 'tarjeta';
  final String title = responsibility.safeName;
  final double amount = responsibility.getAmountForDate(selectedMonth, selectedYear);
  final String formattedAmount = CurrencyHelper.format(amount);
  
  Color categoryColor = const Color(0xFF3D7AF0);
  if (responsibility.safeCategory == 'tarjeta') categoryColor = const Color(0xFFEF4444);
  if (responsibility.safeCategory == 'préstamo') categoryColor = const Color(0xFFF59E0B);
  if (responsibility.safeCategory == 'membresía') categoryColor = const Color(0xFF8B5CF6);

  final Gradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      categoryColor.withOpacity(0.12),
      categoryColor.withOpacity(0.04),
    ],
  );

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Opciones de obligación",
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
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.88,
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: const Color(0xFF222939),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: categoryColor.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(
                    color: categoryColor.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cabecera
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(gradient: backgroundGradient),
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        child: Column(
                          children: [
                            Container(
                              height: 65,
                              width: 65,
                              decoration: BoxDecoration(
                                color: categoryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: categoryColor.withOpacity(0.5), width: 1.5),
                              ),
                              child: Icon(
                                IconData(responsibility.safeIconCode, fontFamily: 'MaterialIcons'),
                                size: 30,
                                color: categoryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              responsibility.safeCategory.toUpperCase(),
                              style: TextStyle(
                                color: categoryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              formattedAmount,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: categoryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Acciones
                      FutureBuilder<bool>(
                        future: isCard 
                            ? CreditCardCalculator.isAccountOrphaned(responsibility.safeName)
                            : Future.value(false),
                        builder: (context, snapshot) {
                          final isOrphaned = snapshot.data ?? false;
                          
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                // Mostrar alerta si es huérfana
                                if (isCard && isOrphaned)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE53935).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE53935).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          color: Color(0xFFE53935),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        const Expanded(
                                          child: Text(
                                            'Esta cuenta fue eliminada. Puedes eliminar esta responsabilidad.',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                Row(
                                  children: [
                                    if (!isCard) ...[
                                      // Botón Editar
                                      _buildActionButton(
                                        label: 'Editar',
                                        icon: Icons.edit_rounded,
                                        color: const Color(0xFFFFA726),
                                        onTap: () {
                                          Navigator.pop(context);
                                          onEdit(responsibility);
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    
                                    // Botón Pagar (o Pagar Cuota para tarjetas) - Solo si NO es huérfana
                                    if (!isOrphaned)
                                      _buildActionButton(
                                        label: isCard 
                                            ? 'Pagar Cuota' 
                                            : (isPaid ? 'Desmarcar' : 'Pagar'),
                                        icon: isCard 
                                            ? Icons.payment_rounded 
                                            : (isPaid ? Icons.undo_rounded : Icons.check_circle_rounded),
                                        color: isCard 
                                            ? const Color(0xFF3D7AF0)
                                            : (isPaid ? Colors.blueAccent : Colors.greenAccent),
                                        onTap: () {
                                          Navigator.pop(context);
                                          onPay(responsibility);
                                        },
                                      ),

                                    // Botón Eliminar - Para no-tarjetas O tarjetas huérfanas
                                    if (!isCard || isOrphaned) ...[
                                      const SizedBox(width: 12),
                                      _buildActionButton(
                                        label: isOrphaned ? 'Eliminar Tarjeta' : 'Borrar',
                                        icon: Icons.delete_rounded,
                                        color: const Color(0xFFE53935),
                                        onTap: () {
                                          Navigator.pop(context);
                                          onDelete(responsibility);
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      // Pie
                      Container(
                        width: double.infinity,
                        color: Colors.black.withOpacity(0.2),
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.close_rounded, size: 16, color: Colors.white.withOpacity(0.7)),
                                const SizedBox(width: 6),
                                Text(
                                  'Cerrar',
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildActionButton({
  required String label,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 75,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    ),
  );
}
