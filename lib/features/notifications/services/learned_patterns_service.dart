import 'package:hive/hive.dart';
import 'package:finazaap/features/notifications/domain/models/learned_pattern.dart';
import 'package:finazaap/features/notifications/domain/models/transaction_classification.dart';

/// Servicio de almacenamiento local en Hive para patrones aprendidos de comercios.
///
/// Gestiona la caja Hive "learned_patterns" usando serialización Map/JSON sin tocar
/// adaptadores generados (*.g.dart). Soporta normalización agnóstica de comercios,
/// confirmación progresiva de patrones y correcciones explícitas del usuario.
class LearnedPatternsService {
  static const String defaultBoxName = 'learned_patterns';

  final Box<dynamic>? _injectedBox;
  final String _boxName;

  LearnedPatternsService({
    Box<dynamic>? box,
    String boxName = defaultBoxName,
  })  : _injectedBox = box,
        _boxName = boxName;

  /// Obtiene la caja Hive abierta, abriéndola si es necesario.
  Future<Box<dynamic>> _getBox() async {
    if (_injectedBox != null) {
      return _injectedBox!;
    }
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<dynamic>(_boxName);
    }
    return await Hive.openBox<dynamic>(_boxName);
  }

  /// Normaliza la cadena del comercio:
  /// - Minúsculas
  /// - Sin tildes / diacríticos
  /// - Sin caracteres especiales ni puntuación
  /// - Sin sufijos numéricos de sucursal (ej. '034', '#12', 'suc. 4')
  /// - Espacios colapsados y podados
  static String normalizeMerchant(String merchant) {
    var text = merchant.trim().toLowerCase();
    if (text.isEmpty) return '';

    // 1. Reemplazo de vocales con tildes y diacríticos
    text = text
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n');

    // 2. Eliminar puntuación y caracteres especiales no alfanuméricos
    text = text.replaceAll(RegExp(r'[^\w\s]'), ' ');

    // 3. Eliminar sufijos o prefijos explícitos de sucursal / tienda / sede seguidos de número
    text = text.replaceAll(
      RegExp(r'\b(sucursal|suc|tienda|store|sede|no)\s*\d+\b', caseSensitive: false),
      ' ',
    );

    // 4. Eliminar números aislados al final del texto (ej. 'Éxito Laureles 034' -> 'exito laureles')
    // preservando tokens alfanuméricos integrados como 'd1' o '3b'
    final withoutTrailingNumbers = text.replaceAll(RegExp(r'(?:\s+\d+)+$'), '').trim();
    if (withoutTrailingNumbers.isNotEmpty) {
      text = withoutTrailingNumbers;
    }

    // 5. Colapsar espacios múltiples y recortar bordes
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Busca un patrón previamente aprendido por nombre de comercio.
  Future<LearnedPattern?> findPattern(String merchant) async {
    final key = normalizeMerchant(merchant);
    if (key.isEmpty) return null;

    final box = await _getBox();
    final raw = box.get(key);
    if (raw == null) return null;

    if (raw is Map) {
      return LearnedPattern.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  /// Registra la confirmación de una transacción por el usuario.
  /// Incrementa el contador de confirmaciones y actualiza la última fecha de uso.
  Future<LearnedPattern> recordConfirmation({
    required String merchant,
    required String category,
    String? accountName,
    String classification = 'gasto',
    String? moneoType,
    DateTime? at,
  }) async {
    final key = normalizeMerchant(merchant);
    if (key.isEmpty) {
      throw ArgumentError('El comercio normalizado no puede estar vacío');
    }

    final box = await _getBox();
    final existing = await findPattern(merchant);
    final now = at ?? DateTime.now();
    final resolvedMoneo = moneoType ??
        TransactionClassification.resolveMoneoType(classification) ??
        'Expenses';

    final LearnedPattern updated;
    if (existing != null) {
      updated = existing.incrementConfirmation(at: now).copyWith(
            category: category,
            accountName: accountName ?? existing.accountName,
            classification: classification,
            moneoType: resolvedMoneo,
          );
    } else {
      updated = LearnedPattern(
        merchantKey: key,
        category: category,
        accountName: accountName,
        classification: classification,
        moneoType: resolvedMoneo,
        confirmations: 1,
        createdAt: now,
        lastUsedAt: now,
      );
    }

    await box.put(key, updated.toJson());
    return updated;
  }

  /// Registra una corrección explícita del usuario sobre un comercio.
  /// Sobrescribe la categoría/cuenta, fija confirmations en 1 y actualiza lastCorrectedAt.
  Future<LearnedPattern> recordCorrection({
    required String merchant,
    required String newCategory,
    String? newAccountName,
    String? newClassification,
    String? newMoneoType,
    DateTime? at,
  }) async {
    final key = normalizeMerchant(merchant);
    if (key.isEmpty) {
      throw ArgumentError('El comercio normalizado no puede estar vacío');
    }

    final box = await _getBox();
    final existing = await findPattern(merchant);
    final now = at ?? DateTime.now();
    final classification = newClassification ?? existing?.classification ?? 'gasto';
    final resolvedMoneo = newMoneoType ??
        TransactionClassification.resolveMoneoType(classification) ??
        'Expenses';

    final LearnedPattern updated;
    if (existing != null) {
      updated = existing.applyCorrection(
        newCategory: newCategory,
        newAccountName: newAccountName,
        newClassification: classification,
        newMoneoType: resolvedMoneo,
        at: now,
      );
    } else {
      updated = LearnedPattern(
        merchantKey: key,
        category: newCategory,
        accountName: newAccountName,
        classification: classification,
        moneoType: resolvedMoneo,
        confirmations: 1,
        createdAt: now,
        lastUsedAt: now,
        lastCorrectedAt: now,
      );
    }

    await box.put(key, updated.toJson());
    return updated;
  }

  /// Elimina un patrón aprendido por clave de comercio.
  Future<void> deletePattern(String merchant) async {
    final key = normalizeMerchant(merchant);
    if (key.isEmpty) return;

    final box = await _getBox();
    await box.delete(key);
  }

  /// Obtiene todos los patrones aprendidos almacenados.
  Future<List<LearnedPattern>> getAllPatterns() async {
    final box = await _getBox();
    final patterns = <LearnedPattern>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is Map) {
        patterns.add(LearnedPattern.fromJson(Map<String, dynamic>.from(raw)));
      }
    }
    return patterns;
  }

  /// Limpia todos los patrones aprendidos en la caja.
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }
}
