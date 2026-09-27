import 'package:flutter/material.dart';

import 'package:el_ahorrador/features/accounts/data/account_group_repository.dart';
import 'package:el_ahorrador/features/accounts/data/account_repository.dart';
import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/core/database/daos.dart';
import 'package:el_ahorrador/features/accounts/presentation/legacy/app_styles.dart';
import 'package:el_ahorrador/features/accounts/presentation/legacy/account_detail_screen.dart';
import 'package:el_ahorrador/features/accounts/presentation/legacy/add_account_screen.dart';

/// Contenido de la pestaña Cuentas, embebido directamente en el body de
/// HomeScreen (sin Scaffold/AppBar/FAB propios) para que se comporte como
/// un tab más de la barra inferior — sin botón de back ni pila de
/// navegación extra.
class AccountsTabBody extends StatefulWidget {
  const AccountsTabBody({
    super.key,
    required this.db,
    this.showBackButton = false,
  });
  final AppDatabase db;

  /// true solo cuando se llega acá empujada desde otra pantalla (Backup,
  /// Settings) en vez de desde la barra inferior principal.
  final bool showBackButton;
  @override
  State<AccountsTabBody> createState() => _AccountsTabBodyState();
}

/// Wrapper con Scaffold para los pocos lugares que todavía empujan a
/// Cuentas como sub-pantalla (backup_screen.dart, settings_screen.dart)
/// en vez de llegar por la barra inferior principal de HomeScreen.
class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key, required this.db});
  final AppDatabase db;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: AccountsTabBody(db: db, showBackButton: true),
  );
}

class _AccountsTabBodyState extends State<AccountsTabBody> {
  late final AccountRepository _repository = AccountRepository(widget.db);
  late final AccountGroupRepository _groupRepository = AccountGroupRepository(
    widget.db,
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Column(
      children: [
        _buildHeader(),
        Expanded(
          child: StreamBuilder<List<AccountGroup>>(
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
                        return const _Message(
                          'No pudimos cargar los movimientos.',
                        );
                      if (!expensesSnapshot.hasData)
                        return const Center(child: CircularProgressIndicator());
                      return StreamBuilder<List<AccountBalance>>(
                        stream: _repository.watchBalances(),
                        builder: (context, balanceSnapshot) {
                          if (balanceSnapshot.hasError)
                            return const _Message(
                              'No pudimos calcular los saldos.',
                            );
                          if (!balanceSnapshot.hasData)
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
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
        ),
      ],
    ),
  );

  Widget _buildHeader() => Container(
    height: 56,
    color: Colors.white,
    padding: EdgeInsets.only(left: widget.showBackButton ? 4 : 16, right: 4),
    child: Row(
      children: [
        if (widget.showBackButton)
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        const Expanded(
          child: Text(
            'Cuentas',
            style: TextStyle(fontSize: 20, color: Colors.black),
          ),
        ),
        IconButton(
          onPressed: () =>
              ScaffoldMessenger.of(context).showSnackBar(comingSoonSnackBar),
          tooltip: 'Estadísticas de cuentas',
          icon: const Icon(Icons.bar_chart_outlined, color: Colors.black),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.black),
          onSelected: (value) {
            if (value == 'add') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddAccountScreen(db: widget.db),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(comingSoonSnackBar);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'add', child: Text('Agregar')),
            PopupMenuItem(value: 'show_hide', child: Text('Mostrar/Ocultar')),
            PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            PopupMenuItem(value: 'order', child: Text('Modificar orden')),
          ],
        ),
      ],
    ),
  );

  void _openDetail(Account account) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AccountDetailScreen(db: widget.db, account: account),
    ),
  );
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

  String _money(int cents, String currency) {
    final symbol = switch (currency) {
      'PEN' => 'S/.',
      'USD' => '\$',
      _ => currency,
    };
    return '$symbol ${(cents.abs() / 100).toStringAsFixed(2)}';
  }

  /// En la referencia de Money Manager, toda cuenta de un grupo "activo"
  /// con saldo distinto de cero se pinta azul (nunca rojo) — el rojo ahí
  /// queda reservado a Liabilities. No usamos el signo real de
  /// balanceCents acá: algunas cuentas ya migradas tienen saldo negativo
  /// internamente (siempre se mostró con .abs(), nunca se expuso el signo
  /// en la UI hasta ahora), y colorear eso de rojo sería inventar una
  /// semántica de "deuda" que esa cuenta no tiene — es un grupo activo.
  Color? _valueColor(int cents, bool isLiability) {
    if (isLiability || cents == 0) return null;
    return AppColors.income;
  }

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
      padding: const EdgeInsets.only(bottom: 24),
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
          const _GroupBand(title: 'Archivadas', trailing: ''),
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
    final isLiability = group?.type == accountGroupTypeLiability;
    final currency = list.first.currency;
    final subtotal = list.fold<int>(0, (s, a) => s + _balance(a));
    return [
      _GroupBand(
        title: group?.name ?? 'Sin grupo',
        trailing: _money(subtotal, currency),
        trailingColor: _valueColor(subtotal, isLiability),
      ),
      for (final account in list)
        _AccountRow(
          name: account.name,
          value: _money(_balance(account), account.currency),
          muted: _balance(account) == 0,
          valueColor: _valueColor(_balance(account), isLiability),
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
      const SizedBox(height: 2),
      Text(value, style: AppTextStyles.summaryValue.copyWith(color: color)),
    ],
  );
}

class _GroupBand extends StatelessWidget {
  const _GroupBand({
    required this.title,
    required this.trailing,
    this.trailingColor,
  });
  final String title;
  final String trailing;
  final Color? trailingColor;
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.groupBand,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        if (trailing.isNotEmpty)
          Text(
            trailing,
            style: AppTextStyles.amountMedium.copyWith(
              color: trailingColor ?? AppColors.textPrimary,
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
    this.valueColor,
  });
  final String name;
  final String value;
  final bool muted;
  final VoidCallback? onTap;
  final Color? valueColor;
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
              fontSize: 14,
              color: muted ? AppColors.textMuted : AppColors.textPrimary,
            ),
          ),
          if (value.isNotEmpty)
            Text(
              value,
              style: AppTextStyles.amountMedium.copyWith(
                color: muted
                    ? AppColors.textMuted
                    : (valueColor ?? AppColors.textPrimary),
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
