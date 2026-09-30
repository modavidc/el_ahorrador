import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/ledger/data/drift_ledger_repository.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/reminders/domain/reminder_service.dart';
import 'package:el_ahorrador/features/reminders/domain/reminders.dart';
import 'package:el_ahorrador/features/settings/data/drift_app_preferences.dart';
import 'package:el_ahorrador/features/settings/domain/app_preferences.dart';

Movement _m(DateTime at, int cents, {String category = 'Comida'}) => Movement(
  id: '${at.microsecondsSinceEpoch}$cents$category',
  at: at,
  type: MovementType.expense,
  category: category,
  subcategory: '',
  note: 'Menú',
  account: 'Efectivo',
  amountCents: cents,
);

class _Scheduler implements ReminderScheduler {
  final plans = <ReminderPlan>[];
  final shown = <ReminderNotice>[];

  @override
  Future<void> schedule(ReminderPlan plan) async => plans.add(plan);

  @override
  Future<void> show(ReminderNotice notice) async => shown.add(notice);
}

void main() {
  // Sunday 27 September 2026, 21:00.
  final evening = DateTime(2026, 9, 27, 21);

  List<ReminderNotice> due(
    ReminderSlot slot,
    List<Movement> movements, {
    DateTime? now,
    Map<Preference, bool> prefs = const {},
    Set<String> sent = const {},
    int budget = 240000,
  }) => remindersFor(
    slot,
    movements: movements,
    budgetCents: budget,
    prefs: prefs,
    sent: sent,
    now: now ?? evening,
  );

  group('evening', () {
    test('reminds with the streak when today has nothing yet', () {
      final notices = due(ReminderSlot.evening, [
        _m(DateTime(2026, 9, 25), 1000),
        _m(DateTime(2026, 9, 26), 1000),
      ]);
      expect(notices.single.id, 'daily');
      expect(notices.single.title, 'Aún no registras nada hoy');
      expect(notices.single.body, contains('racha de 2 días'));
    });

    test('stays silent once something was registered today', () {
      expect(due(ReminderSlot.evening, [_m(evening, 1000)]), isEmpty);
    });

    test('the daily reminder can be switched off', () {
      expect(
        due(ReminderSlot.evening, [], prefs: {Preference.dailyReminder: false}),
        isEmpty,
      );
    });

    test('alerts once at 80% of the budget', () {
      final spent = [_m(DateTime(2026, 9, 27, 9), 200000)];
      final alert = due(
        ReminderSlot.evening,
        spent,
      ).where((n) => n.id == 'budget').single;
      expect(alert.title, 'Llevas 83% del presupuesto');
      expect(alert.onceKey, 'budget80-2026-09');
      expect(
        due(
          ReminderSlot.evening,
          spent,
          sent: {'budget80-2026-09'},
        ).where((n) => n.id == 'budget'),
        isEmpty,
      );
    });
  });

  group('morning', () {
    test('Monday brings the weekly recap of the week before', () {
      final notices = due(ReminderSlot.morning, [
        _m(DateTime(2026, 9, 22), 3000),
        _m(DateTime(2026, 9, 23), 5000, category: 'Transporte'),
        _m(DateTime(2026, 9, 28, 8), 9999), // Monday itself: not counted.
      ], now: DateTime(2026, 9, 28, 9));
      expect(notices.single.id, 'weekly');
      expect(notices.single.title, 'Tu semana: S/ 80.00');
      expect(notices.single.body, contains('Transporte'));
    });

    test('day 1 brings how the month before closed', () {
      final notices = due(ReminderSlot.morning, [
        _m(DateTime(2026, 9, 10), 120000),
      ], now: DateTime(2026, 10, 1, 9));
      expect(notices.single.id, 'monthly');
      expect(notices.single.title, 'Cierre de setiembre');
      expect(notices.single.body, contains('S/ 1,200.00 de S/ 2,400 (50%)'));
    });

    test('other days are quiet', () {
      expect(due(ReminderSlot.morning, [], now: evening), isEmpty);
    });
  });

  test('the plan follows the switches and the hour', () {
    final plan = ReminderPlan.from({
      Preference.dailyReminder: false,
      Preference.budgetAlert: false,
      Preference.weeklyRecap: true,
    }, '22:00');
    expect(plan.evening, isFalse);
    expect(plan.morning, isTrue);
    expect(plan.hour, 22);
  });

  group('ReminderService', () {
    late AppDatabase db;
    late DriftAppPreferences preferences;
    late _Scheduler scheduler;
    late ReminderService service;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      preferences = DriftAppPreferences(db);
      scheduler = _Scheduler();
      service = ReminderService(
        ledger: DriftLedgerRepository(db),
        preferences: preferences,
        scheduler: scheduler,
        now: () => evening,
      );
    });
    tearDown(() => db.close());

    test('reschedules when the hour changes', () async {
      final sub = service.keepScheduled().listen(null);
      await pumpEventQueue();
      await preferences.setText(TextPreference.reminderTime, '20:00');
      await pumpEventQueue();
      await sub.cancel();
      expect([for (final p in scheduler.plans) p.hour], [21, 20]);
    });

    test('"Probar recordatorio" shows the daily reminder', () async {
      await service.test();
      expect(scheduler.shown.single.title, 'Aún no registras nada hoy');
    });

    test('the budget alert is remembered once sent', () async {
      await DriftLedgerRepository(db).setMonthlyBudget(10000);
      await DriftLedgerRepository(db).addEntry(
        type: MovementType.expense,
        amountCents: 9000,
        account: 'Efectivo',
        category: 'Comida',
        at: DateTime(2026, 9, 27, 12),
      );
      final first = await service.due(ReminderSlot.evening);
      expect(first.map((n) => n.id), ['budget']);
      expect(await service.due(ReminderSlot.evening), isEmpty);
    });
  });
}
