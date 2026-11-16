import 'dart:math' as math;

/// Índice ligero en memoria para similitud de texto usando BM25 + JaccardTrigram.
///
/// Diseñado para operar en < 1 ms sobre listas locales de patrones aprendidos
/// o candidatos recientes de deduplicación, sin dependencias externas ni red.
class TextSimilarityIndex {
  const TextSimilarityIndex._();

  /// Normaliza texto para comparación: minúsculas, sin tildes, sin puntuación.
  static String normalize(String input) {
    var text = input.trim().toLowerCase();
    if (text.isEmpty) return '';

    text = text
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return text;
  }

  /// Extrae trigramas de caracteres con padding de bordes.
  static Set<String> trigrams(String text) {
    final norm = normalize(text);
    if (norm.isEmpty) return const {};
    if (norm.length < 3) return {norm};

    final padded = ' $norm ';
    final result = <String>{};
    for (var i = 0; i <= padded.length - 3; i++) {
      result.add(padded.substring(i, i + 3));
    }
    return result;
  }

  /// Similitud Jaccard sobre trigramas en [0.0, 1.0].
  static double jaccardTrigram(String a, String b) {
    final normA = normalize(a);
    final normB = normalize(b);
    if (normA.isEmpty || normB.isEmpty) return 0.0;
    if (normA == normB) return 1.0;

    final tA = trigrams(normA);
    final tB = trigrams(normB);
    if (tA.isEmpty || tB.isEmpty) return 0.0;

    var intersection = 0;
    for (final g in tA) {
      if (tB.contains(g)) intersection++;
    }
    final union = tA.length + tB.length - intersection;
    return union == 0 ? 0.0 : intersection / union;
  }

  /// Tokeniza texto normalizado por espacios.
  static List<String> tokenize(String text) {
    final norm = normalize(text);
    if (norm.isEmpty) return const [];
    return norm.split(' ').where((t) => t.isNotEmpty).toList();
  }

  /// Similitud BM25 normalizada en [0.0, 1.0] entre [query] y [document].
  static double bm25Similarity(
    String query,
    String document, {
    List<String>? corpus,
    double k1 = 1.2,
    double b = 0.75,
  }) {
    final qTokens = tokenize(query);
    final dTokens = tokenize(document);
    if (qTokens.isEmpty || dTokens.isEmpty) return 0.0;
    if (normalize(query) == normalize(document)) return 1.0;

    final docs = <List<String>>[
      if (corpus != null && corpus.isNotEmpty) ...corpus.map(tokenize),
      if (corpus == null || corpus.isEmpty) ...[qTokens, dTokens],
    ];
    final totalDocs = docs.length;
    final avgDocLen = docs.fold<int>(0, (sum, d) => sum + d.length) /
        math.max(1, totalDocs);

    double scoreFor(List<String> targetTokens) {
      final tf = <String, int>{};
      for (final tok in targetTokens) {
        tf[tok] = (tf[tok] ?? 0) + 1;
      }
      final docLen = targetTokens.length;
      double total = 0.0;

      for (final term in qTokens.toSet()) {
        final freq = tf[term] ?? 0;
        if (freq == 0) continue;

        var df = 0;
        for (final d in docs) {
          if (d.contains(term)) df++;
        }
        final idf = math.log(((totalDocs - df + 0.5) / (df + 0.5)) + 1.0);
        final denom = freq + k1 * (1.0 - b + b * (docLen / math.max(1.0, avgDocLen)));
        total += idf * ((freq * (k1 + 1.0)) / denom);
      }
      return total;
    }

    final maxScore = scoreFor(qTokens);
    if (maxScore <= 0.0) return 0.0;
    final rawScore = scoreFor(dTokens);
    return (rawScore / maxScore).clamp(0.0, 1.0);
  }

  /// Similitud combinada BM25 + JaccardTrigram en [0.0, 1.0].
  static double combinedSimilarity(
    String a,
    String b, {
    List<String>? corpus,
  }) {
    final normA = normalize(a);
    final normB = normalize(b);
    if (normA.isEmpty || normB.isEmpty) return 0.0;
    if (normA == normB) return 1.0;

    final jaccard = jaccardTrigram(normA, normB);
    final bm25 = bm25Similarity(normA, normB, corpus: corpus);
    return (0.55 * jaccard + 0.45 * bm25).clamp(0.0, 1.0);
  }

  /// Retorna los [k] elementos más similares a [query] ordenados de mayor a menor score.
  static List<({T item, double score})> topKSimilar<T>(
    String query,
    Iterable<T> items,
    String Function(T item) textSelector, {
    int k = 3,
    double minScore = 0.05,
  }) {
    final itemList = items.toList();
    if (itemList.isEmpty || normalize(query).isEmpty || k <= 0) {
      return const [];
    }

    final corpus = itemList.map(textSelector).toList(growable: false);
    final scored = <({T item, double score})>[];
    for (var i = 0; i < itemList.length; i++) {
      final score = combinedSimilarity(query, corpus[i], corpus: corpus);
      if (score >= minScore) {
        scored.add((item: itemList[i], score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(k).toList(growable: false);
  }
}
