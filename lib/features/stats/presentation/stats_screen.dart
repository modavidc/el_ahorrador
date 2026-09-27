import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:el_ahorrador/core/clock/app_clock.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/core/format/fmt.dart';
import 'package:el_ahorrador/features/ledger/presentation/ledger_scope.dart';
import 'package:el_ahorrador/features/ledger/presentation/period_scope.dart';
import 'package:el_ahorrador/app/home/app_shell.dart';
import 'package:el_ahorrador/design_system/legacy_widgets.dart';

/// Estadísticas of the v1 prototype: donut + category list, and the
/// category detail (subcategories, 6-month line, movements).
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, this.categoryRequest});

  /// Other screens (the Coach) open a category detail here.
  final ValueNotifier<String?>? categoryRequest;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  MovementType _type = MovementType.expense;
  String? _category;

  @override
  void initState() {
    super.initState();
    widget.categoryRequest?.addListener(_onCategoryRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onCategoryRequest());
  }

  @override
  void dispose() {
    widget.categoryRequest?.removeListener(_onCategoryRequest);
    super.dispose();
  }

  void _onCategoryRequest() {
    final category = widget.categoryRequest?.value;
    if (category == null || !mounted) return;
    widget.categoryRequest!.value = null;
    final today = AppClock.now();
    PeriodScope.of(context).select(today.year, today.month);
    _type = MovementType.expense;
    _openCategory(category);
  }

  void _openCategory(String? category) {
    setState(() => _category = category);
    ShellScope.maybeOf(context)?.setFabHidden(category != null);
  }

  @override
  Widget build(BuildContext context) {
    final period = PeriodScope.of(context);
    final ledger = LedgerScope.of(context);
    final month = ledger.movements
        .where((m) => m.at.year == period.year && m.at.month == period.month)
        .toList();
    final category = _category;
    if (category != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _openCategory(null);
        },
        child: _CategoryDetail(
          category: category,
          period: period,
          movements: ledger.movements,
          onBack: () => _openCategory(null),
        ),
      );
    }

    final list = month.where((m) => m.type == _type).toList();
    final total = list.fold(0, (t, m) => t + m.amountCents) / 100;
    final byCategory = <String, double>{};
    for (final m in list) {
      byCategory.update(
        m.category,
        (v) => v + m.amount,
        ifAbsent: () => m.amount,
      );
    }
    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    double sumOf(MovementType type) =>
        month
            .where((m) => m.type == type)
            .fold(0, (t, m) => t + m.amountCents) /
        100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: DesignColors.surfaceCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PeriodHeader(
                label: '${Fmt.months[period.month - 1]} ${period.year}',
                onPrevious: () => period.shift(-1),
                onNext: () => period.shift(1),
                trailing: Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: DesignColors.borderInput),
                    borderRadius: BorderRadius.circular(DesignRadius.sm),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Mensual',
                        style: DesignText.label.copyWith(
                          color: DesignColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: DesignSpacing.xxs),
                      const Sym(
                        DesignIcons.expandMore,
                        size: 18,
                        color: DesignColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: DesignSpacing.sm),
              UnderlineTabs(
                labels: [
                  'Ingresos ${Fmt.money(sumOf(MovementType.income))}',
                  'Gastos ${Fmt.money(sumOf(MovementType.expense))}',
                ],
                selected: _type == MovementType.income ? 0 : 1,
                onSelected: (i) => setState(
                  () => _type = i == 0
                      ? MovementType.income
                      : MovementType.expense,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.only(top: 20, bottom: 16),
                decoration: const BoxDecoration(
                  color: DesignColors.surfaceCard,
                  border: Border(
                    bottom: BorderSide(color: DesignColors.border),
                  ),
                ),
                alignment: Alignment.center,
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(200, 200),
                        painter: _DonutPainter([
                          for (final e in sorted)
                            (
                              e.value / total,
                              CategoryStyle.forName(e.key).foreground,
                            ),
                        ]),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _type == MovementType.expense
                                ? 'Gastos'
                                : 'Ingresos',
                            style: DesignText.caption.copyWith(
                              color: DesignColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: DesignSpacing.xxs),
                          Text(
                            Fmt.money(total),
                            style: DesignText.headlineBold,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: DesignSpacing.md),
              ColoredBox(
                color: DesignColors.surfaceCard,
                child: Column(
                  children: [
                    for (final e in sorted)
                      _CategoryRow(
                        name: e.key,
                        amount: e.value,
                        percent: (e.value / total * 100).round(),
                        onTap: () => _openCategory(e.key),
                      ),
                  ],
                ),
              ),
              bottomScrollSpacer,
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.name,
    required this.amount,
    required this.percent,
    required this.onTap,
  });

  final String name;
  final double amount;
  final int percent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.forName(name);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: DesignColors.borderSubtle)),
        ),
        child: Row(
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 40),
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: style.foreground,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$percent%',
                textAlign: TextAlign.center,
                style: DesignText.microStrong.copyWith(
                  color: DesignColors.textInverse,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Sym(style.icon, size: 20, color: style.foreground),
            const SizedBox(width: 10),
            Expanded(child: Text(name, style: DesignText.body)),
            const SizedBox(width: 10),
            Text(Fmt.money(amount), style: DesignText.bodyMedium),
            const SizedBox(width: 10),
            const Sym(
              DesignIcons.chevronRight,
              size: 18,
              color: DesignColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}

/// SVG donut of the prototype: r 66, stroke 30, 1.5px gaps, starting at
/// 12 o'clock over a #F2F2F2 ring.
class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices);

  final List<(double, Color)> slices;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 66.0;
    const circumference = 2 * math.pi * radius;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30;
    canvas.drawCircle(center, radius, paint..color = DesignColors.borderSubtle);
    final gap = slices.length > 1 ? 1.5 : 0.0;
    var offset = 0.0;
    for (final (share, color) in slices) {
      final length = share * circumference;
      final visible = math.max(0.1, length - gap);
      canvas.drawArc(
        rect,
        -math.pi / 2 + offset / radius,
        visible / radius,
        false,
        paint..color = color,
      );
      offset += length;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.slices != slices;
}

// ───────────────────────── Category detail ─────────────────────────

class _CategoryDetail extends StatelessWidget {
  const _CategoryDetail({
    required this.category,
    required this.period,
    required this.movements,
    required this.onBack,
  });

  final String category;
  final PeriodController period;
  final List<Movement> movements;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.forName(category);
    final list = movements
        .where(
          (m) =>
              m.category == category &&
              m.at.year == period.year &&
              m.at.month == period.month,
        )
        .toList();
    final total = list.fold(0, (t, m) => t + m.amountCents) / 100;
    final isIncome = list.isNotEmpty && list.first.type == MovementType.income;
    final subs = <String, double>{};
    for (final m in list) {
      subs.update(m.subcategory, (v) => v + m.amount, ifAbsent: () => m.amount);
    }
    final sortedSubs = subs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final series = [
      for (var i = 5; i >= 0; i--)
        () {
          final d = DateTime(period.year, period.month - i);
          final value =
              movements
                  .where(
                    (m) =>
                        m.category == category &&
                        m.at.year == d.year &&
                        m.at.month == d.month,
                  )
                  .fold(0, (t, m) => t + m.amountCents) /
              100;
          return (Fmt.months[d.month - 1], value, i == 0);
        }(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: const BoxDecoration(
            color: DesignColors.surfaceCard,
            border: Border(bottom: BorderSide(color: DesignColors.border)),
          ),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBack,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Sym(DesignIcons.arrowBack, size: 24),
                ),
              ),
              const SizedBox(width: DesignSpacing.sm),
              Sym(style.icon, size: 22, color: style.foreground),
              const SizedBox(width: DesignSpacing.sm),
              Expanded(child: Text(category, style: DesignText.sheetTitle)),
              const SizedBox(width: DesignSpacing.sm),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => period.shift(-1),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Sym(DesignIcons.chevronLeft, size: 22),
                ),
              ),
              const SizedBox(width: DesignSpacing.sm),
              Text(
                '${Fmt.months[period.month - 1]} ${period.year}',
                style: DesignText.bodyMedium,
              ),
              const SizedBox(width: DesignSpacing.sm),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => period.shift(1),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Sym(DesignIcons.chevronRight, size: 22),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                color: DesignColors.surfaceCard,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total del mes',
                      style: DesignText.caption.copyWith(
                        color: DesignColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: DesignSpacing.xxs),
                    Text(
                      Fmt.money(total),
                      style: DesignText.display.copyWith(
                        color: isIncome
                            ? DesignColors.income
                            : DesignColors.expense,
                      ),
                    ),
                  ],
                ),
              ),
              ColoredBox(
                color: DesignColors.surfaceCard,
                child: Column(
                  children: [
                    _SubRow(
                      name: 'Todas',
                      percent: '100%',
                      amount: total,
                      highlighted: true,
                    ),
                    for (final e in sortedSubs)
                      _SubRow(
                        name: e.key.isEmpty ? category : e.key,
                        percent:
                            '${(e.value / (total == 0 ? 1 : total) * 100).round()}%',
                        amount: e.value,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: DesignSpacing.md),
              Container(
                color: DesignColors.surfaceCard,
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                      child: Text(
                        'Últimos 6 meses',
                        style: DesignText.caption.copyWith(
                          color: DesignColors.textTertiary,
                        ),
                      ),
                    ),
                    ClipRect(
                      child: SizedBox(
                        height: 150,
                        child: CustomPaint(
                          painter: _LinePainter(series, style.foreground),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: DsCard(
                  child: Column(
                    children: [
                      for (final (i, m) in list.indexed)
                        _DetailRow(movement: m, first: i == 0),
                    ],
                  ),
                ),
              ),
              bottomScrollSpacer,
            ],
          ),
        ),
      ],
    );
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow({
    required this.name,
    required this.percent,
    required this.amount,
    this.highlighted = false,
  });

  final String name;
  final String percent;
  final double amount;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
    decoration: BoxDecoration(
      color: highlighted ? DesignColors.selectedSoft : DesignColors.surfaceCard,
      border: const Border(top: BorderSide(color: DesignColors.borderSubtle)),
    ),
    child: Row(
      children: [
        Expanded(child: Text(name, style: DesignText.label)),
        SizedBox(
          width: 60,
          child: Text(
            percent,
            textAlign: TextAlign.right,
            style: DesignText.label.copyWith(color: DesignColors.textTertiary),
          ),
        ),
        SizedBox(
          width: 100,
          child: Text(
            Fmt.money(amount),
            textAlign: TextAlign.right,
            style: DesignText.labelMedium,
          ),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.movement, required this.first});

  final Movement movement;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final m = movement;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        border: first
            ? null
            : const Border(top: BorderSide(color: DesignColors.borderSubtle)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Text(
                  Fmt.twoDigits(m.at.day),
                  style: DesignText.headlineBold.copyWith(height: 1),
                ),
                const SizedBox(height: DesignSpacing.xxs),
                Text(
                  Fmt.weekday(m.at),
                  style: DesignText.microRegular.copyWith(
                    color: DesignColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DesignSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DesignText.bodyMedium,
                ),
                const SizedBox(height: DesignSpacing.xxs),
                Text(
                  [
                    m.subcategory,
                    m.account,
                  ].where((p) => p.isNotEmpty).join(' · '),
                  style: DesignText.caption.copyWith(
                    color: DesignColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DesignSpacing.md),
          Text(
            Fmt.money(m.amount),
            style: DesignText.bodyStrong.copyWith(color: amountColor(m.type)),
          ),
        ],
      ),
    );
  }
}

/// 6-month line of the prototype's SVG (358×150): x = 56 + i·58,
/// y = 118 − v/max·104, grid at 0, ½ and 1 of the maximum. The prototype
/// renders no axis or month labels, so neither does this chart.
class _LinePainter extends CustomPainter {
  _LinePainter(this.series, this.color);

  final List<(String, double, bool)> series;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final max = math.max(1.0, series.map((p) => p.$2).reduce(math.max)) * 1.15;
    double x(int i) => 56.0 + i * 58;
    double y(double v) => 118 - (v / max) * 104;

    final grid = Paint()
      ..color = DesignColors.border
      ..strokeWidth = 1;
    for (final p in [0.0, 0.5, 1.0]) {
      final value = max * p / 1.15;
      final gy = y(value);
      canvas.drawLine(Offset(40, gy), Offset(350, gy), grid);
    }

    final path = Path();
    for (final (i, p) in series.indexed) {
      i == 0 ? path.moveTo(x(i), y(p.$2)) : path.lineTo(x(i), y(p.$2));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    for (final (i, p) in series.indexed) {
      final center = Offset(x(i), y(p.$2));
      final radius = p.$3 ? 5.0 : 3.5;
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = p.$3 ? color : DesignColors.surfaceCard,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.series != series || old.color != color;
}
