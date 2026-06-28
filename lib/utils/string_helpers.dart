/// Utilidades de texto reutilizables en toda la app.

/// Convierte la primera letra a mayúscula.
String capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

/// Normaliza un string para búsquedas insensibles a tildes y mayúsculas.
String normalizeString(String s) {
  const accents = 'áéíóúÁÉÍÓÚàèìòùÀÈÌÒÙäëïöüÄËÏÖÜ';
  const normalized = 'aeiouAEIOUaeiouAEIOUaeiouAEIOU';
  var result = s.toLowerCase();
  for (int i = 0; i < accents.length; i++) {
    result = result.replaceAll(accents[i], normalized[i]);
  }
  return result;
}

/// Devuelve el código de icono para una categoría de transacción.
int getCategoryIconCode(String category, List<Map<String, dynamic>> categoryList) {
  final normalized = normalizeString(category);
  for (final cat in categoryList) {
    final catText = normalizeString(cat['text']?.toString() ?? '');
    if (catText == normalized) {
      return (cat['icon'] as int?) ?? 0xe3a6;
    }
  }
  return 0xe3a6;
}
