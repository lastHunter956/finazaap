class NotificationEvent {
  final String id;
  final String packageName;
  final String title;
  final String body;
  final DateTime timestamp;
  final String? channelId;
  final String? category;
  final String? subText;
  final String? summaryText;
  final String? tickerText;
  final List<String> textLines;
  final bool isOngoing;
  final bool isGroupSummary;

  const NotificationEvent({
    required this.id,
    required this.packageName,
    required this.title,
    required this.body,
    required this.timestamp,
    this.channelId,
    this.category,
    this.subText,
    this.summaryText,
    this.tickerText,
    this.textLines = const [],
    this.isOngoing = false,
    this.isGroupSummary = false,
  });

  /// Clave de deduplicación basada en paquete, título, cuerpo y ventana de 5 minutos (300.000 ms).
  String get deduplicationKey =>
      '${packageName.toLowerCase()}|${title.trim()}|${body.trim()}|${timestamp.millisecondsSinceEpoch ~/ 300000}';

  /// Combina título, cuerpo y metadatos textuales adicionales sin duplicar segmentos.
  String get enrichedBody {
    final parts = <String>[];
    void addUnique(String? raw) {
      final clean = raw?.trim() ?? '';
      if (clean.isEmpty) return;
      final lower = clean.toLowerCase();
      if (lower == title.trim().toLowerCase()) return;
      if (parts.any((p) {
        final pLower = p.toLowerCase();
        return pLower == lower || pLower.contains(lower);
      })) {
        return;
      }
      parts.add(clean);
    }

    addUnique(body);
    for (final line in textLines) {
      addUnique(line);
    }
    if (parts.isEmpty) {
      addUnique(subText);
      addUnique(summaryText);
      addUnique(tickerText);
    } else if (subText != null && subText!.trim().length >= 3) {
      addUnique(subText);
    }
    return parts.join(' | ');
  }

  NotificationEvent copyWith({
    String? id,
    String? packageName,
    String? title,
    String? body,
    DateTime? timestamp,
    String? channelId,
    String? category,
    String? subText,
    String? summaryText,
    String? tickerText,
    List<String>? textLines,
    bool? isOngoing,
    bool? isGroupSummary,
  }) {
    return NotificationEvent(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      channelId: channelId ?? this.channelId,
      category: category ?? this.category,
      subText: subText ?? this.subText,
      summaryText: summaryText ?? this.summaryText,
      tickerText: tickerText ?? this.tickerText,
      textLines: textLines ?? this.textLines,
      isOngoing: isOngoing ?? this.isOngoing,
      isGroupSummary: isGroupSummary ?? this.isGroupSummary,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'package_name': packageName,
        'title': title,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        if (channelId != null && channelId!.isNotEmpty) 'channel_id': channelId,
        if (category != null && category!.isNotEmpty) 'category': category,
        if (subText != null && subText!.isNotEmpty) 'sub_text': subText,
        if (summaryText != null && summaryText!.isNotEmpty)
          'summary_text': summaryText,
        if (tickerText != null && tickerText!.isNotEmpty)
          'ticker_text': tickerText,
        if (textLines.isNotEmpty) 'text_lines': textLines,
        if (isOngoing) 'is_ongoing': isOngoing,
        if (isGroupSummary) 'is_group_summary': isGroupSummary,
      };

  factory NotificationEvent.fromJson(Map<String, dynamic> json) {
    final rawLines = json['text_lines'] ?? json['textLines'];
    final lines = rawLines is Iterable
        ? rawLines
            .map((e) => e?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty)
            .toList()
        : const <String>[];
    String? optStr(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return NotificationEvent(
      id: json['id'] as String,
      packageName: (json['package_name'] ?? json['packageName']) as String,
      title: json['title'] as String,
      body: json['body'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      channelId: optStr(json['channel_id'] ?? json['channelId']),
      category: optStr(json['category']),
      subText: optStr(json['sub_text'] ?? json['subText']),
      summaryText: optStr(json['summary_text'] ?? json['summaryText']),
      tickerText: optStr(json['ticker_text'] ?? json['tickerText']),
      textLines: lines,
      isOngoing: (json['is_ongoing'] ?? json['isOngoing']) == true,
      isGroupSummary:
          (json['is_group_summary'] ?? json['isGroupSummary']) == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationEvent &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          packageName == other.packageName &&
          title == other.title &&
          body == other.body &&
          timestamp == other.timestamp &&
          channelId == other.channelId &&
          isOngoing == other.isOngoing &&
          isGroupSummary == other.isGroupSummary;

  @override
  int get hashCode =>
      id.hashCode ^
      packageName.hashCode ^
      title.hashCode ^
      body.hashCode ^
      timestamp.hashCode ^
      (channelId?.hashCode ?? 0) ^
      isOngoing.hashCode ^
      isGroupSummary.hashCode;

  @override
  String toString() =>
      'NotificationEvent(id: $id, packageName: $packageName, channelId: $channelId, title: $title, timestamp: $timestamp)';
}
