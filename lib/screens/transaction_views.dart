import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/daos.dart';

enum TransactionView { daily, calendar, monthly, total, notes }

enum LedgerEntryKind { income, expense, transfer }

LedgerEntryKind classifyOrigination(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  if (normalized == 'income' ||
      normalized.contains('ingreso') ||
      normalized.contains('deposit') ||
      normalized.contains('depósit')) {
    return LedgerEntryKind.income;
  }
  if (normalized == 'transfer' || normalized.contains('transfer')) {
    return LedgerEntryKind.transfer;
  }
  return LedgerEntryKind.expense;
}

bool isInMonth(int epochMilliseconds, DateTime month) {
  final date = DateTime.fromMillisecondsSinceEpoch(epochMilliseconds);
  return date.year == month.year && date.month == month.month;
}

/// Contenido reactivo de las cinco pestañas de Transacciones.
///
/// El encabezado mensual y el resumen común siguen perteneciendo al Home. Este
/// widget recibe el mes seleccionado para que todas las vistas usen el mismo
/// período y la misma fuente de datos.
class TransactionViewBody extends StatelessWidget {
  const TransactionViewBody({
    super.key,
    required this.db,
    required this.month,
    required this.view,
    this.onExpenseTap,
  });

  final AppDatabase db;
  final DateTime month;
  final TransactionView view;
  final ValueChanged<Expense>? onExpenseTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Expense>>(
      stream: db.watchExpenses(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _EmptyView(
            icon: Icons.error_outline,
            label: 'No se pudieron cargar las transacciones',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows =
            snapshot.data!.where((row) => isInMonth(row.date, month)).toList()
              ..sort((a, b) => b.date.compareTo(a.date));
        switch (view) {
          case TransactionView.daily:
            return TransactionDailyView(rows: rows, onTap: onExpenseTap);
          case TransactionView.calendar:
            return TransactionCalendarView(
              month: month,
              rows: rows,
              onTap: onExpenseTap,
            );
          case TransactionView.monthly:
            return TransactionMonthlyView(month: month, rows: rows);
          case TransactionView.total:
            return TransactionTotalView(rows: rows);
          case TransactionView.notes:
            return TransactionNotesView(rows: rows, onTap: onExpenseTap);
        }
      },
    );
  }
}

class TransactionDailyView extends StatelessWidget {
  const TransactionDailyView({super.key, required this.rows, this.onTap});
  final List<Expense> rows;
  final ValueChanged<Expense>? onTap;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyView(
        icon: Icons.receipt_long,
        label: 'No hay transacciones este mes',
      );
    }
    final grouped = <DateTime, List<Expense>>{};
    for (final row in rows) {
      final d = DateTime.fromMillisecondsSinceEpoch(row.date);
      grouped.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(row);
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final items = grouped[day]!;
        final income = items
            .where(_isIncome)
            .fold<int>(0, (s, e) => s + e.amountCents);
        final expense = items
            .where((e) => !_isIncome(e) && !_isTransfer(e))
            .fold<int>(0, (s, e) => s + e.amountCents);
        return Column(
          children: [
            _DayHeader(day: day, income: income, expense: expense),
            ...items.map((row) => _TransactionRow(row: row, onTap: onTap)),
          ],
        );
      },
    );
  }
}

class TransactionCalendarView extends StatelessWidget {
  const TransactionCalendarView({
    super.key,
    required this.month,
    required this.rows,
    this.onTap,
  });
  final DateTime month;
  final List<Expense> rows;
  final ValueChanged<Expense>? onTap;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday - 1;
    final totals = <int, (int, int)>{};
    for (final row in rows) {
      final day = DateTime.fromMillisecondsSinceEpoch(row.date).day;
      final old = totals[day] ?? (0, 0);
      totals[day] = _isIncome(row)
          ? (old.$1 + row.amountCents, old.$2)
          : _isTransfer(row)
          ? old
          : (old.$1, old.$2 + row.amountCents);
    }
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(8, 14, 8, 8),
          child: Row(
            children: [
              for (final d in ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        color: Color(0xFF777777),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: .7,
            ),
            itemCount: offset + count,
            itemBuilder: (context, index) {
              if (index < offset) return const SizedBox.shrink();
              final day = index - offset + 1;
              final value = totals[day];
              final today = DateTime.now();
              final selected =
                  today.year == month.year &&
                  today.month == month.month &&
                  today.day == day;
              final dayRows = rows
                  .where(
                    (row) =>
                        DateTime.fromMillisecondsSinceEpoch(row.date).day ==
                        day,
                  )
                  .toList();
              return Material(
                color: selected ? const Color(0xFFFFECE9) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: dayRows.isEmpty
                      ? null
                      : () => _showDayTransactions(context, day, dayRows),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE6E6E8)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (value != null && value.$1 > 0)
                          Text(
                            _compact(value.$1),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF2F80ED),
                            ),
                          ),
                        if (value != null && value.$2 > 0)
                          Text(
                            _compact(value.$2),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFFF0523C),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDayTransactions(
    BuildContext context,
    int day,
    List<Expense> dayRows,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              '$day de ${_monthNames[month.month - 1]}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          ...dayRows.map(
            (row) => _TransactionRow(
              row: row,
              onTap: onTap == null
                  ? null
                  : (expense) {
                      Navigator.pop(sheetContext);
                      onTap!(expense);
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionMonthlyView extends StatelessWidget {
  const TransactionMonthlyView({
    super.key,
    required this.month,
    required this.rows,
  });
  final DateTime month;
  final List<Expense> rows;

  @override
  Widget build(BuildContext context) {
    final count = DateTime(month.year, month.month + 1, 0).day;
    final daily = List.generate(count, (_) => <int>[0, 0]);
    for (final row in rows) {
      final day = DateTime.fromMillisecondsSinceEpoch(row.date).day - 1;
      if (_isIncome(row)) {
        daily[day][0] += row.amountCents;
      } else if (!_isTransfer(row)) {
        daily[day][1] += row.amountCents;
      }
    }
    final maxValue = daily.expand((e) => e).fold<int>(1, math.max);
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: Color(0xFF2F80ED), text: 'Ingresos'),
              SizedBox(width: 24),
              _Legend(color: Color(0xFFF0523C), text: 'Gastos'),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            itemCount: count,
            separatorBuilder: (_, _) => const SizedBox(height: 7),
            itemBuilder: (_, i) => Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(color: Color(0xFF777777)),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _AmountBar(
                        value: daily[i][0],
                        max: maxValue,
                        color: const Color(0xFF2F80ED),
                      ),
                      const SizedBox(height: 2),
                      _AmountBar(
                        value: daily[i][1],
                        max: maxValue,
                        color: const Color(0xFFF0523C),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class TransactionTotalView extends StatelessWidget {
  const TransactionTotalView({super.key, required this.rows});
  final List<Expense> rows;

  @override
  Widget build(BuildContext context) {
    final accounts = <String, int>{};
    final categories = <String, int>{};
    for (final row in rows.where((e) => !_isTransfer(e))) {
      accounts.update(
        row.account?.trim().isNotEmpty == true ? row.account! : 'Sin cuenta',
        (v) => v + row.amountCents,
        ifAbsent: () => row.amountCents,
      );
      categories.update(
        row.categoryId ?? 'Sin categoría',
        (v) => v + row.amountCents,
        ifAbsent: () => row.amountCents,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        const _SectionTitle(icon: Icons.savings_outlined, title: 'Presupuesto'),
        const _InfoCard(
          children: [
            ListTile(
              title: Text('Ajustes de presupuestos'),
              trailing: Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionTitle(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Cuentas',
        ),
        _BreakdownCard(values: accounts),
        const SizedBox(height: 20),
        const _SectionTitle(icon: Icons.category_outlined, title: 'Categorías'),
        _BreakdownCard(values: categories),
      ],
    );
  }
}

class TransactionNotesView extends StatelessWidget {
  const TransactionNotesView({super.key, required this.rows, this.onTap});
  final List<Expense> rows;
  final ValueChanged<Expense>? onTap;

  @override
  Widget build(BuildContext context) {
    final noted = rows.where((e) => (e.notes ?? '').trim().isNotEmpty).toList();
    if (noted.isEmpty) {
      return const _EmptyView(
        icon: Icons.sticky_note_2_outlined,
        label: 'No hay notas este mes',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: noted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final row = noted[i];
        final date = DateTime.fromMillisecondsSinceEpoch(row.date);
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap == null ? null : () => onTap!(row),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.sticky_note_2_outlined,
                    color: Color(0xFFF0523C),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.description ?? row.vendor ?? 'Transacción',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          row.notes!,
                          style: const TextStyle(color: Color(0xFF666666)),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${date.day}/${date.month}/${date.year} · ${row.account ?? 'Sin cuenta'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.income,
    required this.expense,
  });
  final DateTime day;
  final int income;
  final int expense;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: const BoxDecoration(
      color: Color(0xFFF0F0F2),
      border: Border(bottom: BorderSide(color: Color(0xFFE0E0E2))),
    ),
    child: Row(
      children: [
        Text(
          '${day.day}',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 8),
        Text(
          _weekdays[day.weekday - 1],
          style: const TextStyle(color: Color(0xFF777777)),
        ),
        const Spacer(),
        Text(_money(income), style: const TextStyle(color: Color(0xFF2F80ED))),
        const SizedBox(width: 18),
        Text(_money(expense), style: const TextStyle(color: Color(0xFFF0523C))),
      ],
    ),
  );
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.row, this.onTap});
  final Expense row;
  final ValueChanged<Expense>? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    tileColor: Colors.white,
    onTap: onTap == null ? null : () => onTap!(row),
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFFFECE9),
      child: Icon(
        _isTransfer(row)
            ? Icons.swap_horiz
            : _isIncome(row)
            ? Icons.south_west
            : Icons.north_east,
        color: const Color(0xFFF0523C),
      ),
    ),
    title: Text(
      row.description ??
          row.vendor ??
          (_isIncome(row)
              ? 'Ingreso'
              : _isTransfer(row)
              ? 'Transferencia'
              : 'Gasto'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Text(row.account ?? 'Sin cuenta'),
    trailing: Text(
      _currency(row),
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: _isIncome(row)
            ? const Color(0xFF2F80ED)
            : _isTransfer(row)
            ? const Color(0xFF333333)
            : const Color(0xFFF0523C),
      ),
    ),
  );
}

class _AmountBar extends StatelessWidget {
  const _AmountBar({
    required this.value,
    required this.max,
    required this.color,
  });
  final int value;
  final int max;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value / max,
            minHeight: 8,
            color: color,
            backgroundColor: const Color(0xFFE8E8EA),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 58,
        child: Text(
          value == 0 ? '' : _compact(value),
          style: TextStyle(fontSize: 10, color: color),
        ),
      ),
    ],
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(text),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icon),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E2E4)),
    ),
    child: Column(children: children),
  );
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.values});
  final Map<String, int> values;
  @override
  Widget build(BuildContext context) {
    final sorted = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _InfoCard(
      children: sorted.isEmpty
          ? [const ListTile(title: Text('Sin movimientos'))]
          : sorted
                .map(
                  (e) => ListTile(
                    dense: true,
                    title: Text(e.key),
                    trailing: Text(
                      _money(e.value),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
                .toList(),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: const Color(0xFFBBBBBB)),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Color(0xFF888888))),
      ],
    ),
  );
}

bool _isIncome(Expense row) =>
    classifyOrigination(row.origination) == LedgerEntryKind.income;
bool _isTransfer(Expense row) =>
    classifyOrigination(row.origination) == LedgerEntryKind.transfer;
String _money(int cents) => 'S/ ${(cents / 100).toStringAsFixed(2)}';
String _compact(int cents) => cents >= 100000
    ? '${(cents / 100000).toStringAsFixed(1)}k'
    : (cents / 100).toStringAsFixed(0);
String _currency(Expense row) =>
    '${row.currency == 'USD' ? r'$' : 'S/'} ${(row.amountCents / 100).toStringAsFixed(2)}';
const _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _monthNames = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
