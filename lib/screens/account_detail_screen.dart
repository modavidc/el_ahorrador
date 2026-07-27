import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';

class AccountDetailScreen extends StatelessWidget {
  const AccountDetailScreen({
    super.key,
    required this.accountName,
    required this.expenses,
  });
  final String accountName;
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final sorted = [...expenses]..sort((a, b) => b.date.compareTo(a.date));
    final total = sorted.fold<int>(0, (sum, item) => sum + item.amountCents);
    final activeDays = sorted
        .map((item) {
          final date = DateTime.fromMillisecondsSinceEpoch(item.date);
          return DateTime(date.year, date.month, date.day);
        })
        .toSet()
        .length;
    return Scaffold(
      backgroundColor: const Color(0xFF24252A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF24252A),
        foregroundColor: Colors.white,
        title: Text(accountName),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF414248))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gastos asociados registrados',
                  style: TextStyle(color: Color(0xFFAAAAAF)),
                ),
                const SizedBox(height: 5),
                Text(
                  _money(total),
                  style: const TextStyle(
                    color: Color(0xFF3D9BF2),
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Este valor no es el saldo de la cuenta.',
                  style: TextStyle(color: Color(0xFF8F8F96), fontSize: 12),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Movimientos',
                        value: '${sorted.length}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Metric(
                        label: 'Días con actividad',
                        value: '$activeDays',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: sorted.isEmpty
                ? const Center(
                    child: Text(
                      'No hay movimientos registrados.',
                      style: TextStyle(color: Color(0xFFAAAAAF)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: sorted.length,
                    itemBuilder: (_, index) {
                      final item = sorted[index];
                      final date = DateTime.fromMillisecondsSinceEpoch(
                        item.date,
                      );
                      final showDate =
                          index == 0 ||
                          !_sameDay(
                            date,
                            DateTime.fromMillisecondsSinceEpoch(
                              sorted[index - 1].date,
                            ),
                          );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDate) _DateHeader(date: date),
                          _MovementTile(item: item),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF2B2C31),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF9999A0), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 17)),
      ],
    ),
  );
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF24252A),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Text(
      DateFormat('EEEE, d MMMM', 'es').format(date),
      style: const TextStyle(color: Color(0xFFAAAAAF), fontSize: 13),
    ),
  );
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.item});
  final Expense item;

  @override
  Widget build(BuildContext context) {
    final title =
        _firstText([item.vendor, item.description, item.destination]) ??
        'Movimiento';
    final detail = _firstText([item.description, item.sourceApp, item.notes]);
    return Container(
      color: const Color(0xFF2B2C31),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF383941),
          foregroundColor: Color(0xFFFF625D),
          child: Icon(Icons.receipt_long_outlined),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: detail == null || detail == title
            ? null
            : Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF9999A0)),
              ),
        trailing: Text(
          '-${_money(item.amountCents)}',
          style: const TextStyle(color: Color(0xFFFF625D), fontSize: 16),
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class AccountTotalsScreen extends StatelessWidget {
  const AccountTotalsScreen({super.key, required this.db});
  final AppDatabase db;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF24252A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF24252A),
      foregroundColor: Colors.white,
      title: const Text('Estadísticas totales'),
    ),
    body: StreamBuilder<List<Expense>>(
      stream: db.select(db.expenses).watch(),
      builder: (_, snapshot) {
        final items = snapshot.data ?? const <Expense>[];
        final months = <DateTime, int>{};
        for (final item in items) {
          final date = DateTime.fromMillisecondsSinceEpoch(item.date);
          final key = DateTime(date.year, date.month);
          months.update(
            key,
            (value) => value + item.amountCents,
            ifAbsent: () => item.amountCents,
          );
        }
        final rows = months.entries.toList()
          ..sort((a, b) => b.key.compareTo(a.key));
        final max = rows.fold<int>(
          0,
          (value, row) => row.value > value ? row.value : value,
        );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Gastos registrados por mes',
              style: TextStyle(color: Color(0xFFAAAAAF), fontSize: 16),
            ),
            const SizedBox(height: 5),
            const Text(
              'No representa la evolución del saldo.',
              style: TextStyle(color: Color(0xFF77777F), fontSize: 12),
            ),
            const SizedBox(height: 24),
            if (rows.isEmpty)
              const Center(
                child: Text(
                  'Aún no hay datos para graficar.',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else
              ...rows.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('MMMM yyyy', 'es').format(row.key),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          Text(
                            _money(row.value),
                            style: const TextStyle(color: Color(0xFF3D9BF2)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: max == 0 ? 0 : row.value / max,
                          minHeight: 12,
                          color: const Color(0xFFFF625D),
                          backgroundColor: const Color(0xFF3A3B42),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

String? _firstText(List<String?> values) {
  for (final value in values) {
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String _money(int cents) => 'S/ ${(cents / 100).toStringAsFixed(2)}';
