import 'dart:io';

import 'package:finazaap/core/prefs_manager.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Suite de reproducción aislada pendiente (Ola 0 - T0.1).
///
/// Las pruebas de L1.3a/b/c y L1.4 ya fueron trasladadas a
/// `test/audit/t1_3a_transaction_service_test.dart` al corregirse en T1.3a.
/// Aquí permanecen únicamente las reproducciones aún pendientes de Ola 1+.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('moneo_audit_t0_1_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ResponsibilityAdapter());
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefsManager.init();

    if (Hive.isBoxOpen('data')) {
      await Hive.box<Add_data>('data').clear();
    } else {
      await Hive.openBox<Add_data>('data');
    }
    if (Hive.isBoxOpen('responsibilities')) {
      await Hive.box<Responsibility>('responsibilities').clear();
    } else {
      await ResponsibilityService.init();
      await Hive.box<Responsibility>('responsibilities').clear();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('L3.2 escenario probado: togglePaidStatus persiste isPaid=true en Hive', () async {
    final respBox = Hive.box<Responsibility>('responsibilities');
    await respBox.add(Responsibility(
      id: 'internet_id',
      name: 'Internet',
      amount: 100000,
      dueDay: 15,
      category: 'servicio',
      frequency: 'mensual',
      isPaid: false,
    ));

    await ResponsibilityService.togglePaidStatus('internet_id');
    final updated = respBox.getAt(0)!;
    expect(updated.isPaid, isTrue);
  });
}
