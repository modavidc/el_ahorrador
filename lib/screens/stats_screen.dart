import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/daos.dart';
import '../widgets/app_bottom_navigation.dart';
import 'stats_category_detail_screen.dart';

enum StatsPeriod { weekly, monthly, annually, period }

class StatsScreen extends StatefulWidget {
  final AppDatabase db;
  const StatsScreen({super.key, required this.db});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  static const accent = Color(0xffef706d);
  static const muted = Color(0xffa3a3a3);
  static const palette = [
    Color(0xffff6d68),
    Color(0xffff934b),
    Color(0xffffc83d),
    Color(0xffb6dc3d),
    Color(0xff69c96d),
    Color(0xff56d7cd),
    Color(0xff6cb5da),
    Color(0xff9d7bd1),
    Color(0xffd96cc8),
  ];

  DateTime anchor = DateTime.now();
  StatsPeriod period = StatsPeriod.monthly;
  DateTimeRange? customRange;
  bool showIncome = true;
  late final Future<Map<String, _CategoryInfo>> categories = loadCategories();

  Future<Map<String, _CategoryInfo>> loadCategories() async {
    final rows = await widget.db.select(widget.db.categories).get();
    return {for (final row in rows) row.id: _CategoryInfo(row.name, row.icon)};
  }

  DateTimeRange get range {
    if (customRange != null && period == StatsPeriod.period)
      return customRange!;
    if (period == StatsPeriod.annually) {
      return DateTimeRange(
        start: DateTime(anchor.year),
        end: DateTime(anchor.year, 12, 31, 23, 59, 59),
      );
    }
    if (period == StatsPeriod.weekly) {
      final end = DateTime(anchor.year, anchor.month, anchor.day, 23, 59, 59);
      return DateTimeRange(
        start: end.subtract(const Duration(days: 6)),
        end: end,
      );
    }
    return DateTimeRange(
      start: DateTime(anchor.year, anchor.month),
      end: DateTime(anchor.year, anchor.month + 1, 0, 23, 59, 59),
    );
  }

  String get periodLabel => switch (period) {
    StatsPeriod.weekly => 'Weekly',
    StatsPeriod.monthly => 'Monthly',
    StatsPeriod.annually => 'Annually',
    StatsPeriod.period => 'Period',
  };

  String get dateLabel {
    if (period == StatsPeriod.annually) return '${anchor.year}';
    if (period == StatsPeriod.monthly)
      return '${monthName(anchor.month)} ${anchor.year}';
    return '${shortDate(range.start)} ~ ${shortDate(range.end)}';
  }

  String shortDate(DateTime date) =>
      '${date.month}.${date.day.toString().padLeft(2, '0')}.${date.year.toString().substring(2)}';
  String monthName(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
  String formatAmount(double amount) {
    final fixed = amount.toStringAsFixed(2).split('.');
    final integer = fixed[0].replaceAllMapped(
      RegExp(r'(?<!^)(?=(\d{3})+$)'),
      (_) => ',',
    );
    return 'S/. $integer.${fixed[1]}';
  }

  void move(int direction) {
    setState(() {
      if (period == StatsPeriod.annually)
        anchor = DateTime(anchor.year + direction, anchor.month, anchor.day);
      if (period == StatsPeriod.weekly)
        anchor = anchor.add(Duration(days: direction * 7));
      if (period == StatsPeriod.monthly)
        anchor = DateTime(anchor.year, anchor.month + direction);
    });
  }

  Future<void> choosePeriod() async {
    final choice = await showMenu<StatsPeriod>(
      context: context,
      position: const RelativeRect.fromLTRB(262, 70, 8, 0),
      items: const [
        PopupMenuItem(value: StatsPeriod.weekly, child: Text('Weekly')),
        PopupMenuItem(value: StatsPeriod.monthly, child: Text('Monthly')),
        PopupMenuItem(value: StatsPeriod.annually, child: Text('Annually')),
        PopupMenuItem(value: StatsPeriod.period, child: Text('Period')),
      ],
    );
    if (!mounted || choice == null) return;
    if (choice == StatsPeriod.period) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: customRange ?? range,
      );
      if (picked == null) return;
      setState(() {
        customRange = picked;
        period = choice;
      });
    } else {
      setState(() => period = choice);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: StreamBuilder<List<Expense>>(
        stream: widget.db.watchExpenses(),
        builder: (context, snapshot) =>
            FutureBuilder<Map<String, _CategoryInfo>>(
              future: categories,
              builder: (context, cats) => buildContent(
                snapshot.data ?? const [],
                cats.data ?? const {},
              ),
            ),
      ),
    ),
    bottomNavigationBar: buildNavigation(),
  );

  Widget buildContent(
    List<Expense> all,
    Map<String, _CategoryInfo> categoryMap,
  ) {
    final currentRange = range;
    final grouped = <String, double>{};
    for (final item in all) {
      final date = DateTime.fromMillisecondsSinceEpoch(item.date);
      if (date.isBefore(currentRange.start) ||
          date.isAfter(currentRange.end) ||
          (item.amountCents >= 0) != showIncome)
        continue;
      final name =
          categoryMap[item.categoryId]?.name ?? item.categoryId ?? 'Otro';
      grouped[name] = (grouped[name] ?? 0) + item.amountCents.abs() / 100;
    }
    final values = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = values.fold<double>(0, (sum, item) => sum + item.value);
    return Column(
      children: [
        buildHeader(),
        buildTypeTabs(all, currentRange),
        Expanded(
          child: values.isEmpty
              ? const Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          'No data available.',
                          style: TextStyle(fontSize: 18, color: muted),
                        ),
                      ),
                    ),
                    Divider(
                      height: 14,
                      thickness: 14,
                      color: Color(0xfff1f1f1),
                    ),
                  ],
                )
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    SizedBox(
                      height: 300,
                      child: buildChart(values, total, categoryMap),
                    ),
                    const Divider(
                      height: 14,
                      thickness: 14,
                      color: Color(0xfff1f1f1),
                    ),
                    ...values.asMap().entries.map(
                      (entry) =>
                          buildRow(entry.key, entry.value, total, categoryMap),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget buildHeader() => SizedBox(
    height: 56,
    child: Row(
      children: [
        IconButton(
          onPressed: () => move(-1),
          icon: const Icon(Icons.chevron_left, size: 32),
        ),
        Expanded(child: Text(dateLabel, style: const TextStyle(fontSize: 18))),
        IconButton(
          onPressed: () => move(1),
          icon: const Icon(Icons.chevron_right, size: 32),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: OutlinedButton(
            onPressed: choosePeriod,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  periodLabel,
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.black),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget buildTypeTabs(List<Expense> all, DateTimeRange currentRange) {
    double total(bool income) => all
        .where((item) {
          final date = DateTime.fromMillisecondsSinceEpoch(item.date);
          return !date.isBefore(currentRange.start) &&
              !date.isAfter(currentRange.end) &&
              (item.amountCents >= 0) == income;
        })
        .fold(0, (sum, item) => sum + item.amountCents.abs() / 100);
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          typeTab(
            'Income',
            total(true),
            showIncome,
            () => setState(() => showIncome = true),
          ),
          typeTab(
            'Expenses',
            total(false),
            !showIncome,
            () => setState(() => showIncome = false),
          ),
        ],
      ),
    );
  }

  Widget typeTab(
    String label,
    double amount,
    bool selected,
    VoidCallback onTap,
  ) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? accent : const Color(0xffe4e4e4),
              width: selected ? 4 : 1,
            ),
          ),
        ),
        child: Text(
          '$label  ${amount == 0 ? '' : formatAmount(amount)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? Colors.black : muted,
          ),
        ),
      ),
    ),
  );

  Widget buildChart(
    List<MapEntry<String, double>> values,
    double total,
    Map<String, _CategoryInfo> categoryMap,
  ) => LayoutBuilder(
    builder: (context, constraints) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final index = _PiePainter.indexAt(
          details.localPosition,
          Size(constraints.maxWidth, constraints.maxHeight),
          values,
        );
        if (index == null) return;
        _openCategory(values[index].key, categoryMap: categoryMap);
      },
      child: CustomPaint(
        painter: _PiePainter(values, palette, categoryMap),
        child: const SizedBox.expand(),
      ),
    ),
  );

  void _openCategory(
    String categoryName, {
    Map<String, _CategoryInfo>? categoryMap,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatsCategoryDetailScreen(
          db: widget.db,
          categoryName: categoryName,
          categoryId:
              categoryMap?.entries
                  .firstWhere(
                    (entry) => entry.value.name == categoryName,
                    orElse: () => MapEntry(
                      categoryName,
                      _CategoryInfo(categoryName, '🔠'),
                    ),
                  )
                  .key ??
              categoryName,
          categoryIcon:
              categoryMap?.values
                  .firstWhere(
                    (info) => info.name == categoryName,
                    orElse: () => const _CategoryInfo('', '🔠'),
                  )
                  .icon ??
              '🔠',
          range: range,
          isIncome: showIncome,
        ),
      ),
    );
  }

  Widget buildRow(
    int index,
    MapEntry<String, double> item,
    double total,
    Map<String, _CategoryInfo> categoryMap,
  ) {
    final percent = total == 0 ? 0 : item.value / total * 100;
    final info = categoryMap.values
        .where((value) => value.name == item.key)
        .firstOrNull;
    return InkWell(
      onTap: () => _openCategory(item.key, categoryMap: categoryMap),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xffdddddd))),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette[index % palette.length],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${percent.round()}%',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            Text(info?.icon ?? '🔠', style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                item.key,
                style: const TextStyle(fontSize: 14, color: Color(0xff565656)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              formatAmount(item.value),
              style: const TextStyle(fontSize: 15, color: Color(0xff565656)),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNavigation() => AppBottomNavigation(
    currentIndex: 1,
    onTap: (index) {
      if (index == 0) Navigator.of(context).pop();
      if (index > 1)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Próximamente')));
    },
  );
}

class _CategoryInfo {
  final String name;
  final String icon;
  const _CategoryInfo(this.name, this.icon);
}

class _PiePainter extends CustomPainter {
  final List<MapEntry<String, double>> entries;
  final List<Color> colors;
  final Map<String, _CategoryInfo> categoryMap;
  _PiePainter(this.entries, this.colors, this.categoryMap);

  static int? indexAt(
    Offset position,
    Size size,
    List<MapEntry<String, double>> entries,
  ) {
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);
    if (total == 0) return null;
    final center = Offset(size.width / 2, size.height * .5);
    final radius = math.min(size.width, size.height) * .23;
    final delta = position - center;
    if (delta.distance > radius) return null;
    var angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;
    var cursor = 0.0;
    for (var i = 0; i < entries.length; i++) {
      cursor += entries[i].value / total * math.pi * 2;
      if (angle <= cursor) return i;
    }
    return entries.isEmpty ? null : entries.length - 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height * .5);
    final radius = math.min(size.width, size.height) * .23;
    var start = -math.pi / 2;
    final labels = <_PieLabel>[];
    final rankedEntries = entries.asMap().entries.toList()
      ..sort((a, b) => b.value.value.compareTo(a.value.value));
    final visibleLabelIndexes = rankedEntries
        .take(6)
        .map((entry) => entry.key)
        .toSet();
    for (var i = 0; i < entries.length; i++) {
      final sweep = entries[i].value / total * math.pi * 2;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = colors[i % colors.length],
      );
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      if (visibleLabelIndexes.contains(i) && entries[i].value / total >= .007) {
        final angle = start + sweep / 2;
        final side = math.cos(angle) >= 0 ? 1.0 : -1.0;
        final icon = categoryMap.values
            .where((info) => info.name == entries[i].key)
            .firstOrNull
            ?.icon;
        final name = entries[i].key.length > 13
            ? '${entries[i].key.substring(0, 12)}…'
            : entries[i].key;
        final label = TextPainter(
          text: TextSpan(
            text:
                '${icon == null ? '' : '$icon '}$name\n'
                '${(entries[i].value / total * 100).toStringAsFixed(1)} %',
            style: const TextStyle(
              color: Color(0xff343434),
              fontSize: 13,
              height: 1.15,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 2,
          ellipsis: '…',
        )..layout(maxWidth: size.width * .27);
        labels.add(
          _PieLabel(
            side: side,
            desiredY: center.dy + math.sin(angle) * (radius + 42),
            from:
                center +
                Offset(math.cos(angle) * radius, math.sin(angle) * radius),
            painter: label,
            color: colors[i % colors.length],
          ),
        );
      }
      start += sweep;
    }

    for (final side in <double>[-1, 1]) {
      final sideLabels = labels.where((label) => label.side == side).toList()
        ..sort((a, b) => a.desiredY.compareTo(b.desiredY));
      if (sideLabels.isEmpty) continue;

      final edgePadding = 14.0;
      final minY = edgePadding + sideLabels.first.painter.height / 2;
      final maxY =
          size.height - edgePadding - sideLabels.last.painter.height / 2;
      var previousBottom = minY - sideLabels.first.painter.height / 2 - 7;
      for (final label in sideLabels) {
        label.y = math.max(
          label.desiredY.clamp(minY, maxY).toDouble(),
          previousBottom + label.painter.height / 2,
        );
        previousBottom = label.y + label.painter.height / 2 + 6;
      }
      final overflow = sideLabels.last.y - maxY;
      if (overflow > 0) {
        for (final label in sideLabels) {
          label.y -= overflow;
        }
        if (sideLabels.first.y < minY) {
          final correction = minY - sideLabels.first.y;
          for (final label in sideLabels) {
            label.y += correction;
          }
        }
      }
      for (final label in sideLabels) {
        final end = Offset(
          label.side > 0 ? size.width * .69 : size.width * .31,
          label.y,
        );
        final elbow = Offset(center.dx + label.side * (radius + 24), label.y);
        final line = Paint()
          ..color = label.color
          ..strokeWidth = 1.5;
        canvas.drawLine(label.from, elbow, line);
        canvas.drawLine(elbow, end, line);
        label.painter.paint(
          canvas,
          Offset(
            label.side > 0 ? end.dx + 5 : end.dx - label.painter.width - 5,
            label.y - label.painter.height / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) => true;
}

class _PieLabel {
  final double side;
  final double desiredY;
  final Offset from;
  final TextPainter painter;
  final Color color;
  double y;

  _PieLabel({
    required this.side,
    required this.desiredY,
    required this.from,
    required this.painter,
    required this.color,
  }) : y = desiredY;
}
