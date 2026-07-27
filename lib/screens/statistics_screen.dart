import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/daos.dart';

class IncomeStatisticsScreen extends StatelessWidget {
  const IncomeStatisticsScreen({super.key, required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) =>
      StatisticsScreen(db: db, initialType: StatisticsType.income);
}

class ExpenseStatisticsScreen extends StatelessWidget {
  const ExpenseStatisticsScreen({super.key, required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) =>
      StatisticsScreen(db: db, initialType: StatisticsType.expense);
}

enum StatisticsType { income, expense }

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    required this.db,
    this.initialType = StatisticsType.expense,
  });

  final AppDatabase db;
  final StatisticsType initialType;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  static const _accent = Color(0xFFFF625D);
  static const _background = Color(0xFFF4F5F7);
  static const _palette = <Color>[
    Color(0xFFFF625D),
    Color(0xFFFF944D),
    Color(0xFFFFC844),
    Color(0xFFFFDF00),
    Color(0xFFB9E83D),
    Color(0xFF65D06E),
    Color(0xFF56D7D0),
    Color(0xFF6DB1DA),
    Color(0xFF9B7BD4),
  ];

  late StatisticsType _type;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: StreamBuilder<List<Expense>>(
          stream: widget.db.watchExpenses(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _StatisticsError();
            }
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snapshot.data ?? const <Expense>[];
            final monthly = all.where((item) {
              final date = DateTime.fromMillisecondsSinceEpoch(item.date);
              return date.year == _month.year && date.month == _month.month;
            }).toList();
            final incomeTotal = statisticsTotal(monthly, StatisticsType.income);
            final expenseTotal = statisticsTotal(
              monthly,
              StatisticsType.expense,
            );
            final groups = buildStatisticsGroups(monthly, _type);

            return Column(
              children: [
                _MonthHeader(
                  month: _month,
                  onPrevious: () => _changeMonth(-1),
                  onNext: () => _changeMonth(1),
                  onToday: _goToCurrentMonth,
                ),
                _TypeSelector(
                  selected: _type,
                  income: incomeTotal,
                  expense: expenseTotal,
                  onSelected: (value) => setState(() => _type = value),
                ),
                Expanded(
                  child: groups.isEmpty
                      ? _EmptyStatistics(type: _type)
                      : ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            _ChartCard(groups: groups, palette: _palette),
                            const SizedBox(height: 10),
                            ...groups.indexed.map(
                              (entry) => _CategoryRow(
                                group: entry.$2,
                                color: _palette[entry.$1 % _palette.length],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _changeMonth(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
  });

  void _goToCurrentMonth() {
    final now = DateTime.now();
    setState(() => _month = DateTime(now.year, now.month));
  }
}

bool expenseMatchesStatisticsType(Expense item, StatisticsType type) {
  final origin = (item.origination ?? '').trim().toLowerCase();
  final isIncome = origin == 'income' || origin == 'ingreso';
  final isTransfer = origin == 'transfer' || origin == 'transferencia';
  return type == StatisticsType.income ? isIncome : !isIncome && !isTransfer;
}

double statisticsTotal(List<Expense> items, StatisticsType type) => items
    .where((item) => expenseMatchesStatisticsType(item, type))
    .fold(0, (sum, item) => sum + item.amountCents.abs() / 100);

List<StatisticsCategoryGroup> buildStatisticsGroups(
  List<Expense> items,
  StatisticsType type,
) {
  final totals = <String, double>{};
  for (final item in items.where(
    (item) => expenseMatchesStatisticsType(item, type),
  )) {
    final category = item.categoryId?.trim();
    final vendor = item.vendor?.trim();
    final rawName = category?.isNotEmpty == true
        ? category!
        : vendor?.isNotEmpty == true
        ? vendor!
        : 'Otros';
    final name = _displayCategory(rawName);
    final amount = item.amountCents.abs() / 100;
    totals.update(name, (value) => value + amount, ifAbsent: () => amount);
  }
  final total = totals.values.fold<double>(0, (sum, value) => sum + value);
  return totals.entries
      .map(
        (entry) => StatisticsCategoryGroup(
          name: entry.key,
          amount: entry.value,
          percentage: total == 0 ? 0 : entry.value / total,
        ),
      )
      .toList()
    ..sort((a, b) {
      final amountOrder = b.amount.compareTo(a.amount);
      return amountOrder != 0 ? amountOrder : a.name.compareTo(b.name);
    });
}

String _displayCategory(String value) {
  final spaced = value.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  if (spaced.isEmpty) return 'Otros';
  if (spaced.startsWith('cat ') && int.tryParse(spaced.substring(4)) != null) {
    return 'Categoría ${spaced.substring(4)}';
  }
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sept',
      'oct',
      'nov',
      'dic',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            tooltip: 'Mes anterior',
            icon: const Icon(Icons.chevron_left),
          ),
          InkWell(
            onLongPress: onToday,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                '${months[month.month - 1]} ${month.year}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            tooltip: 'Mes siguiente',
            icon: const Icon(Icons.chevron_right),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD3D6DC)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Text('Mensual', style: TextStyle(fontSize: 16)),
                SizedBox(width: 5),
                Icon(Icons.keyboard_arrow_down, size: 19),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({
    required this.selected,
    required this.income,
    required this.expense,
    required this.onSelected,
  });

  final StatisticsType selected;
  final double income;
  final double expense;
  final ValueChanged<StatisticsType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: StatisticsType.values.map((type) {
        final active = selected == type;
        final label = type == StatisticsType.income ? 'Ingresos' : 'Gastos';
        final value = type == StatisticsType.income ? income : expense;
        return Expanded(
          child: InkWell(
            onTap: () => onSelected(type),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    '$label  S/ ${value.toStringAsFixed(2)}',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? const Color(0xFF20232A) : Colors.grey,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 4,
                  color: active
                      ? _StatisticsScreenState._accent
                      : Colors.transparent,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.groups, required this.palette});

  final List<StatisticsCategoryGroup> groups;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 285,
      margin: const EdgeInsets.only(top: 1),
      color: Colors.white,
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _DonutPainter(groups: groups, palette: palette),
              child: Center(
                child: Text(
                  'Total\nS/ ${groups.fold<double>(0, (s, e) => s + e.amount).toStringAsFixed(2)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 125,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: groups.take(5).indexed.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: palette[entry.$1 % palette.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          entry.$2.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.group, required this.color});

  final StatisticsCategoryGroup group;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE3E5E8))),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Text(
              '${(group.percentage * 100).round()}%',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            'S/ ${group.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptyStatistics extends StatelessWidget {
  const _EmptyStatistics({required this.type});

  final StatisticsType type;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.pie_chart_outline, size: 58, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(
          'No hay ${type == StatisticsType.income ? 'ingresos' : 'gastos'} este mes',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
        const SizedBox(height: 5),
        const Text(
          'Cambia de mes o registra una transacción',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    ),
  );
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.groups, required this.palette});

  final List<StatisticsCategoryGroup> groups;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .43;
    final rect = Rect.fromCircle(center: center, radius: radius);
    var start = -math.pi / 2;
    for (final entry in groups.indexed) {
      final sweep = math.pi * 2 * entry.$2.percentage;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = palette[entry.$1 % palette.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * .48
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.groups != groups;
}

class StatisticsCategoryGroup {
  const StatisticsCategoryGroup({
    required this.name,
    required this.amount,
    required this.percentage,
  });

  final String name;
  final double amount;
  final double percentage;
}

class _StatisticsError extends StatelessWidget {
  const _StatisticsError();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'No se pudieron cargar las estadísticas.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey, fontSize: 16),
      ),
    ),
  );
}
