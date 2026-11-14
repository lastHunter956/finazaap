import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/widgets/add_account_dialogs.dart';
import 'package:finazaap/widgets/edit_account_dialogs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'default_currency': 'USD',
    });
    await CurrencyHelper.loadCurrency();
  });

  testWidgets(
    'AddAccountDialog da fila propia al saldo inicial en móvil estrecho con texto ampliado y conserva valor al guardar',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      AccountItem? created;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: [AppTheme.forMode(AppThemeMode.defaultDark)],
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.35),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  created = await showAddAccountDialog(context);
                },
                child: const Text('Crear'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      final nameField = find.byType(TextField).at(0);
      final balanceField = find.byType(TextField).at(1);
      final typeLabel = find.text('Tipo de cuenta');
      final balanceLabel = find.text('Saldo inicial');

      expect(typeLabel, findsOneWidget);
      expect(balanceLabel, findsOneWidget);

      final typeRect = tester.getRect(typeLabel);
      final balanceLabelRect = tester.getRect(balanceLabel);
      final balanceFieldRect = tester.getRect(balanceField);

      // Fila propia separada de Tipo de cuenta y ancho aprovechado (> 220px en pantalla 360px)
      expect(balanceLabelRect.top, greaterThan(typeRect.bottom));
      expect(balanceFieldRect.width, greaterThan(220));

      final balanceWidget = tester.widget<TextField>(balanceField);
      expect(balanceWidget.style?.fontSize, greaterThanOrEqualTo(15));

      await tester.enterText(nameField, 'Cuenta Pruebas');
      await tester.enterText(balanceField, '12345678.90');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Crear Cuenta'));
      await tester.tap(find.text('Crear Cuenta'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(created, isNotNull);
      expect(created!.balance, equals('12345678.90'));
    },
  );

  testWidgets(
    'EditAccountDialog da fila propia al saldo actual en móvil estrecho con texto ampliado y conserva valor al guardar',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      dynamic edited;
      final existing = AccountItem(
        id: 'acc_edit_1',
        icon: Icons.account_balance_wallet,
        title: 'Nu',
        subtitle: 'Cuenta de Ahorros',
        balance: '12345678.90',
        iconColor: Colors.purple,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: [AppTheme.forMode(AppThemeMode.defaultDark)],
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.35),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  edited = await showEditAccountDialog(context, existing);
                },
                child: const Text('Editar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      final balanceLabel = find.text('Saldo actual');
      final typeLabel = find.text('Tipo');
      final balanceField = find.byType(TextField).at(1);

      expect(balanceLabel, findsOneWidget);
      expect(typeLabel, findsOneWidget);

      final balanceFieldRect = tester.getRect(balanceField);
      final typeLabelRect = tester.getRect(typeLabel);

      // Fila propia separada de Tipo y ancho aprovechado (> 220px en pantalla 360px)
      expect(typeLabelRect.top, greaterThan(balanceFieldRect.bottom));
      expect(balanceFieldRect.width, greaterThan(220));

      final balanceWidget = tester.widget<TextField>(balanceField);
      expect(balanceWidget.style?.fontSize, greaterThanOrEqualTo(15));

      await tester.enterText(balanceField, '98765432.15');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Guardar Cambios'));
      await tester.tap(find.text('Guardar Cambios'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(edited, isA<AccountItem>());
      expect((edited as AccountItem).balance, equals('98765432.15'));
    },
  );

  testWidgets(
    'AddAccountDialog deshabilita Incluir en saldo total y explica exclusión al elegir Tarjeta de Crédito',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      AccountItem? created;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: [AppTheme.forMode(AppThemeMode.defaultDark)],
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  created = await showAddAccountDialog(context);
                },
                child: const Text('Crear TC'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Crear TC'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tarjeta de Crédito').last);
      await tester.pumpAndSettle();

      expect(
        find.text('Excluida: el cupo de TC no es dinero propio'),
        findsOneWidget,
      );
      final switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchTile.value, isFalse);
      expect(switchTile.onChanged, isNull);

      await tester.enterText(find.byType(TextField).at(0), 'Visa Test');
      await tester.enterText(find.byType(TextField).at(1), '5000');
      await tester.ensureVisible(find.text('Crear Cuenta'));
      await tester.tap(find.text('Crear Cuenta'));
      await tester.pumpAndSettle();

      expect(created, isNotNull);
      expect(created!.subtitle, equals('Tarjeta de Crédito'));
      expect(created!.includeInTotal, isFalse);
    },
  );

  testWidgets(
    'EditAccountDialog deshabilita Incluir en saldo total y explica exclusión para Tarjeta de Crédito',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      dynamic edited;
      final existingCard = AccountItem(
        id: 'tc_edit_1',
        icon: Icons.credit_card,
        title: 'Mastercard Test',
        subtitle: 'Tarjeta de Crédito',
        balance: '0.00',
        creditLimit: '3000.00',
        includeInTotal: true,
        iconColor: Colors.orange,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: [AppTheme.forMode(AppThemeMode.defaultDark)],
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  edited = await showEditAccountDialog(context, existingCard);
                },
                child: const Text('Editar TC'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Editar TC'));
      await tester.pumpAndSettle();

      expect(
        find.text('Excluida: el cupo de TC no es dinero propio'),
        findsOneWidget,
      );
      final switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchTile.value, isFalse);
      expect(switchTile.onChanged, isNull);

      await tester.ensureVisible(find.text('Guardar Cambios'));
      await tester.tap(find.text('Guardar Cambios'));
      await tester.pumpAndSettle();

      expect(edited, isA<AccountItem>());
      expect((edited as AccountItem).includeInTotal, isFalse);
    },
  );
}
