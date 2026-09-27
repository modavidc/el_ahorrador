import 'dart:math' as math;

import 'package:el_ahorrador/core/format/fmt.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';

enum InsightKind { pace, habit, subscriptions, unusual }

/// One actionable card of the Coach (design README → Coach). Computed
/// locally from the month's movements; nothing leaves the phone.
final class Insight {
  const Insight({
    required this.kind,
    required this.title,
    required this.body,
    this.category,
  });

  final InsightKind kind;
  final String title;
  final String body;

  /// Category the secondary/primary action opens in Estad., when any.
  final String? category;
}

/// Coach calculations with the prototype's formulas, generalised from its
/// fixed demo data to any ledger.
final class CoachAnalysis {
  CoachAnalysis({
    required List<Movement> movements,
    required this.budgets,
    required this.today,
  }) : current = _inMonth(movements, today.year, today.month),
       previous = _inMonth(movements, today.year, today.month - 1),
       _all = movements;

  final List<Movement> current;
  final List<Movement> previous;
  final Map<String, int> budgets;
  final DateTime today;
  final List<Movement> _all;

  static List<Movement> _inMonth(List<Movement> all, int year, int month) {
    final d = DateTime(year, month);
    return all
        .where((m) => m.at.year == d.year && m.at.month == d.month)
        .toList();
  }

  int get daysInMonth => DateTime(today.year, today.month + 1, 0).day;
  int get daysLeft => daysInMonth - today.day;
  String get monthLong => Fmt.monthsLong[today.month - 1];
  String get previousMonthLong =>
      Fmt.monthsLong[DateTime(today.year, today.month - 1).month - 1];

  static double _expense(Iterable<Movement> list) =>
      list
          .where((m) => m.type == MovementType.expense)
          .fold(0, (t, m) => t + m.amountCents) /
      100;

  double get currentExpense => _expense(current);
  double get previousExpense => _expense(previous);
  double get projection => currentExpense / today.day * daysInMonth;
  double get budgetTotal => budgets.values.fold(0, (a, b) => a + b) / 100;
  double get budgetLeft => budgetTotal - currentExpense;

  Map<String, double> expenseByCategory(Iterable<Movement> list) {
    final totals = <String, double>{};
    for (final m in list.where((m) => m.type == MovementType.expense)) {
      totals.update(m.category, (v) => v + m.amount, ifAbsent: () => m.amount);
    }
    return totals;
  }

  static bool _isDelivery(Movement m) {
    final text = '${m.subcategory} ${m.note}'.toLowerCase();
    return m.type == MovementType.expense &&
        (text.contains('delivery') ||
            text.contains('rappi') ||
            text.contains('pedidosya'));
  }

  List<Insight> insights() => [
    ?_pace(),
    ?_habit(),
    ?_subscriptions(),
    ?_unusual(),
  ];

  Insight? _pace() {
    if (current.isEmpty) return null;
    final proj = projection;
    final prev = previousExpense;
    final comparison = prev > 0
        ? '${((proj / prev - 1).abs() * 100).round()}% '
              '${proj >= prev ? 'más' : 'menos'} que $previousMonthLong '
              '(${Fmt.money(prev)}). '
        : '';
    final budget = budgetTotal <= 0
        ? ''
        : budgetLeft > 0
        ? 'Te quedan $daysLeft días y ${Fmt.money(budgetLeft)} de '
              'presupuesto: unos ${Fmt.money(budgetLeft / math.max(1, daysLeft))} '
              'por día.'
        : 'Ya superaste tu presupuesto por ${Fmt.money(-budgetLeft)}; '
              'quedan $daysLeft días.';
    return Insight(
      kind: InsightKind.pace,
      title: 'A este ritmo cerrarás $monthLong en ${Fmt.money(proj)}',
      body: (comparison + budget).trim(),
    );
  }

  Insight? _habit() {
    final orders = current.where(_isDelivery).toList();
    if (orders.isEmpty) return null;
    final before = previous.where(_isDelivery).length;
    final total = orders.fold(0.0, (t, m) => t + m.amount);
    final projected = orders.length / today.day * daysInMonth;
    // Two orders a week ≈ 8.6 a month.
    final saving = math.max(0, projected - 8.6) * total / orders.length;
    final hours = orders.map((m) => m.at.hour).toList()..sort();
    final place = orders.every((m) => m.note.toLowerCase().contains('rappi'))
        ? 'en Rappi'
        : 'en delivery';
    return Insight(
      kind: InsightKind.habit,
      category: orders.first.category,
      title:
          '${orders.length} pedidos de delivery este mes '
          '(en $previousMonthLong fueron $before)',
      body:
          'Llevas ${Fmt.money(total)} $place, casi todos entre las '
          '${Fmt.twoDigits(hours.first)}:00 y ${Fmt.twoDigits(hours.last + 1)}:00; '
          'vas camino a ${projected.round()} pedidos. Bajando a 2 por semana '
          'ahorrarías ~${Fmt.money(saving.toDouble())} al mes.',
    );
  }

  Insight? _subscriptions() {
    final subs = current
        .where(
          (m) =>
              m.type == MovementType.expense &&
              m.category.toLowerCase().contains('suscrip'),
        )
        .toList();
    if (subs.isEmpty) return null;
    final total = subs.fold(0.0, (t, m) => t + m.amount);
    Movement? find(String name) {
      for (final m in subs) {
        if (m.note.toLowerCase().contains(name)) return m;
      }
      return null;
    }

    final youtube = find('youtube');
    final spotify = find('spotify');
    final body = youtube != null && spotify != null
        ? 'YouTube Premium ya incluye música: se solapa con Spotify. '
              'Quedarte con uno te ahorra '
              '${Fmt.money(math.min(youtube.amount, spotify.amount) * 12)} al año.'
        : 'Revisa cuáles usas de verdad: cada una que canceles se nota a '
              'fin de año.';
    return Insight(
      kind: InsightKind.subscriptions,
      category: subs.first.category,
      title: 'Pagas ${Fmt.money(total)}/mes en ${subs.length} suscripciones',
      body: body,
    );
  }

  Insight? _unusual() {
    Movement? best;
    var bestRatio = 0.0;
    for (final m in current.where((m) => m.type == MovementType.expense)) {
      final history = [
        for (var i = 1; i <= 3; i++)
          _expense(
            _inMonth(
              _all,
              today.year,
              today.month - i,
            ).where((x) => x.category == m.category),
          ),
      ];
      final average = history.reduce((a, b) => a + b) / history.length;
      if (average <= 0) continue;
      final ratio = m.amount / average;
      if (ratio >= 3 && ratio > bestRatio) {
        best = m;
        bestRatio = ratio;
      }
    }
    if (best == null) return null;
    return Insight(
      kind: InsightKind.unusual,
      category: best.category,
      title: '${best.note} · ${Fmt.money(best.amount)}',
      body:
          'Es ${bestRatio.toStringAsFixed(1)}x tu gasto mensual promedio en '
          '${best.category}. ¿Fue planeado? Si fue un gasto único, lo excluyo '
          'de tus promedios.',
    );
  }

  /// Local answers to the decision questions (the LLM replaces this later,
  /// with these same monthly aggregates as context).
  String answer(String question) {
    final q = question.toLowerCase();
    final byCategory = expenseByCategory(current);
    final left = math.max(1, daysLeft);
    if (q.contains('300') || q.contains('finde') || q.contains('permit')) {
      if (budgetTotal <= 0) {
        return 'Define tus presupuestos en Ajustes → Presupuestos y te digo '
            'cuánto puedes gastar sin pasarte.';
      }
      final after = budgetLeft - 300;
      final top = byCategory.entries
          .where((e) => (budgets[e.key] ?? 0) > 0)
          .map((e) => (e.key, e.value / (budgets[e.key]! / 100)))
          .fold<(String, double)?>(
            null,
            (best, e) => best == null || e.$2 > best.$2 ? e : best,
          );
      return after > 0
          ? 'Sí, con cuidado. Te quedan ${Fmt.money(budgetLeft)} de presupuesto '
                'para $left días. Si gastas S/ 300 este finde te quedarían '
                '${Fmt.money(after)} (${Fmt.money(after / left)}/día).'
                '${top == null ? '' : ' Lo que más te aprieta es ${top.$1}: ya vas en ${(top.$2 * 100).round()}% de su tope.'}'
          : 'Mejor no. Te quedan ${Fmt.money(budgetLeft)} de presupuesto para '
                '$left días; gastar S/ 300 te dejaría ${Fmt.money(after.abs())} '
                'por encima. Un tope razonable para el finde sería '
                '${Fmt.money(math.max(0, budgetLeft * 0.4))}.';
    }
    if (q.contains('suscrip')) {
      final subs = current.where(
        (m) =>
            m.type == MovementType.expense &&
            m.category.toLowerCase().contains('suscrip'),
      );
      final total = subs.fold(0.0, (t, m) => t + m.amount);
      return 'Pagas ${Fmt.money(total)}/mes en ${subs.length} suscripciones:\n'
          '${subs.map((m) => '· ${m.note} — ${Fmt.money(m.amount)}').join('\n')}'
          '${_subscriptions()?.body.startsWith('YouTube') ?? false ? '\n\n${_subscriptions()!.body}' : ''}';
    }
    if (q.contains('ahorr') || q.contains('500')) {
      final orders = current.where(_isDelivery).toList();
      final projected = orders.length / today.day * daysInMonth;
      final average = orders.isEmpty
          ? 0.0
          : orders.fold(0.0, (t, m) => t + m.amount) / orders.length;
      final delivery = math.max(0, projected - 8.6) * average;
      return 'Plan para ahorrar S/ 500 el próximo mes:\n'
          '· Delivery a 2 veces/semana (vas camino a ${projected.round()} '
          'pedidos): ~${Fmt.money(delivery.toDouble())}\n'
          '· Revisa suscripciones que se solapan\n'
          '· Pon un tope a Ocio en Presupuestos\n\n'
          '¿Lo convierto en presupuesto?';
    }
    if (q.contains('por qué') ||
        q.contains('más') ||
        q.contains(previousMonthLong)) {
      final before = expenseByCategory(previous);
      final diffs =
          byCategory.entries
              .map(
                (e) => (
                  e.key,
                  e.value / today.day * daysInMonth - (before[e.key] ?? 0),
                ),
              )
              .toList()
            ..sort((a, b) => b.$2.compareTo(a.$2));
      return 'Proyectando $monthLong completo vs $previousMonthLong, lo que '
          'más sube:\n'
          '${diffs.take(3).map((d) => '· ${d.$1}: ${d.$2 >= 0 ? '+' : ''}${Fmt.money(d.$2)}').join('\n')}';
    }
    return 'Puedo ayudarte con decisiones: si puedes permitirte un gasto, '
        'dónde recortar, qué suscripciones sobran o cómo llegar a una meta de '
        'ahorro. Para ver totales y gráficos, Estadísticas lo muestra mejor.';
  }
}
