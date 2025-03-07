import 'package:flutter/material.dart';
import 'package:finazaap/screens/add.dart';
import 'package:finazaap/screens/add_expense.dart';
import 'package:finazaap/screens/transfer.dart';

class FloatingActionMenuScreen extends StatelessWidget {
  const FloatingActionMenuScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF242535), // Fondo oscuro para mantener el tema
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        // Alineamos todo el contenido hacia la esquina inferior derecha
        child: Align(
          alignment: Alignment.bottomRight,
          child: Column(
            mainAxisSize: MainAxisSize.min,  // Para que ocupe solo el espacio necesario
            crossAxisAlignment: CrossAxisAlignment.end,  // Alinea los elementos a la derecha
            children: [
              // Botón de Ingreso con texto cercano
              _buildActionRow(
                text: 'Ingreso',
                icon: Icons.arrow_upward,
                color: Colors.greenAccent,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const Add_Screen()),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // Botón de Transferencia con texto cercano
              _buildActionRow(
                text: 'Transferir',
                icon: Icons.sync_alt,
                color: Colors.indigoAccent,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => TransferScreen()),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // Botón de Egreso con texto cercano
              _buildActionRow(
                text: 'Egreso',
                icon: Icons.arrow_downward_outlined,
                color: Colors.orangeAccent,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
                  );
                },
              ),
              
              const SizedBox(height: 30),
              
              // Botón X para volver al menú principal (ahora a la derecha)
              Row(
                mainAxisSize: MainAxisSize.min, // Solo ocupa el espacio necesario
                children: [
                  // Texto descriptivo del botón Cerrar
                  Container(
                    margin: const EdgeInsets.only(right: 15),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Cerrar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  // Botón X alineado a la derecha con el mismo estilo
                  FloatingActionButton(
                    backgroundColor: Colors.grey.shade700, // Color más neutral como los otros botones
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              
              const SizedBox(height: 20), // Espacio al fondo para mejorar apariencia
            ],
          ),
        ),
      ),
    );
  }

  // Widget para construir cada fila de acción con texto cercano al botón
  Widget _buildActionRow({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,  // Solo ocupa el espacio necesario
      children: [
        // Texto descriptivo cerca del botón
        Container(
          margin: const EdgeInsets.only(right: 15),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        
        // Botón flotante a la derecha
        FloatingActionButton(
          backgroundColor: color,
          onPressed: onPressed,
          child: Icon(icon),
        ),
      ],
    );
  }
}