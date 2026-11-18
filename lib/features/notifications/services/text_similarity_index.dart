import 'dart:math' as math;

/// Entrada compacta indexada en RAM para búsqueda semántica ultrarrápida.
class CompactSimilarityEntry {
  final String key;
  final List<String> aliases;
  final String category;
  final List<String> knownPackages;
  final int confirmations;

  const CompactSimilarityEntry({
    required this.key,
    this.aliases = const [],
    this.category = '',
    this.knownPackages = const [],
    this.confirmations = 1,
  });
}

/// Resultado de similitud híbrida emitido por [CompactSimilarityIndex].
class CompactSimilarityMatch {
  final String key;
  final double score;
  final double bm25;
  final double jaccard3Gram;
  final double pkgMatch;
  final double confBoost;

  const CompactSimilarityMatch({
    required this.key,
    required this.score,
    required this.bm25,
    required this.jaccard3Gram,
    required this.pkgMatch,
    required this.confBoost,
  });
}

class _IndexedVariant {
  final String norm;
  final List<String> tokens;
  final Map<String, int> tf;
  final Set<String> trigrams;

  _IndexedVariant({
    required this.norm,
    required this.tokens,
    required this.tf,
    required this.trigrams,
  });
}

class _IndexedCompactDoc {
  final String key;
  final List<_IndexedVariant> variants;
  final Set<String> uniqueTokens;
  final Set<String> uniqueTrigrams;
  final Set<String> knownPackagesLower;
  final int confirmations;
  final int primaryTokenCount;

  _IndexedCompactDoc({
    required this.key,
    required this.variants,
    required this.uniqueTokens,
    required this.uniqueTrigrams,
    required this.knownPackagesLower,
    required this.confirmations,
    required this.primaryTokenCount,
  });
}

/// Índice invertido ligero en RAM (posting list por tokens y trigramas)
/// optimizado para evaluar similitud híbrida en `< 1 ms` sobre cientos de patrones.
class CompactSimilarityIndex {
  final List<_IndexedCompactDoc?> _docs = [];
  final Map<String, int> _keyToId = {};
  final Map<String, List<int>> _tokenPostings = {};
  final Map<String, List<int>> _trigramPostings = {};
  final Map<String, int> _tokenDocFreq = {};
  final List<int> _freeIds = [];

  int _activeCount = 0;
  int _totalTokenCount = 0;

  int get length => _activeCount;
  bool get isEmpty => _activeCount == 0;
  int get postingTermCount => _tokenPostings.length;
  int get postingTrigramCount => _trigramPostings.length;

  bool containsKey(String key) => _keyToId.containsKey(key);

  /// Inserta o actualiza una entrada en el índice invertido.
  void upsert(CompactSimilarityEntry entry) {
    final existingId = _keyToId[entry.key];
    if (existingId != null) {
      _removeDocAt(existingId);
    }

    final doc = _buildDoc(entry);
    final int docId;
    if (existingId != null) {
      docId = existingId;
      _docs[docId] = doc;
    } else if (_freeIds.isNotEmpty) {
      docId = _freeIds.removeLast();
      _docs[docId] = doc;
    } else {
      docId = _docs.length;
      _docs.add(doc);
    }

    _keyToId[entry.key] = docId;
    _activeCount++;
    _totalTokenCount += doc.primaryTokenCount;

    for (final token in doc.uniqueTokens) {
      _tokenPostings.putIfAbsent(token, () => <int>[]).add(docId);
      _tokenDocFreq[token] = (_tokenDocFreq[token] ?? 0) + 1;
    }
    for (final gram in doc.uniqueTrigrams) {
      _trigramPostings.putIfAbsent(gram, () => <int>[]).add(docId);
    }
  }

  /// Elimina una entrada por su [key].
  void remove(String key) {
    final docId = _keyToId.remove(key);
    if (docId == null) return;
    _removeDocAt(docId);
    _freeIds.add(docId);
  }

  /// Reemplaza todo el índice con [entries].
  void rebuild(Iterable<CompactSimilarityEntry> entries) {
    clear();
    for (final entry in entries) {
      upsert(entry);
    }
  }

  /// Limpia completamente el índice en memoria.
  void clear() {
    _docs.clear();
    _keyToId.clear();
    _tokenPostings.clear();
    _trigramPostings.clear();
    _tokenDocFreq.clear();
    _freeIds.clear();
    _activeCount = 0;
    _totalTokenCount = 0;
  }

  void _removeDocAt(int docId) {
    final oldDoc = _docs[docId];
    if (oldDoc == null) return;
    _docs[docId] = null;
    _activeCount--;
    _totalTokenCount -= oldDoc.primaryTokenCount;

    for (final token in oldDoc.uniqueTokens) {
      final list = _tokenPostings[token];
      if (list != null) {
        list.remove(docId);
        if (list.isEmpty) {
          _tokenPostings.remove(token);
        }
      }
      final nextDf = (_tokenDocFreq[token] ?? 1) - 1;
      if (nextDf <= 0) {
        _tokenDocFreq.remove(token);
      } else {
        _tokenDocFreq[token] = nextDf;
      }
    }

    for (final gram in oldDoc.uniqueTrigrams) {
      final list = _trigramPostings[gram];
      if (list != null) {
        list.remove(docId);
        if (list.isEmpty) {
          _trigramPostings.remove(gram);
        }
      }
    }
  }

  _IndexedCompactDoc _buildDoc(CompactSimilarityEntry entry) {
    final variantStrings = <String>[];
    final seenNorms = <String>{};

    void addVariant(String raw) {
      final norm = TextSimilarityIndex.normalize(raw);
      if (norm.isNotEmpty && seenNorms.add(norm)) {
        variantStrings.add(norm);
      }
    }

    addVariant(entry.key);
    for (final alias in entry.aliases) {
      addVariant(alias);
    }
    final normCategory = TextSimilarityIndex.normalize(entry.category);
    if (normCategory.isNotEmpty) {
      final normKey = TextSimilarityIndex.normalize(entry.key);
      if (normKey.isNotEmpty) {
        addVariant('$normKey $normCategory');
      }
      for (final alias in entry.aliases) {
        final normAlias = TextSimilarityIndex.normalize(alias);
        if (normAlias.isNotEmpty) {
          addVariant('$normAlias $normCategory');
        }
      }
    }

    final variants = <_IndexedVariant>[];
    final uniqueTokens = <String>{};
    final uniqueTrigrams = <String>{};

    for (final norm in variantStrings) {
      final tokens = norm.split(' ').where((t) => t.isNotEmpty).toList();
      final tf = <String, int>{};
      for (final tok in tokens) {
        tf[tok] = (tf[tok] ?? 0) + 1;
        uniqueTokens.add(tok);
      }
      final grams = TextSimilarityIndex.trigramsFromNormalized(norm);
      uniqueTrigrams.addAll(grams);
      variants.add(_IndexedVariant(
        norm: norm,
        tokens: tokens,
        tf: tf,
        trigrams: grams,
      ));
    }

    final primaryTokenCount = variants.isNotEmpty ? variants.first.tokens.length : 1;
    final packagesLower = entry.knownPackages
        .map((p) => p.trim().toLowerCase())
        .where((p) => p.isNotEmpty)
        .toSet();

    return _IndexedCompactDoc(
      key: entry.key,
      variants: variants,
      uniqueTokens: uniqueTokens,
      uniqueTrigrams: uniqueTrigrams,
      knownPackagesLower: packagesLower,
      confirmations: entry.confirmations,
      primaryTokenCount: math.max(1, primaryTokenCount),
    );
  }

  /// Busca los mejores candidatos para [query] usando posting list y la ecuación híbrida:
  /// `Score(q, p) = 0.40 * BM25 + 0.35 * Jaccard3Gram + 0.15 * PkgMatch + 0.10 * ConfBoost`
  List<CompactSimilarityMatch> search(
    String query, {
    String? packageName,
    int limit = 5,
    double minScore = 0.0,
    int maxCandidates = 32,
  }) {
    if (_activeCount == 0 || limit <= 0) return const [];
    final normQ = TextSimilarityIndex.normalize(query);
    if (normQ.isEmpty) return const [];

    final qTokens = normQ.split(' ').where((t) => t.isNotEmpty).toList();
    if (qTokens.isEmpty) return const [];
    final qUniqueTokens = qTokens.toSet();
    final qTrigrams = TextSimilarityIndex.trigramsFromNormalized(normQ);

    // 1. Recuperación rápida por posting list (tokens con mayor peso + trigramas)
    final candidateHits = <int, int>{};
    for (final tok in qUniqueTokens) {
      final posting = _tokenPostings[tok];
      if (posting == null) continue;
      for (final docId in posting) {
        candidateHits[docId] = (candidateHits[docId] ?? 0) + 4;
      }
    }
    for (final gram in qTrigrams) {
      final posting = _trigramPostings[gram];
      if (posting == null) continue;
      for (final docId in posting) {
        candidateHits[docId] = (candidateHits[docId] ?? 0) + 1;
      }
    }

    if (candidateHits.isEmpty) return const [];

    List<int> candidateIds;
    if (candidateHits.length <= maxCandidates) {
      candidateIds = candidateHits.keys.toList(growable: false);
    } else {
      final sortedEntries = candidateHits.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      candidateIds = sortedEntries
          .take(maxCandidates)
          .map((e) => e.key)
          .toList(growable: false);
    }

    // 2. Precalcular TF e IDF de la consulta una sola vez
    final totalDocs = math.max(1, _activeCount);
    final avgDocLen = math.max(1.0, _totalTokenCount / totalDocs);
    const double k1 = 1.2;
    const double b = 0.75;

    final qTf = <String, int>{};
    for (final tok in qTokens) {
      qTf[tok] = (qTf[tok] ?? 0) + 1;
    }

    final termIdf = <String, double>{};
    double maxBm25Score = 0.0;
    for (final term in qUniqueTokens) {
      final df = _tokenDocFreq[term] ?? 0;
      final idf = math.log(((totalDocs - df + 0.5) / (df + 0.5)) + 1.0);
      termIdf[term] = idf;

      final qFreq = qTf[term]!;
      final qDenom =
          qFreq + k1 * (1.0 - b + b * (qTokens.length / avgDocLen));
      maxBm25Score += idf * ((qFreq * (k1 + 1.0)) / qDenom);
    }

    final normPkg = packageName?.trim().toLowerCase();

    // 3. Evaluar ecuación híbrida únicamente sobre los candidatos filtrados
    final matches = <CompactSimilarityMatch>[];
    for (final docId in candidateIds) {
      final doc = _docs[docId];
      if (doc == null || doc.variants.isEmpty) continue;

      double bestTextContribution = -1.0;
      double bestBm25 = 0.0;
      double bestJaccard = 0.0;

      for (final variant in doc.variants) {
        final double bm25;
        final double jaccard;

        if (variant.norm == normQ) {
          bm25 = 1.0;
          jaccard = 1.0;
        } else {
          if (maxBm25Score <= 0.0 || variant.tokens.isEmpty) {
            bm25 = 0.0;
          } else {
            double rawBm25 = 0.0;
            final docLen = variant.tokens.length;
            for (final term in qUniqueTokens) {
              final freq = variant.tf[term] ?? 0;
              if (freq == 0) continue;
              final idf = termIdf[term]!;
              final denom = freq + k1 * (1.0 - b + b * (docLen / avgDocLen));
              rawBm25 += idf * ((freq * (k1 + 1.0)) / denom);
            }
            bm25 = (rawBm25 / maxBm25Score).clamp(0.0, 1.0);
          }

          if (qTrigrams.isEmpty || variant.trigrams.isEmpty) {
            jaccard = 0.0;
          } else {
            var intersection = 0;
            for (final gram in qTrigrams) {
              if (variant.trigrams.contains(gram)) intersection++;
            }
            final union =
                qTrigrams.length + variant.trigrams.length - intersection;
            jaccard = union == 0 ? 0.0 : intersection / union;
          }
        }

        final textContribution = 0.40 * bm25 + 0.35 * jaccard;
        if (textContribution > bestTextContribution) {
          bestTextContribution = textContribution;
          bestBm25 = bm25;
          bestJaccard = jaccard;
          if (bestBm25 == 1.0 && bestJaccard == 1.0) break;
        }
      }

      final pkgMatch = TextSimilarityIndex.computePkgMatch(
        normPkg,
        doc.knownPackagesLower,
      );
      final confBoost = TextSimilarityIndex.computeConfBoost(doc.confirmations);
      final totalScore = TextSimilarityIndex.hybridScore(
        bm25: bestBm25,
        jaccard3Gram: bestJaccard,
        pkgMatch: pkgMatch,
        confBoost: confBoost,
      );

      if (totalScore >= minScore) {
        matches.add(CompactSimilarityMatch(
          key: doc.key,
          score: totalScore,
          bm25: bestBm25,
          jaccard3Gram: bestJaccard,
          pkgMatch: pkgMatch,
          confBoost: confBoost,
        ));
      }
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches.take(limit).toList(growable: false);
  }
}

/// Índice ligero en memoria para similitud de texto usando BM25 + JaccardTrigram.
///
/// Diseñado para operar en < 1 ms sobre listas locales de patrones aprendidos
/// o candidatos recientes de deduplicación, sin dependencias externas ni red.
class TextSimilarityIndex {
  const TextSimilarityIndex._();

  static final RegExp _reA = RegExp(r'[áàäâ]');
  static final RegExp _reE = RegExp(r'[éèëê]');
  static final RegExp _reI = RegExp(r'[íìïî]');
  static final RegExp _reO = RegExp(r'[óòöô]');
  static final RegExp _reU = RegExp(r'[úùüû]');
  static final RegExp _reN = RegExp(r'[ñ]');
  static final RegExp _reNonWord = RegExp(r'[^\w\s]');
  static final RegExp _reMultiSpace = RegExp(r'\s+');

  /// Normaliza texto para comparación: minúsculas, sin tildes, sin puntuación.
  static String normalize(String input) {
    var text = input.trim().toLowerCase();
    if (text.isEmpty) return '';

    text = text
        .replaceAll(_reA, 'a')
        .replaceAll(_reE, 'e')
        .replaceAll(_reI, 'i')
        .replaceAll(_reO, 'o')
        .replaceAll(_reU, 'u')
        .replaceAll(_reN, 'n')
        .replaceAll(_reNonWord, ' ')
        .replaceAll(_reMultiSpace, ' ')
        .trim();

    return text;
  }

  /// Extrae trigramas de caracteres desde una cadena ya normalizada.
  static Set<String> trigramsFromNormalized(String norm) {
    if (norm.isEmpty) return const {};
    if (norm.length < 3) return {norm};

    final padded = ' $norm ';
    final result = <String>{};
    for (var i = 0; i <= padded.length - 3; i++) {
      result.add(padded.substring(i, i + 3));
    }
    return result;
  }

  /// Ecuación híbrida de similitud para Mini-RAG:
  /// `Score(q, p) = 0.40 * BM25 + 0.35 * Jaccard3Gram + 0.15 * PkgMatch + 0.10 * ConfBoost`
  static double hybridScore({
    required double bm25,
    required double jaccard3Gram,
    required double pkgMatch,
    required double confBoost,
  }) {
    return (0.40 * bm25 +
            0.35 * jaccard3Gram +
            0.15 * pkgMatch +
            0.10 * confBoost)
        .clamp(0.0, 1.0);
  }

  /// Calcula [PkgMatch] en `[0.0, 1.0]`:
  /// - `1.0` si [packageName] coincide con [knownPackagesLower].
  /// - `0.5` si no hay paquete o el patrón aún no registra paquetes (señal neutra).
  /// - `0.0` si el paquete difiere de los paquetes conocidos del patrón.
  static double computePkgMatch(
    String? packageName,
    Set<String> knownPackagesLower,
  ) {
    final normPkg = packageName?.trim().toLowerCase() ?? '';
    if (normPkg.isEmpty || knownPackagesLower.isEmpty) {
      return 0.5;
    }
    return knownPackagesLower.contains(normPkg) ? 1.0 : 0.0;
  }

  /// Calcula [ConfBoost] en `[0.0, 1.0]` con saturación logarítmica en 4 confirmaciones.
  static double computeConfBoost(int confirmations) {
    if (confirmations <= 0) return 0.0;
    if (confirmations >= 4) return 1.0;
    return (math.log(1 + confirmations) / math.log(5)).clamp(0.0, 1.0);
  }

  /// Extrae trigramas de caracteres con padding de bordes.
  static Set<String> trigrams(String text) {
    return trigramsFromNormalized(normalize(text));
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
