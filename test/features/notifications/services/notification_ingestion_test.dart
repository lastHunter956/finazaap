import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

import 'package:finazaap/features/notifications/adapters/simulated_notification_source.dart';
import 'package:finazaap/features/notifications/domain/models/notification_event.dart';
import 'package:finazaap/features/notifications/domain/ports/notification_source_port.dart';
import 'package:finazaap/features/notifications/services/bank_whitelist_service.dart';
import 'package:finazaap/features/notifications/services/notification_ingestion_service.dart';

void main() {
  group('BankWhitelistService', () {
    late BankWhitelistService whitelistService;

    setUp(() {
      whitelistService = BankWhitelistService();
    });

    test('contiene las entidades colombianas clave por defecto', () {
      expect(whitelistService.isWhitelisted('com.bancolombia.personas'), isTrue);
      expect(whitelistService.isWhitelisted('com.nequi.MobileApp'), isTrue);
      expect(whitelistService.isWhitelisted('com.davivienda.billetera'), isTrue);
      expect(whitelistService.isWhitelisted('co.daviplata'), isTrue);
      expect(whitelistService.isWhitelisted('com.nu.production'), isTrue);
      expect(whitelistService.isWhitelisted('co.com.bbva.mb'), isTrue);
      expect(whitelistService.isWhitelisted('com.scotiabank.colpatria'), isTrue);
      expect(whitelistService.isWhitelisted('com.bancofalabella.mobile'), isTrue);
      expect(whitelistService.isWhitelisted('com.moneo.simulated.bank'), isTrue);

      expect(whitelistService.getBankName('com.bancolombia.personas'), equals('Bancolombia'));
      expect(whitelistService.getBankName('com.nequi.MobileApp'), equals('Nequi'));
    });

    test('rechaza paquetes no autorizados o desconocidos', () {
      expect(whitelistService.isWhitelisted('com.random.app'), isFalse);
      expect(whitelistService.isWhitelisted('com.whatsapp'), isFalse);
      expect(whitelistService.isWhitelisted('com.instagram.android'), isFalse);
      expect(whitelistService.getBankName('com.random.app'), isNull);
    });

    test('permite agregar y remover paquetes personalizados', () {
      whitelistService.addPackage(
        'com.custom.fintech',
        bankName: 'Mi Fintech Local',
        country: 'CO',
      );

      expect(whitelistService.isWhitelisted('com.custom.fintech'), isTrue);
      expect(whitelistService.getBankName('com.custom.fintech'), equals('Mi Fintech Local'));

      final removed = whitelistService.removePackage('com.custom.fintech');
      expect(removed, isTrue);
      expect(whitelistService.isWhitelisted('com.custom.fintech'), isFalse);
    });

    test('permite deshabilitar y rehabilitar un paquete sin eliminarlo', () {
      expect(whitelistService.isWhitelisted('co.daviplata'), isTrue);

      whitelistService.disablePackage('co.daviplata');
      expect(whitelistService.isWhitelisted('co.daviplata'), isFalse);
      expect(whitelistService.getBankName('co.daviplata'), equals('Daviplata'));

      whitelistService.enablePackage('co.daviplata');
      expect(whitelistService.isWhitelisted('co.daviplata'), isTrue);
    });

    test('resetToDefaults restablece los bancos iniciales', () {
      whitelistService.addPackage('com.temp.bank', bankName: 'Temp Bank');
      whitelistService.disablePackage('com.bancolombia.personas');

      expect(whitelistService.isWhitelisted('com.temp.bank'), isTrue);
      expect(whitelistService.isWhitelisted('com.bancolombia.personas'), isFalse);

      whitelistService.resetToDefaults();

      expect(whitelistService.isWhitelisted('com.temp.bank'), isFalse);
      expect(whitelistService.isWhitelisted('com.bancolombia.personas'), isTrue);
    });
  });

  group('NotificationIngestionService', () {
    late BankWhitelistService whitelistService;
    late NotificationIngestionService ingestionService;

    setUp(() {
      whitelistService = BankWhitelistService();
      ingestionService = NotificationIngestionService(
        whitelistService: whitelistService,
        dedupWindow: const Duration(minutes: 5),
      );
    });

    tearDown(() async {
      await ingestionService.dispose();
    });

    test('acepta y encola eventos de paquetes whitelisted', () async {
      final now = DateTime(2026, 11, 13, 15, 0, 0);
      final event = NotificationEvent(
        id: 'evt_1',
        packageName: 'com.bancolombia.personas',
        title: 'Bancolombia',
        body: 'Compra aprobada por $45.000 en Éxito',
        timestamp: now,
      );

      final eventsEmitted = <NotificationEvent>[];
      final sub = ingestionService.ingestedStream.listen(eventsEmitted.add);

      final result = ingestionService.ingest(event, now: now);

      expect(result.status, equals(IngestionStatus.accepted));
      expect(result.isAccepted, isTrue);
      expect(result.dedupHash.length, equals(64)); // SHA-256 hex string
      expect(ingestionService.ingestedCount, equals(1));
      expect(ingestionService.totalReceivedCount, equals(1));

      // Esperar propagación en stream
      await Future<void>.delayed(Duration.zero);
      expect(eventsEmitted.length, equals(1));
      expect(eventsEmitted.first.id, equals('evt_1'));

      await sub.cancel();
    });

    test('descarta eventos de paquetes fuera de la whitelist', () {
      final now = DateTime(2026, 11, 13, 15, 0, 0);
      final event = NotificationEvent(
        id: 'evt_spam',
        packageName: 'com.spam.promotions',
        title: 'Promo',
        body: 'Gana un millón de pesos hoy',
        timestamp: now,
      );

      final result = ingestionService.ingest(event, now: now);

      expect(result.status, equals(IngestionStatus.ignoredNotWhitelisted));
      expect(result.isNotWhitelisted, isTrue);
      expect(result.isAccepted, isFalse);
      expect(ingestionService.discardedNonWhitelistedCount, equals(1));
      expect(ingestionService.ingestedCount, equals(0));
    });

    test('deduplica ráfagas idénticas dentro de la ventana de 5 minutos', () {
      final baseTime = DateTime(2026, 11, 13, 15, 0, 0);

      final event1 = NotificationEvent(
        id: 'evt_original',
        packageName: 'com.nequi.MobileApp',
        title: 'Nequi',
        body: 'Te enviaron $20.000 de Pedro',
        timestamp: baseTime,
      );

      final eventDuplicate = NotificationEvent(
        id: 'evt_dup',
        packageName: 'com.nequi.MobileApp',
        title: 'Nequi',
        body: 'Te enviaron $20.000 de Pedro',
        timestamp: baseTime.add(const Duration(seconds: 45)),
      );

      final result1 = ingestionService.ingest(event1, now: baseTime);
      expect(result1.status, equals(IngestionStatus.accepted));

      final result2 = ingestionService.ingest(
        eventDuplicate,
        now: baseTime.add(const Duration(seconds: 45)),
      );
      expect(result2.status, equals(IngestionStatus.ignoredDuplicate));
      expect(result2.isDuplicate, isTrue);

      expect(ingestionService.ingestedCount, equals(1));
      expect(ingestionService.discardedDuplicatesCount, equals(1));
      expect(ingestionService.totalReceivedCount, equals(2));
    });

    test('permite un evento con el mismo texto si ocurre pasados los 5 minutos', () {
      final baseTime = DateTime(2026, 11, 13, 15, 0, 0);

      final event1 = NotificationEvent(
        id: 'evt_first',
        packageName: 'co.daviplata',
        title: 'Daviplata',
        body: 'Pasaste $10.000 a Juan',
        timestamp: baseTime,
      );

      final eventLater = NotificationEvent(
        id: 'evt_second',
        packageName: 'co.daviplata',
        title: 'Daviplata',
        body: 'Pasaste $10.000 a Juan',
        timestamp: baseTime.add(const Duration(minutes: 6)),
      );

      final res1 = ingestionService.ingest(event1, now: baseTime);
      expect(res1.status, equals(IngestionStatus.accepted));

      final res2 = ingestionService.ingest(
        eventLater,
        now: baseTime.add(const Duration(minutes: 6)),
      );
      expect(res2.status, equals(IngestionStatus.accepted));
      expect(ingestionService.ingestedCount, equals(2));
      expect(ingestionService.discardedDuplicatesCount, equals(0));
    });

    test('eventos con distinto body o distinto package no se deduplican entre sí', () {
      final now = DateTime(2026, 11, 13, 15, 0, 0);

      final ev1 = NotificationEvent(
        id: '1',
        packageName: 'com.bancolombia.personas',
        title: 'Bancolombia',
        body: 'Compra por $50.000 en Tienda A',
        timestamp: now,
      );

      final ev2 = NotificationEvent(
        id: '2',
        packageName: 'com.bancolombia.personas',
        title: 'Bancolombia',
        body: 'Compra por $50.000 en Tienda B',
        timestamp: now,
      );

      final ev3 = NotificationEvent(
        id: '3',
        packageName: 'com.nequi.MobileApp',
        title: 'Bancolombia',
        body: 'Compra por $50.000 en Tienda A',
        timestamp: now,
      );

      expect(ingestionService.ingest(ev1, now: now).isAccepted, isTrue);
      expect(ingestionService.ingest(ev2, now: now).isAccepted, isTrue);
      expect(ingestionService.ingest(ev3, now: now).isAccepted, isTrue);
      expect(ingestionService.ingestedCount, equals(3));
    });

    test('computeDedupHash genera hashes deterministas y únicos', () {
      final time = DateTime(2026, 11, 13, 10, 0, 0);
      final evA = NotificationEvent(
        id: 'A',
        packageName: 'com.nu.production',
        title: 'Nu',
        body: 'Compra de $12.000',
        timestamp: time,
      );
      final evB = NotificationEvent(
        id: 'B',
        packageName: 'com.nu.production',
        title: 'Nu',
        body: 'Compra de $12.000',
        timestamp: time,
      );

      final hashA = ingestionService.computeDedupHash(evA);
      final hashB = ingestionService.computeDedupHash(evB);

      expect(hashA, equals(hashB));
      expect(hashA.length, equals(64));
    });
  });

  group('SimulatedNotificationSource e Integración con IngestionService', () {
    late SimulatedNotificationSource simulatedSource;
    late BankWhitelistService whitelistService;
    late NotificationIngestionService ingestionService;

    setUp(() {
      simulatedSource = SimulatedNotificationSource();
      whitelistService = BankWhitelistService();
      ingestionService = NotificationIngestionService(
        whitelistService: whitelistService,
      );
    });

    tearDown(() async {
      await simulatedSource.dispose();
      await ingestionService.dispose();
    });

    test('estado inicial del simulador y control de escucha', () async {
      var status = await simulatedSource.checkStatus();
      expect(status.isListening, isFalse);
      expect(status.permissionStatus, equals(NotificationPermissionStatus.granted));

      final started = await simulatedSource.startListening();
      expect(started, isTrue);
      expect(simulatedSource.isListening, isTrue);

      status = await simulatedSource.checkStatus();
      expect(status.isListening, isTrue);

      await simulatedSource.stopListening();
      expect(simulatedSource.isListening, isFalse);
    });

    test('no emite eventos si no está en modo escucha', () {
      final event = NotificationEvent(
        id: 'ev_1',
        packageName: 'com.moneo.simulated.bank',
        title: 'Sim',
        body: 'Compra de $10.000',
        timestamp: DateTime.now(),
      );

      final emitted = simulatedSource.emit(event);
      expect(emitted, isFalse);
    });

    test('flujo integrado: attachSource canaliza eventos al stream ingerido', () async {
      await simulatedSource.startListening();
      ingestionService.attachSource(simulatedSource);

      final ingestedEvents = <NotificationEvent>[];
      final sub = ingestionService.ingestedStream.listen(ingestedEvents.add);

      final ev1 = simulatedSource.emitRaw(
        packageName: 'com.bancolombia.personas',
        title: 'Alerta Bancolombia',
        body: 'Compra por $25.000 en Farmacia',
      );
      expect(ev1, isNotNull);

      // Esperar recepción asíncrona
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(ingestedEvents.length, equals(1));
      expect(ingestedEvents.first.packageName, equals('com.bancolombia.personas'));
      expect(ingestedEvents.first.body, contains('25.000'));

      // Detach y verificar que ya no recibe más eventos
      ingestionService.detachSource();

      simulatedSource.emitRaw(
        packageName: 'com.nequi.MobileApp',
        title: 'Nequi',
        body: 'Enviaste $5.000',
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(ingestedEvents.length, equals(1));

      await sub.cancel();
    });
  });
}
