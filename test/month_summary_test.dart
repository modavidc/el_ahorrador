import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/ledger/domain/month_summary.dart';
import 'package:el_ahorrador/features/ledger/presentation/movements_screen.dart';

Movement _m(
  DateTime at,
  int cents, {
  MovementType type = MovementType.expense,
  String note = 'Menú',
}) => Movement(
  id: '${at.microsecondsSinceEpoch}$cents$note',
  at: at,
  type: type,
  category: 'Comida',
  subcategory: '',
  note: note,
  account: 'Efectivo',
  amountCents: cents,
);

void main() {
  final today = DateTime(2026, 9, 27, 21, 40);

  test('"Puedes gastar hoy" divides what is left by the days left', () {
    // The prototype: budget 2,400, spent 2,107.80 by the 27th of 30 days.
    final s = MonthSummary(
      movements: [
        _m(DateTime(2026, 9, 1), 210780),
        _m(DateTime(2026, 9, 1), 365000, type: MovementType.income),
        _m(DateTime(2026, 8, 30), 99900),
      ],
      budgetCents: 240000,
      today: today,
    );
    expect(s.spentCents, 210780);
    expect(s.incomeCents, 365000);
    expect(s.leftCents, 29220);
    expect(s.daysLeft, 4);
    expect(s.perDay, closeTo(73.05, .001));
    expect(s.spentPercent, 88);
    expect(s.dayRatio, closeTo(.9, .001));
  });

  test('streak counts back from today, or from yesterday while today is '
      'empty', () {
    final days = [
      for (final d in [22, 23, 24, 26]) _m(DateTime(2026, 9, d), 100),
    ];
    expect(streakDays(days, today), 1);
    expect(streakDays([...days, _m(DateTime(2026, 9, 25), 1)], today), 5);
    expect(bestStreak([...days, _m(DateTime(2026, 9, 27), 1)]), 3);
  });

  test('frequent entries rank repeated note and amount first', () {
    final list = [
      _m(DateTime(2026, 9, 1), 1500),
      _m(DateTime(2026, 9, 2), 1500),
      _m(DateTime(2026, 9, 3), 900, note: 'Café'),
    ];
    final f = frequentEntries(list, MovementType.expense);
    expect(f.map((m) => m.note), ['Menú', 'Café']);
  });

  test('day labels', () {
    expect(dayLabel(DateTime(2026, 9, 27), today), 'Hoy');
    expect(dayLabel(DateTime(2026, 9, 26), today), 'Ayer');
    expect(dayLabel(DateTime(2026, 9, 25), today), 'Viernes 25');
    expect(dayLabel(DateTime(2026, 8, 25), today), 'Martes 25 ago');
  });
}
