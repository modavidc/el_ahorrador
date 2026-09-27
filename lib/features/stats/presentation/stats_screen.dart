import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:el_ahorrador/core/clock/app_clock.dart';
import 'package:el_ahorrador/core/format/fmt.dart';
import 'package:el_ahorrador/design_system/kit.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/ledger/domain/ledger_repository.dart';
import 'package:el_ahorrador/features/ledger/domain/month_summary.dart';
import 'package:el_ahorrador/features/ledger/presentation/ledger_scope.dart';
import 'package:el_ahorrador/features/settings/domain/app_preferences.dart';
import 'package:el_ahorrador/features/stats/domain/stats.dart';

/// Estadísticas (v3): Gastos/Ingresos, Semana/Mes, one card with Barras |
/// Dona, and "En qué se fue" by category.
class StatsScreen extends StatefulWidget {
  const StatsScreen({
    super.key,
    required this.ledger,
    required this.preferences,
    required this.onOpenMovement,
    this.categoryRequest,
  });

  final LedgerRepository ledger;
  final AppPreferences preferences;
  final ValueChanged<Movement> onOpenMovement;

  /// Other screens (the Coach) open a category detail here.
  final ValueNotifier<String?>? categoryRequest;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  MovementType _type = MovementType.expense;
  StatsPeriod _period = StatsPeriod.month;
  bool _donut = false;

  @override
  void initState() {
    super.initState();
    widget.categoryRequest?.addListener(_onCategoryRequest);
  }

  @override
  void dispose() {
    widget.categoryRequest?.removeListener(_onCategoryRequest);
    super.dispose();
  }

  void _onCategoryRequest() {
    final name = widget.categoryRequest?.value;
    if (name == null) return;
    widget.categoryRequest!.value = null;
    _openCategory(Category.of(name));
  }

  void _openCategory(Category category) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LedgerScope.forward(
        context,
        child: CategoryDetailScreen(
          category: category,
          onOpenMovement: widget.onOpenMovement,
        ),
      ),
    ),
  );

  void _openBudgets() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LedgerScope.forward(
        context,
        child: BudgetsScreen(
          ledger: widget.ledger,
          preferences: widget.preferences,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final data = LedgerScope.of(context);
    final today = AppClock.now();
    final stats = StatsSummary(
      movements: data.movements,
      type: _type,
      period: _period,
      today: today,
    );
    final kind = _type == MovementType.expense ? 'gastos' : 'ingresos';
    final label = _period == StatsPeriod.week
        ? 'Semana ${stats.from.day} – ${stats.from.add(const Duration(days: 6)).day} '
              '${Fmt.months[stats.from.month - 1].toLowerCase()}'
        : '${Fmt.monthTitle(today.month)} ${today.year}';
    final top = stats.categories.isEmpty ? 1 : stats.categories.first.cents;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              Expanded(child: Text('Estadísticas', style: DesignText.tabTitle)),
              _PillButton(
                icon: DesignIcons.savings,
                label: 'Presupuestos',
                onTap: _openBudgets,
              ),
            ],
          ),
        ),
        Segmented(
          labels: const ['Gastos', 'Ingresos'],
          selected: _type == MovementType.expense ? 0 : 1,
          onSelected: (i) => setState(
            () => _type = i == 0 ? MovementType.expense : MovementType.income,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            DsChip(
              label: 'Semana',
              selected: _period == StatsPeriod.week,
              onTap: () => setState(() => _period = StatsPeriod.week),
            ),
            const SizedBox(width: 6),
            DsChip(
              label: 'Mes',
              selected: _period == StatsPeriod.month,
              onTap: () => setState(() => _period = StatsPeriod.month),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (stats.isEmpty && data.loaded)
          EmptyState(
            icon: DesignIcons.barChart,
            title:
                'Sin $kind ${_period == StatsPeriod.week ? 'esta semana' : 'este mes'}',
            body: 'Prueba otro periodo o registra un movimiento.',
          )
        else ...[
          PaperCard(
            radius: DesignRadius.bigCard,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$label · $kind',
                            style: DesignText.label13Semi.copyWith(
                              color: DesignColors.ink2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              Fmt.money(stats.totalCents / 100),
                              style: DesignText.style(
                                32,
                                FontWeight.w800,
                                letterSpacing: -.03,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ViewSwitch(
                      donut: _donut,
                      onChanged: (v) => setState(() => _donut = v),
                    ),
                  ],
                ),
                if (_donut) _Donut(stats: stats) else _Bars(bars: stats.bars),
              ],
            ),
          ),
          const SectionHeader(title: 'En qué se fue'),
          PaperCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(
              children: [
                for (final (i, c) in stats.categories.indexed)
                  _CategoryRow(
                    total: c,
                    ratio: c.cents / top,
                    first: i == 0,
                    onTap: () => _openCategory(c.category),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: DesignColors.card,
          borderRadius: BorderRadius.circular(DesignRadius.pill),
          boxShadow: DesignShadows.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Sym(icon, size: 18, color: DesignColors.red),
            const SizedBox(width: 4),
            Text(label, style: DesignText.label13Bold),
          ],
        ),
      ),
    ),
  );
}

class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.donut, required this.onChanged});

  final bool donut;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: DesignColors.chip,
      borderRadius: BorderRadius.circular(DesignRadius.md),
    ),
    child: Row(
      children: [
        for (final (value, icon, label) in const [
          (false, DesignIcons.barChart, 'Ver barras'),
          (true, DesignIcons.donutLarge, 'Ver categorías'),
        ])
          Semantics(
            button: true,
            selected: donut == value,
            label: label,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => onChanged(value),
              child: Container(
                width: 40,
                height: 36,
                decoration: BoxDecoration(
                  color: donut == value ? DesignColors.card : null,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Sym(
                    icon,
                    size: 20,
                    color: donut == value
                        ? DesignColors.ink
                        : DesignColors.ink2,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Bars of 86px at most; the last one in red.
class _Bars extends StatelessWidget {
  const _Bars({required this.bars});

  final List<StatsBar> bars;

  @override
  Widget build(BuildContext context) {
    final max = bars.fold(1, (m, b) => math.max(m, b.cents));
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 110,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, b) in bars.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxWidth: 30),
                      height: math.max(4, b.cents / max * 86),
                      decoration: BoxDecoration(
                        color: i == bars.length - 1
                            ? DesignColors.red
                            : DesignColors.lineStrong,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                          bottom: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        b.label,
                        style: DesignText.tinyBold.copyWith(
                          color: DesignColors.ink2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ring of the 5 largest categories and the count in the middle.
class _Donut extends StatelessWidget {
  const _Donut({required this.stats});

  final StatsSummary stats;

  @override
  Widget build(BuildContext context) {
    final top = stats.categories.take(5).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _DonutPainter([
                for (final c in stats.categories)
                  (CategoryStyle.of(c.category).foreground, c.cents),
              ]),
              child: Center(
                child: Text(
                  '${stats.count} mov.',
                  style: DesignText.label13Bold.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: [
                for (final c in top)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: CategoryStyle.of(c.category).foreground,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.category.label,
                            style: DesignText.label13Semi,
                          ),
                        ),
                        Text(
                          '${(c.cents / stats.totalCents * 100).round()}%',
                          style: DesignText.label13.copyWith(
                            color: DesignColors.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices);

  final List<(Color, int)> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold(0, (t, s) => t + s.$2);
    final stroke = size.width * (120 - 82) / 2 / 120;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    if (total == 0) {
      canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        paint..color = DesignColors.chip,
      );
      return;
    }
    var start = -math.pi / 2;
    for (final (color, cents) in slices) {
      final sweep = cents / total * 2 * math.pi;
      canvas.drawArc(rect, start, sweep, false, paint..color = color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.slices != slices;
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.total,
    required this.ratio,
    required this.first,
    required this.onTap,
  });

  final CategoryTotal total;
  final double ratio;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(total.category);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          decoration: BoxDecoration(
            border: first
                ? null
                : const Border(top: BorderSide(color: DesignColors.lineSoft)),
          ),
          child: Row(
            children: [
              IconTile.category(style, size: 38, iconSize: 20, radius: 13),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            total.category.label,
                            style: DesignText.row,
                          ),
                        ),
                        Text(
                          Fmt.money(total.cents / 100),
                          style: DesignText.rowAmount,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ProgressLine(
                      ratio: ratio,
                      color: style.foreground,
                      height: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Sym(
                DesignIcons.chevronRight,
                size: 20,
                color: DesignColors.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detalle por categoría: total, "vs agosto: ±N%", cap and movements.
class CategoryDetailScreen extends StatelessWidget {
  const CategoryDetailScreen({
    super.key,
    required this.category,
    required this.onOpenMovement,
  });

  final Category category;
  final ValueChanged<Movement> onOpenMovement;

  @override
  Widget build(BuildContext context) {
    final data = LedgerScope.of(context);
    final today = AppClock.now();
    final d = CategoryDetail(
      category: category,
      movements: data.movements,
      budgets: data.budgets,
      today: today,
    );
    final style = CategoryStyle.of(category);
    final change = d.changePercent;
    final up = (change ?? 0) > 0;
    final previousMonth = Fmt.monthsLong[(today.month + 10) % 12];
    final over = d.capRatio > 1;
    return SubPage(
      title: category.label,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(
            children: [
              IconTile.category(style, size: 56, iconSize: 30, radius: 18),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Fmt.money(d.totalCents / 100),
                      style: DesignText.style(
                        34,
                        FontWeight.w800,
                        letterSpacing: -.03,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${d.movements.length} '
                      '${d.movements.length == 1 ? 'movimiento' : 'movimientos'} · '
                      '${Fmt.monthsLong[today.month - 1]}',
                      style: DesignText.label13.copyWith(
                        color: DesignColors.ink2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StatusPill(
                      icon: up
                          ? DesignIcons.trendingUp
                          : DesignIcons.trendingDown,
                      label: change == null
                          ? 'Sin datos de $previousMonth'
                          : 'vs $previousMonth: ${up ? '+' : Fmt.minus}${change.abs()}%',
                      background: up
                          ? DesignColors.blush
                          : DesignColors.greenSoft,
                      color: up ? DesignColors.redDeep : DesignColors.green,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PaperCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Presupuesto', style: DesignText.body14Bold),
                  ),
                  Text(
                    d.capCents == null
                        ? 'Sin tope'
                        : '${(d.capRatio * 100).round()}% de '
                              '${Fmt.money0(d.capCents! / 100)}',
                    style: DesignText.body14Bold.copyWith(
                      color: over ? DesignColors.red : DesignColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ProgressLine(
                ratio: d.capRatio,
                color: over ? DesignColors.red : DesignColors.ink,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PaperCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: d.movements.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Sin movimientos este mes',
                    textAlign: TextAlign.center,
                    style: DesignText.body14.copyWith(color: DesignColors.ink2),
                  ),
                )
              : Column(
                  children: [
                    for (final (i, m) in d.movements.indexed)
                      _DetailRow(
                        movement: m,
                        first: i == 0,
                        onTap: () => onOpenMovement(m),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.movement,
    required this.first,
    required this.onTap,
  });

  final Movement movement;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        decoration: BoxDecoration(
          border: first
              ? null
              : const Border(top: BorderSide(color: DesignColors.lineSoft)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                Fmt.twoDigits(movement.at.day),
                style: DesignText.rowAmountStrong,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movement.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DesignText.row,
                  ),
                  Text(
                    movement.account,
                    style: DesignText.small.copyWith(color: DesignColors.ink2),
                  ),
                ],
              ),
            ),
            Text(Fmt.money(movement.amount), style: DesignText.rowAmount),
          ],
        ),
      ),
    ),
  );
}

/// Presupuestos: the month on a dark card with −/+ S/ 100, the switch to
/// use it, and a cap per category with −/+ S/ 20.
class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({
    super.key,
    required this.ledger,
    required this.preferences,
  });

  final LedgerRepository ledger;
  final AppPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final data = LedgerScope.of(context);
    final today = AppClock.now();
    final summary = MonthSummary(
      movements: data.movements,
      budgetCents: data.monthlyBudgetCents,
      today: today,
    );
    final spending = StatsSummary(
      movements: data.movements,
      type: MovementType.expense,
      period: StatsPeriod.month,
      today: today,
    );
    final spentBy = {for (final c in spending.categories) c.category: c.cents};
    final shown = [
      for (final c in Category.expenses)
        if (spentBy.containsKey(c) || budgetFor(c, data.budgets) != null) c,
      if (spentBy.containsKey(Category.otros)) Category.otros,
    ];

    Future<void> setCap(Category c, int delta) {
      final current = budgetFor(c, data.budgets) ?? 0;
      final next = math.max(0, current + delta);
      return next == 0
          ? ledger.clearBudget(c.label)
          : ledger.setBudget(c.label, next);
    }

    return StreamBuilder<Map<Preference, bool>>(
      stream: preferences.watch(),
      builder: (context, snapshot) {
        final on =
            snapshot.data?[Preference.useMonthlyBudget] ??
            Preference.useMonthlyBudget.defaultValue;
        return SubPage(
          title: 'Presupuestos',
          children: [
            _MonthBudgetCard(
              summary: summary,
              monthLabel: '${Fmt.monthTitle(today.month)} ${today.year}',
              onMinus: () => ledger.setMonthlyBudget(
                math.max(30000, data.monthlyBudgetCents - 10000),
              ),
              onPlus: () =>
                  ledger.setMonthlyBudget(data.monthlyBudgetCents + 10000),
            ),
            const SizedBox(height: 12),
            PaperCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: ToggleRow(
                label: 'Usar presupuesto mensual',
                value: on,
                first: true,
                onTap: () => preferences.set(Preference.useMonthlyBudget, !on),
              ),
            ),
            const SectionHeader(title: 'Topes por categoría'),
            Opacity(
              opacity: on ? 1 : .4,
              child: PaperCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Column(
                  children: [
                    for (final (i, c) in shown.indexed)
                      _CapRow(
                        category: c,
                        spentCents: spentBy[c] ?? 0,
                        capCents: budgetFor(c, data.budgets),
                        first: i == 0,
                        onMinus: () => setCap(c, -2000),
                        onPlus: () => setCap(c, 2000),
                      ),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Registra gastos para poner topes.',
                          style: DesignText.body14.copyWith(
                            color: DesignColors.ink2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MonthBudgetCard extends StatelessWidget {
  const _MonthBudgetCard({
    required this.summary,
    required this.monthLabel,
    required this.onMinus,
    required this.onPlus,
  });

  final MonthSummary summary;
  final String monthLabel;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final soft = DesignText.label13.copyWith(color: DesignColors.onDarkText);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignColors.ink,
        borderRadius: BorderRadius.circular(DesignRadius.bigCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(monthLabel, style: soft),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: '${Fmt.money0(s.spentCents / 100)} ',
              children: [
                TextSpan(
                  text: 'de ${Fmt.money0(s.budgetCents / 100)}',
                  style: DesignText.style(
                    16,
                    FontWeight.w600,
                  ).copyWith(color: DesignColors.onDarkText),
                ),
              ],
            ),
            style: DesignText.style(
              36,
              FontWeight.w800,
              letterSpacing: -.03,
              height: 1.1,
            ).copyWith(color: DesignColors.card),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 16,
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 4,
                    height: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: DesignColors.onDarkTile,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 4,
                    height: 8,
                    width: box.maxWidth * s.spentRatio.clamp(0, 1),
                    child: Container(
                      decoration: BoxDecoration(
                        color: DesignColors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Positioned(
                    left: box.maxWidth * s.dayRatio - 1,
                    top: 0,
                    bottom: 0,
                    width: 2,
                    child: const ColoredBox(color: DesignColors.card),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Ritmo: ${Fmt.money(s.perDay)} por día hasta el ${s.daysInMonth}',
            style: soft,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _DarkButton('${Fmt.minus} S/ 100', onMinus)),
              const SizedBox(width: 8),
              Expanded(child: _DarkButton('+ S/ 100', onPlus)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DarkButton extends StatelessWidget {
  const _DarkButton(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: DesignColors.onDarkTile,
          borderRadius: BorderRadius.circular(DesignRadius.button),
        ),
        child: Text(
          label,
          style: DesignText.body14Bold.copyWith(color: DesignColors.card),
        ),
      ),
    ),
  );
}

class _CapRow extends StatelessWidget {
  const _CapRow({
    required this.category,
    required this.spentCents,
    required this.capCents,
    required this.first,
    required this.onMinus,
    required this.onPlus,
  });

  final Category category;
  final int spentCents;
  final int? capCents;
  final bool first;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(category);
    final ratio = capCents == null ? 0.0 : spentCents / capCents!;
    final over = ratio > 1;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: first
            ? null
            : const Border(top: BorderSide(color: DesignColors.lineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile.category(style, size: 36, iconSize: 20, radius: 12),
              const SizedBox(width: 12),
              Expanded(child: Text(category.label, style: DesignText.row)),
              Text(
                Fmt.money0(spentCents / 100),
                style: DesignText.rowAmount.copyWith(
                  color: over ? DesignColors.red : DesignColors.ink,
                ),
              ),
              Text(
                ' / ${capCents == null ? 'sin tope' : Fmt.money0(capCents! / 100)}',
                style: DesignText.label13.copyWith(color: DesignColors.ink2),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 10),
            child: ProgressLine(
              ratio: ratio,
              color: over ? DesignColors.red : DesignColors.ink,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 10),
            child: Row(
              children: [
                _StepButton(
                  icon: DesignIcons.remove,
                  label: 'Bajar tope',
                  onTap: onMinus,
                ),
                const SizedBox(width: 8),
                _StepButton(
                  icon: DesignIcons.add,
                  label: 'Subir tope',
                  onTap: onPlus,
                ),
                const SizedBox(width: 8),
                Text(
                  capCents == null ? '' : '${(ratio * 100).round()}% usado',
                  style: DesignText.label13.copyWith(color: DesignColors.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: DesignColors.tile,
          borderRadius: BorderRadius.circular(DesignRadius.md),
        ),
        child: Center(child: Sym(icon, size: 20)),
      ),
    ),
  );
}
