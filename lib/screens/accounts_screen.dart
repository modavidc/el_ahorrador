import 'package:flutter/material.dart';

import '../data/app_database.dart';
import 'account_detail_screen.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key, required this.db});

  final AppDatabase db;

  static const accent = Color(0xFFFF625D);
  static const blue = Color(0xFF3D9BF2);
  static const background = Color(0xFF24252A);
  static const surface = Color(0xFF2B2C31);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Cuentas'),
        actions: [
          IconButton(
            tooltip: 'Estadísticas totales',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AccountTotalsScreen(db: db),
              ),
            ),
            icon: const Icon(Icons.insert_chart_outlined),
          ),
          PopupMenuButton<String>(
            color: surface,
            onSelected: (value) => _showAccountsInfo(context, value),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'manage',
                child: Text('Administrar cuentas'),
              ),
              PopupMenuItem(value: 'order', child: Text('Cambiar orden')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Expense>>(
        stream: db.select(db.expenses).watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final expenses = snapshot.data ?? const <Expense>[];
          final grouped = <String, List<Expense>>{};
          for (final expense in expenses) {
            final raw = expense.account?.trim();
            final account = raw == null || raw.isEmpty
                ? 'Sin cuenta asignada'
                : raw;
            grouped.putIfAbsent(account, () => []).add(expense);
          }
          final entries = grouped.entries.toList()
            ..sort((a, b) {
              final byActivity = _latest(b.value).compareTo(_latest(a.value));
              return byActivity != 0 ? byActivity : a.key.compareTo(b.key);
            });
          final total = expenses.fold<int>(
            0,
            (sum, item) => sum + item.amountCents,
          );

          return Column(
            children: [
              _Summary(
                accountCount: entries.length,
                movementCount: expenses.length,
                movementCents: total,
              ),
              const _DataNotice(),
              Expanded(
                child: entries.isEmpty
                    ? const _EmptyAccounts()
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 32),
                        children: [
                          _SectionHeader(
                            title: 'Cuentas con actividad',
                            amountCents: total,
                          ),
                          ...entries.map((entry) {
                            final cents = _sum(entry.value);
                            return _AccountTile(
                              name: entry.key,
                              count: entry.value.length,
                              amountCents: cents,
                              latestActivity: _latest(entry.value),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => AccountDetailScreen(
                                    accountName: entry.key,
                                    expenses: entry.value,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAccountsInfo(BuildContext context, String action) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              action == 'order' ? 'Orden de cuentas' : 'Administrar cuentas',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'Por ahora las cuentas se detectan automáticamente desde tus '
              'transacciones. La edición de saldos iniciales llegará cuando '
              'exista un modelo de cuentas independiente.',
              style: TextStyle(color: Color(0xFFB6B6BD), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.accountCount,
    required this.movementCount,
    required this.movementCents,
  });
  final int accountCount;
  final int movementCount;
  final int movementCents;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AccountsScreen.background,
        border: Border(bottom: BorderSide(color: Color(0xFF414248))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Row(
        children: [
          Expanded(child: _value('Cuentas', '$accountCount')),
          Expanded(child: _value('Movimientos', '$movementCount')),
          Expanded(
            child: _value(
              'Gastos registrados',
              money(movementCents),
              color: AccountsScreen.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _value(String label, String value, {Color color = Colors.white}) =>
      Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFB6B6BD)),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: color),
          ),
        ],
      );
}

class _DataNotice extends StatelessWidget {
  const _DataNotice();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: const Color(0xFF303139),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
    child: const Text(
      'Actividad registrada · estos importes no representan saldos',
      style: TextStyle(color: Color(0xFFAAAAAF), fontSize: 12),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.amountCents});
  final String title;
  final int amountCents;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: Color(0xFFAAAAAF), fontSize: 17),
          ),
        ),
        Text(
          money(amountCents),
          style: const TextStyle(color: AccountsScreen.blue, fontSize: 17),
        ),
      ],
    ),
  );
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.name,
    required this.count,
    required this.amountCents,
    required this.latestActivity,
    required this.onTap,
  });
  final String name;
  final int count;
  final int amountCents;
  final int latestActivity;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AccountsScreen.surface,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF414248))),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              color: Color(0xFFB6B6BD),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 17),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$count ${count == 1 ? 'movimiento' : 'movimientos'} · '
                    '${_activityLabel(latestActivity)}',
                    style: const TextStyle(
                      color: Color(0xFF9999A0),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  money(amountCents),
                  style: const TextStyle(
                    color: AccountsScreen.blue,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'registrados',
                  style: TextStyle(color: Color(0xFF88888F), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Color(0xFF77777F)),
          ],
        ),
      ),
    ),
  );
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 58,
            color: Color(0xFF77777F),
          ),
          SizedBox(height: 16),
          Text(
            'Aún no hay cuentas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Las cuentas usadas en tus transacciones aparecerán aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFAAAAAF)),
          ),
        ],
      ),
    ),
  );
}

int _sum(List<Expense> items) =>
    items.fold(0, (sum, item) => sum + item.amountCents);
int _latest(List<Expense> items) =>
    items.fold(0, (latest, item) => item.date > latest ? item.date : latest);

String _activityLabel(int epoch) {
  if (epoch == 0) return 'sin actividad';
  final date = DateTime.fromMillisecondsSinceEpoch(epoch);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'hoy';
  if (difference == 1) return 'ayer';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String money(int cents) => 'S/ ${(cents / 100).toStringAsFixed(2)}';
