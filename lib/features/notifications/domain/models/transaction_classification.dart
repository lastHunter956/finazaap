class TransactionClassification {
  final String
      classification; // 'gasto', 'ingreso', 'transferencia-propia', 'sospechosa', 'spam'
  final String? moneoType; // 'Expenses', 'Income', 'Transfer', null
  final String? category;
  final String? accountName;
  final String? destinationAccount;
  final double confidence;
  final bool requiresReview;
  final bool createTransaction;
  final String
      decisionSource; // 'anti_fraud', 'learned_spam', 'promo_filter', 'ai_spam', 'learned_patterns', 'deterministic_rules', 'gemma_fallback', 'ai_context_aware', 'fallback_ambiguous'
  final String? strategicNote;
  final bool isTransaction;
  final String? spamReason;
  final String? matchedSpamRuleKey;
  final String? suggestedDescription;
  final double? suggestedAmount;
  final bool aiAnalyzed;

  const TransactionClassification({
    required this.classification,
    this.moneoType,
    this.category,
    this.accountName,
    this.destinationAccount,
    required this.confidence,
    required this.requiresReview,
    required this.createTransaction,
    required this.decisionSource,
    this.strategicNote,
    this.isTransaction = true,
    this.spamReason,
    this.matchedSpamRuleKey,
    this.suggestedDescription,
    this.suggestedAmount,
    this.aiAnalyzed = false,
  });

  static String? resolveMoneoType(String classification) {
    switch (classification) {
      case 'gasto':
        return 'Expenses';
      case 'ingreso':
        return 'Income';
      case 'transferencia-propia':
        return 'Transfer';
      case 'sospechosa':
      case 'spam':
      default:
        return null;
    }
  }

  bool get isSuspicious => classification == 'sospechosa';
  bool get isSpam => !isTransaction || classification == 'spam';
  bool get isExpense => classification == 'gasto';
  bool get isIncome => classification == 'ingreso';
  bool get isTransfer => classification == 'transferencia-propia';

  TransactionClassification copyWith({
    String? classification,
    String? moneoType,
    String? category,
    String? accountName,
    String? destinationAccount,
    double? confidence,
    bool? requiresReview,
    bool? createTransaction,
    String? decisionSource,
    String? strategicNote,
    bool? isTransaction,
    String? spamReason,
    String? matchedSpamRuleKey,
    String? suggestedDescription,
    double? suggestedAmount,
    bool? aiAnalyzed,
  }) {
    return TransactionClassification(
      classification: classification ?? this.classification,
      moneoType: moneoType ?? this.moneoType,
      category: category ?? this.category,
      accountName: accountName ?? this.accountName,
      destinationAccount: destinationAccount ?? this.destinationAccount,
      confidence: confidence ?? this.confidence,
      requiresReview: requiresReview ?? this.requiresReview,
      createTransaction: createTransaction ?? this.createTransaction,
      decisionSource: decisionSource ?? this.decisionSource,
      strategicNote: strategicNote ?? this.strategicNote,
      isTransaction: isTransaction ?? this.isTransaction,
      spamReason: spamReason ?? this.spamReason,
      matchedSpamRuleKey: matchedSpamRuleKey ?? this.matchedSpamRuleKey,
      suggestedDescription: suggestedDescription ?? this.suggestedDescription,
      suggestedAmount: suggestedAmount ?? this.suggestedAmount,
      aiAnalyzed: aiAnalyzed ?? this.aiAnalyzed,
    );
  }

  Map<String, dynamic> toJson() => {
        'classification': classification,
        'moneo_type': moneoType,
        'category': category,
        'account_name': accountName,
        'destination_account': destinationAccount,
        'confidence': confidence,
        'requires_review': requiresReview,
        'create_transaction': createTransaction,
        'decision_source': decisionSource,
        if (strategicNote != null) 'strategic_note': strategicNote,
        if (!isTransaction) 'is_transaction': isTransaction,
        if (spamReason != null) 'spam_reason': spamReason,
        if (matchedSpamRuleKey != null)
          'matched_spam_rule_key': matchedSpamRuleKey,
        if (suggestedDescription != null)
          'suggested_description': suggestedDescription,
        if (suggestedAmount != null) 'suggested_amount': suggestedAmount,
        if (aiAnalyzed) 'ai_analyzed': aiAnalyzed,
      };

  factory TransactionClassification.fromJson(
    Map<String, dynamic> json,
  ) =>
      TransactionClassification(
        classification: json['classification'] as String,
        moneoType: (json['moneo_type'] ?? json['moneoType']) as String?,
        category: json['category'] as String?,
        accountName: (json['account_name'] ?? json['accountName']) as String?,
        destinationAccount: (json['destination_account'] ??
            json['destinationAccount']) as String?,
        confidence: (json['confidence'] as num).toDouble(),
        requiresReview:
            (json['requires_review'] ?? json['requiresReview']) as bool,
        createTransaction:
            (json['create_transaction'] ?? json['createTransaction']) as bool,
        decisionSource:
            (json['decision_source'] ?? json['decisionSource']) as String,
        strategicNote:
            (json['strategic_note'] ?? json['strategicNote']) as String?,
        isTransaction:
            (json['is_transaction'] ?? json['isTransaction']) as bool? ?? true,
        spamReason: (json['spam_reason'] ?? json['spamReason']) as String?,
        matchedSpamRuleKey: (json['matched_spam_rule_key'] ??
            json['matchedSpamRuleKey']) as String?,
        suggestedDescription: (json['suggested_description'] ??
            json['suggestedDescription']) as String?,
        suggestedAmount:
            (json['suggested_amount'] ?? json['suggestedAmount']) != null
                ? ((json['suggested_amount'] ?? json['suggestedAmount']) as num)
                    .toDouble()
                : null,
        aiAnalyzed: (json['ai_analyzed'] ?? json['aiAnalyzed']) == true,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionClassification &&
          runtimeType == other.runtimeType &&
          classification == other.classification &&
          moneoType == other.moneoType &&
          category == other.category &&
          accountName == other.accountName &&
          destinationAccount == other.destinationAccount &&
          confidence == other.confidence &&
          requiresReview == other.requiresReview &&
          createTransaction == other.createTransaction &&
          decisionSource == other.decisionSource;

  @override
  int get hashCode =>
      classification.hashCode ^
      moneoType.hashCode ^
      category.hashCode ^
      accountName.hashCode ^
      destinationAccount.hashCode ^
      confidence.hashCode ^
      requiresReview.hashCode ^
      createTransaction.hashCode ^
      decisionSource.hashCode;

  @override
  String toString() =>
      'TransactionClassification(classification: $classification, moneoType: $moneoType, '
      'category: $category, account: $accountName, confidence: $confidence, source: $decisionSource)';
}
