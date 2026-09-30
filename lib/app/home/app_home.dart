import 'package:flutter/material.dart';

import 'package:el_ahorrador/app/dependencies.dart';
import 'package:el_ahorrador/app/home/app_shell.dart';
import 'package:el_ahorrador/design_system/kit.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/features/accounts/presentation/accounts_screen.dart';
import 'package:el_ahorrador/features/capture/application/capture_controller.dart';
import 'package:el_ahorrador/features/capture/domain/capture_models.dart';
import 'package:el_ahorrador/features/capture/presentation/capture_hub_screen.dart';
import 'package:el_ahorrador/features/capture/presentation/capture_sheet.dart';
import 'package:el_ahorrador/features/capture/presentation/inbox_screen.dart';
import 'package:el_ahorrador/features/capture/presentation/rules_screen.dart';
import 'package:el_ahorrador/features/capture/presentation/scan_receipt_screen.dart';
import 'package:el_ahorrador/features/coach/presentation/coach_model_screen.dart';
import 'package:el_ahorrador/features/coach/presentation/coach_screen.dart';
import 'package:el_ahorrador/features/import/presentation/debug_import_screen.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/ledger/domain/ledger_repository.dart';
import 'package:el_ahorrador/features/ledger/presentation/dictate_sheet.dart';
import 'package:el_ahorrador/features/ledger/presentation/entry_sheet.dart';
import 'package:el_ahorrador/features/ledger/presentation/ledger_scope.dart';
import 'package:el_ahorrador/features/ledger/presentation/movements_screen.dart';
import 'package:el_ahorrador/features/onboarding/presentation/onboarding_screen.dart';
import 'package:el_ahorrador/features/settings/domain/app_preferences.dart';
import 'package:el_ahorrador/features/settings/presentation/settings_screen.dart';
import 'package:el_ahorrador/features/stats/presentation/stats_screen.dart';

/// Root of the interface (design handoff v3 in `design/`).
class AppHome extends StatefulWidget {
  const AppHome({
    super.key,
    required this.dependencies,
    this.version = '',
    this.welcomeOnFirstRun = false,
  });

  final AppDependencies dependencies;
  final String version;

  /// Shows the onboarding until the user finishes or skips it once.
  final bool welcomeOnFirstRun;

  @override
  State<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  late final _repository = widget.dependencies.ledger;
  late final _preferences = widget.dependencies.preferences;
  final _shell = ShellController();
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

  /// The onboarding is on screen; null while the flag is read.
  bool? _welcome;
  int _welcomeBudget = LedgerRepository.defaultMonthlyBudgetCents;

  static const _movements = 0;
  static const _coach = 2;
  static const _accounts = 3;

  @override
  void initState() {
    super.initState();
    _capture.addListener(_onCapture);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onCapture());
    if (widget.welcomeOnFirstRun) {
      _preferences.get(Preference.onboardingDone).then((done) async {
        if (done) {
          if (mounted) setState(() => _welcome = false);
        } else {
          await _openWelcome();
        }
      });
    } else {
      _welcome = false;
    }
  }

  /// Onboarding, on the first run and from Ajustes → Ver bienvenida.
  Future<void> _openWelcome() async {
    final budget = await _repository.watchMonthlyBudget().first;
    if (!mounted) return;
    setState(() {
      _welcomeBudget = budget;
      _welcome = true;
    });
  }

  Future<void> _finishWelcome(OnboardingResult result) async {
    final budget = result.budgetCents;
    if (budget != null) await _repository.setMonthlyBudget(budget);
    await _preferences.set(Preference.onboardingDone, true);
    if (!mounted) return;
    setState(() => _welcome = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _shellContext;
      if (result.activateCapture && context != null && context.mounted) {
        _startBackgroundCapture(context);
      }
      _onCapture();
    });
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
    _registered(context, result.id, result.message);
  }

  void _openScan(BuildContext context) => _push(
    context,
    (_) => ScanReceiptScreen(
      service: _capture.service,
      camera: widget.dependencies.camera,
      accounts: [for (final a in LedgerScope.of(context).accounts) a.name],
      onSaved: (id, message) => _registered(context, id, message),
    ),
  );

  Future<void> _openDictate(BuildContext context) async {
    final result = await showDictateSheet(
      context,
      speech: widget.dependencies.speech,
      repository: _repository,
      accounts: LedgerScope.of(context).accounts,
      letters: LedgerScope.of(context).letters,
    );
    if (result != null && context.mounted) {
      _registered(context, result.id, result.message);
    }
  }

  /// A movement registered from a sheet or screen: pill, tab and toast.
  void _registered(BuildContext context, String id, String message) {
    _recent.add(id);
    _shell.select(_movements);
    showUndoToast(context, message, onUndo: () => _undoById(context, id));
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

  void _pushScoped(BuildContext context, Widget page) =>
      _push(context, (_) => LedgerScope.forward(context, child: page));

  void _openBudgets(BuildContext context) => _pushScoped(
    context,
    BudgetsScreen(ledger: _repository, preferences: _preferences),
  );

  void _openCategory(BuildContext context, Category category) => _pushScoped(
    context,
    CategoryDetailScreen(
      category: category,
      onOpenMovement: (m) => _openMovement(context, m),
    ),
  );

  void _openPermissions(BuildContext context) => _push(
    context,
    (_) => PermissionsScreen(capture: widget.dependencies.backgroundCapture),
  );

  void _openCaptureHub(BuildContext context) => _push(
    context,
    (_) => CaptureHubScreen(
      capture: widget.dependencies.backgroundCapture,
      inboxCount: _inboxCount,
      onTryShare: () => _openTryShare(context),
      onOpenInbox: () => _openInbox(context),
      onOpenRules: () => _openRules(context),
      onOpenPermissions: () => _openPermissions(context),
    ),
  );

  void _openCoachHistory(BuildContext context) => _push(
    context,
    (_) => ConversationsScreen(
      controller: widget.dependencies.coach,
      onOpen: (conversation) {
        widget.dependencies.coach.open(conversation);
        Navigator.of(context).popUntil((route) => route.isFirst);
        _shell.select(_coach);
      },
    ),
  );

  /// Captura en segundo plano from the + menu: the permissions it needs, or
  /// how to share where the platform cannot capture.
  Future<void> _startBackgroundCapture(BuildContext context) async {
    final state = await widget.dependencies.backgroundCapture.watch().first;
    if (!context.mounted) return;
    if (!state.supported) return _openTryShare(context);
    if (state.ready) {
      await widget.dependencies.backgroundCapture.setEnabled(true);
      if (context.mounted) {
        showUndoToast(
          context,
          'Captura activa: toma una captura de pantalla de tu pago',
        );
      }
      return;
    }
    await showPaperSheet<void>(
      context,
      builder: (sheet) => MissingPermissionsSheet(
        missing: state.missingRequired,
        onOpenPermissions: () {
          Navigator.of(sheet).pop();
          _openPermissions(context);
        },
      ),
    );
  }

  SettingsLinks _settingsLinks(BuildContext context) => SettingsLinks(
    openCapture: () => _openCaptureHub(context),
    openStreak: () => _openStreak(context),
    openBudgets: () => _openBudgets(context),
    openAccounts: () => _shell.select(_accounts),
    openCategory: (c) => _openCategory(context, c),
    openCoachHistory: () => _openCoachHistory(context),
    showWelcome: _openWelcome,
    coachModel: widget.dependencies.coachModel == null
        ? null
        : () => _push(
            context,
            (_) => CoachModelScreen(access: widget.dependencies.coachModel!),
          ),
    testReminder: () async {
      await widget.dependencies.reminders.test();
      if (context.mounted) showUndoToast(context, 'Recordatorio enviado');
    },
    runImport: widget.dependencies.runImport == null
        ? null
        : () => _push(
            context,
            (_) => DebugImportScreen(runImport: widget.dependencies.runImport!),
          ),
  );

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      _home(),
      if (_welcome != false)
        Positioned.fill(
          child: _welcome == null
              ? const ColoredBox(color: DesignColors.paper)
              : OnboardingScreen(
                  initialBudgetCents: _welcomeBudget,
                  onFinish: _finishWelcome,
                ),
        ),
    ],
  );

  Widget _home() => LedgerProvider(
    repository: _repository,
    child: RecentEntriesScope(
      entries: _recent,
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
                builder: (context) => StatsScreen(
                  ledger: _repository,
                  preferences: _preferences,
                  categoryRequest: _statsCategory,
                  onOpenMovement: (m) => _openMovement(context, m),
                ),
              ),
              ShellDestination(
                icon: DesignIcons.autoAwesome,
                label: 'Coach',
                builder: (_) => CoachScreen(
                  controller: widget.dependencies.coach,
                  preferences: _preferences,
                ),
              ),
              ShellDestination(
                icon: DesignIcons.accountBalanceWallet,
                label: 'Cuentas',
                showFab: true,
                builder: (_) =>
                    AccountsScreen(accounts: widget.dependencies.accounts),
              ),
              ShellDestination(
                icon: DesignIcons.settings,
                label: 'Ajustes',
                builder: (context) => SettingsScreen(
                  preferences: _preferences,
                  capture: widget.dependencies.backgroundCapture,
                  links: _settingsLinks(context),
                  version: widget.version,
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
                onSelected: () => _openScan(context),
              ),
              FabAction(
                label: 'Dictar',
                subtitle: 'Dilo en voz alta',
                icon: DesignIcons.mic,
                onSelected: () => _openDictate(context),
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
                subtitle: 'Detecta tus capturas de pantalla',
                icon: DesignIcons.screenshotMonitor,
                capture: true,
                onSelected: () => _startBackgroundCapture(context),
              ),
            ],
          );
        },
      ),
    ),
  );
}
