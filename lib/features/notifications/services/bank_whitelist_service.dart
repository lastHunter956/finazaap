import 'dart:collection';
import 'package:shared_preferences/shared_preferences.dart';

/// Metadatos asociados a una entidad bancaria o billetera soportada.
class BankMetadata {
  final String packageName;
  final String name;
  final String country;
  final bool isDefault;

  const BankMetadata({
    required this.packageName,
    required this.name,
    this.country = 'CO',
    this.isDefault = true,
  });

  Map<String, dynamic> toJson() => {
        'package_name': packageName,
        'name': name,
        'country': country,
        'is_default': isDefault,
      };

  factory BankMetadata.fromJson(Map<String, dynamic> json) => BankMetadata(
        packageName: json['package_name'] as String,
        name: json['name'] as String,
        country: json['country'] as String? ?? 'CO',
        isDefault: json['is_default'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BankMetadata &&
          runtimeType == other.runtimeType &&
          packageName == other.packageName;

  @override
  int get hashCode => packageName.hashCode;

  @override
  String toString() =>
      'BankMetadata($name, pkg: $packageName, country: $country)';
}

/// Servicio de whitelist bancaria para filtrado previo de notificaciones entrantes.
///
/// Solo las notificaciones provenientes de paquetes registrados y habilitados
/// en esta lista blanca son procesadas por el pipeline de ingestión.
class BankWhitelistService {
  static const String prefsKey = 'notifications_whitelisted_packages';

  /// Lista predeterminada de entidades financieras y billeteras en Colombia.
  static final List<BankMetadata> defaultBankList = [
    const BankMetadata(
      packageName: 'com.bancolombia.personas',
      name: 'Bancolombia',
    ),
    const BankMetadata(
      packageName: 'com.nequi.MobileApp',
      name: 'Nequi',
    ),
    const BankMetadata(
      packageName: 'com.davivienda.billetera',
      name: 'Davivienda',
    ),
    const BankMetadata(
      packageName: 'co.daviplata',
      name: 'Daviplata',
    ),
    const BankMetadata(
      packageName: 'com.nu.production',
      name: 'Nu Colombia',
    ),
    const BankMetadata(
      packageName: 'co.com.bbva.mb',
      name: 'BBVA Colombia',
    ),
    const BankMetadata(
      packageName: 'com.scotiabank.colpatria',
      name: 'Scotiabank Colpatria',
    ),
    const BankMetadata(
      packageName: 'com.bancofalabella.mobile',
      name: 'Banco Falabella',
    ),
    const BankMetadata(
      packageName: 'com.bancodebogota.bancamovil',
      name: 'Banco de Bogotá',
    ),
    const BankMetadata(
      packageName: 'com.rappipay.app',
      name: 'RappiPay',
    ),
    const BankMetadata(
      packageName: 'co.com.bancopopular.mb',
      name: 'Banco Popular Colombia',
    ),
    const BankMetadata(
      packageName: 'com.avvillas.bancamovil',
      name: 'Banco AV Villas',
    ),
    const BankMetadata(
      packageName: 'com.bancodeoccidente.movil',
      name: 'Banco de Occidente',
    ),
    const BankMetadata(
      packageName: 'com.lulo.app',
      name: 'Lulo Bank',
    ),
    const BankMetadata(
      packageName: 'com.dale.app',
      name: 'Dale!',
    ),
    const BankMetadata(
      packageName: 'com.itau.personas.co',
      name: 'Itaú Colombia',
    ),
    const BankMetadata(
      packageName: 'com.uala.colombia',
      name: 'Ualá Colombia',
    ),
    const BankMetadata(
      packageName: 'com.bancocajasocial.mb',
      name: 'Banco Caja Social',
    ),
    const BankMetadata(
      packageName: 'com.serfinanza.app',
      name: 'Banco Serfinanza',
    ),
    const BankMetadata(
      packageName: 'com.moneo.simulated.bank',
      name: 'Moneo Bank (Simulador)',
    ),
  ];

  final Map<String, BankMetadata> _banks = {};
  final Set<String> _enabledPackages = {};

  BankWhitelistService({List<BankMetadata>? initialBanks}) {
    final listToLoad = initialBanks ?? defaultBankList;
    for (final bank in listToLoad) {
      _banks[bank.packageName] = bank;
      _enabledPackages.add(bank.packageName);
    }
  }

  /// Verifica si el paquete indicado está registrado y habilitado en la whitelist.
  bool isWhitelisted(String packageName) {
    final normalized = packageName.trim();
    return _enabledPackages.contains(normalized);
  }

  /// Obtiene el nombre amigable de la entidad para un paquete dado.
  String? getBankName(String packageName) {
    return _banks[packageName.trim()]?.name;
  }

  /// Obtiene los metadatos completos para un paquete registrado.
  BankMetadata? getMetadata(String packageName) {
    return _banks[packageName.trim()];
  }

  /// Conjunto inmutable de identificadores de paquetes actualmente activos.
  Set<String> get whitelistedPackages => UnmodifiableSetView(_enabledPackages);

  /// Lista inmutable de todos los bancos registrados (activos o inactivos).
  List<BankMetadata> get allBanks => UnmodifiableListView(_banks.values);

  /// Agrega un nuevo paquete bancario personalizado a la whitelist.
  void addPackage(
    String packageName, {
    required String bankName,
    String country = 'CO',
    bool enabled = true,
  }) {
    final normalized = packageName.trim();
    final metadata = BankMetadata(
      packageName: normalized,
      name: bankName.trim(),
      country: country.trim().toUpperCase(),
      isDefault: false,
    );
    _banks[normalized] = metadata;
    if (enabled) {
      _enabledPackages.add(normalized);
    } else {
      _enabledPackages.remove(normalized);
    }
  }

  /// Remueve un paquete de la whitelist (si es personalizado).
  /// Si es predeterminado, se recomienda deshabilitarlo en vez de eliminarlo.
  bool removePackage(String packageName) {
    final normalized = packageName.trim();
    _enabledPackages.remove(normalized);
    return _banks.remove(normalized) != null;
  }

  /// Habilita la escucha de notificaciones para un paquete existente.
  void enablePackage(String packageName) {
    final normalized = packageName.trim();
    if (_banks.containsKey(normalized)) {
      _enabledPackages.add(normalized);
    }
  }

  /// Deshabilita temporalmente un paquete sin eliminar sus metadatos.
  void disablePackage(String packageName) {
    _enabledPackages.remove(packageName.trim());
  }

  /// Restablece la configuración a los valores predeterminados de fábrica.
  void resetToDefaults() {
    _banks.clear();
    _enabledPackages.clear();
    for (final bank in defaultBankList) {
      _banks[bank.packageName] = bank;
      _enabledPackages.add(bank.packageName);
    }
  }

  /// Carga los paquetes habilitados desde [SharedPreferences].
  ///
  /// Si no hay preferencia guardada aún, conserva los valores predeterminados.
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(prefsKey);
    if (saved == null) return;

    _enabledPackages
      ..clear()
      ..addAll(saved.where((pkg) => _banks.containsKey(pkg)));
  }

  /// Persiste los paquetes habilitados actuales en [SharedPreferences].
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(prefsKey, _enabledPackages.toList());
  }

  /// Activa o desactiva un paquete bancario y guarda el cambio localmente.
  Future<void> setBankEnabled(String packageName, bool enabled) async {
    if (enabled) {
      enablePackage(packageName);
    } else {
      disablePackage(packageName);
    }
    await saveToPrefs();
  }
}
