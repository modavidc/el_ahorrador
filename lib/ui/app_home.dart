import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../features/ledger/ledger.dart';
import '../screens/account_settings_screen.dart';
import '../screens/add_account_screen.dart';
import '../theme/design_tokens.dart';
import 'accounts/accounts_screen.dart';
import 'add/add_screen.dart';
import 'coach/coach_screen.dart';
import 'ledger_scope.dart';
import 'period_scope.dart';
import 'settings/settings_screen.dart';
import 'shell/app_shell.dart';
import 'stats/stats_screen.dart';
import 'trans/trans_screen.dart';
import 'widgets.dart';

/// Root of the v1 interface (design handoff in `design/`).
class AppHome extends StatefulWidget {
  const AppHome({super.key, required this.db});

  final AppDatabase db;

  @override
  State<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  late final _repository = LedgerRepository(widget.db);
  final _shell = ShellController();
  final _period = PeriodController();
  final _transTab = ValueNotifier<int?>(null);
  final _statsCategory = ValueNotifier<String?>(null);

  static const _trans = 0;
  static const _stats = 1;
  static const _coach = 2;

  @override
  void dispose() {
    _shell.dispose();
    _period.dispose();
    _transTab.dispose();
    _statsCategory.dispose();
    super.dispose();
  }

  Future<void> _openEntry(BuildContext context, {Movement? editing}) async {
    final accounts = LedgerScope.of(context).accounts;
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            AddScreen(db: widget.db, accounts: accounts, editing: editing),
      ),
    );
    if (message != null && context.mounted) showDsToast(context, message);
  }

  void _push(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));

  @override
  Widget build(BuildContext context) => LedgerProvider(
    repository: _repository,
    child: PeriodScope(
      controller: _period,
      child: Builder(
        builder: (context) => AppShell(
          controller: _shell,
          destinations: [
            ShellDestination(
              icon: DesignIcons.receiptLong,
              label: 'Trans.',
              showFab: true,
              builder: (context) => TransScreen(
                tabRequest: _transTab,
                onTapMovement: (m) => _openEntry(context, editing: m),
              ),
            ),
            ShellDestination(
              icon: DesignIcons.barChart,
              label: 'Estad.',
              showFab: true,
              builder: (_) => StatsScreen(categoryRequest: _statsCategory),
            ),
            ShellDestination(
              icon: DesignIcons.autoAwesome,
              label: 'Coach',
              builder: (_) => CoachScreen(
                onShowBudget: () {
                  _transTab.value = 3;
                  _shell.select(_trans);
                },
                onShowCategory: (category) {
                  _statsCategory.value = category;
                  _shell.select(_stats);
                },
              ),
            ),
            ShellDestination(
              icon: DesignIcons.accountBalanceWallet,
              label: 'Cuentas',
              builder: (context) => AccountsScreen(
                onEdit: () =>
                    _push(context, (_) => AccountSettingsScreen(db: widget.db)),
                onAdd: () =>
                    _push(context, (_) => AddAccountScreen(db: widget.db)),
              ),
            ),
            ShellDestination(
              icon: DesignIcons.settings,
              label: 'Ajustes',
              builder: (_) => SettingsScreen(db: widget.db),
            ),
          ],
          fabActions: (shell) => [
            FabAction(
              label: 'Añadir manual',
              icon: DesignIcons.edit,
              color: DesignColors.income,
              onSelected: () => _openEntry(context),
            ),
            FabAction(
              label: 'Escanear recibo',
              icon: DesignIcons.documentScanner,
              color: DesignColors.success,
              onSelected: () => showDsToast(context, 'Próximamente'),
            ),
            FabAction(
              label: 'Preguntar al Coach',
              icon: DesignIcons.autoAwesome,
              color: DesignColors.primary,
              onSelected: () => shell.select(_coach),
            ),
          ],
        ),
      ),
    ),
  );
}
