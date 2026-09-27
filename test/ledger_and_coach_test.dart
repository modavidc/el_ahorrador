import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/core/format/fmt.dart';
import 'package:el_ahorrador/features/coach/domain/coach.dart';
import 'package:el_ahorrador/features/ledger/data/demo_seed.dart';
import 'package:el_ahorrador/features/ledger/data/drift_ledger_repository.dart';
import 'package:el_ahorrador/features/ledger/domain/category.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/ledger/domain/entry_interpreter.dart';
import 'package:el_ahorrador/features/ledger/domain/ledger_repository.dart';
import 'package:el_ahorrador/features/stats/domain/stats.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository ledger;
  late CoachContext coach;

  setUpAll(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await DemoSeedV3.load(db);
    ledger = DriftLedgerRepository(db);
    coach = CoachContext(
      movements: await ledger.watchMovements().first,
      budgetCents: LedgerRepository.defaultMonthlyBudgetCents,
      today: DemoSeedV3.today,
    );
  });
  tearDownAll(() => db.close());

  test('account balances match the prototype', () async {
    final accounts = {
      for (final a in await ledger.watchAccounts().first)
        a.name: Fmt.signedMoney(a.balanceCents / 100),
    };
    expect(accounts, {
      'Efectivo': 'S/ 145.00',
      'BCP': 'S/ 2,310.75',
      'Yape': 'S/ 482.40',
      'BBVA Visa': '${Fmt.minus}S/ 612.30',
    });
  });

  test('Coach insights reproduce the prototype on its data', () {
    final insights = {for (final i in insightsFor(coach)) i.kind: i};
    expect(insights[InsightKind.topCategory]!.title, 'Casa es tu mayor gasto');
    expect(
      insights[InsightKind.topCategory]!.body,
      'S/ 850.00 este mes, 40% del total.',
    );
    expect(
      insights[InsightKind.capture]!.body,
      '12 pagos se registraron solos este mes.',
    );
    expect(insights[InsightKind.monthClose]!.title, 'Cierre de mes en 4 días');
    expect(
      insights[InsightKind.monthClose]!.body,
      'Con S/ 73.05 diarios llegas justo al presupuesto.',
    );
  });

  test('the local coach answers from the figures', () {
    expect(
      LocalCoach.answer('¿Cuánto gasté en Comida?', coach),
      startsWith('En Comida llevas S/ 204.50 en 8 movimientos.'),
    );
    expect(
      LocalCoach.answer('¿Me alcanza hasta fin de mes?', coach),
      startsWith('Sí: te quedan S/ 292.20 para 4 días, unos S/ 73.05 diarios.'),
    );
    expect(
      LocalCoach.answer('¿Puedo gastar S/ 300 este finde?', coach),
      startsWith('Mejor no: te quedan S/ 292.20 para 4 días'),
    );
    expect(
      LocalCoach.answer('¿Qué suscripciones tengo?', coach),
      contains('Netflix S/ 44.90'),
    );
  });

  test('statistics group the month by week and category', () {
    final stats = StatsSummary(
      movements: coach.month.movements,
      type: MovementType.expense,
      period: StatsPeriod.month,
      today: DemoSeedV3.today,
    );
    expect(stats.totalCents, 210780);
    expect(
      [for (final b in stats.bars) b.label],
      ['1–6', '7–13', '14–20', '21–27'],
    );
    expect(stats.categories.first.category, Category.casa);
  });

  test('natural language fills an entry', () async {
    final accounts = await ledger.watchAccounts().first;
    final entry = interpretEntry(
      'almuerzo 18 soles en efectivo',
      accounts: accounts,
    );
    expect(entry.type, MovementType.expense);
    expect(entry.amount, '18');
    expect(entry.category, Category.comida);
    expect(entry.account, 'Efectivo');

    final income = interpretEntry('quincena 2482', accounts: accounts);
    expect(income.type, MovementType.income);
    expect(income.category, Category.sueldo);
  });

  test('amount formatting', () {
    expect(Fmt.money(5451), 'S/ 5,451.00');
    expect(Fmt.money0(2400), 'S/ 2,400');
    expect(Fmt.net(-25), '${Fmt.minus}S/ 25.00');
    expect(Fmt.net0(1542), '+S/ 1,542');
    expect(Fmt.signedMoney(-448.9), '${Fmt.minus}S/ 448.90');
    expect(Fmt.short(3200), '3.2k');
    expect(Fmt.short(249), '249.00');
    expect(Fmt.parseCents('1,234.5'), 123450);
  });
}
