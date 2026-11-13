class NotificationEvent {
  final String id;
  final String packageName;
  final String title;
  final String body;
  final DateTime timestamp;

  const NotificationEvent({
    required this.id,
    required this.packageName,
    required this.title,
    required this.body,
    required this.timestamp,
  });

  /// Clave de deduplicación basada en paquete, título, cuerpo y ventana de 5 minutos (300.000 ms).
  String get deduplicationKey =>
      '$packageName|${title.trim()}|${body.trim()}|${timestamp.millisecondsSinceEpoch ~/ 300000}';

  NotificationEvent copyWith({
    String? id,
    String? packageName,
    String? title,
    String? body,
    DateTime? timestamp,
  }) {
    return NotificationEvent(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'package_name': packageName,
    'title': title,
    'body': body,
    'timestamp': timestamp.toIso8601String(),
  };

  factory NotificationEvent.fromJson(Map<String, dynamic> json) =>
      NotificationEvent(
        id: json['id'] as String,
        packageName: (json['package_name'] ?? json['packageName']) as String,
        title: json['title'] as String,
        body: json['body'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationEvent &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          packageName == other.packageName &&
          title == other.title &&
          body == other.body &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      id.hashCode ^
      packageName.hashCode ^
      title.hashCode ^
      body.hashCode ^
      timestamp.hashCode;

  @override
  String toString() =>
      'NotificationEvent(id: $id, packageName: $packageName, title: $title, timestamp: $timestamp)';
}
