/// Estado explícito del ciclo de vida de un patrón aprendido en Hive.
enum PatternStatus {
  /// 1 confirmación.
  nuevo('nuevo'),

  /// 2 a 3 confirmaciones sin conflicto reciente.
  enRefuerzo('en_refuerzo'),

  /// 4 o más confirmaciones sin conflicto reciente.
  consolidado('consolidado'),

  /// Corrección reciente sin borrar el historial consolidado previo.
  enRevision('en_revision'),

  /// Más de 180 días sin uso.
  obsoleto('obsoleto');

  final String wireValue;
  const PatternStatus(this.wireValue);

  static PatternStatus fromWire(String? value) {
    switch (value) {
      case 'nuevo':
        return PatternStatus.nuevo;
      case 'en_refuerzo':
        return PatternStatus.enRefuerzo;
      case 'consolidado':
        return PatternStatus.consolidado;
      case 'en_revision':
        return PatternStatus.enRevision;
      case 'obsoleto':
        return PatternStatus.obsoleto;
      default:
        return PatternStatus.nuevo;
    }
  }
}

class LearnedPattern {
  static const int obsoleteAfterDays = 180;
  static const int consolidatedThreshold = 4;

  final String merchantKey;
  final String category;
  final String? accountName;
  final String classification; // 'gasto', 'ingreso', 'transferencia-propia'
  final String? moneoType; // 'Expenses', 'Income', 'Transfer'
  final int confirmations;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final DateTime? lastCorrectedAt;

  /// Puntuación acumulada por categoría para evitar que 1 corrección atípica
  /// borre confirmaciones previas consolidadas.
  final Map<String, int> categoryScores;

  /// Puntuación acumulada por cuenta asociada al comercio.
  final Map<String, int> accountScores;

  /// Estado explícito del patrón.
  final PatternStatus status;

  /// Racha de correcciones consecutivas hacia [pendingCorrectionCategory].
  final int correctionStreak;

  /// Categoría propuesta en corrección reciente mientras el patrón está en revisión.
  final String? pendingCorrectionCategory;

  LearnedPattern({
    required this.merchantKey,
    required this.category,
    this.accountName,
    this.classification = 'gasto',
    this.moneoType = 'Expenses',
    this.confirmations = 1,
    required this.createdAt,
    required this.lastUsedAt,
    this.lastCorrectedAt,
    Map<String, int>? categoryScores,
    Map<String, int>? accountScores,
    PatternStatus? status,
    this.correctionStreak = 0,
    this.pendingCorrectionCategory,
  })  : categoryScores = Map<String, int>.unmodifiable(
          categoryScores ?? {category: confirmations},
        ),
        accountScores = Map<String, int>.unmodifiable(
          accountScores ??
              (accountName != null && accountName.trim().isNotEmpty
                  ? {accountName: confirmations}
                  : const <String, int>{}),
        ),
        status = status ??
            computeStatus(
              confirmations: confirmations,
              lastUsedAt: lastUsedAt,
              correctionStreak: correctionStreak,
            );

  /// Calcula el [PatternStatus] efectivo según confirmaciones, conflictos e inactividad.
  static PatternStatus computeStatus({
    required int confirmations,
    required DateTime lastUsedAt,
    int correctionStreak = 0,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    if (reference.difference(lastUsedAt).inDays > obsoleteAfterDays) {
      return PatternStatus.obsoleto;
    }
    if (correctionStreak > 0) {
      return PatternStatus.enRevision;
    }
    if (confirmations >= consolidatedThreshold) {
      return PatternStatus.consolidado;
    }
    if (confirmations >= 2) {
      return PatternStatus.enRefuerzo;
    }
    return PatternStatus.nuevo;
  }

  /// Devuelve el estado efectivo evaluado contra [now] (útil para detectar obsolescencia >180 días).
  PatternStatus effectiveStatus({DateTime? now}) {
    final reference = now ?? DateTime.now();
    if (reference.difference(lastUsedAt).inDays > obsoleteAfterDays) {
      return PatternStatus.obsoleto;
    }
    return status;
  }

  bool get isConsolidated =>
      confirmations >= consolidatedThreshold ||
      (categoryScores[category] ?? 0) >= consolidatedThreshold;

  LearnedPattern incrementConfirmation({
    DateTime? at,
    String? confirmedCategory,
    String? confirmedAccountName,
  }) {
    final now = at ?? DateTime.now();
    final effectiveCategory = confirmedCategory ?? category;
    final nextCategoryScores = Map<String, int>.from(categoryScores);
    nextCategoryScores[effectiveCategory] =
        (nextCategoryScores[effectiveCategory] ?? 0) + 1;

    final nextAccountScores = Map<String, int>.from(accountScores);
    final effectiveAccount = confirmedAccountName ?? accountName;
    if (effectiveAccount != null && effectiveAccount.trim().isNotEmpty) {
      nextAccountScores[effectiveAccount] =
          (nextAccountScores[effectiveAccount] ?? 0) + 1;
    }

    final nextConfirmations = confirmations + 1;
    return LearnedPattern(
      merchantKey: merchantKey,
      category: effectiveCategory,
      accountName: effectiveAccount,
      classification: classification,
      moneoType: moneoType,
      confirmations: nextConfirmations,
      createdAt: createdAt,
      lastUsedAt: now,
      lastCorrectedAt: lastCorrectedAt,
      categoryScores: nextCategoryScores,
      accountScores: nextAccountScores,
      correctionStreak: 0,
      pendingCorrectionCategory: null,
      status: computeStatus(
        confirmations: nextConfirmations,
        lastUsedAt: now,
        correctionStreak: 0,
        now: now,
      ),
    );
  }

  LearnedPattern applyCorrection({
    required String newCategory,
    String? newAccountName,
    String? newClassification,
    String? newMoneoType,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    final nextCategoryScores = Map<String, int>.from(categoryScores);
    if (!nextCategoryScores.containsKey(category)) {
      nextCategoryScores[category] = confirmations;
    }
    nextCategoryScores[newCategory] =
        (nextCategoryScores[newCategory] ?? 0) + 1;

    final nextAccountScores = Map<String, int>.from(accountScores);
    if (newAccountName != null && newAccountName.trim().isNotEmpty) {
      nextAccountScores[newAccountName] =
          (nextAccountScores[newAccountName] ?? 0) + 1;
    }

    final sameCategory = newCategory == category;
    final currentCategoryScore = nextCategoryScores[category] ?? confirmations;
    final newCategoryScore = nextCategoryScores[newCategory] ?? 1;

    // Si es la misma categoría (ej. ajuste de cuenta o tipo), conservar historial sin borrar.
    if (sameCategory) {
      final resolvedAccount = _resolvePreferredAccount(
        currentAccount: accountName,
        candidateAccount: newAccountName,
        accountScores: nextAccountScores,
        isConsolidated: isConsolidated,
      );
      return LearnedPattern(
        merchantKey: merchantKey,
        category: category,
        accountName: resolvedAccount,
        classification: isConsolidated
            ? classification
            : (newClassification ?? classification),
        moneoType: isConsolidated ? moneoType : (newMoneoType ?? moneoType),
        confirmations: confirmations,
        createdAt: createdAt,
        lastUsedAt: now,
        lastCorrectedAt: now,
        categoryScores: nextCategoryScores,
        accountScores: nextAccountScores,
        correctionStreak: 0,
        pendingCorrectionCategory: null,
        status: computeStatus(
          confirmations: confirmations,
          lastUsedAt: now,
          correctionStreak: 0,
          now: now,
        ),
      );
    }

    // Patrón no consolidado (<4): una corrección directa actualiza la categoría activa
    // conservando el historial en categoryScores.
    if (!isConsolidated) {
      return LearnedPattern(
        merchantKey: merchantKey,
        category: newCategory,
        accountName: newAccountName ?? accountName,
        classification: newClassification ?? classification,
        moneoType: newMoneoType ?? moneoType,
        confirmations: 1,
        createdAt: createdAt,
        lastUsedAt: now,
        lastCorrectedAt: now,
        categoryScores: nextCategoryScores,
        accountScores: nextAccountScores,
        correctionStreak: 0,
        pendingCorrectionCategory: null,
        status: PatternStatus.nuevo,
      );
    }

    // Patrón consolidado (>=4): 1 corrección atípica NO borra las confirmaciones previas.
    // Requiere >= 2 correcciones consecutivas hacia la nueva categoría o superar su puntuación.
    final nextStreak =
        pendingCorrectionCategory == newCategory ? correctionStreak + 1 : 1;
    final shouldDisplace =
        nextStreak >= 2 || newCategoryScore > currentCategoryScore;

    if (shouldDisplace) {
      return LearnedPattern(
        merchantKey: merchantKey,
        category: newCategory,
        accountName: newAccountName ?? accountName,
        classification: newClassification ?? classification,
        moneoType: newMoneoType ?? moneoType,
        confirmations: newCategoryScore,
        createdAt: createdAt,
        lastUsedAt: now,
        lastCorrectedAt: now,
        categoryScores: nextCategoryScores,
        accountScores: nextAccountScores,
        correctionStreak: 0,
        pendingCorrectionCategory: null,
        status: computeStatus(
          confirmations: newCategoryScore,
          lastUsedAt: now,
          correctionStreak: 0,
          now: now,
        ),
      );
    }

    return LearnedPattern(
      merchantKey: merchantKey,
      category: category,
      accountName: accountName,
      classification: classification,
      moneoType: moneoType,
      confirmations: confirmations,
      createdAt: createdAt,
      lastUsedAt: now,
      lastCorrectedAt: now,
      categoryScores: nextCategoryScores,
      accountScores: nextAccountScores,
      correctionStreak: nextStreak,
      pendingCorrectionCategory: newCategory,
      status: PatternStatus.enRevision,
    );
  }

  static String? _resolvePreferredAccount({
    required String? currentAccount,
    required String? candidateAccount,
    required Map<String, int> accountScores,
    required bool isConsolidated,
  }) {
    if (candidateAccount == null || candidateAccount.trim().isEmpty) {
      return currentAccount;
    }
    if (currentAccount == null || currentAccount.trim().isEmpty) {
      return candidateAccount;
    }
    if (!isConsolidated) return candidateAccount;
    final currentScore = accountScores[currentAccount] ?? 1;
    final candidateScore = accountScores[candidateAccount] ?? 1;
    return candidateScore >= currentScore ? candidateAccount : currentAccount;
  }

  LearnedPattern copyWith({
    String? merchantKey,
    String? category,
    String? accountName,
    String? classification,
    String? moneoType,
    int? confirmations,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    DateTime? lastCorrectedAt,
    Map<String, int>? categoryScores,
    Map<String, int>? accountScores,
    PatternStatus? status,
    int? correctionStreak,
    String? pendingCorrectionCategory,
  }) {
    final nextConfirmations = confirmations ?? this.confirmations;
    final nextLastUsedAt = lastUsedAt ?? this.lastUsedAt;
    final nextStreak = correctionStreak ?? this.correctionStreak;
    return LearnedPattern(
      merchantKey: merchantKey ?? this.merchantKey,
      category: category ?? this.category,
      accountName: accountName ?? this.accountName,
      classification: classification ?? this.classification,
      moneoType: moneoType ?? this.moneoType,
      confirmations: nextConfirmations,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: nextLastUsedAt,
      lastCorrectedAt: lastCorrectedAt ?? this.lastCorrectedAt,
      categoryScores: categoryScores ?? this.categoryScores,
      accountScores: accountScores ?? this.accountScores,
      status: status ??
          computeStatus(
            confirmations: nextConfirmations,
            lastUsedAt: nextLastUsedAt,
            correctionStreak: nextStreak,
          ),
      correctionStreak: nextStreak,
      pendingCorrectionCategory:
          pendingCorrectionCategory ?? this.pendingCorrectionCategory,
    );
  }

  Map<String, dynamic> toJson() => {
        'merchant_key': merchantKey,
        'category': category,
        'account_name': accountName,
        'classification': classification,
        'moneo_type': moneoType,
        'confirmations': confirmations,
        'created_at': createdAt.toIso8601String(),
        'last_used_at': lastUsedAt.toIso8601String(),
        'last_corrected_at': lastCorrectedAt?.toIso8601String(),
        'category_scores': categoryScores,
        'account_scores': accountScores,
        'status': status.wireValue,
        'correction_streak': correctionStreak,
        'pending_correction_category': pendingCorrectionCategory,
      };

  factory LearnedPattern.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as String;
    final accountName = (json['account_name'] ?? json['accountName']) as String?;
    final confirmations = (json['confirmations'] as num?)?.toInt() ?? 1;
    final createdAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : (json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now());
    final lastUsedAt = json['last_used_at'] != null
        ? DateTime.parse(json['last_used_at'] as String)
        : (json['lastUsedAt'] != null
            ? DateTime.parse(json['lastUsedAt'] as String)
            : DateTime.now());
    final lastCorrectedAt =
        (json['last_corrected_at'] ?? json['lastCorrectedAt']) != null
            ? DateTime.parse(
                (json['last_corrected_at'] ?? json['lastCorrectedAt'])
                    as String,
              )
            : null;

    final rawCatScores = json['category_scores'] ?? json['categoryScores'];
    final parsedCatScores = <String, int>{};
    if (rawCatScores is Map) {
      rawCatScores.forEach((k, v) {
        if (k is String && v is num) {
          parsedCatScores[k] = v.toInt();
        }
      });
    }
    if (parsedCatScores.isEmpty) {
      parsedCatScores[category] = confirmations;
    }

    final rawAccScores = json['account_scores'] ?? json['accountScores'];
    final parsedAccScores = <String, int>{};
    if (rawAccScores is Map) {
      rawAccScores.forEach((k, v) {
        if (k is String && v is num) {
          parsedAccScores[k] = v.toInt();
        }
      });
    } else if (accountName != null && accountName.trim().isNotEmpty) {
      parsedAccScores[accountName] = confirmations;
    }

    final correctionStreak =
        (json['correction_streak'] ?? json['correctionStreak'] as num?)
                ?.toInt() ??
            0;
    final pendingCorrectionCategory = (json['pending_correction_category'] ??
        json['pendingCorrectionCategory']) as String?;
    final rawStatus = json['status'] as String?;
    final parsedStatus = rawStatus != null
        ? PatternStatus.fromWire(rawStatus)
        : computeStatus(
            confirmations: confirmations,
            lastUsedAt: lastUsedAt,
            correctionStreak: correctionStreak,
          );

    return LearnedPattern(
      merchantKey: (json['merchant_key'] ?? json['merchantKey']) as String,
      category: category,
      accountName: accountName,
      classification: (json['classification'] as String?) ?? 'gasto',
      moneoType:
          (json['moneo_type'] ?? json['moneoType']) as String? ?? 'Expenses',
      confirmations: confirmations,
      createdAt: createdAt,
      lastUsedAt: lastUsedAt,
      lastCorrectedAt: lastCorrectedAt,
      categoryScores: parsedCatScores,
      accountScores: parsedAccScores,
      status: parsedStatus,
      correctionStreak: correctionStreak,
      pendingCorrectionCategory: pendingCorrectionCategory,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearnedPattern &&
          runtimeType == other.runtimeType &&
          merchantKey == other.merchantKey &&
          category == other.category &&
          accountName == other.accountName &&
          classification == other.classification &&
          confirmations == other.confirmations &&
          status == other.status;

  @override
  int get hashCode =>
      merchantKey.hashCode ^
      category.hashCode ^
      (accountName?.hashCode ?? 0) ^
      classification.hashCode ^
      confirmations.hashCode ^
      status.hashCode;

  @override
  String toString() =>
      'LearnedPattern(merchantKey: $merchantKey, category: $category, account: $accountName, '
      'confirmations: $confirmations, status: ${status.wireValue}, lastUsedAt: $lastUsedAt)';
}
