import 'package:flutter/material.dart';

import 'package:el_ahorrador/core/format/fmt.dart';
import 'package:el_ahorrador/design_system/kit.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/features/accounts/domain/account_group.dart';
import 'package:el_ahorrador/features/accounts/domain/accounts_repository.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/ledger/presentation/ledger_scope.dart';

/// Cuentas (v3): net worth, assets and debts, accounts by group; tapping an
/// account edits its name and balance, hides or removes it.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key, required this.accounts});

  final AccountsRepository accounts;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  Future<void> _add() async {
    final message = await showPaperSheet<String>(
      context,
      builder: (_) => _NewAccountSheet(accounts: widget.accounts),
    );
    if (message != null && mounted) showUndoToast(context, message);
  }

  Future<void> _edit(LedgerAccount account) async {
    final message = await showPaperSheet<String>(
      context,
      builder: (_) =>
          _EditAccountSheet(account: account, accounts: widget.accounts),
    );
    if (message != null && mounted) showUndoToast(context, message);
  }

  Future<void> _showHidden(List<LedgerAccount> hidden) async {
    for (final a in hidden) {
      await widget.accounts.setHidden(a.id, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = LedgerScope.of(context);
    final visible = data.accounts.where((a) => !a.isHidden).toList();
    final hidden = data.accounts.where((a) => a.isHidden).toList();
    final assets = visible
        .where((a) => a.balanceCents >= 0)
        .fold(0, (t, a) => t + a.balanceCents);
    final debts = visible
        .where((a) => a.balanceCents < 0)
        .fold(0, (t, a) => t - a.balanceCents);
    final counts = <String, int>{};
    for (final m in data.movements) {
      counts.update(m.account, (n) => n + 1, ifAbsent: () => 1);
      if (m.toAccount case final to?) {
        counts.update(to, (n) => n + 1, ifAbsent: () => 1);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              Expanded(child: Text('Cuentas', style: DesignText.tabTitle)),
              IconAction(
                icon: DesignIcons.add,
                label: 'Nueva cuenta',
                color: DesignColors.ink,
                onTap: _add,
              ),
            ],
          ),
        ),
        Text(
          'Patrimonio neto',
          style: DesignText.label13Semi.copyWith(color: DesignColors.ink2),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            Fmt.signedMoney((assets - debts) / 100),
            style: DesignText.style(
              44,
              FontWeight.w800,
              letterSpacing: -.03,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _Figure('Activos', assets, DesignColors.green)),
            const SizedBox(width: 10),
            Expanded(child: _Figure('Deudas', debts, DesignColors.red)),
          ],
        ),
        if (data.loaded && visible.isEmpty) ...[
          const SizedBox(height: 18),
          EmptyState(
            icon: DesignIcons.accountBalanceWallet,
            title: 'Aún no tienes cuentas',
            body: 'Agrega Yape, tu banco o efectivo para ver tu patrimonio.',
            action: 'Agregar cuenta',
            onAction: _add,
          ),
        ],
        for (final group in AccountGroup.values)
          if (visible.where((a) => AccountGroup.of(a) == group).toList()
              case final items when items.isNotEmpty) ...[
            SectionHeader(
              title: group.label,
              trailing: Fmt.signedMoney(
                items.fold(0, (t, a) => t + a.balanceCents) / 100,
              ),
            ),
            PaperCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Column(
                children: [
                  for (final (i, a) in items.indexed)
                    _AccountRow(
                      account: a,
                      group: group,
                      movements: counts[a.name] ?? 0,
                      first: i == 0,
                      onTap: () => _edit(a),
                    ),
                ],
              ),
            ),
          ],
        if (hidden.isNotEmpty)
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: () => _showHidden(hidden),
              child: Container(
                height: 48,
                margin: const EdgeInsets.only(top: 12),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Sym(
                      DesignIcons.visibility,
                      size: 18,
                      color: DesignColors.ink2,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${hidden.length} '
                      '${hidden.length == 1 ? 'cuenta oculta' : 'cuentas ocultas'}'
                      ' · Mostrar',
                      style: DesignText.body14Bold.copyWith(
                        color: DesignColors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.cents, this.color);

  final String label;
  final int cents;
  final Color color;

  @override
  Widget build(BuildContext context) => PaperCard(
    radius: DesignRadius.cta,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DesignText.small.copyWith(color: DesignColors.ink2)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            Fmt.money(cents / 100),
            style: DesignText.style(16, FontWeight.w800).copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.group,
    required this.movements,
    required this.first,
    required this.onTap,
  });

  final LedgerAccount account;
  final AccountGroup group;
  final int movements;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = AccountGroupStyle.of(group);
    final negative = account.balanceCents < 0;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            border: first
                ? null
                : const Border(top: BorderSide(color: DesignColors.lineSoft)),
          ),
          child: Row(
            children: [
              IconTile(
                icon: style.icon,
                color: style.foreground,
                background: style.background,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DesignText.rowAmount,
                    ),
                    Text(
                      negative
                          ? 'Por pagar'
                          : '$movements '
                                '${movements == 1 ? 'movimiento' : 'movimientos'}',
                      style: DesignText.small.copyWith(
                        color: DesignColors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Fmt.signedMoney(account.balanceCents / 100),
                style: DesignText.rowAmount.copyWith(
                  color: negative ? DesignColors.red : DesignColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Nueva cuenta": name with suggestions, group and opening balance.
class _NewAccountSheet extends StatefulWidget {
  const _NewAccountSheet({required this.accounts});

  final AccountsRepository accounts;

  @override
  State<_NewAccountSheet> createState() => _NewAccountSheetState();
}

class _NewAccountSheetState extends State<_NewAccountSheet> {
  final _name = TextEditingController();
  final _balance = TextEditingController();
  AccountGroup _group = AccountGroup.bancos;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    try {
      await widget.accounts.create(
        name: name,
        group: _group,
        openingBalanceCents: Fmt.parseCents(_balance.text) ?? 0,
      );
      if (mounted) Navigator.of(context).pop('Cuenta creada');
    } on Object catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Nueva cuenta', style: DesignText.sheetHeading),
        const SizedBox(height: 14),
        FieldBox(
          controller: _name,
          hint: 'Nombre (ej. Interbank)',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in const [
              'Interbank',
              'Scotiabank',
              'Plin',
              'Caja Arequipa',
            ])
              TileChip(label: s, onTap: () => setState(() => _name.text = s)),
          ],
        ),
        const FieldLabel('GRUPO'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final g in AccountGroup.values)
              DsChip(
                label: g.label,
                selected: g == _group,
                padding: 12,
                onTap: () => setState(() => _group = g),
              ),
          ],
        ),
        const FieldLabel('SALDO INICIAL'),
        FieldBox(
          controller: _balance,
          hint: 'S/ 0.00',
          amount: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
        ),
        if (_error != null) ErrorText(_error!),
        const SizedBox(height: 16),
        SheetButton(
          label: 'Crear cuenta',
          color: _name.text.trim().isEmpty
              ? DesignColors.disabled
              : DesignColors.red,
          onTap: _name.text.trim().isEmpty ? null : _save,
        ),
      ],
    ),
  );
}

/// "Editar cuenta": name and current balance; Eliminar, Ocultar, Guardar.
class _EditAccountSheet extends StatefulWidget {
  const _EditAccountSheet({required this.account, required this.accounts});

  final LedgerAccount account;
  final AccountsRepository accounts;

  @override
  State<_EditAccountSheet> createState() => _EditAccountSheetState();
}

class _EditAccountSheetState extends State<_EditAccountSheet> {
  late final _name = TextEditingController(text: widget.account.name);
  late final _balance = TextEditingController(
    text: (widget.account.balanceCents / 100).toStringAsFixed(2),
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    try {
      await action();
      if (mounted) Navigator.of(context).pop(message);
    } on Object catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Editar cuenta', style: DesignText.sheetHeading),
          const FieldLabel('NOMBRE'),
          FieldBox(controller: _name),
          const FieldLabel('SALDO ACTUAL'),
          FieldBox(
            controller: _balance,
            amount: true,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
          ),
          if (_error != null) ErrorText(_error!),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlineAction(
                  icon: DesignIcons.delete,
                  label: 'Eliminar',
                  color: DesignColors.red,
                  onTap: () => _run(
                    () => widget.accounts.delete(a.id),
                    'Cuenta eliminada',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlineAction(
                  icon: DesignIcons.visibilityOff,
                  label: 'Ocultar',
                  onTap: () => _run(
                    () => widget.accounts.setHidden(a.id, true),
                    'Cuenta oculta · no suma en totales',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SheetButton.ink(
                  label: 'Guardar',
                  height: 52,
                  onTap: () => _run(
                    () => widget.accounts.update(
                      a.id,
                      name: _name.text.trim().isEmpty
                          ? a.name
                          : _name.text.trim(),
                      balanceCents:
                          Fmt.parseCents(_balance.text) ?? a.balanceCents,
                    ),
                    'Cuenta actualizada',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
