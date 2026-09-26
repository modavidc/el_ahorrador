import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_clock.dart';
import '../../features/ledger/ledger.dart';
import '../../theme/design_tokens.dart';
import '../format.dart';
import '../ledger_scope.dart';
import '../period_scope.dart';
import '../widgets.dart';

/// Trans. screen of the v1 prototype: Diario, Calendario, Mensual, Total.
class TransScreen extends StatefulWidget {
  const TransScreen({super.key, this.onTapMovement, this.tabRequest});

  final ValueChanged<Movement>? onTapMovement;

  /// Other screens (the Coach) ask for a tab here: 0 Diario … 3 Total.
  final ValueNotifier<int?>? tabRequest;

  @override
  State<TransScreen> createState() => _TransScreenState();
}

enum _Tab { daily, calendar, monthly, total }

class _TransScreenState extends State<TransScreen> {
  late DateTime _today;
  late int _listYear; // year shown by Mensual
  late int _selectedDay;
  late int _openMonth; // month expanded in Mensual, -1 for none
  _Tab _tab = _Tab.daily;

  @override
  void initState() {
    super.initState();
    _today = AppClock.now();
    _listYear = _today.year;
    widget.tabRequest?.addListener(_onTabRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.tabRequest?.value != null) _onTabRequest();
    });
    _selectedDay = _today.day;
    _openMonth = _today.month;
  }

  @override
  void dispose() {
    widget.tabRequest?.removeListener(_onTabRequest);
    super.dispose();
  }

  void _onTabRequest() {
    final tab = widget.tabRequest!.value;
    if (tab == null) return;
    widget.tabRequest!.value = null;
    _period.select(_today.year, _today.month);
    _selectTab(tab);
  }

  int _daysIn(int year, int month) => DateTime(year, month + 1, 0).day;

  PeriodController get _period => PeriodScope.of(context);
  int get _year => _period.year;
  int get _month => _period.month;

  void _shiftMonth(int delta) {
    _period.shift(delta);
    setState(() {
      _selectedDay = _selectedDay.clamp(1, _daysIn(_year, _month));
      _openMonth = _month;
      _listYear = _year;
    });
  }

  void _shiftPeriod(int delta) {
    if (_tab != _Tab.monthly) return _shiftMonth(delta);
    setState(() {
      if (delta < 0) {
        _listYear--;
        _openMonth = -1;
      } else {
        _listYear = (_listYear + 1).clamp(_listYear, _today.year);
      }
    });
  }

  void _selectTab(int index) => setState(() {
    _tab = _Tab.values[index];
    if (_tab == _Tab.monthly) _openMonth = _month;
    _listYear = _year;
  });

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    final all = ledger.movements;
    final monthMovements = all
        .where((m) => m.at.year == _year && m.at.month == _month)
        .toList();
    final scope = _tab == _Tab.monthly
        ? all.where((m) => m.at.year == _listYear).toList()
        : monthMovements;
    final income = _sum(scope, MovementType.income);
    final expense = _sum(scope, MovementType.expense);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: DesignColors.surfaceCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PeriodHeader(
                label: _tab == _Tab.monthly
                    ? '$_listYear'
                    : '${Fmt.months[_month - 1]} $_year',
                onPrevious: () => _shiftPeriod(-1),
                onNext: () => _shiftPeriod(1),
                trailing: const Row(
                  children: [
                    Sym(
                      DesignIcons.star,
                      size: 22,
                      color: DesignColors.textSecondary,
                    ),
                    SizedBox(width: DesignSpacing.lg),
                    Sym(
                      DesignIcons.search,
                      size: 22,
                      color: DesignColors.textSecondary,
                    ),
                    SizedBox(width: DesignSpacing.lg),
                    Sym(
                      DesignIcons.tune,
                      size: 22,
                      color: DesignColors.textSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              UnderlineTabs(
                labels: const ['Diario', 'Calendario', 'Mensual', 'Total'],
                selected: _tab.index,
                onSelected: _selectTab,
              ),
              SummaryBar(
                items: [
                  ('Ingresos', Fmt.money(income), DesignColors.income),
                  ('Gastos', Fmt.money(expense), DesignColors.expense),
                  (
                    'Total',
                    Fmt.signedMoney(income - expense),
                    DesignColors.textPrimary,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            key: PageStorageKey(_tab),
            padding: EdgeInsets.zero,
            children: [
              switch (_tab) {
                _Tab.daily => _DailyView(
                  movements: monthMovements,
                  onTap: widget.onTapMovement,
                ),
                _Tab.calendar => _CalendarView(
                  year: _year,
                  month: _month,
                  today: _today,
                  selectedDay: _selectedDay,
                  movements: monthMovements,
                  onSelectDay: (day) => setState(() => _selectedDay = day),
                  onTap: widget.onTapMovement,
                ),
                _Tab.monthly => _MonthlyView(
                  year: _listYear,
                  today: _today,
                  openMonth: _openMonth,
                  movements: all,
                  onToggle: (month) => setState(
                    () => _openMonth = _openMonth == month ? -1 : month,
                  ),
                ),
                _Tab.total => _TotalView(
                  year: _year,
                  month: _month,
                  today: _today,
                  ledger: ledger,
                  monthMovements: monthMovements,
                ),
              },
              bottomScrollSpacer,
            ],
          ),
        ),
      ],
    );
  }
}

double _sum(Iterable<Movement> list, MovementType type) =>
    list
        .where((m) => m.type == type)
        .fold(0, (total, m) => total + m.amountCents) /
    100;

Map<int, List<Movement>> _byDay(List<Movement> movements) {
  final days = <int, List<Movement>>{};
  for (final m in movements) {
    days.putIfAbsent(m.at.day, () => []).add(m);
  }
  return days;
}

// ───────────────────────────── Diario ─────────────────────────────

class _DailyView extends StatelessWidget {
  const _DailyView({required this.movements, this.onTap});

  final List<Movement> movements;
  final ValueChanged<Movement>? onTap;

  @override
  Widget build(BuildContext context) {
    final days = _byDay(movements);
    final keys = days.keys.toList()..sort((a, b) => b.compareTo(a));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (keys.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Text(
                'Sin movimientos este mes',
                textAlign: TextAlign.center,
                style: DesignText.body.copyWith(
                  color: DesignColors.textTertiary,
                ),
              ),
            ),
          for (final (i, day) in keys.indexed) ...[
            if (i > 0) const SizedBox(height: DesignSpacing.md),
            _DayCard(movements: days[day]!, onTap: onTap),
          ],
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.movements, this.onTap});

  final List<Movement> movements;
  final ValueChanged<Movement>? onTap;

  @override
  Widget build(BuildContext context) {
    final date = movements.first.at;
    final weekday = Fmt.weekdayIndex(date);
    final chip = weekday == 0
        ? DesignColors.expense
        : weekday == 6
        ? DesignColors.income
        : DesignColors.neutralAmount;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: DesignColors.borderSubtle),
              ),
            ),
            child: Row(
              children: [
                Text(Fmt.twoDigits(date.day), style: DesignText.title),
                const SizedBox(width: DesignSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 6,
                  ),
                  decoration: BoxDecoration(
                    color: chip,
                    borderRadius: BorderRadius.circular(DesignRadius.xs),
                  ),
                  child: Text(
                    Fmt.weekdays[weekday],
                    style: DesignText.micro.copyWith(
                      color: DesignColors.textInverse,
                    ),
                  ),
                ),
                const SizedBox(width: DesignSpacing.sm),
                // Yields space (ellipsis) so the day totals always fit, even
                // with large accessibility text.
                Expanded(
                  child: Text(
                    '${Fmt.twoDigits(date.month)}.${date.year}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DesignText.caption.copyWith(
                      color: DesignColors.textTertiary,
                    ),
                  ),
                ),
                Text(
                  Fmt.money(_sum(movements, MovementType.income)),
                  style: DesignText.labelMedium.copyWith(
                    color: DesignColors.income,
                  ),
                ),
                const SizedBox(width: DesignSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 78),
                  child: Text(
                    Fmt.money(_sum(movements, MovementType.expense)),
                    textAlign: TextAlign.right,
                    style: DesignText.labelMedium.copyWith(
                      color: DesignColors.expense,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final (i, m) in movements.indexed)
            TransactionRow(
              movement: m,
              first: i == 0,
              onTap: onTap == null ? null : () => onTap!(m),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Calendario ───────────────────────────

class _CalendarView extends StatelessWidget {
  const _CalendarView({
    required this.year,
    required this.month,
    required this.today,
    required this.selectedDay,
    required this.movements,
    required this.onSelectDay,
    this.onTap,
  });

  final int year;
  final int month;
  final DateTime today;
  final int selectedDay;
  final List<Movement> movements;
  final ValueChanged<int> onSelectDay;
  final ValueChanged<Movement>? onTap;

  @override
  Widget build(BuildContext context) {
    final days = _byDay(movements);
    final first = Fmt.weekdayIndex(DateTime(year, month));
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final daysInPrevious = DateTime(year, month, 0).day;
    final weeks = ((first + daysInMonth) / 7).ceil();
    final selected = days[selectedDay] ?? const <Movement>[];
    final selectedDate = DateTime(year, month, selectedDay);
    final selectedNet =
        _sum(selected, MovementType.income) -
        _sum(selected, MovementType.expense);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: DesignColors.surfaceCard,
          child: Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: DesignColors.border),
                  ),
                ),
                child: Row(
                  children: [
                    for (final (i, label) in Fmt.weekdays.indexed)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: DesignText.caption.copyWith(
                              color: i == 0
                                  ? DesignColors.expense
                                  : i == 6
                                  ? DesignColors.income
                                  : DesignColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              for (var w = 0; w < weeks; w++)
                Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(
                        child: _cell(
                          index: w * 7 + col,
                          column: col,
                          first: first,
                          daysInMonth: daysInMonth,
                          daysInPrevious: daysInPrevious,
                          days: days,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${Fmt.weekday(selectedDate)} $selectedDay de '
                      '${Fmt.monthsLong[month - 1]}',
                      style: DesignText.headline,
                    ),
                    const Spacer(),
                    if (selected.isNotEmpty)
                      Text(
                        '${selected.length} mov. · '
                        '${Fmt.signedMoney(selectedNet)}',
                        style: DesignText.label.copyWith(
                          color: DesignColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              DsCard(
                child: selected.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Sin movimientos este día',
                          textAlign: TextAlign.center,
                          style: DesignText.label.copyWith(
                            color: DesignColors.textTertiary,
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, m) in selected.indexed)
                            TransactionRow(
                              movement: m,
                              first: i == 0,
                              inlineAmount: false,
                              onTap: onTap == null ? null : () => onTap!(m),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cell({
    required int index,
    required int column,
    required int first,
    required int daysInMonth,
    required int daysInPrevious,
    required Map<int, List<Movement>> days,
  }) {
    final day = index - first + 1;
    final inMonth = day >= 1 && day <= daysInMonth;
    final number = inMonth
        ? day
        : day < 1
        ? daysInPrevious + day
        : day - daysInMonth;
    final list = inMonth
        ? (days[day] ?? const <Movement>[])
        : const <Movement>[];
    final income = _sum(list, MovementType.income);
    final expense = _sum(list, MovementType.expense);
    final isToday =
        inMonth &&
        today.year == year &&
        today.month == month &&
        today.day == day;
    final isSelected = inMonth && day == selectedDay;
    final numberColor = isToday
        ? DesignColors.textInverse
        : !inMonth
        ? DesignColors.textDisabled
        : column == 0
        ? DesignColors.expense
        : column == 6
        ? DesignColors.income
        : DesignColors.textPrimary;
    final amountStyle = DesignText.microRegular.copyWith(height: 14 / 11);
    final amounts = [
      if (income > 0) (Fmt.short(income), DesignColors.income),
      if (expense > 0) (Fmt.short(expense), DesignColors.expense),
      if (income > 0 && expense > 0)
        (Fmt.short(income - expense), DesignColors.textSecondary),
    ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: inMonth ? () => onSelectDay(day) : null,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        decoration: BoxDecoration(
          color: !inMonth
              ? DesignColors.inputFill
              : isSelected
              ? DesignColors.selectedSoft
              : DesignColors.surfaceCard,
          border: const Border(
            right: BorderSide(color: DesignColors.borderSubtle),
            bottom: BorderSide(color: DesignColors.borderSubtle),
          ),
        ),
        foregroundDecoration: isSelected
            ? BoxDecoration(
                border: Border.all(color: DesignColors.primary, width: 2),
              )
            : null,
        // The prototype's flex column with `overflow: hidden`: amounts sit at
        // the bottom (margin-top: auto) but never above the day number, and
        // whatever does not fit is clipped.
        child: ClipRect(
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isToday ? DesignColors.inverse : null,
                  borderRadius: BorderRadius.circular(DesignRadius.xs),
                ),
                child: Text(
                  '$number',
                  style: DesignText.micro.copyWith(
                    color: numberColor,
                    height: 16 / 11,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: math.max(16.0, 57.0 - amounts.length * 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (text, color) in amounts)
                      Text(
                        text,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        style: amountStyle.copyWith(color: color),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────── Mensual ────────────────────────────

class _MonthlyView extends StatelessWidget {
  const _MonthlyView({
    required this.year,
    required this.today,
    required this.openMonth,
    required this.movements,
    required this.onToggle,
  });

  final int year;
  final DateTime today;
  final int openMonth;
  final List<Movement> movements;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final lastMonth = year == today.year ? today.month : 12;
    return ColoredBox(
      color: DesignColors.surfaceCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var month = lastMonth; month >= 1; month--) ..._monthRows(month),
        ],
      ),
    );
  }

  List<Widget> _monthRows(int month) {
    final list = movements
        .where((m) => m.at.year == year && m.at.month == month)
        .toList();
    final income = _sum(list, MovementType.income);
    final expense = _sum(list, MovementType.expense);
    final days = DateTime(year, month + 1, 0).day;
    final open = openMonth == month && list.isNotEmpty;
    final mm = Fmt.twoDigits(month);

    return [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onToggle(month),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: DesignColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(Fmt.months[month - 1], style: DesignText.headline),
                        if (list.isNotEmpty) ...[
                          const SizedBox(width: DesignSpacing.xs),
                          Sym(
                            open
                                ? DesignIcons.expandLess
                                : DesignIcons.expandMore,
                            size: 18,
                            color: DesignColors.textDisabled,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '01.$mm ~ $days.$mm',
                      style: DesignText.caption.copyWith(
                        color: DesignColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              _Totals(
                income: income,
                expense: expense,
                style: DesignText.labelMedium,
                netStyle: DesignText.caption,
                netGap: 2,
              ),
            ],
          ),
        ),
      ),
      if (open)
        for (final week in _weeks(month, list).reversed)
          Container(
            padding: const EdgeInsets.fromLTRB(36, 10, 16, 10),
            decoration: const BoxDecoration(
              color: DesignColors.inputFill,
              border: Border(bottom: BorderSide(color: DesignColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    week.$1,
                    style: DesignText.label.copyWith(
                      color: DesignColors.textSecondary,
                    ),
                  ),
                ),
                _Totals(
                  income: week.$2,
                  expense: week.$3,
                  style: DesignText.label,
                  netStyle: DesignText.microRegular,
                  netGap: 1,
                ),
              ],
            ),
          ),
    ];
  }

  /// Sunday–Saturday weeks clipped to the month: (range, income, expense).
  List<(String, double, double)> _weeks(int month, List<Movement> list) {
    final last = DateTime(year, month + 1, 0).day;
    final mm = Fmt.twoDigits(month);
    final weeks = <(String, double, double)>[];
    var start = 1;
    while (start <= last) {
      final weekday = Fmt.weekdayIndex(DateTime(year, month, start));
      final end = (start + (6 - weekday)).clamp(start, last);
      final inWeek = list.where((m) => m.at.day >= start && m.at.day <= end);
      weeks.add((
        '${Fmt.twoDigits(start)}.$mm ~ ${Fmt.twoDigits(end)}.$mm',
        _sum(inWeek, MovementType.income),
        _sum(inWeek, MovementType.expense),
      ));
      start = end + 1;
    }
    return weeks;
  }
}

class _Totals extends StatelessWidget {
  const _Totals({
    required this.income,
    required this.expense,
    required this.style,
    required this.netStyle,
    required this.netGap,
  });

  final double income;
  final double expense;
  final TextStyle style;
  final TextStyle netStyle;
  final double netGap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Fmt.money(income),
            style: style.copyWith(color: DesignColors.income),
          ),
          const SizedBox(width: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 84),
            child: Text(
              Fmt.money(expense),
              textAlign: TextAlign.right,
              style: style.copyWith(color: DesignColors.expense),
            ),
          ),
        ],
      ),
      SizedBox(height: netGap),
      Text(
        Fmt.signedMoney(income - expense),
        style: netStyle.copyWith(color: DesignColors.textTertiary),
      ),
    ],
  );
}

// ───────────────────────────── Total ─────────────────────────────

class _TotalView extends StatelessWidget {
  const _TotalView({
    required this.year,
    required this.month,
    required this.today,
    required this.ledger,
    required this.monthMovements,
  });

  final int year;
  final int month;
  final DateTime today;
  final LedgerData ledger;
  final List<Movement> monthMovements;

  @override
  Widget build(BuildContext context) {
    final expense = _sum(monthMovements, MovementType.expense);
    final previous = DateTime(year, month - 1);
    final previousExpense = _sum(
      ledger.movements.where(
        (m) => m.at.year == previous.year && m.at.month == previous.month,
      ),
      MovementType.expense,
    );
    final cards = {
      for (final a in ledger.accounts)
        if (a.isLiability) a.name,
    };
    final expenses = monthMovements.where(
      (m) => m.type == MovementType.expense,
    );
    final cardExpense =
        expenses
            .where((m) => cards.contains(m.account))
            .fold(0, (t, m) => t + m.amountCents) /
        100;
    final days = DateTime(year, month + 1, 0).day;
    final mm = Fmt.twoDigits(month);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BudgetCard(
            year: year,
            month: month,
            today: today,
            budgets: ledger.budgets,
            monthMovements: monthMovements,
            expense: expense,
          ),
          const SizedBox(height: DesignSpacing.md),
          DsCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Sym(DesignIcons.accountBalanceWallet, size: 22),
                    const SizedBox(width: DesignSpacing.sm),
                    Expanded(
                      child: Text('Cuentas', style: DesignText.headline),
                    ),
                    Text(
                      '01.$mm ~ $days.$mm',
                      style: DesignText.caption.copyWith(
                        color: DesignColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: DesignColors.border),
                    borderRadius: BorderRadius.circular(DesignRadius.md),
                  ),
                  child: Column(
                    children: [
                      for (final (i, (label, value)) in [
                        (
                          'Gastos vs mes anterior',
                          previousExpense > 0
                              ? '${(expense / previousExpense * 100).round()}%'
                              : '—',
                        ),
                        (
                          'Gastos (efectivo y cuentas)',
                          Fmt.money(expense - cardExpense),
                        ),
                        ('Gastos (tarjeta)', Fmt.money(cardExpense)),
                        (
                          'Transferencias',
                          Fmt.money(
                            _sum(monthMovements, MovementType.transfer),
                          ),
                        ),
                      ].indexed)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            border: i == 0
                                ? null
                                : const Border(
                                    top: BorderSide(
                                      color: DesignColors.borderSubtle,
                                    ),
                                  ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  style: DesignText.label.copyWith(
                                    color: DesignColors.textTertiary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: DesignSpacing.sm),
                              Text(value, style: DesignText.labelMedium),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignSpacing.md),
          GestureDetector(
            onTap: () => showDsToast(context, 'Próximamente'),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: DesignColors.surfaceCard,
                border: Border.all(color: DesignColors.borderInput),
                borderRadius: BorderRadius.circular(DesignRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Sym(
                    DesignIcons.tableView,
                    size: 20,
                    color: DesignColors.success,
                  ),
                  const SizedBox(width: DesignSpacing.sm),
                  Text('Exportar a Excel', style: DesignText.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.year,
    required this.month,
    required this.today,
    required this.budgets,
    required this.monthMovements,
    required this.expense,
  });

  final int year;
  final int month;
  final DateTime today;
  final Map<String, int> budgets;
  final List<Movement> monthMovements;
  final double expense;

  @override
  Widget build(BuildContext context) {
    final total = budgets.values.fold(0, (a, b) => a + b) / 100;
    final isCurrent = today.year == year && today.month == month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final elapsed = isCurrent ? today.day / daysInMonth : 1.0;
    final usedRatio = total > 0 ? expense / total : 0.0;
    final spentByCategory = <String, double>{};
    for (final m in monthMovements.where(
      (m) => m.type == MovementType.expense,
    )) {
      spentByCategory.update(
        m.category,
        (v) => v + m.amount,
        ifAbsent: () => m.amount,
      );
    }
    final rows = [
      for (final e in budgets.entries)
        (e.key, spentByCategory[e.key] ?? 0.0, e.value / 100),
    ]..sort((a, b) => (b.$2 / b.$3).compareTo(a.$2 / a.$3));

    Color tone(double ratio) => ratio > 1
        ? DesignColors.expense
        : ratio > elapsed + 0.05
        ? DesignColors.warning
        : DesignColors.success;

    return DsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Sym(DesignIcons.savings, size: 22),
              const SizedBox(width: DesignSpacing.sm),
              Expanded(child: Text('Presupuesto', style: DesignText.headline)),
              GestureDetector(
                onTap: () => showDsToast(context, 'Próximamente'),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                  decoration: BoxDecoration(
                    color: DesignColors.background,
                    borderRadius: BorderRadius.circular(DesignRadius.sm),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Configurar',
                        style: DesignText.caption.copyWith(
                          color: DesignColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: DesignSpacing.xxs),
                      const Sym(
                        DesignIcons.chevronRight,
                        size: 16,
                        color: DesignColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (budgets.isEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Define un tope mensual por categoría para ver tu avance.',
              style: DesignText.label.copyWith(
                color: DesignColors.textTertiary,
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Gastado',
                  style: DesignText.label.copyWith(
                    color: DesignColors.textTertiary,
                  ),
                ),
                const Spacer(),
                Text.rich(
                  TextSpan(
                    style: DesignText.label.copyWith(
                      color: DesignColors.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: Fmt.money(expense),
                        style: DesignText.labelStrong,
                      ),
                      TextSpan(text: ' de ${Fmt.money(total)}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _Bar(height: 8, ratio: usedRatio, color: tone(usedRatio)),
            const SizedBox(height: 6),
            Text(
              isCurrent
                  ? '${(usedRatio * 100).round()}% del presupuesto usado · '
                        '${(elapsed * 100).round()}% del mes transcurrido'
                  : '${(usedRatio * 100).round()}% del presupuesto usado',
              style: DesignText.caption.copyWith(
                color: DesignColors.textTertiary,
              ),
            ),
            const SizedBox(height: DesignSpacing.lg),
            for (final (i, (name, spent, cap)) in rows.take(5).indexed) ...[
              if (i > 0) const SizedBox(height: DesignSpacing.md),
              _BudgetRow(
                name: name,
                spent: spent,
                cap: cap,
                color: tone(spent / cap),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.name,
    required this.spent,
    required this.cap,
    required this.color,
  });

  final String name;
  final double spent;
  final double cap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.forName(name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Sym(style.icon, size: 16, color: style.foreground),
            const SizedBox(width: DesignSpacing.sm),
            Expanded(child: Text(name, style: DesignText.label)),
            const SizedBox(width: DesignSpacing.sm),
            Text(
              '${(spent / cap * 100).round()}%',
              style: DesignText.labelStrong.copyWith(color: color),
            ),
            const SizedBox(width: DesignSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 124),
              child: Text(
                '${Fmt.money(spent)} / ${Fmt.short(cap)}',
                textAlign: TextAlign.right,
                style: DesignText.label.copyWith(
                  color: DesignColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        _Bar(height: 5, ratio: spent / cap, color: color),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.ratio, required this.color});

  final double height;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(DesignRadius.pill),
    child: Container(
      height: height,
      color: DesignColors.borderSubtle,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: ratio.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(DesignRadius.pill),
          ),
        ),
      ),
    ),
  );
}
