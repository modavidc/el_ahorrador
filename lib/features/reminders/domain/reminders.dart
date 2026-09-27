import 'package:el_ahorrador/core/format/fmt.dart';
import 'package:el_ahorrador/features/ledger/domain/category.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/ledger/domain/month_summary.dart';
import 'package:el_ahorrador/features/settings/domain/app_preferences.dart';

/// When the phone wakes the app to decide what to notify.
enum ReminderSlot {
  /// At the hour chosen in Recordatorios: daily reminder and budget alert.
  evening,

  /// 09:00: weekly recap on Mondays, monthly recap on day 1.
  morning,
}

/// The alarms Recordatorios asks for.
final class ReminderPlan {
  const ReminderPlan({
    required this.evening,
    required this.hour,
    required this.minute,
    required this.morning,
  });

  factory ReminderPlan.from(Map<Preference, bool> prefs, String time) {
    bool on(Preference p) => prefs[p] ?? p.defaultValue;
    final parts = time.split(':');
    return ReminderPlan(
      evening: on(Preference.dailyReminder) || on(Preference.budgetAlert),
      hour: int.tryParse(parts.first) ?? 21,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      morning: on(Preference.weeklyRecap) || on(Preference.monthlyRecap),
    );
  }

  static const morningHour = 9;

  final bool evening;
  final int hour;
  final int minute;
  final bool morning;

  @override
  bool operator ==(Object other) =>
      other is ReminderPlan &&
      other.evening == evening &&
      other.hour == hour &&
      other.minute == minute &&
      other.morning == morning;

  @override
  int get hashCode => Object.hash(evening, hour, minute, morning);
}

final class ReminderNotice {
  const ReminderNotice(this.id, this.title, this.body, {this.onceKey});

  /// daily, budget, weekly or monthly.
  final String id;
  final String title;
  final String body;

  /// Sent once: remembered so it is not repeated ("budget80-2026-09").
  final String? onceKey;
}

/// What to notify in [slot], from the ledger and the switches of
/// Recordatorios. [sent] holds the [ReminderNotice.onceKey]s already used.
List<ReminderNotice> remindersFor(
  ReminderSlot slot, {
  required List<Movement> movements,
  required int budgetCents,
  required Map<Preference, bool> prefs,
  required Set<String> sent,
  required DateTime now,
}) {
  bool on(Preference p) => prefs[p] ?? p.defaultValue;
  final today = DateTime(now.year, now.month, now.day);
  return switch (slot) {
    ReminderSlot.evening => [
      if (on(Preference.dailyReminder)) ?dailyReminder(movements, now),
      if (on(Preference.budgetAlert))
        ?_budgetAlert(movements, budgetCents, now, sent),
    ],
    ReminderSlot.morning => [
      if (on(Preference.weeklyRecap) && today.weekday == DateTime.monday)
        _weeklyRecap(movements, today),
      if (on(Preference.monthlyRecap) && today.day == 1)
        _monthlyRecap(movements, budgetCents, today),
    ],
  };
}

/// "Aún no registras nada hoy"; null when today already has movements.
/// [force] builds it anyway ("Probar recordatorio").
ReminderNotice? dailyReminder(
  List<Movement> movements,
  DateTime now, {
  bool force = false,
}) {
  final today = DateTime(now.year, now.month, now.day);
  if (!force && movements.any((m) => m.day == today)) return null;
  final streak = streakDays(movements, now);
  return ReminderNotice(
    'daily',
    'Aún no registras nada hoy',
    streak > 0
        ? 'Tu racha de $streak ${streak == 1 ? 'día' : 'días'} está en juego. '
              'Registra en segundos.'
        : 'Registra tus gastos en segundos o comparte un comprobante.',
  );
}

ReminderNotice? _budgetAlert(
  List<Movement> movements,
  int budgetCents,
  DateTime now,
  Set<String> sent,
) {
  final key = 'budget80-${now.year}-${now.month.toString().padLeft(2, '0')}';
  if (sent.contains(key) || budgetCents <= 0) return null;
  final m = MonthSummary(
    movements: movements,
    budgetCents: budgetCents,
    today: now,
  );
  if (m.spentRatio < .8) return null;
  return ReminderNotice(
    'budget',
    'Llevas ${m.spentPercent}% del presupuesto',
    m.overBudget
        ? 'Pasaste el presupuesto por ${Fmt.money(-m.leftCents / 100)}.'
        : 'Te quedan ${Fmt.money(m.leftCents / 100)} para ${m.daysLeft} '
              '${m.daysLeft == 1 ? 'día' : 'días'}: ${Fmt.money(m.perDay)} '
              'por día.',
    onceKey: key,
  );
}

/// Monday: the week that ended yesterday.
ReminderNotice _weeklyRecap(List<Movement> movements, DateTime today) {
  final from = today.subtract(const Duration(days: 7));
  final week = [
    for (final m in movements)
      if (m.type == MovementType.expense &&
          !m.day.isBefore(from) &&
          m.day.isBefore(today))
        m,
  ];
  if (week.isEmpty) {
    return const ReminderNotice(
      'weekly',
      'Tu semana',
      'No registraste gastos la semana pasada. ¿Empezamos hoy?',
    );
  }
  final total = week.fold(0, (t, m) => t + m.amountCents);
  final top = _top(week);
  return ReminderNotice(
    'weekly',
    'Tu semana: ${Fmt.money(total / 100)}',
    'Lo que más pesó fue ${top.$1.label} (${Fmt.money(top.$2 / 100)}).',
  );
}

/// Day 1: how the month that just ended closed.
ReminderNotice _monthlyRecap(
  List<Movement> movements,
  int budgetCents,
  DateTime today,
) {
  final previous = DateTime(today.year, today.month - 1);
  final m = MonthSummary(
    movements: movements,
    budgetCents: budgetCents,
    today: today,
    month: previous,
  );
  final name = Fmt.monthsLong[previous.month - 1];
  final expenses = [
    for (final e in m.movements)
      if (e.type == MovementType.expense) e,
  ];
  return ReminderNotice(
    'monthly',
    'Cierre de $name',
    expenses.isEmpty
        ? 'No registraste gastos en $name.'
        : 'Gastaste ${Fmt.money(m.spentCents / 100)} de '
              '${Fmt.money0(budgetCents / 100)} (${m.spentPercent}%). Lo que '
              'más pesó: ${_top(expenses).$1.label}.',
  );
}

(Category, int) _top(List<Movement> expenses) {
  final totals = <Category, int>{};
  for (final m in expenses) {
    totals.update(
      Category.of(m.category),
      (t) => t + m.amountCents,
      ifAbsent: () => m.amountCents,
    );
  }
  final best = totals.entries.reduce((a, b) => a.value >= b.value ? a : b);
  return (best.key, best.value);
}

/// The phone's alarms and notifications.
abstract interface class ReminderScheduler {
  Future<void> schedule(ReminderPlan plan);
  Future<void> show(ReminderNotice notice);
}
