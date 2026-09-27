import 'package:flutter/material.dart';

import 'package:el_ahorrador/app/dependencies.dart';
import 'package:el_ahorrador/app/home/app_shell.dart';
import 'package:el_ahorrador/design_system/kit.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/features/accounts/presentation/accounts_screen.dart';
import 'package:el_ahorrador/features/accounts/presentation/legacy/account_settings_screen.dart';
import 'package:el_ahorrador/features/accounts/presentation/legacy/add_account_screen.dart';
import 'package:el_ahorrador/features/capture/application/capture_controller.dart';
import 'package:el_ahorrador/features/capture/domain/capture_models.dart';
import 'package:el_ahorrador/features/capture/presentation/capture_sheet.dart';
import 'package:el_ahorrador/features/capture/presentation/inbox_screen.dart';
import 'package:el_ahorrador/features/capture/presentation/rules_screen.dart';
import 'package:el_ahorrador/features/coach/presentation/coach_screen.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/ledger/presentation/entry_sheet.dart';
import 'package:el_ahorrador/features/ledger/presentation/ledger_scope.dart';
import 'package:el_ahorrador/features/ledger/presentation/movements_screen.dart';
import 'package:el_ahorrador/features/ledger/presentation/period_scope.dart';
import 'package:el_ahorrador/features/settings/presentation/budgets_screen.dart';
import 'package:el_ahorrador/features/settings/presentation/settings_screen.dart';
import 'package:el_ahorrador/features/stats/presentation/stats_screen.dart';

/// Root of the interface (design handoff v3 in `design/`).
class AppHome extends StatefulWidget {
  const AppHome({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  late final _repository = widget.dependencies.ledger;
  late final _preferences = widget.dependencies.preferences;
  final _shell = ShellController();
  final _period = PeriodController();
  final _recent = RecentEntries();
  final _statsCategory = ValueNotifier<String?>(null);

  /// Created by the app, so shares that arrive before the interface is
  /// ready are not lost.
  late final CaptureController _capture = widget.dependencies.capture;
  late final Stream<int> _inboxCount = _capture.service.watchInbox().map(
    (items) => items.length,
  );

  /// Context below the ledger scope, for sheets opened by captures.
  BuildContext? _shellContext;
  bool _captureSheetOpen = false;

  /// The capture sheet was closed while images were still being read.
  bool _captureInBackground = false;

  static const _movements = 0;
  static const _stats = 1;

  @override
  void initState() {
    super.initState();
    _capture.addListener(_onCapture);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onCapture());
  }

  void _onCapture() {
    for (final id in _capture.takeRegistered()) {
      _recent.add(id);
    }
    final context = _shellContext;
    if (context == null || !context.mounted) return;
    final job = _capture.job;
    if (_capture.visible && !_captureSheetOpen) {
      _captureSheetOpen = true;
      _captureInBackground = false;
      _shell.select(_movements);
      showPaperSheet<void>(
        context,
        builder: (_) => CaptureSheet(
          controller: _capture,
          onUndo: (ids) => _undoCapture(context, ids),
          onOpenInbox: () => _openInbox(context),
          onOpenMovement: (id) => _openMovementById(context, id),
        ),
      ).whenComplete(() {
        _captureSheetOpen = false;
        if (_capture.job?.finished ?? true) {
          _capture.close();
        } else {
          _captureInBackground = true;
          _capture.hide();
        }
      });
    } else if (_captureInBackground && job != null && job.finished) {
      _captureInBackground = false;
      final ids = job.registeredIds;
      showUndoToast(
        context,
        job.single ? _singleToast(job) : job.summary,
        onUndo: ids.isEmpty ? null : () => _undoCapture(context, ids),
      );
      _capture.close();
    }
  }

  static String _singleToast(CaptureJob job) {
    final o = job.items.single.outcome!;
    return switch (o.status) {
      CaptureStatus.registered => 'Registrado · ${o.draft!.note}',
      CaptureStatus.review => 'Enviado a Por revisar',
      CaptureStatus.duplicate => 'Ya estaba registrado',
      CaptureStatus.notReceipt => 'No es un comprobante',
      CaptureStatus.failed => 'No se pudo leer la imagen',
    };
  }

  Future<void> _undoCapture(BuildContext context, List<String> ids) async {
    for (final id in ids) {
      _recent.remove(id);
      await _repository.deleteById(id);
    }
    if (context.mounted) showUndoToast(context, 'Registro deshecho');
  }

  void _openMovementById(BuildContext context, String id) {
    final movement = LedgerScope.of(
      context,
    ).movements.where((m) => m.id == id).firstOrNull;
    if (movement != null) _openMovement(context, movement);
  }

  void _openInbox(BuildContext context) => _push(
    context,
    (_) => InboxScreen(service: _capture.service, onApproved: _recent.add),
  );

  void _openRules(BuildContext context) => _push(
    context,
    (_) => RulesScreen(
      store: widget.dependencies.captureRules,
      accounts: [for (final a in LedgerScope.of(context).accounts) a.name],
    ),
  );

  @override
  void dispose() {
    _capture.removeListener(_onCapture);
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
            final restore = await _repository.delete(m);
            if (!context.mounted) return;
            showUndoToast(context, 'Movimiento eliminado', onUndo: restore);
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
          builder: (context) {
            _shellContext = context;
            return AppShell(
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
                    inboxCount: _inboxCount,
                    onOpenInbox: () => _openInbox(context),
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
                    onShowBudget: () => _push(
                      context,
                      (_) => BudgetsScreen(db: widget.dependencies.database),
                    ),
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
                      (_) => AccountSettingsScreen(
                        db: widget.dependencies.database,
                      ),
                    ),
                    onAdd: () => _push(
                      context,
                      (_) => AddAccountScreen(db: widget.dependencies.database),
                    ),
                  ),
                ),
                ShellDestination(
                  icon: DesignIcons.settings,
                  label: 'Ajustes',
                  builder: (context) => SettingsScreen(
                    db: widget.dependencies.database,
                    onOpenInbox: () => _openInbox(context),
                    onOpenRules: () => _openRules(context),
                  ),
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
            );
          },
        ),
      ),
    ),
  );
}
