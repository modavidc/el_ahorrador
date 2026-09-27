import 'ledger.dart';

/// Figures of the "Puedes gastar hoy" card and the Mensual tab, computed as
/// `capture-core.js` does: `(budget − spent) / days left (today included)`.
final class MonthSummary {
  MonthSummary({
    required List<Movement> movements,
    required this.budgetCents,
    required this.today,
    DateTime? month,
  }) : month = month ?? DateTime(today.year, today.month),
       movements = [
         for (final m in movements)
           if (m.at.year == (month ?? today).year &&
               m.at.month == (month ?? today).month)
             m,
       ];

  final DateTime month;
  final DateTime today;
  final int budgetCents;

  /// Movements of [month] only.
  final List<Movement> movements;

  int get daysInMonth => DateTime(month.year, month.month + 1, 0).day;

  bool get isCurrent => month.year == today.year && month.month == today.month;

  int _sum(MovementType type) => movements
      .where((m) => m.type == type)
      .fold(0, (total, m) => total + m.amountCents);

  int get spentCents => _sum(MovementType.expense);
  int get incomeCents => _sum(MovementType.income);
  int get netCents => incomeCents - spentCents;
  int get leftCents => budgetCents - spentCents;

  /// Days still to spend in the month, today included.
  int get daysLeft => isCurrent ? daysInMonth - today.day + 1 : 0;

  double get perDay => daysLeft == 0 ? 0 : leftCents / 100 / daysLeft;

  /// Share of the budget already spent, 0–1+ (not clamped).
  double get spentRatio => budgetCents <= 0 ? 0 : spentCents / budgetCents;

  int get spentPercent => (spentRatio * 100).round();

  /// Position of today's mark on the budget bar.
  double get dayRatio => isCurrent ? today.day / daysInMonth : 1;

  bool get overBudget => leftCents < 0;
}

/// Consecutive days with at least one movement, counted back from today (or
/// from yesterday while today has nothing yet, so the streak is not lost
/// before the day ends).
int streakDays(Iterable<Movement> movements, DateTime today) {
  final days = {for (final m in movements) m.day};
  var cursor = DateTime(today.year, today.month, today.day);
  if (!days.contains(cursor)) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  var count = 0;
  while (days.contains(cursor)) {
    count++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return count;
}

/// Movements grouped by day, most recent first; rows keep the order in
/// which they were registered, newest on top.
List<(DateTime, List<Movement>)> groupByDay(Iterable<Movement> movements) {
  final byDay = <DateTime, List<Movement>>{};
  for (final m in movements) {
    byDay.putIfAbsent(m.day, () => []).add(m);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final d in days) (d, byDay[d]!..sort((a, b) => b.at.compareTo(a.at))),
  ];
}

/// Net of a day: income minus expenses (transfers are neutral).
int dayNetCents(Iterable<Movement> movements) => movements.fold(
  0,
  (total, m) => switch (m.type) {
    MovementType.income => total + m.amountCents,
    MovementType.expense => total - m.amountCents,
    MovementType.transfer => total,
  },
);

/// Longest run of consecutive days with movements ("Tu mejor racha").
int bestStreak(Iterable<Movement> movements) {
  final days = {for (final m in movements) m.day}.toList()..sort();
  var best = 0, run = 0;
  DateTime? previous;
  for (final d in days) {
    final next = previous == null
        ? null
        : DateTime(previous.year, previous.month, previous.day + 1);
    run = d == next ? run + 1 : 1;
    if (run > best) best = run;
    previous = d;
  }
  return best;
}

/// Frequent entries of the manual sheet ("Menú · S/ 15"): the notes most
/// repeated with the same amount, newest first on ties.
List<Movement> frequentEntries(
  Iterable<Movement> movements,
  MovementType type, {
  int limit = 4,
}) {
  final groups = <(String, int), List<Movement>>{};
  for (final m in movements.where((m) => m.type == type)) {
    groups.putIfAbsent((m.note.toLowerCase(), m.amountCents), () => []).add(m);
  }
  final ranked = groups.values.toList()
    ..sort((a, b) {
      final byCount = b.length.compareTo(a.length);
      return byCount != 0 ? byCount : b.first.at.compareTo(a.first.at);
    });
  return [for (final g in ranked.take(limit)) g.first];
}
