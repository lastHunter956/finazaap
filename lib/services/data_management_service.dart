import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/category_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

/// Servicio para exportar, importar y eliminar todos los datos de la app
class DataManagementService {
  static final DataManagementService _instance = DataManagementService._internal();
  factory DataManagementService() => _instance;
  DataManagementService._internal();

  /// Generar el mapa de datos para exportación
  Future<Map<String, dynamic>> _generateExportData() async {
    final exportData = <String, dynamic>{};
      
    // 1. Exportar transacciones de Hive
    final dataBox = Hive.isBoxOpen('data') 
        ? Hive.box<Add_data>('data') 
        : await Hive.openBox<Add_data>('data');
    
    final transactions = <Map<String, dynamic>>[];
    for (var item in dataBox.values) {
      transactions.add({
        'IN': item.IN,
        'amount': item.amount,
        'datetime': item.datetime?.toIso8601String(),
        'detail': item.detail,
        'explain': item.explain,
        'name': item.name,
        'iconCode': item.iconCode,
        'installments': item.installments,
        'isInterestFree': item.isInterestFree,
      });
    }
    exportData['transactions'] = transactions;
    
    // 2. Exportar responsabilidades
    final respBox = Hive.isBoxOpen('responsibilities') 
        ? Hive.box<Responsibility>('responsibilities') 
        : await Hive.openBox<Responsibility>('responsibilities');
    
    final responsibilities = <Map<String, dynamic>>[];
    for (var item in respBox.values) {
      responsibilities.add({
        'id': item.id,
        'name': item.name,
        'amount': item.amount,
        'dueDay': item.dueDay,
        'category': item.category,
        'frequency': item.frequency,
        'isPaid': item.isPaid,
        'lastPaymentDate': item.lastPaymentDate?.toIso8601String(),
        'iconCode': item.iconCode,
        'cardLimit': item.cardLimit,
        'cardBalance': item.cardBalance,
        'minimumPayment': item.minimumPayment,
        'cutoffDay': item.cutoffDay,
        'paymentDay': item.paymentDay,
        'interestRate': item.interestRate,
        'installments': item.installments,
        'installmentPlansJson': item.installmentPlansJson,
        'paidAmountThisMonth': item.paidAmountThisMonth,
        'lastPaymentMonth': item.lastPaymentMonth,
        'lastPaymentYear': item.lastPaymentYear,
      });
    }
    exportData['responsibilities'] = responsibilities;
    
    // 3. Exportar SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final prefsData = <String, dynamic>{};
    
    prefsData['accounts'] = prefs.getStringList('accounts');
    prefsData['income_categories'] = prefs.getStringList('income_categories');
    prefsData['expense_categories'] = prefs.getStringList('expense_categories');
    prefsData['ingresos'] = prefs.getStringList('ingresos');
    prefsData['gastos'] = prefs.getStringList('gastos');
    prefsData['default_currency'] = prefs.getString('default_currency');
    
    exportData['preferences'] = prefsData;
    
    // 4. Metadatos
    exportData['metadata'] = {
      'app': 'Moneo',
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'transactionCount': transactions.length,
      'responsibilityCount': responsibilities.length,
    };

    return exportData;
  }

  /// Exportar datos permitiendo al usuario elegir la carpeta de destino
  /// Retorna la ruta del archivo guardado o null si se canceló/falló
  Future<String?> exportDataToDevice() async {
    try {
      // 1. Elegir directorio
      String? outputDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Seleccionar carpeta para guardar backup',
      );

      if (outputDir == null) {
        // Usuario canceló la selección de carpeta
        return null;
      }

      // 2. Generar datos
      final exportData = await _generateExportData();
      final jsonString = jsonEncode(exportData);

      // 3. Guardar archivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'moneo_backup_$timestamp.json';
      final file = File('$outputDir/$fileName');
      
      await file.writeAsString(jsonString);
      return file.path;
      
    } catch (e) {
      print('❌ Error exportando a carpeta: $e');
      // Fallback: Si falla getDirectoryPath (común en ciertos Androids), intentar Share
      return null;
    }
  }

  /// Método fallback para usar Share (si el usuario lo prefiere o falla lo anterior)
  Future<bool> exportAndShareData() async {
    try {
      final exportData = await _generateExportData();
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/moneo_backup_$timestamp.json');
      await file.writeAsString(jsonEncode(exportData));
      
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Moneo Backup',
        text: 'Respaldo de datos de Moneo',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Importar datos desde un archivo JSON seleccionado por el usuario
  Future<Map<String, dynamic>> importData() async {
    try {
      // Seleccionar archivo
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      
      if (result == null || result.files.isEmpty) {
        return {'success': false, 'message': 'No se seleccionó ningún archivo'};
      }
      
      String? content;
      final fileBytes = result.files.single.bytes;
      
      if (fileBytes != null) {
        content = utf8.decode(fileBytes);
      } else {
        // Fallback para cuando bytes no está disponible (ruta física)
        final filePath = result.files.single.path;
        if (filePath == null) {
          return {'success': false, 'message': 'No se pudo leer el archivo'};
        }
        final file = File(filePath);
        content = await file.readAsString();
      }
      
      return await _processImport(content);
    } catch (e) {
      return {'success': false, 'message': 'Error al importar: $e'};
    }
  }

  /// Procesar el contenido JSON importado
  Future<Map<String, dynamic>> _processImport(String jsonContent) async {
    try {
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      
      // Validar que sea un backup de Moneo
      final metadata = data['metadata'] as Map<String, dynamic>?;
      if (metadata == null || metadata['app'] != 'Moneo') {
        return {'success': false, 'message': 'Archivo no válido. No es un backup de Moneo.'};
      }
      
      int transactionsImported = 0;
      int responsibilitiesImported = 0;
      
      // 1. Importar transacciones (Append)
      final transactions = data['transactions'] as List<dynamic>?;
      if (transactions != null) {
        final dataBox = Hive.isBoxOpen('data') 
            ? Hive.box<Add_data>('data') 
            : await Hive.openBox<Add_data>('data');
        
        for (var item in transactions) {
          final transaction = Add_data(
            item['IN'],
            item['amount'],
            item['datetime'] != null ? DateTime.tryParse(item['datetime']) : null,
            item['detail'],
            item['explain'],
            item['name'],
            item['iconCode'] ?? 0,
            item['installments'] ?? '1',
            item['isInterestFree'] ?? false,
          );
          
          await dataBox.add(transaction);
          transactionsImported++;
        }
      }
      
      // 2. Importar responsabilidades (Append)
      final responsibilities = data['responsibilities'] as List<dynamic>?;
      if (responsibilities != null) {
        final respBox = Hive.isBoxOpen('responsibilities') 
            ? Hive.box<Responsibility>('responsibilities') 
            : await Hive.openBox<Responsibility>('responsibilities');
        
        for (var item in responsibilities) {
          final resp = Responsibility(
            id: item['id'],
            name: item['name'],
            amount: item['amount']?.toDouble(),
            dueDay: item['dueDay'],
            category: item['category'],
            frequency: item['frequency'],
            isPaid: item['isPaid'],
            lastPaymentDate: item['lastPaymentDate'] != null 
                ? DateTime.tryParse(item['lastPaymentDate']) 
                : null,
            iconCode: item['iconCode'],
            cardLimit: item['cardLimit']?.toDouble(),
            cardBalance: item['cardBalance']?.toDouble(),
            minimumPayment: item['minimumPayment']?.toDouble(),
            cutoffDay: item['cutoffDay'],
            paymentDay: item['paymentDay'],
            interestRate: item['interestRate']?.toDouble(),
            installments: item['installments'],
            installmentPlansJson: item['installmentPlansJson'] != null 
                ? List<String>.from(item['installmentPlansJson']) 
                : null,
            paidAmountThisMonth: item['paidAmountThisMonth']?.toDouble(),
            lastPaymentMonth: item['lastPaymentMonth'],
            lastPaymentYear: item['lastPaymentYear'],
          );
          
          await respBox.add(resp);
          responsibilitiesImported++;
        }
      }
      
      // 3. Importar preferencias (MERGE)
      final prefsData = data['preferences'] as Map<String, dynamic>?;
      if (prefsData != null) {
        final prefs = await SharedPreferences.getInstance();
        
        // Helper para mezclar listas de strings
        Future<void> mergeStringList(String key, List<dynamic>? newItems) async {
           if (newItems == null) return;
           final current = prefs.getStringList(key) ?? [];
           bool changed = false;
           for (var item in newItems) {
              if (item is String && !current.contains(item)) {
                 current.add(item);
                 changed = true;
              }
           }
           if (changed) await prefs.setStringList(key, current);
        }

        // Cuentas y Categorías Simples
        await mergeStringList('accounts', prefsData['accounts']);
        await mergeStringList('income_categories', prefsData['income_categories']);
        await mergeStringList('expense_categories', prefsData['expense_categories']);
        
        // Categorías con Metadatos (JSON List) - Verificar unicidad por 'text'
        Future<void> mergeJsonList(String key, List<dynamic>? newItems) async {
            if (newItems == null) return;
            final currentStrs = prefs.getStringList(key) ?? [];
            
            // Extraer nombres existentes para evitar duplicados visuales
            final existingNames = <String>{};
            for (var s in currentStrs) {
                try {
                    existingNames.add(jsonDecode(s)['text']);
                } catch (_) {}
            }
            
            bool changed = false;
            for (var itemStr in newItems) {
               if (itemStr is String) {
                  try {
                     final map = jsonDecode(itemStr) as Map<String, dynamic>;
                     if (!existingNames.contains(map['text'])) {
                        currentStrs.add(itemStr);
                        existingNames.add(map['text']);
                        changed = true;
                     }
                  } catch (e) {
                     // Ignorar items mal formados
                  }
               }
            }
            if (changed) await prefs.setStringList(key, currentStrs);
        }

        await mergeJsonList('ingresos', prefsData['ingresos']);
        await mergeJsonList('gastos', prefsData['gastos']);

        if (prefsData['default_currency'] != null && !prefs.containsKey('default_currency')) {
          await prefs.setString('default_currency', prefsData['default_currency']);
        }
      }
      
      // 4. Limpieza y Sincronización de Categorías
      // Esto asegura que las categorías importadas se reflejen correctamente en el sistema
      await CategoryService.cleanupCategories();
      
      return {
        'success': true,
        'message': 'Importación completada',
        'transactionsImported': transactionsImported,
        'responsibilitiesImported': responsibilitiesImported,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error al procesar: $e'};
    }
  }

  /// Eliminar TODOS los datos de la app
  Future<bool> deleteAllData() async {
    try {
      // 1. Limpiar Hive boxes
      final dataBox = Hive.isBoxOpen('data') 
          ? Hive.box<Add_data>('data') 
          : await Hive.openBox<Add_data>('data');
      await dataBox.clear();
      
      final respBox = Hive.isBoxOpen('responsibilities') 
          ? Hive.box<Responsibility>('responsibilities') 
          : await Hive.openBox<Responsibility>('responsibilities');
      await respBox.clear();
      
      // Limpiar otras boxes si existen
      try {
        if (Hive.isBoxOpen('transactions_v2')) {
          await Hive.box('transactions_v2').clear();
        }
        if (Hive.isBoxOpen('accounts')) {
          await Hive.box('accounts').clear();
        }
        if (Hive.isBoxOpen('accounts_v2')) {
          await Hive.box('accounts_v2').clear();
        }
      } catch (e) {
        // Ignorar si no existen
      }
      
      // 2. Limpiar SharedPreferences (excepto configuración de seguridad)
      final prefs = await SharedPreferences.getInstance();
      
      // Limpiar datos financieros
      await prefs.remove('accounts');
      await prefs.remove('income_categories');
      await prefs.remove('expense_categories');
      await prefs.remove('ingresos');
      await prefs.remove('gastos');
      await prefs.remove('deleted_income_categories');
      await prefs.remove('deleted_expense_categories');
      await prefs.remove('available_balance');
      
      return true;
    } catch (e) {
      return false;
    }
  }
}
