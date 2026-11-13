class LearnedPattern {
  final String merchantKey;
  final String category;
  final String? accountName;
  final String classification; // 'gasto', 'ingreso', 'transferencia-propia'
  final String? moneoType; // 'Expenses', 'Income', 'Transfer'
  final int confirmations;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final DateTime? lastCorrectedAt;

  const LearnedPattern({
    required this.merchantKey,
    required this.category,
    this.accountName,
    this.classification = 'gasto',
    this.moneoType = 'Expenses',
    this.confirmations = 1,
    required this.createdAt,
    required this.lastUsedAt,
    this.lastCorrectedAt,
  });

  LearnedPattern incrementConfirmation({DateTime? at}) {
    return copyWith(
      confirmations: confirmations + 1,
      lastUsedAt: at ?? DateTime.now(),
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
    );
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
  }) {
    return LearnedPattern(
      merchantKey: merchantKey ?? this.merchantKey,
      category: category ?? this.category,
      accountName: accountName ?? this.accountName,
      classification: classification ?? this.classification,
      moneoType: moneoType ?? this.moneoType,
      confirmations: confirmations ?? this.confirmations,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      lastCorrectedAt: lastCorrectedAt ?? this.lastCorrectedAt,
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
      };

  factory LearnedPattern.fromJson(Map<String, dynamic> json) => LearnedPattern(
        merchantKey: (json['merchant_key'] ?? json['merchantKey']) as String,
        category: json['category'] as String,
        accountName: (json['account_name'] ?? json['accountName']) as String?,
        classification: (json['classification'] as String?) ?? 'gasto',
        moneoType:
            (json['moneo_type'] ?? json['moneoType']) as String? ?? 'Expenses',
        confirmations: (json['confirmations'] as num?)?.toInt() ?? 1,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : (json['createdAt'] != null
                ? DateTime.parse(json['createdAt'] as String)
                : DateTime.now()),
        lastUsedAt: json['last_used_at'] != null
            ? DateTime.parse(json['last_used_at'] as String)
            : (json['lastUsedAt'] != null
                ? DateTime.parse(json['lastUsedAt'] as String)
                : DateTime.now()),
        lastCorrectedAt:
            (json['last_corrected_at'] ?? json['lastCorrectedAt']) != null
                ? DateTime.parse(
                    (json['last_corrected_at'] ?? json['lastCorrectedAt'])
                        as String,
                  )
                : null,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearnedPattern &&
          runtimeType == other.runtimeType &&
          merchantKey == other.merchantKey &&
          category == other.category &&
          accountName == other.accountName &&
          classification == other.classification &&
          confirmations == other.confirmations;

  @override
  int get hashCode =>
      merchantKey.hashCode ^
      category.hashCode ^
      (accountName?.hashCode ?? 0) ^
      classification.hashCode ^
      confirmations.hashCode;

  @override
  String toString() =>
      'LearnedPattern(merchantKey: $merchantKey, category: $category, account: $accountName, '
      'confirmations: $confirmations, lastUsedAt: $lastUsedAt)';
}
