import 'package:finazaap/features/notifications/domain/models/notification_parse_result.dart';
import 'package:finazaap/features/notifications/services/notification_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('T3.4b: NotificationParser.parseRaw trunca title (>200) y body (>1000) sin perder monto inicial', () {
    final parser = NotificationParser();
    final longTitle = 'Banco ' * 60; // > 200 chars
    final longBody = 'Compra por \$75.000 en Supermercado. ${'detalle ' * 300}';

    final result = parser.parseRaw(title: longTitle, body: longBody);
    expect(result, isA<ParsedTransaction>());
    final tx = result as ParsedTransaction;
    expect(tx.monto, 75000.0);
  });

  test('T3.4c: NotificationParser.parseRaw trunca enlace malicioso más allá de 1000 chars sin colgarse', () {
    final parser = NotificationParser();
    final longBody = 'Compra por \$50.000 en Tienda. ${'a' * 1200} https://evil.example/phish';
    final result = parser.parseRaw(title: 'Banco', body: longBody);
    expect(result, isA<ParsedTransaction>());
  });
}
