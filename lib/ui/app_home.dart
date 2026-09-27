import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../features/ledger/ledger.dart';
import '../features/settings/app_preferences.dart';
import '../screens/account_settings_screen.dart';
import '../screens/add_account_screen.dart';
import '../theme/design_tokens.dart';
import 'accounts/accounts_screen.dart';
import 'coach/coach_screen.dart';
import 'kit.dart';
import 'ledger_scope.dart';
import 'movements/entry_sheet.dart';
import 'movements/movements_screen.dart';
import 'period_scope.dart';
import 'settings/budgets_screen.dart';
import 'settings/settings_screen.dart';
import 'shell/app_shell.dart';
import 'stats/stats_screen.dart';

/// Root of the interface (design handoff v3 in `design/`).
class AppHome extends StatefulWidget {
  const AppHome({super.key, required this.db});

  final AppDatabase db;

  @override
  State<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  late final _repository = LedgerRepository(widget.db);
  late final _preferences = AppPreferences(widget.db);
  final _shell = ShellController();
  final _period = PeriodController();
  final _recent = RecentEntries();
  final _statsCategory = ValueNotifier<String?>(null);

  static const _movements = 0;
  static const _stats = 1;

  @override
  void dispose() {
    _shell.dispose();
    _period.dispose();
    _recent.dispose();
    _statsCategory.dispose();
    super.dispose();
  }

  Future<void> _openEntry(BuildContext context) async {
    final data = LedgerScope.of(context);
    final result = await showEntrySheet(
      context,
      repository: _repository,
      accounts: data.accounts,
      movements: data.movements,
    );
    if (result == null || !context.mounted) return;
    _recent.add(result.id);
    _shell.select(_movements);
    showUndoToast(
      context,
      result.message,
      onUndo: () => _undoById(context, result.id),
    );
  }

  Future<void> _undoById(BuildContext context, String id) async {
    final movement = LedgerScope.of(
      context,
    ).movements.where((m) => m.id == id).firstOrNull;
    if (movement != null) await _undo(context, movement);
  }

  /// "Deshacer" of a new movement: removes it for good.
  Future<void> _undo(BuildContext context, Movement m) async {
    _recent.remove(m.id);
    await _repository.delete(m);
    if (context.mounted) showUndoToast(context, 'Movimiento deshecho');
  }

  Future<void> _openMovement(BuildContext context, Movement m) =>
      showPaperSheet<void>(
        context,
        builder: (sheet) => MovementDetailSheet(
          movement: m,
          onCategory: (name) async {
            await _repository.setCategory(m, name);
            if (sheet.mounted) Navigator.of(sheet).pop();
          },
          onDelete: () async {
            Navigator.of(sheet).pop();
            final rows = await _repository.delete(m);
            if (!context.mounted) return;
            showUndoToast(
              context,
              'Movimiento eliminado',
              onUndo: () => _repository.restore(rows),
            );
          },
          onRepeat: () async {
            Navigator.of(sheet).pop();
            final id = await _repository.repeat(m);
            _recent.add(id);
            if (!context.mounted) return;
            showUndoToast(
              context,
              'Repetido hoy',
              onUndo: () => _undoById(context, id),
            );
          },
        ),
      );

  void _openStreak(BuildContext context) => showPaperSheet<void>(
    context,
    builder: (sheet) => StreakSheet(
      movements: LedgerScope.of(context).movements,
      onAdd: () {
        Navigator.of(sheet).pop();
        _openEntry(context);
      },
    ),
  );

  void _openTryShare(BuildContext context) =>
      showPaperSheet<void>(context, builder: (_) => const TryShareSheet());

  void _push(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));

  @override
  Widget build(BuildContext context) => LedgerProvider(
    repository: _repository,
    child: RecentEntriesScope(
      entries: _recent,
      child: PeriodScope(
        controller: _period,
        child: Builder(
          builder: (context) => AppShell(
            controller: _shell,
            destinations: [
              ShellDestination(
                icon: DesignIcons.receiptLong,
                label: 'Movimientos',
                showFab: true,
                builder: (context) => MovementsScreen(
                  preferences: _preferences,
                  onAdd: () => _openEntry(context),
                  onOpen: (m) => _openMovement(context, m),
                  onUndo: (m) => _undo(context, m),
                  onTryShare: () => _openTryShare(context),
                  onStreak: () => _openStreak(context),
                ),
              ),
              ShellDestination(
                icon: DesignIcons.barChart,
                label: 'Estadísticas',
                showFab: true,
                builder: (_) => StatsScreen(categoryRequest: _statsCategory),
              ),
              ShellDestination(
                icon: DesignIcons.autoAwesome,
                label: 'Coach',
                builder: (context) => CoachScreen(
                  onShowBudget: () =>
                      _push(context, (_) => BudgetsScreen(db: widget.db)),
                  onShowCategory: (category) {
                    _statsCategory.value = category;
                    _shell.select(_stats);
                  },
                ),
              ),
              ShellDestination(
                icon: DesignIcons.accountBalanceWallet,
                label: 'Cuentas',
                showFab: true,
                builder: (context) => AccountsScreen(
                  onEdit: () => _push(
                    context,
                    (_) => AccountSettingsScreen(db: widget.db),
                  ),
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
                label: 'Manual',
                subtitle: 'Monto, categoría y cuenta',
                icon: DesignIcons.editNote,
                onSelected: () => _openEntry(context),
              ),
              FabAction(
                label: 'Escanear boleta',
                subtitle: 'Foto del ticket',
                icon: DesignIcons.documentScanner,
                onSelected: () => showUndoToast(context, 'Próximamente'),
              ),
              FabAction(
                label: 'Dictar',
                subtitle: 'Dilo en voz alta',
                icon: DesignIcons.mic,
                onSelected: () => showUndoToast(context, 'Próximamente'),
              ),
              FabAction(
                label: 'Compartir comprobante',
                subtitle: 'Desde Yape o tu banco',
                icon: DesignIcons.share,
                capture: true,
                onSelected: () => _openTryShare(context),
              ),
              FabAction(
                label: 'Captura en segundo plano',
                subtitle: 'Requiere permisos',
                icon: DesignIcons.screenshotMonitor,
                capture: true,
                onSelected: () => showUndoToast(context, 'Próximamente'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
