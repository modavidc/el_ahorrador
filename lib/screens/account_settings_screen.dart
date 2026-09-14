import 'package:flutter/material.dart';

import '../data/account_repository.dart';
import '../data/app_database.dart';
import '../data/daos.dart';
import 'account_detail_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key, required this.db});
  final AppDatabase db;
  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late final AccountRepository _repository = AccountRepository(widget.db);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff8f7fb),
    appBar: AppBar(
      title: const Text('Cuentas'),
      actions: [
        IconButton(
          tooltip: 'Administrar cuentas',
          icon: const Icon(Icons.tune_rounded),
          onPressed: _showManagementDialog,
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _showNameDialog,
      icon: const Icon(Icons.add),
      label: const Text('Nueva cuenta'),
    ),
    body: StreamBuilder<List<Account>>(
      stream: _repository.watchAll(),
      builder: (context, accountsSnapshot) {
        if (accountsSnapshot.hasError)
          return const _Message('No pudimos cargar las cuentas.');
        if (!accountsSnapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        return StreamBuilder<List<Expense>>(
          stream: widget.db.watchExpenses(),
          builder: (context, expensesSnapshot) {
            if (expensesSnapshot.hasError)
              return const _Message('No pudimos cargar los movimientos.');
            if (!expensesSnapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            return StreamBuilder<List<AccountBalance>>(
              stream: _repository.watchBalances(),
              builder: (context, balanceSnapshot) {
                if (balanceSnapshot.hasError)
                  return const _Message('No pudimos calcular los saldos.');
                if (!balanceSnapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                return _Dashboard(
                  accounts: accountsSnapshot.data!,
                  expenses: expensesSnapshot.data!,
                  balances: {
                    for (final item in balanceSnapshot.data!)
                      item.accountId: item,
                  },
                  onOpen: _openDetail,
                );
              },
            );
          },
        );
      },
    ),
  );

  void _openDetail(Account account) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AccountDetailScreen(db: widget.db, account: account),
    ),
  );

  Future<void> _showManagementDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => StreamBuilder<List<Account>>(
        stream: _repository.watchAll(),
        builder: (context, snapshot) => AlertDialog(
          title: const Text('Administrar cuentas'),
          content: SizedBox(
            width: 420,
            child: snapshot.hasData
                ? SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: snapshot.data!.map(_manageTile).toList(),
                    ),
                  )
                : const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _manageTile(Account account) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      account.isArchived
          ? Icons.archive_outlined
          : Icons.account_balance_wallet_outlined,
    ),
    title: Text(account.name),
    subtitle: Text(
      account.isDefault
          ? 'Predeterminada'
          : account.isArchived
          ? 'Archivada'
          : account.currency,
    ),
    trailing: PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'edit') await _showNameDialog(account: account);
        if (value == 'default')
          await _run(() => _repository.setDefault(account.id));
        if (value == 'archive')
          await _run(
            () => _repository.setArchived(account.id, !account.isArchived),
          );
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Editar')),
        if (!account.isDefault && !account.isArchived)
          const PopupMenuItem(
            value: 'default',
            child: Text('Hacer predeterminada'),
          ),
        if (!account.isDefault)
          PopupMenuItem(
            value: 'archive',
            child: Text(account.isArchived ? 'Restaurar' : 'Archivar'),
          ),
      ],
    ),
  );

  Future<void> _showNameDialog({Account? account}) async {
    final controller = TextEditingController(text: account?.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(account == null ? 'Nueva cuenta' : 'Editar cuenta'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    await _run(
      () => account == null
          ? _repository.create(name: name)
          : _repository.rename(account.id, name),
    );
  }

  Future<void> _run(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('Invalid argument(s): ', ''),
            ),
          ),
        );
    }
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.accounts,
    required this.expenses,
    required this.balances,
    required this.onOpen,
  });
  final List<Account> accounts;
  final List<Expense> expenses;
  final Map<String, AccountBalance> balances;
  final ValueChanged<Account> onOpen;
  int _balance(Account a) =>
      balances[a.id]?.balanceCents ??
      expenses
          .where((e) => e.accountId == a.id)
          .fold(0, (s, e) => s + e.amountCents);
  bool _liability(Account a) {
    final n = a.name.toLowerCase();
    return n.contains('tarjeta') ||
        n.contains('card') ||
        n.contains('crédito') ||
        n.contains('credito');
  }

  String _money(int cents, String currency) =>
      '${currency == 'PEN' ? 'S/' : currency} ${(cents.abs() / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final active = accounts.where((a) => !a.isArchived).toList();
    final assets = active.where((a) => !_liability(a)).toList();
    final debts = active.where(_liability).toList();
    final totals = _byCurrency(active);
    final assetTotals = _byCurrency(assets);
    final debtTotals = _byCurrency(debts);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        _TotalsCard(
          total: totals,
          assets: assetTotals,
          debts: debtTotals,
          money: _money,
        ),
        const SizedBox(height: 24),
        if (active.isEmpty)
          const _EmptyAccounts()
        else ...[
          if (assets.isNotEmpty)
            _AccountGroup(
              title: 'Activos',
              icon: Icons.account_balance_wallet_outlined,
              accounts: assets,
              balance: _balance,
              money: _money,
              onOpen: onOpen,
            ),
          if (debts.isNotEmpty)
            _AccountGroup(
              title: 'Tarjetas y deudas',
              icon: Icons.credit_card_outlined,
              accounts: debts,
              balance: _balance,
              money: _money,
              onOpen: onOpen,
            ),
        ],
        if (accounts.any((a) => a.isArchived)) ...[
          const SizedBox(height: 12),
          Text(
            'Archivadas',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          ...accounts
              .where((a) => a.isArchived)
              .map(
                (a) => ListTile(
                  leading: const Icon(Icons.archive_outlined),
                  title: Text(a.name),
                  subtitle: const Text('Historial conservado'),
                ),
              ),
        ],
      ],
    );
  }

  Map<String, int> _byCurrency(List<Account> rows) => {
    for (final currency in rows.map((a) => a.currency).toSet())
      currency: rows
          .where((a) => a.currency == currency)
          .fold(0, (s, a) => s + _balance(a)),
  };
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.total,
    required this.assets,
    required this.debts,
    required this.money,
  });
  final Map<String, int> total, assets, debts;
  final String Function(int, String) money;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: const Color(0xff20242d),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BALANCE TOTAL',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          ...total.entries.map(
            (entry) => Text(
              money(entry.value, entry.key),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _Metric('Activos', _format(assets), const Color(0xff8ed6a5)),
              const SizedBox(width: 28),
              _Metric('Deudas', _format(debts), const Color(0xffffa39d)),
            ],
          ),
        ],
      ),
    ),
  );

  String _format(Map<String, int> values) =>
      values.entries.map((e) => money(e.value, e.key)).join(' · ');
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.color);
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white60)),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 17,
        ),
      ),
    ],
  );
}

class _AccountGroup extends StatelessWidget {
  const _AccountGroup({
    required this.title,
    required this.icon,
    required this.accounts,
    required this.balance,
    required this.money,
    required this.onOpen,
  });
  final String title;
  final IconData icon;
  final List<Account> accounts;
  final int Function(Account) balance;
  final String Function(int, String) money;
  final ValueChanged<Account> onOpen;
  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          c,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Card(
        elevation: 0,
        child: Column(
          children: accounts
              .map(
                (a) => ListTile(
                  onTap: () => onOpen(a),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xffedf0f7),
                    child: Icon(icon, color: const Color(0xff475569)),
                  ),
                  title: Text(a.name),
                  subtitle: Text(
                    a.isDefault ? 'Predeterminada · ${a.currency}' : a.currency,
                  ),
                  trailing: Text(
                    money(balance(a), a.currency),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 20),
    ],
  );
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();
  @override
  Widget build(BuildContext c) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 12),
          const Text('Aún no tienes cuentas'),
          const SizedBox(height: 6),
          Text(
            'Crea una cuenta para saber dónde está tu dinero.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;
  @override
  Widget build(BuildContext c) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
