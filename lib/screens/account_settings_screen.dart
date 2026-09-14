import 'package:flutter/material.dart';

import '../data/account_group_repository.dart';
import '../data/account_repository.dart';
import '../data/app_database.dart';
import '../data/daos.dart';
import '../theme/app_styles.dart';
import 'account_detail_screen.dart';
import 'account_group_settings_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key, required this.db});
  final AppDatabase db;
  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late final AccountRepository _repository = AccountRepository(widget.db);
  late final AccountGroupRepository _groupRepository = AccountGroupRepository(
    widget.db,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Cuentas'),
      actions: [
        IconButton(
          tooltip: 'Grupos de cuentas',
          icon: const Icon(Icons.folder_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AccountGroupSettingsScreen(db: widget.db),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Administrar cuentas',
          icon: const Icon(Icons.tune_rounded),
          onPressed: _showManagementDialog,
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _showAccountDialog(),
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('Nueva cuenta'),
    ),
    body: StreamBuilder<List<AccountGroup>>(
      stream: _groupRepository.watchAll(),
      builder: (context, groupsSnapshot) {
        if (groupsSnapshot.hasError)
          return const _Message('No pudimos cargar los grupos.');
        if (!groupsSnapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        return StreamBuilder<List<Account>>(
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
                      groups: groupsSnapshot.data!,
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
        if (value == 'edit') await _showAccountDialog(account: account);
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

  Future<void> _showAccountDialog({Account? account}) async {
    final groups = await _groupRepository.watchAll().first;
    if (groups.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Primero creá un grupo de cuentas.')),
        );
      }
      return;
    }
    final controller = TextEditingController(text: account?.name);
    String groupId =
        account?.groupId ??
        (groups.any((g) => g.id == AppDatabase.defaultAccountGroupId)
            ? AppDatabase.defaultAccountGroupId
            : groups.first.id);
    if (!groups.any((g) => g.id == groupId)) groupId = groups.first.id;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(account == null ? 'Nueva cuenta' : 'Editar cuenta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: groupId,
                decoration: const InputDecoration(labelText: 'Grupo'),
                items: groups
                    .map(
                      (g) => DropdownMenuItem(value: g.id, child: Text(g.name)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => groupId = value ?? groupId),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final name = controller.text;
    await _run(() async {
      if (account == null) {
        await _repository.create(name: name, groupId: groupId);
      } else {
        await _repository.rename(account.id, name);
        if (groupId != account.groupId) {
          await _repository.setGroup(account.id, groupId);
        }
      }
    });
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
    required this.groups,
    required this.accounts,
    required this.expenses,
    required this.balances,
    required this.onOpen,
  });
  final List<AccountGroup> groups;
  final List<Account> accounts;
  final List<Expense> expenses;
  final Map<String, AccountBalance> balances;
  final ValueChanged<Account> onOpen;

  int _balance(Account a) =>
      balances[a.id]?.balanceCents ??
      expenses
          .where((e) => e.accountId == a.id)
          .fold(0, (s, e) => s + e.amountCents);

  String _money(int cents, String currency) =>
      '${currency == 'PEN' ? 'S/' : currency} ${(cents.abs() / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final active = accounts.where((a) => !a.isArchived).toList();
    final archived = accounts.where((a) => a.isArchived).toList();
    final groupById = {for (final g in groups) g.id: g};

    final assetTotals = <String, int>{};
    final liabilityTotals = <String, int>{};
    final netTotals = <String, int>{};
    for (final account in active) {
      final balance = _balance(account);
      final group = groupById[account.groupId];
      final isLiability = group?.type == accountGroupTypeLiability;
      netTotals.update(
        account.currency,
        (v) => v + balance,
        ifAbsent: () => balance,
      );
      final bucket = isLiability ? liabilityTotals : assetTotals;
      bucket.update(
        account.currency,
        (v) => v + balance,
        ifAbsent: () => balance,
      );
    }

    if (active.isEmpty && archived.isEmpty) {
      return const _EmptyAccounts();
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        _SummaryRow(
          assets: assetTotals,
          liabilities: liabilityTotals,
          total: netTotals,
          money: _money,
        ),
        const Divider(height: 1, color: AppColors.border),
        for (final group in groups)
          ..._groupSection(group, active.where((a) => a.groupId == group.id)),
        ..._groupSection(
          null,
          active.where((a) => !groupById.containsKey(a.groupId)),
        ),
        if (archived.isNotEmpty) ...[
          _GroupBand(title: 'Archivadas', trailing: ''),
          for (final account in archived)
            _AccountRow(
              name: account.name,
              value: '',
              muted: true,
              onTap: null,
            ),
        ],
      ],
    );
  }

  List<Widget> _groupSection(AccountGroup? group, Iterable<Account> rows) {
    final list = rows.toList();
    if (list.isEmpty) return const [];
    final currency = list.first.currency;
    final subtotal = list.fold<int>(0, (s, a) => s + _balance(a));
    return [
      _GroupBand(
        title: group?.name ?? 'Sin grupo',
        trailing: _money(subtotal, currency),
      ),
      for (final account in list)
        _AccountRow(
          name: account.name,
          value: _money(_balance(account), account.currency),
          muted: _balance(account) == 0,
          onTap: () => onOpen(account),
        ),
    ];
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.assets,
    required this.liabilities,
    required this.total,
    required this.money,
  });
  final Map<String, int> assets, liabilities, total;
  final String Function(int, String) money;

  String _format(Map<String, int> values) => values.isEmpty
      ? money(0, 'PEN')
      : values.entries.map((e) => money(e.value, e.key)).join(' · ');

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    child: Row(
      children: [
        Expanded(
          child: _SummaryItem(
            label: 'Assets',
            value: _format(assets),
            color: AppColors.income,
          ),
        ),
        Expanded(
          child: _SummaryItem(
            label: 'Liabilities',
            value: _format(liabilities),
            color: AppColors.expense,
          ),
        ),
        Expanded(
          child: _SummaryItem(
            label: 'Total',
            value: _format(total),
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(label, style: AppTextStyles.label),
      const SizedBox(height: 4),
      Text(
        value,
        style: AppTextStyles.amountMedium.copyWith(color: color, fontSize: 16),
      ),
    ],
  );
}

class _GroupBand extends StatelessWidget {
  const _GroupBand({required this.title, required this.trailing});
  final String title;
  final String trailing;
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.groupBand,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: AppColors.textSecondary)),
        if (trailing.isNotEmpty)
          Text(
            trailing,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    ),
  );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.name,
    required this.value,
    required this.muted,
    required this.onTap,
  });
  final String name;
  final String value;
  final bool muted;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: TextStyle(
              color: muted ? AppColors.textMuted : AppColors.textPrimary,
            ),
          ),
          if (value.isNotEmpty)
            Text(
              value,
              style: TextStyle(
                color: muted ? AppColors.textMuted : AppColors.textPrimary,
              ),
            ),
        ],
      ),
    ),
  );
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();
  @override
  Widget build(BuildContext c) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          const Text(
            'Aún no tienes cuentas',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Crea una cuenta para saber dónde está tu dinero.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
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
