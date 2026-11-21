import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/presentation/widgets/correction_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setMockCategoryPrefs({
    List<String> expenses = const ['Comida', 'Transporte', 'Mercado', 'Obsoleta'],
    List<String> incomes = const ['Salario', 'Extras', 'BonoViejo'],
    List<String> deletedExpenses = const ['Obsoleta'],
    List<String> deletedIncomes = const ['BonoViejo'],
  }) {
    final gastosJson = expenses
        .map((name) => jsonEncode({
              'text': name,
              'icon': Icons.category.codePoint,
              'color': Colors.blueAccent.value,
            }))
        .toList();
    final ingresosJson = incomes
        .map((name) => jsonEncode({
              'text': name,
              'icon': Icons.attach_money.codePoint,
              'color': Colors.greenAccent.value,
            }))
        .toList();

    SharedPreferences.setMockInitialValues({
      'gastos': gastosJson,
      'ingresos': ingresosJson,
      CategoryService.expenseCategoriesKey: expenses,
      CategoryService.incomeCategoriesKey: incomes,
      CategoryService.deletedExpenseCategoriesKey: deletedExpenses,
      CategoryService.deletedIncomeCategoriesKey: deletedIncomes,
    });
  }

  PendingTransactionItem buildItem({
    String classification = 'gasto',
    String? category = 'Alimentación',
  }) {
    return PendingTransactionItem(
      id: 'item_cat_1',
      notificationId: 'notif_cat_1',
      rawText: 'Compra en Exito por \$50.000',
      comercio: 'Exito',
      monto: 50000,
      moneda: 'COP',
      fecha: DateTime(2026, 11, 14, 10, 0),
      classification: classification,
      moneoType: classification == 'ingreso' ? 'Income' : 'Expenses',
      category: category,
      accountName: 'Nu',
      confidence: 0.75,
      requiresReview: true,
      autoProcessable: false,
      decisionSource: 'deterministic_rules',
      createdAt: DateTime(2026, 11, 14, 10, 0),
    );
  }

  testWidgets(
    'Carga categorías activas desde CategoryService, excluye eliminadas y no inventa sugerencia inexistente',
    (tester) async {
      setMockCategoryPrefs();
      CorrectionData? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await CorrectionDialog.show(
                    context,
                    item: buildItem(
                      classification: 'gasto',
                      // 'Alimentación' era sugerencia fija antigua, NO existe en CategoryService
                      category: 'Alimentación',
                    ),
                    availableAccounts: const ['Nu', 'Nequi'],
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // Debe pedir elegir categoría porque 'Alimentación' no existe en CategoryService
      expect(find.text('Elige categoría'), findsOneWidget);

      // Intentar guardar sin elegir categoría válida debe bloquearse con aviso
      await tester.ensureVisible(find.text('Guardar corrección'));
      await tester.tap(find.text('Guardar corrección'));
      await tester.pumpAndSettle();
      expect(find.text('Selecciona una categoría válida'), findsOneWidget);
      expect(result, isNull);

      // Abrir dropdown de categoría y verificar activas vs eliminadas/hardcoded
      await tester.ensureVisible(find.text('Elige categoría'));
      await tester.tap(find.text('Elige categoría'));
      await tester.pumpAndSettle();

      expect(find.text('Comida').last, findsOneWidget);
      expect(find.text('Transporte').last, findsOneWidget);
      expect(find.text('Mercado').last, findsOneWidget);
      expect(find.text('Obsoleta'), findsNothing);
      expect(find.text('Alimentación'), findsNothing);
      expect(find.text('Suscripciones'), findsNothing);

      // Seleccionar 'Mercado' y guardar
      await tester.tap(find.text('Mercado').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Guardar corrección'));
      await tester.tap(find.text('Guardar corrección'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.classification, equals('gasto'));
      expect(result!.category, equals('Mercado'));
    },
  );

  testWidgets(
    'Cambiar entre Gasto e Ingreso limpia selección inválida y muestra solo categorías de ingreso',
    (tester) async {
      setMockCategoryPrefs();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CorrectionDialog(
              item: buildItem(classification: 'gasto', category: 'Comida'),
              availableAccounts: const ['Nu', 'Nequi'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inicialmente tiene 'Comida' (categoría válida de gasto)
      expect(find.text('Comida'), findsOneWidget);

      // Cambiar a Ingreso: 'Comida' no es de ingreso, debe limpiarse a 'Elige categoría'
      await tester.tap(find.text('Ingreso'));
      await tester.pumpAndSettle();

      expect(find.text('Comida'), findsNothing);
      expect(find.text('Elige categoría'), findsOneWidget);

      // Abrir dropdown: solo ingresos activos ('Salario', 'Extras'), sin 'BonoViejo' ni 'Freelance'
      await tester.tap(find.text('Elige categoría'));
      await tester.pumpAndSettle();
      expect(find.text('Salario').last, findsOneWidget);
      expect(find.text('Extras').last, findsOneWidget);
      expect(find.text('BonoViejo'), findsNothing);
      expect(find.text('Freelance'), findsNothing);
    },
  );

  testWidgets(
    'Cambiar a Transferir permite guardar transferencia/pago de tarjeta sin forzar categoría de gasto',
    (tester) async {
      setMockCategoryPrefs();
      CorrectionData? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await CorrectionDialog.show(
                    context,
                    item: buildItem(
                      classification: 'gasto',
                      category: 'Inexistente',
                    ),
                    availableAccounts: const ['Nu', 'TC Banco de Occidente'],
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Transferir'));
      await tester.pumpAndSettle();
      expect(find.text('Cuenta destino'), findsOneWidget);

      await tester.ensureVisible(find.text('Guardar corrección'));
      await tester.tap(find.text('Guardar corrección'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.classification, equals('transferencia-propia'));
      expect(result!.category, equals('Transferencia'));
      expect(result!.accountName, equals('Nu'));
      expect(result!.destinationAccount, equals('TC Banco de Occidente'));
    },
  );

  testWidgets(
    'Si accountName viene nulo NO preselecciona NU por defecto y exige elegir cuenta',
    (tester) async {
      setMockCategoryPrefs();
      CorrectionData? result;

      final itemWithoutAccount = PendingTransactionItem(
        id: 'item_no_acc',
        notificationId: 'notif_no_acc',
        rawText: 'Compra en Juan Valdez por \$18.000',
        comercio: 'Juan Valdez',
        monto: 18000,
        moneda: 'COP',
        fecha: DateTime(2026, 11, 21, 10, 0),
        classification: 'gasto',
        moneoType: 'Expenses',
        category: 'Comida',
        accountName: null,
        confidence: 0.70,
        requiresReview: true,
        autoProcessable: false,
        decisionSource: 'deterministic_rules',
        createdAt: DateTime(2026, 11, 21, 10, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await CorrectionDialog.show(
                    context,
                    item: itemWithoutAccount,
                    availableAccounts: const ['Nu', 'RappiCard', 'Nequi'],
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // Debe mostrar placeholder 'Elige cuenta' y NO preseleccionar 'Nu'
      expect(find.text('Elige cuenta'), findsOneWidget);

      await tester.ensureVisible(find.text('Guardar corrección'));
      await tester.tap(find.text('Guardar corrección'));
      await tester.pumpAndSettle();
      expect(find.text('Selecciona una cuenta válida'), findsOneWidget);
      expect(result, isNull);

      // Elegir RappiCard explícitamente y guardar
      await tester.ensureVisible(find.text('Elige cuenta'));
      await tester.tap(find.text('Elige cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RappiCard').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Guardar corrección'));
      await tester.tap(find.text('Guardar corrección'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.accountName, equals('RappiCard'));
    },
  );
}
