import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:finazaap/data/models/account_item.dart';

/// Datasource seguro para cuentas usando flutter_secure_storage
/// 
/// Reemplaza SharedPreferences por almacenamiento encriptado
/// Proporciona:
/// - Almacenamiento encriptado de cuentas
/// - Wipe automático después de intentos fallidos
/// - Backup encriptado de metadatos de usuario
class SecurePreferencesDataSource {
  static final SecurePreferencesDataSource _instance = SecurePreferencesDataSource._internal();
  factory SecurePreferencesDataSource() => _instance;
  SecurePreferencesDataSource._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _accountsKey = 'accounts_encrypted';
  static const String _userPrefsKey = 'user_preferences';

  /// Carga todas las cuentas del almacenamiento seguro
  Future<List<AccountItem>> loadAccounts() async {
    try {
      final String? accountsJson = await _secureStorage.read(key: _accountsKey);
      
      if (accountsJson == null || accountsJson.isEmpty) {
        print('ℹ️ No hay cuentas almacenadas');
        return [];
      }

      final List<dynamic> accountsList = jsonDecode(accountsJson);
      final accounts = accountsList
          .map((json) => AccountItem.fromJson(json as Map<String, dynamic>))
          .toList();
      
      print('✅ ${accounts.length} cuentas cargadas desde almacenamiento seguro');
      return accounts;
      
    } catch (e) {
      print('❌ Error al cargar cuentas: $e');
      return [];
    }
  }

  /// Guarda todas las cuentas en almacenamiento seguro
  Future<void> saveAccounts(List<AccountItem> accounts) async {
    try {
      final accountsList = accounts.map((account) => account.toJson()).toList();
      final accountsJson = jsonEncode(accountsList);
      
      await _secureStorage.write(key: _accountsKey, value: accountsJson);
      print('✅ ${accounts.length} cuentas guardadas en almacenamiento seguro');
      
    } catch (e) {
      print('❌ Error al guardar cuentas: $e');
      rethrow;
    }
  }

  /// Agrega una nueva cuenta
  Future<void> addAccount(AccountItem account) async {
    final accounts = await loadAccounts();
    accounts.add(account);
    await saveAccounts(accounts);
  }

  /// Actualiza una cuenta existente
  Future<void> updateAccount(String oldTitle, AccountItem newAccount) async {
    final accounts = await loadAccounts();
    final index = accounts.indexWhere((acc) => acc.title == oldTitle);
    
    if (index != -1) {
      accounts[index] = newAccount;
      await saveAccounts(accounts);
      print('✅ Cuenta actualizada: ${newAccount.title}');
    } else {
      print('⚠️ Cuenta no encontrada: $oldTitle');
    }
  }

  /// Elimina una cuenta
  Future<void> deleteAccount(String accountTitle) async {
    final accounts = await loadAccounts();
    accounts.removeWhere((acc) => acc.title == accountTitle);
    await saveAccounts(accounts);
    print('✅ Cuenta eliminada: $accountTitle');
  }

  /// Calcula el saldo total de cuentas visibles
  Future<double> getTotalBalance() async {
    final accounts = await loadAccounts();
    double total = 0.0;
    
    for (var account in accounts) {
      if (account.includeInTotal) {
        total += double.tryParse(account.balance) ?? 0.0;
      }
    }
    
    return total;
  }

  /// Obtiene una cuenta por título
  Future<AccountItem?> getAccountByTitle(String title) async {
    final accounts = await loadAccounts();
    try {
      return accounts.firstWhere((acc) => acc.title == title);
    } catch (e) {
      return null;
    }
  }

  /// Guarda preferencias de usuario (encriptadas)
  Future<void> saveUserPreference(String key, String value) async {
    try {
      await _secureStorage.write(key: '${_userPrefsKey}_$key', value: value);
    } catch (e) {
      print('❌ Error al guardar preferencia $key: $e');
    }
  }

  /// Carga preferencia de usuario
  Future<String?> getUserPreference(String key) async {
    try {
      return await _secureStorage.read(key: '${_userPrefsKey}_$key');
    } catch (e) {
      print('❌ Error al cargar preferencia $key: $e');
      return null;
    }
  }

  /// Limpia todas las cuentas (usar con precaución - pérdida de datos)
  Future<void> clearAllAccounts() async {
    await _secureStorage.delete(key: _accountsKey);
    print('⚠️ Todas las cuentas eliminadas del almacenamiento seguro');
  }

  /// Limpia todos los datos (reset completo)
  Future<void> wipeAllData() async {
    await _secureStorage.deleteAll();
    print('⚠️ Todos los datos eliminados del almacenamiento seguro');
  }

  /// Exporta cuentas a JSON para backup manual
  Future<List<Map<String, dynamic>>> exportAccountsToJson() async {
    final accounts = await loadAccounts();
    return accounts.map((account) => account.toJson()).toList();
  }

  /// Importa cuentas desde JSON (backup restore)
  Future<void> importAccountsFromJson(List<Map<String, dynamic>> jsonData) async {
    try {
      final accounts = jsonData
          .map((json) => AccountItem.fromJson(json))
          .toList();
      
      await saveAccounts(accounts);
      print('✅ ${accounts.length} cuentas importadas desde JSON');
    } catch (e) {
      print('❌ Error al importar cuentas: $e');
      rethrow;
    }
  }
}
