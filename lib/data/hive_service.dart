import 'package:hive_flutter/hive_flutter.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/utlity.dart';

class HiveService {
  static bool _initialized = false;
  
  /// Inicializa Hive y registra adaptadores
  static Future<void> initialize() async {
    if (_initialized) return;
    
    await Hive.initFlutter();
    
    // Registrar adaptadores solo si no están registrados
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
    
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(AccountItemAdapter());
    }
    
    _initialized = true;
  }
  
  /// Abre una caja específica
  static Future<Box<T>> openBox<T>(String boxName) async {
    // Verificar si Hive está inicializado
    if (!_initialized) {
      await initialize();
    }
    
    // Si la caja está abierta pero con tipo incorrecto, cerrarla primero
    if (Hive.isBoxOpen(boxName)) {
      try {
        if (Hive.box(boxName) is! Box<T>) {
          await Hive.box(boxName).close();
        } else {
          return Hive.box<T>(boxName);
        }
      } catch (e) {
        await Hive.box(boxName).close();
      }
    }
    
    // Abrir la caja con el tipo correcto
    return await Hive.openBox<T>(boxName);
  }
  
  /// Obtiene un ValueListenable para escuchar cambios en una caja
  static ValueListenable<Box<T>> getBoxListenable<T>(String boxName) {
    if (!Hive.isBoxOpen(boxName)) {
      throw Exception('La caja $boxName no está abierta');
    }
    return Hive.box<T>(boxName).listenable();
  }

  /// Método simple para abrir una caja de datos
  static Future<Box<Add_data>> openDataBox() async {
    return await openBox<Add_data>('data');
  }
}

// En add.dart, reemplaza el método _saveTransaction
Future<void> _saveTransaction() async {
  // Validaciones básicas
  if (_amountCtrl.text.isEmpty || _selectedAccount == null || _selectedCategory == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Por favor completa todos los campos')),
    );
    return;
  }

  try {
    final amount = double.parse(_amountCtrl.text);
    final int categoryIconCode = _getCategoryIconCode(_selectedCategory!);
    
    // Crear objeto de transacción
    final Add_data transaction = Add_data(
      'Income',
      _amountCtrl.text,
      _selectedDate,
      _detailCtrl.text,
      _selectedCategory!,
      _selectedAccount!.title,
      categoryIconCode,
    );
    
    // Abrir la caja de Hive
    final box = await Hive.openBox<Add_data>('data');
    
    // Proceso según modo edición o creación
    if (widget.isEditing && widget.transaction != null && widget.transactionKey != null) {
      // En edición, primero revertir la transacción anterior
      bool revertSuccess = await AccountUtils.revertTransaction(widget.transaction!);
      
      if (!revertSuccess) {
        throw Exception('Error al revertir la transacción anterior');
      }
      
      // Aplicar nueva transacción
      bool updateSuccess = await AccountUtils.updateAccountBalance(
        _selectedAccount!.title, 
        amount, 
        true // Ingreso siempre suma
      );
      
      if (updateSuccess) {
        box.put(widget.transactionKey, transaction);
      } else {
        throw Exception('Error al actualizar el saldo de la cuenta');
      }
    } else {
      // En creación, simplemente actualizar saldo y añadir
      bool updateSuccess = await AccountUtils.updateAccountBalance(
        _selectedAccount!.title, 
        amount, 
        true // Ingreso siempre suma
      );
      
      if (updateSuccess) {
        box.add(transaction);
      } else {
        throw Exception('Error al actualizar el saldo de la cuenta');
      }
    }

    // Notificar a la pantalla principal
    if (widget.onTransactionUpdated != null) {
      widget.onTransactionUpdated!();
    }
    
    // Navegar de vuelta
    if (mounted) {
      Navigator.pop(context);
    }
  } catch (e) {
    print('Error al guardar: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
    );
  }
}

Future<void> _saveTransfer() async {
  if (_amountCtrl.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Por favor ingresa un monto')),
    );
    return;
  }

  if (_selectedSourceAccount == null || _selectedDestinationAccount == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Por favor selecciona cuentas')),
    );
    return;
  }

  // Verificar que no sean la misma cuenta
  if (_selectedSourceAccount!.title == _selectedDestinationAccount!.title) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No puedes transferir a la misma cuenta')),
    );
    return;
  }

  try {
    setState(() {
      _isProcessing = true;
    });

    final amount = double.parse(_amountCtrl.text);
    
    // Crear objeto de transferencia
    final Add_data transferTransaction = Add_data(
      'Transfer',
      _amountCtrl.text,
      _selectedDate,
      _detailCtrl.text,
      '${_selectedSourceAccount!.title} > ${_selectedDestinationAccount!.title}',
      '',
      Icons.sync_alt.codePoint,
    );

    // Abrir la caja de Hive
    final box = await Hive.openBox<Add_data>('data');
    
    // Proceso según modo edición o creación
    if (widget.isEditing && widget.transaction != null && widget.transactionKey != null) {
      // En edición, primero revertir la transferencia anterior
      bool revertSuccess = await AccountUtils.revertTransaction(widget.transaction!);
      
      if (!revertSuccess) {
        throw Exception('Error al revertir la transferencia anterior');
      }
      
      // Aplicar nueva transferencia
      bool transferSuccess = await AccountUtils.processTransfer(
        _selectedSourceAccount!.title,
        _selectedDestinationAccount!.title,
        amount
      );
      
      if (transferSuccess) {
        box.put(widget.transactionKey, transferTransaction);
      } else {
        throw Exception('Error al procesar la transferencia');
      }
    } else {
      // En creación, simplemente procesar la transferencia
      bool transferSuccess = await AccountUtils.processTransfer(
        _selectedSourceAccount!.title,
        _selectedDestinationAccount!.title,
        amount
      );
      
      if (transferSuccess) {
        box.add(transferTransaction);
      } else {
        throw Exception('Error al procesar la transferencia');
      }
    }

    // Notificar a la pantalla principal
    if (widget.onTransactionUpdated != null) {
      widget.onTransactionUpdated!();
    }

    // Finalizar
    setState(() {
      _isProcessing = false;
    });
    
    // Navegar de vuelta
    if (mounted) {
      Navigator.pop(context);
    }
  } catch (e) {
    setState(() {
      _isProcessing = false;
    });
    
    print('Error al procesar transferencia: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
    );
  }
}

void _confirmDeleteTransaction(Add_data transaction) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF2A2A3A),
      title: const Text('Confirmar eliminación', style: TextStyle(color: Colors.white)),
      content: const Text(
        '¿Estás seguro de que quieres eliminar esta transacción?',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.blueAccent)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
          ),
          onPressed: () {
            Navigator.pop(context);
            _deleteTransaction(transaction);
          },
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
}

void _deleteTransaction(Add_data transaction) async {
  try {
    // Revertir el efecto de la transacción en los saldos
    bool revertSuccess = await AccountUtils.revertTransaction(transaction);
    
    if (!revertSuccess) {
      throw Exception('Error al revertir la transacción');
    }
    
    // Eliminar la transacción de Hive
    await transaction.delete();
    
    // Actualizar UI
    setState(() {});
    
    // Mostrar confirmación
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transacción eliminada'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    print('Error al eliminar transacción: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error al eliminar: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Future<void> _updateAvailableBalance() async {
  await AccountUtils.updateTotalBalance();
  setState(() {});
}

appBar: AppBar(
  backgroundColor: const Color.fromARGB(255, 31, 38, 57),
  elevation: 0,
  centerTitle: true,
  title: const Text(
    'Informes',
    style: TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.bold,
    ),
  ),
  actions: [
    // Botón de recarga manual
    IconButton(
      icon: const Icon(Icons.refresh, color: Colors.white),
      onPressed: () {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos actualizados')),
        );
      },
    ),
  ],
),