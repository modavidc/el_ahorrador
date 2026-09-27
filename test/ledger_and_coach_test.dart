import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/coach/domain/coach_analysis.dart';
import 'package:el_ahorrador/features/ledger/data/demo_seed_v1.dart';
import 'package:el_ahorrador/features/ledger/domain/category.dart';
import 'package:el_ahorrador/features/ledger/domain/entry_interpreter.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/ledger/domain/ledger_repository.dart';
import 'package:el_ahorrador/features/ledger/data/drift_ledger_repository.dart';
import 'package:el_ahorrador/core/format/fmt.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository ledger;

  setUpAll(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await DemoSeed.load(db);
    ledger = DriftLedgerRepository(db);
  });
  tearDownAll(() => db.close());

  test(
    'transfers are one movement and account balances match the design',
    () async {
      final movements = await ledger.watchMovements().first;
      expect(movements, hasLength(DemoSeed.generate().length));
      final transfer = movements.firstWhere((m) => m.note == 'Pago BCP Visa');
      expect(transfer.type, MovementType.transfer);
      expect(transfer.account, 'Interbank Soles');
      expect(transfer.toAccount, 'BCP Visa');

      final accounts = {
        for (final a in await ledger.watchAccounts().first)
          a.name: Fmt.signedMoney(a.balanceCents / 100),
      };
      // Values shown by the prototype's Cuentas screen. The card was overpaid
      // (+349.70), which the screen shows as "Por pagar S/ 0.00".
      expect(accounts, {
        'Efectivo': 'S/ 1,214.40',
        'BCP Soles': 'S/ 2,002.30',
        'Interbank Soles': 'S/ 5,136.00',
        'BCP Visa': 'S/ 349.70',
        'BCP Ahorro': 'S/ 10,444.80',
      });
    },
  );

  test('Coach insights reproduce the prototype on its data', () async {
    final analysis = CoachAnalysis(
      movements: await ledger.watchMovements().first,
      budgets: await ledger.watchBudgets().first,
      today: DemoSeed.today,
    );
    final insights = {for (final i in analysis.insights()) i.kind: i};

    expect(analysis.current, hasLength(64));
    expect(
      insights[InsightKind.pace]!.title,
      'A este ritmo cerrarás setiembre en S/ 4,894.20',
    );
    expect(
      insights[InsightKind.pace]!.body,
      '14% más que agosto (S/ 4,302.80). Te quedan 5 días y S/ 461.50 de '
      'presupuesto: unos S/ 92.30 por día.',
    );
    expect(
      insights[InsightKind.habit]!.title,
      '9 pedidos de delivery este mes (en agosto fueron 4)',
    );
    expect(
      insights[InsightKind.habit]!.body,
      'Llevas S/ 399.10 en Rappi, casi todos entre las 19:00 y 22:00; vas '
      'camino a 11 pedidos. Bajando a 2 por semana ahorrarías ~S/ 97.56 al '
      'mes.',
    );
    expect(
      insights[InsightKind.subscriptions]!.title,
      'Pagas S/ 103.60/mes en 4 suscripciones',
    );
    expect(
      insights[InsightKind.unusual]!.title,
      'Zapatillas Nike Pegasus · S/ 389.00',
    );
  });

  test('natural language fills the form like the prototype', () async {
    final accounts = await ledger.watchAccounts().first;
    final entry = interpretEntry(
      'rappi pizza 42 soles con la visa',
      accounts: accounts,
    );
    expect(entry.type, MovementType.expense);
    expect(entry.amount, '42');
    expect(entry.category, Category.comida);
    expect(entry.account, 'BCP Visa');
    expect(entry.note, 'Rappi pizza');
    expect(entry.hint, 'Gasto · Comida · BCP Visa. Revisa y guarda.');

    final income = interpretEntry('quincena 2482', accounts: accounts);
    expect(income.type, MovementType.income);
    expect(income.category, Category.sueldo);
  });

  test('amount formatting', () {
    expect(Fmt.money(5451), 'S/ 5,451.00');
    expect(Fmt.money0(2400), 'S/ 2,400');
    expect(Fmt.net(-25), '\u2212S/ 25.00');
    expect(Fmt.net0(1542), '+S/ 1,542');
    expect(Fmt.signedMoney(-448.9), '\u2212S/ 448.90');
    expect(Fmt.short(3200), '3.2k');
    expect(Fmt.short(249), '249.00');
  });
}
