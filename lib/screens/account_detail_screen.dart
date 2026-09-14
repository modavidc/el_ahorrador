import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../data/daos.dart';
import '../data/account_repository.dart';
import '../theme/app_styles.dart';

class AccountDetailScreen extends StatelessWidget {
  const AccountDetailScreen({
    super.key,
    required this.db,
    required this.account,
  });
  final AppDatabase db;
  final Account account;

  int _balance(List<Expense> rows) => rows.fold(0, (s, e) => s + e.amountCents);
  String _money(int cents) =>
      '${account.currency == 'PEN' ? 'S/' : account.currency} ${(cents.abs() / 100).toStringAsFixed(2)}';
  String _date(int epoch) {
    final d = DateTime.fromMillisecondsSinceEpoch(epoch);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: Text(account.name),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) =>
              _showBalanceDialog(context, adjust: value == 'adjust'),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'initial',
              child: Text('Editar saldo inicial'),
            ),
            PopupMenuItem(value: 'adjust', child: Text('Ajustar saldo real')),
          ],
        ),
      ],
    ),
    body: StreamBuilder<List<Expense>>(
      stream: db.watchExpenses(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text('No pudimos cargar el detalle.'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!
            .where((e) => e.accountId == account.id)
            .toList();
        final income = rows
            .where((e) => e.amountCents >= 0)
            .fold<int>(0, (s, e) => s + e.amountCents);
        final spent = rows
            .where((e) => e.amountCents < 0)
            .fold<int>(0, (s, e) => s + e.amountCents.abs());
        final movementWidgets = rows
            .take(30)
            .map(
              (row) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xffedf0f7),
                  child: Icon(
                    row.amountCents >= 0
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    color: row.amountCents >= 0
                        ? AppColors.income
                        : AppColors.expense,
                    size: 19,
                  ),
                ),
                title: Text(
                  row.vendor?.trim().isNotEmpty == true
                      ? row.vendor!
                      : (row.description?.trim().isNotEmpty == true
                            ? row.description!
                            : 'Movimiento'),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  _date(row.date),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: Text(
                  '${row.amountCents >= 0 ? '+' : '-'}${_money(row.amountCents)}',
                  style: TextStyle(
                    color: row.amountCents >= 0
                        ? AppColors.income
                        : AppColors.expense,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            StreamBuilder<AccountBalance>(
              stream: AccountRepository(db).watchBalance(account.id),
              builder: (context, balanceSnapshot) => _summaryCard(
                rows,
                income,
                spent,
                balanceCents: balanceSnapshot.data?.balanceCents,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Evolución',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: SizedBox(
                height: 170,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _BalanceChart(rows: rows),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Movimientos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${rows.length}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            rows.isEmpty
                ? Card(
                    elevation: 0,
                    color: AppColors.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Todavía no hay movimientos en esta cuenta.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  )
                : Card(
                    elevation: 0,
                    color: AppColors.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Column(children: movementWidgets),
                  ),
          ],
        );
      },
    ),
  );

  Future<void> _showBalanceDialog(
    BuildContext context, {
    required bool adjust,
  }) async {
    final repository = AccountRepository(db);
    final current = await repository.balance(account.id);
    if (!context.mounted) return;
    final controller = TextEditingController(
      text:
          ((adjust ? current.balanceCents : current.startingBalanceCents)
                      .abs() /
                  100)
              .toStringAsFixed(2),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(adjust ? 'Ajustar saldo real' : 'Editar saldo inicial'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Importe (${account.currency})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    final cents = (value * 100).round();
    await repository.setStartingBalance(
      account.id,
      startingBalanceCents: cents,
      startingBalanceDate: adjust
          ? DateTime.now().millisecondsSinceEpoch
          : current.startingBalanceDate,
    );
  }

  Widget _summaryCard(
    List<Expense> rows,
    int income,
    int spent, {
    int? balanceCents,
  }) => Card(
    elevation: 0,
    color: AppColors.cardBackground,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: AppColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(account.currency, style: AppTextStyles.label),
          const SizedBox(height: 4),
          Text(
            _money(balanceCents ?? _balance(rows)),
            style: AppTextStyles.amountLarge.copyWith(fontSize: 31),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _DetailMetric('Ingresos', _money(income), AppColors.income),
              const SizedBox(width: 24),
              _DetailMetric('Gastos', _money(spent), AppColors.expense),
            ],
          ),
        ],
      ),
    ),
  );
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric(this.label, this.value, this.color);
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTextStyles.label),
      Text(value, style: AppTextStyles.amountMedium.copyWith(color: color)),
    ],
  );
}

class _BalanceChart extends StatelessWidget {
  const _BalanceChart({required this.rows});
  final List<Expense> rows;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty)
      return Center(
        child: Text(
          'Sin datos para graficar',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    final sorted = [...rows]..sort((a, b) => a.date.compareTo(b.date));
    var running = 0;
    final values = <int>[];
    for (final row in sorted) {
      running += row.amountCents;
      values.add(running);
    }
    return CustomPaint(
      painter: _ChartPainter(values),
      child: const SizedBox.expand(),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.values);
  final List<int> values;
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AppColors.income
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = AppColors.income.withOpacity(.1)
      ..style = PaintingStyle.fill;
    final minV = values.reduce(math.min).toDouble();
    final maxV = values.reduce(math.max).toDouble();
    final range = math.max(maxV - minV, 1);
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : i * size.width / (values.length - 1);
      final y =
          size.height - ((values[i] - minV) / range) * (size.height - 12) - 6;
      points.add(Offset(x, y));
    }
    final chart = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      chart.lineTo(p.dx, p.dy);
    }
    final area = Path.from(chart)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(area, fill);
    canvas.drawPath(chart, line);
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) => oldDelegate.values != values;
}
