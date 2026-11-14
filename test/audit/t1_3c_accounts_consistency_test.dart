import 'dart:io';

import 'package:finazaap/data/account_service.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/widgets/add_account_dialogs.dart';
import 'package:finazaap/widgets/edit_account_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'default_currency': 'COP'});
    await CurrencyHelper.loadCurrency();
  });

  Widget wrapWithApp(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        extensions: [AppTheme.forMode(AppThemeMode.defaultDark)],
      ),
      home: Scaffold(body: child),
    );
  }

  testWidgets('L1.8 y L1.3: AddAccountDialog rechaza " > " y desactiva includeInTotal para Tarjeta de Crédito', (tester) async {
    AccountItem? created;
    await tester.pumpWidget(wrapWithApp(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            created = await showDialog<AccountItem>(
              context: context,
              builder: (_) => const AddAccountDialog(),
            );
          },
          child: const Text('Abrir'),
        ),
      ),
    ));

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    // Seleccionar tipo Tarjeta de Crédito
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarjeta de Crédito').last);
    await tester.pumpAndSettle();

    // Intentar nombre con ' > ' -> debe bloquearse
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Visa > Oro');
    await tester.enterText(fields.at(1), '2000000');
    await tester.ensureVisible(find.text('Crear Cuenta'));
    await tester.tap(find.text('Crear Cuenta'));
    await tester.pumpAndSettle();
    expect(created, isNull);
    expect(find.text('Crear Cuenta'), findsOneWidget);

    // Corregir nombre -> debe crear con includeInTotal = false
    await tester.enterText(fields.at(0), 'Visa Oro');
    await tester.ensureVisible(find.text('Crear Cuenta'));
    await tester.tap(find.text('Crear Cuenta'));
    await tester.pumpAndSettle();

    expect(created, isNotNull);
    expect(created!.title, 'Visa Oro');
    expect(created!.subtitle, 'Tarjeta de Crédito');
    expect(created!.includeInTotal, isFalse);
    expect(created!.creditLimit, '2000000');
  });

  testWidgets('L1.8 y L2.2: EditAccountDialog rechaza " > " y preserva creditLimit original de TC', (tester) async {
    AccountItem? edited;
    final originalCard = AccountItem(
      id: 'visa_1',
      icon: Icons.credit_card,
      title: 'Visa',
      subtitle: 'Tarjeta de Crédito',
      balance: '1400000',
      iconColor: Colors.orange,
      includeInTotal: false,
      creditLimit: '2000000',
      cutoffDay: 20,
      paymentDay: 5,
    );

    await tester.pumpWidget(wrapWithApp(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            edited = await showDialog<AccountItem>(
              context: context,
              builder: (_) => EditAccountDialog(item: originalCard),
            );
          },
          child: const Text('Editar'),
        ),
      ),
    ));

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    final titleField = find.byType(TextField).first;
    await tester.enterText(titleField, 'Visa > Black');
    await tester.ensureVisible(find.text('Guardar Cambios'));
    await tester.tap(find.text('Guardar Cambios'));
    await tester.pumpAndSettle();
    expect(edited, isNull);

    await tester.enterText(titleField, 'Visa Black');
    await tester.ensureVisible(find.text('Guardar Cambios'));
    await tester.tap(find.text('Guardar Cambios'));
    await tester.pumpAndSettle();

    expect(edited, isNotNull);
    expect(edited!.title, 'Visa Black');
    expect(double.parse(edited!.balance), 1400000.0);
    expect(edited!.creditLimit, '2000000');
    expect(edited!.includeInTotal, isFalse);
  });

  test('L5.1: AccountService.markAccountAsDeleted persiste cuenta eliminada', () async {
    final tempDir = Directory.systemTemp.createTempSync('moneo_acc_del_');
    try {
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(ResponsibilityAdapter());
      }
      await ResponsibilityService.init();
      await AccountService.markAccountAsDeleted('Cuenta Cerrada');
      final prefs = await SharedPreferences.getInstance();
      final deleted = prefs.getStringList('deleted_accounts') ?? [];
      expect(deleted, contains('Cuenta Cerrada'));
    } finally {
      await Hive.close().timeout(const Duration(seconds: 2), onTimeout: () => <void>[]);
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });
}
