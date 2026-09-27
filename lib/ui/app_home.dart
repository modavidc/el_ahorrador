import 'package:flutter/material.dart';

import '../core/ocr_engine.dart';
import '../data/app_database.dart';
import '../features/capture/capture_controller.dart';
import '../features/capture/capture_rules.dart';
import '../features/capture/capture_service.dart';
import '../features/ledger/ledger.dart';
import '../features/settings/app_preferences.dart';
import '../screens/account_settings_screen.dart';
import '../screens/add_account_screen.dart';
import '../theme/design_tokens.dart';
import 'accounts/accounts_screen.dart';
import 'capture/capture_sheet.dart';
import 'capture/inbox_screen.dart';
import 'capture/rules_screen.dart';
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
  const AppHome({super.key, required this.db, this.capture});

  final AppDatabase db;

  /// Receives shared images; the app creates it so shares that arrive
  /// before the interface is ready are not lost.
  final CaptureController? capture;

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
  late final CaptureController _capture =
      widget.capture ??
      CaptureController(CaptureService(db: widget.db, ocr: MlKitEngine()));
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
      store: CaptureRuleStore(widget.db),
      accounts: [for (final a in LedgerScope.of(context).accounts) a.name],
    ),
  );

  @override
  void dispose() {
    _capture.removeListener(_onCapture);
    if (widget.capture == null) _capture.dispose();
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
                  builder: (context) => SettingsScreen(
                    db: widget.db,
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
