import 'package:shared_preferences/shared_preferences.dart';

/// Singleton para SharedPreferences — evita llamar getInstance() repetidamente.
/// Inicializar con PrefsManager.init() en main.dart antes de runApp().
class PrefsManager {
  static SharedPreferences? _instance;

  /// Inicializa la instancia. Llamar una sola vez en main.dart.
  static Future<void> init() async {
    _instance ??= await SharedPreferences.getInstance();
  }

  /// Retorna la instancia cacheada. Usa await solo si aún no fue inicializada.
  static Future<SharedPreferences> get instance async {
    return _instance ??= await SharedPreferences.getInstance();
  }

  /// Retorna la instancia de forma sincrónica (solo después de init()).
  static SharedPreferences get sync {
    assert(_instance != null, 'PrefsManager.init() debe llamarse antes de usar .sync');
    return _instance!;
  }
}
