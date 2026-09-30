import 'package:el_ahorrador/features/ledger/domain/category.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';

enum StatsPeriod { week, month }

/// Total of one category in the period.
final class CategoryTotal {
  const CategoryTotal(this.category, this.cents, this.count);

  final Category category;
  final int cents;
  final int count;
}

/// One bar of the chart: "L" for a weekday, "7–13" for a week.
final class StatsBar {
  const StatsBar(this.label, this.cents);

  final String label;
  final int cents;
}

/// What Estadísticas shows for a type (gastos or ingresos) and a period
/// (this week or this month), computed as the prototype does.
final class StatsSummary {
  factory StatsSummary({
    required List<Movement> movements,
    required MovementType type,
    required StatsPeriod period,
    required DateTime today,
  }) {
    final day = DateTime(today.year, today.month, today.day);
    final (from, to) = switch (period) {
      StatsPeriod.week => (
        day.subtract(Duration(days: day.weekday - 1)),
        day.add(Duration(days: 7 - day.weekday)),
      ),
      StatsPeriod.month => (
        DateTime(day.year, day.month),
        DateTime(day.year, day.month + 1, 0),
      ),
    };
    final pool = [
      for (final m in movements)
        if (m.type == type && !m.day.isBefore(from) && !m.day.isAfter(to)) m,
    ];
    int sum(DateTime a, DateTime b) => pool
        .where((m) => !m.day.isBefore(a) && !m.day.isAfter(b))
        .fold(0, (t, m) => t + m.amountCents);

    final bars = <StatsBar>[];
    if (period == StatsPeriod.week) {
      const letters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
      for (var i = 0; i < 7; i++) {
        final d = from.add(Duration(days: i));
        bars.add(StatsBar(letters[i], sum(d, d)));
      }
    } else {
      // Calendar weeks (Monday–Sunday) of the month, up to today.
      var start = from;
      while (!start.isAfter(day)) {
        var end = start.add(Duration(days: 7 - start.weekday));
        if (end.isAfter(day)) end = day;
        bars.add(StatsBar('${start.day}–${end.day}', sum(start, end)));
        start = end.add(const Duration(days: 1));
      }
    }

    final byCategory = <Category, (int, int)>{};
    for (final m in pool) {
      final c = Category.of(m.category);
      final (cents, count) = byCategory[c] ?? (0, 0);
      byCategory[c] = (cents + m.amountCents, count + 1);
    }
    final categories = [
      for (final MapEntry(key: c, value: (cents, count)) in byCategory.entries)
        CategoryTotal(c, cents, count),
    ]..sort((a, b) => b.cents.compareTo(a.cents));

    return StatsSummary._(
      from: from,
      totalCents: pool.fold(0, (t, m) => t + m.amountCents),
      count: pool.length,
      bars: bars,
      categories: categories,
    );
  }

  const StatsSummary._({
    required this.from,
    required this.totalCents,
    required this.count,
    required this.bars,
    required this.categories,
  });

  /// First day of the period.
  final DateTime from;
  final int totalCents;
  final int count;
  final List<StatsBar> bars;

  /// Largest first.
  final List<CategoryTotal> categories;

  bool get isEmpty => count == 0;
}

/// Detail of one category this month: movements, total, change against the
/// previous month and its cap.
final class CategoryDetail {
  factory CategoryDetail({
    required Category category,
    required List<Movement> movements,
    required Map<String, int> budgets,
    required DateTime today,
  }) {
    bool inMonth(Movement m, DateTime month) =>
        m.at.year == month.year && m.at.month == month.month;
    final month = DateTime(today.year, today.month);
    final previous = DateTime(today.year, today.month - 1);
    final ofCategory = [
      for (final m in movements)
        if (m.type != MovementType.transfer &&
            Category.of(m.category) == category)
          m,
    ];
    final current = [
      for (final m in ofCategory)
        if (inMonth(m, month)) m,
    ]..sort((a, b) => b.at.compareTo(a.at));
    final before = ofCategory
        .where((m) => inMonth(m, previous))
        .fold(0, (t, m) => t + m.amountCents);
    return CategoryDetail._(
      category: category,
      movements: current,
      totalCents: current.fold(0, (t, m) => t + m.amountCents),
      previousCents: before,
      capCents: budgetFor(category, budgets),
    );
  }

  const CategoryDetail._({
    required this.category,
    required this.movements,
    required this.totalCents,
    required this.previousCents,
    required this.capCents,
  });

  final Category category;
  final List<Movement> movements;
  final int totalCents;
  final int previousCents;
  final int? capCents;

  /// Percent change against last month; null without data last month.
  int? get changePercent => previousCents == 0
      ? null
      : ((totalCents - previousCents) / previousCents * 100).round();

  double get capRatio =>
      capCents == null || capCents == 0 ? 0 : totalCents / capCents!;
}

/// The cap stored for a category, matching any stored name of it.
int? budgetFor(Category category, Map<String, int> budgets) {
  for (final MapEntry(key: name, value: cents) in budgets.entries) {
    if (Category.of(name) == category) return cents;
  }
  return null;
}
