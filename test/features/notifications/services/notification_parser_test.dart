import 'package:flutter_test/flutter_test.dart';

import 'package:finazaap/features/notifications/domain/models/notification_event.dart';
import 'package:finazaap/features/notifications/domain/models/notification_parse_result.dart';
import 'package:finazaap/features/notifications/services/notification_parser.dart';

void main() {
  group('NotificationParser — Reglas Anti-Fraude (Links y Acortadores)', () {
    late NotificationParser parser;

    setUp(() {
      parser = NotificationParser();
    });

    final phishingTestCases = [
      'Tu cuenta fue bloqueada temporalmente. Desbloquea en https://banco-seguro.com/login',
      'Compra por \$100.000 aprobada. Si no fuiste tú, entra ya a bit.ly/3xFakeAlert',
      'Alerta: transacción inusual detectada. Reportar en tinyurl.com/verificar-banco',
      'Comunícate con soporte para revertir tu cargo en wa.me/573001234567',
      'Revisa el estado de tu tarjeta en http://scam-bank.xyz',
      'Confirma tu identidad en www.bancolombia-phishing.click',
      'Transferencia retenida. Desbloquea en cutt.ly/banco-soporte',
      'Ingresa a rb.gy/phish99 para evitar la suspensión de tu producto',
      'Verificación urgente requerida en portal-seguridad.top/auth',
      'Notificación: cobro de \$250.000. Revisa en t.co/alertapago',
    ];

    for (final phishingText in phishingTestCases) {
      test('bloquea incondicionalmente notificación sospechosa: "$phishingText"', () {
        final result = parser.parseRaw(
          title: 'Alerta Bancaria',
          body: phishingText,
        );

        expect(result, isA<SuspiciousNotification>());
        expect(result.status, equals('sospechosa'));
        expect(result.tipo, equals('sospechosa'));
        expect(result.confidence, equals(0.0));
        expect(result.requiresReview, isTrue);
        expect(result.autoProcessable, isFalse);
        expect(result.flags, contains('anti_fraud_link_detected'));

        // Verificar invariantes JSON
        final json = result.toJson();
        expect(json['status'], equals('sospechosa'));
        expect(json['tipo'], equals('sospechosa'));
        expect(json['confidence'], equals(0.0));
        expect(json['requires_review'], isTrue);
        expect(json['auto_processable'], isFalse);
        expect(json['monto'], isNull);
        expect(json['cuenta'], isNull);
      });
    }
  });

  group('NotificationParser — Textos No Transaccionales y OTPs', () {
    late NotificationParser parser;

    setUp(() {
      parser = NotificationParser();
    });

    test('descarta código OTP de seguridad sin extraerlo como monto', () {
      const text =
          'Tu código de seguridad para transferir es 839201. Vence en 5 minutos. No lo compartas con nadie.';

      final result = parser.parseRaw(title: 'Bancolombia', body: text);

      expect(result, isA<UnparseableNotification>());
      expect(result.status, equals('unparseable'));
      expect(result.tipo, equals('desconocido'));
      expect(result.confidence, equals(0.0));
      expect(result.requiresReview, isTrue);
      expect(result.autoProcessable, isFalse);
      expect(result.flags, contains('otp_detected'));

      final json = result.toJson();
      expect(json['monto'], isNull);
    });

    test('descarta clave dinámica no financiera', () {
      const text = 'Usa la clave dinámica 482910 para autorizar tu operación en línea.';

      final result = parser.parseRaw(title: 'Alerta Dinámica', body: text);

      expect(result, isA<UnparseableNotification>());
      expect(result.status, equals('unparseable'));
      expect(result.flags, contains('otp_detected'));
    });

    test('descarta notificación informativa sin monto ni movimiento', () {
      const text = 'Conoce las nuevas funciones y promociones de tu app Bancolombia Personas.';

      final result = parser.parseRaw(title: 'Novedades', body: text);

      expect(result, isA<UnparseableNotification>());
      expect(result.status, equals('unparseable'));
      expect(result.requiresReview, isTrue);
      expect(result.autoProcessable, isFalse);
    });
  });

  group('NotificationParser — Extracción de Montos Multi-Moneda y Separadores', () {
    late NotificationParser parser;

    setUp(() {
      parser = NotificationParser();
    });

    test('parsea monto estándar COP con punto de miles (\$45.000)', () {
      final result = parser.parseRaw(
        title: 'Bancolombia',
        body: 'Compra aprobada por \$45.000 en Éxito Laureles con cta *4821',
      );

      expect(result, isA<ParsedTransaction>());
      final tx = result as ParsedTransaction;
      expect(tx.status, equals('parsed'));
      expect(tx.tipo, equals('gasto'));
      expect(tx.monto, equals(45000.0));
      expect(tx.moneda, equals('COP'));
      expect(tx.comercio, equals('Éxito Laureles'));
      expect(tx.cuenta?.last4, equals('4821'));
      expect(tx.confidence, greaterThanOrEqualTo(0.85));
      expect(tx.requiresReview, isFalse);
      expect(tx.autoProcessable, isTrue);
    });

    test('parsea millones en COP con punto y coma decimal (\$ 1.250.000,50)', () {
      final result = parser.parseRaw(
        title: 'Alerta de Débito',
        body: 'Pago por \$ 1.250.000,50 en Tienda Apple con tarjeta de crédito terminada en 3344',
      );

      expect(result, isA<ParsedTransaction>());
      final tx = result as ParsedTransaction;
      expect(tx.monto, equals(1250000.50));
      expect(tx.tipo, equals('gasto'));
      expect(tx.cuenta?.last4, equals('3344'));
      expect(tx.cuenta?.hint, equals('tarjeta de crédito'));
      expect(tx.requiresReview, isFalse);
      expect(tx.autoProcessable, isTrue);
    });

    test('parsea formato americano USD con coma miles y punto decimal (USD 1,234.56)', () {
      final result = parser.parseRaw(
        title: 'Cargo Internacional',
        body: 'Compra por USD 1,234.56 en Amazon.com con tarjeta *9988',
      );

      expect(result, isA<ParsedTransaction>());
      final tx = result as ParsedTransaction;
      expect(tx.monto, equals(1234.56));
      expect(tx.moneda, equals('USD'));
      expect(tx.comercio, contains('Amazon'));
      expect(tx.cuenta?.last4, equals('9988'));
      expect(tx.requiresReview, isFalse);
      expect(tx.autoProcessable, isTrue);
    });

    test('parsea formato decimal simple sin miles (EUR 150,00)', () {
      final result = parser.parseRaw(
        title: 'BBVA',
        body: 'Pago por EUR 150,00 en Zara con tarjeta *1122',
      );

      expect(result, isA<ParsedTransaction>());
      final tx = result as ParsedTransaction;
      expect(tx.monto, equals(150.00));
      expect(tx.moneda, equals('EUR'));
    });

    test('identifica monto ambiguo (ej. \$1.234 sin contexto unívoco) y activa requires_review', () {
      final result = parser.parseRaw(
        title: 'Aviso',
        body: 'Compra aprobada por \$1.234 en Panadería San Juan',
      );

      expect(result, isA<ParsedTransaction>());
      final tx = result as ParsedTransaction;
      expect(tx.monto, equals(1234.0));
      // Ante ambigüedad de 3 dígitos con prefijo simple, confianza baja y revisión obligatoria
      expect(tx.confidence, equals(0.50));
      expect(tx.requiresReview, isTrue);
      expect(tx.autoProcessable, isFalse);
      expect(tx.flags, contains('ambiguous_amount_separator'));
    });
  });

  group('NotificationParser — Extracción de Tipos, Comercios y Cuentas', () {
    late NotificationParser parser;

    setUp(() {
      parser = NotificationParser();
    });

    test('extrae tipo ingreso correctamente para abonos y transferencias recibidas', () {
      final result = parser.parseRaw(
        title: 'Nequi',
        body: '¡Te enviaron dinero! Recibiste \$80.000 de Pedro Gómez en tu cuenta de ahorros',
      );

      expect(result, isA<ParsedTransaction>());
      final tx = result as ParsedTransaction;
      expect(tx.tipo, equals('ingreso'));
      expect(tx.monto, equals(80000.0));
      expect(tx.comercio, equals('Pedro Gómez'));
      expect(tx.cuenta?.hint, equals('ahorros'));
      expect(tx.requiresReview, isFalse);
      expect(tx.autoProcessable, isTrue);
    });

    test('extrae tipo transferencia entre cuentas propias', () {
      final result = parser.parseRaw(
        title: 'Bancolombia',
        body: 'Transferencia entre cuentas propias por \$300.000 desde cta *1020',
      );

      expect(result, isA<ParsedTransaction>());
      final tx = result as ParsedTransaction;
      expect(tx.tipo, equals('transferencia'));
      expect(tx.monto, equals(300000.0));
      expect(tx.cuenta?.last4, equals('1020'));
    });

    test('maneja ausencia de comercio reduciendo confianza sin romper el parsing', () {
      final result = parser.parseRaw(
        title: 'Débito Automático',
        body: 'Pago aprobado por \$50.000 desde tu cta *7766',
      );

      expect(result, isA<ParsedTransaction>());
      final tx = result as ParsedTransaction;
      expect(tx.tipo, equals('gasto'));
      expect(tx.monto, equals(50000.0));
      expect(tx.comercio, isNull);
      expect(tx.flags, contains('missing_merchant'));
      expect(tx.confidence, lessThan(0.85));
    });

    test('parsea evento completo NotificationEvent', () {
      final event = NotificationEvent(
        id: 'event_real_1',
        packageName: 'com.bancolombia.personas',
        title: 'Bancolombia',
        body: 'Compra por \$65.000 en Restaurante El Punto con cta *9182',
        timestamp: DateTime(2026, 11, 13, 14, 0, 0),
      );

      final result = parser.parse(event);
      expect(result, isA<ParsedTransaction>());
      final tx = result as ParsedTransaction;
      expect(tx.monto, equals(65000.0));
      expect(tx.comercio, equals('Restaurante El Punto'));
      expect(tx.cuenta?.last4, equals('9182'));
      expect(tx.fecha, equals(DateTime(2026, 11, 13, 14, 0, 0)));
      expect(tx.autoProcessable, isTrue);
    });
  });

  group('NotificationParser — Invariantes Estrictos del Contrato', () {
    late NotificationParser parser;

    setUp(() {
      parser = NotificationParser();
    });

    test('invariante: si confidence < 0.80, forzosamente requires_review=true y auto_processable=false', () {
      // Notificación sin comercio y sin tipo claro pero con monto
      final result = parser.parseRaw(
        title: 'Aviso',
        body: 'Movimiento registrado por \$20.000',
      );

      expect(result, isA<ParsedTransaction>());
      final tx = result as ParsedTransaction;
      expect(tx.confidence, lessThan(0.80));
      expect(tx.requiresReview, isTrue);
      expect(tx.autoProcessable, isFalse);
    });

    test('invariante JSON: todas las salidas cumplen con los 9 campos obligatorios', () {
      final inputs = [
        ('Bancolombia', 'Compra aprobada por \$45.000 en Éxito con *1234'),
        ('Alerta', 'Transacción de \$10.000. Ver más en bit.ly/promo'),
        ('Seguridad', 'Tu código OTP es 991122'),
      ];

      for (final (t, b) in inputs) {
        final res = parser.parseRaw(title: t, body: b);
        final json = res.toJson();

        expect(json.containsKey('status'), isTrue);
        expect(json.containsKey('tipo'), isTrue);
        expect(json.containsKey('monto'), isTrue);
        expect(json.containsKey('comercio'), isTrue);
        expect(json.containsKey('fecha'), isTrue);
        expect(json.containsKey('cuenta'), isTrue);
        expect(json.containsKey('confidence'), isTrue);
        expect(json.containsKey('requires_review'), isTrue);
        expect(json.containsKey('auto_processable'), isTrue);

        // Si status == sospechosa
        if (json['status'] == 'sospechosa') {
          expect(json['tipo'], equals('sospechosa'));
          expect(json['confidence'], equals(0.0));
          expect(json['requires_review'], isTrue);
          expect(json['auto_processable'], isFalse);
        }
      }
    });
  });
}
