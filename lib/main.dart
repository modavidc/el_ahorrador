import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_handler/share_handler.dart';

import 'core/category_service.dart';
import 'core/observability.dart';
import 'core/ocr_engine.dart';
import 'data/app_database.dart';
import 'data/daos.dart';
import 'data/historical_import.dart';
import 'features/capture/capture_controller.dart';
import 'features/capture/capture_service.dart';
import 'features/ledger/demo_seed.dart';
import 'features/ledger/demo_seed_v3.dart';
import 'security/app_lock_gate.dart';
import 'security/app_lock_settings.dart';
import 'theme/design_tokens.dart';
import 'ui/app_home.dart';

void _debugLog(Object? message) {
  if (kDebugMode) debugPrint(message?.toString());
}

Future<void> main() async {
  final startTime = DateTime.now();
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      AppObservability.error(
        'flutter_framework_failed',
        details.exception,
        details.stack ?? StackTrace.current,
      ),
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(AppObservability.error('platform_dispatch_failed', error, stack));
    return true;
  };
  final appLockSettings = await AppLockSettings.load(
    const SecureAppLockPreferenceStore(),
  );
  await AppObservability.run(MisGastosApp(appLockSettings: appLockSettings));
  AppObservability.metric(
    'startup_duration',
    DateTime.now().difference(startTime).inMilliseconds,
  );
}

class MisGastosApp extends StatefulWidget {
  const MisGastosApp({super.key, this.appLockSettings});

  /// Fingerprint lock preference, loaded before the first frame so a locked
  /// app never shows financial data. Defaults to disabled.
  final AppLockSettings? appLockSettings;

  @override
  State<MisGastosApp> createState() => _MisGastosAppState();
}

class _MisGastosAppState extends State<MisGastosApp> {
  final db = AppDatabase();
  late final AppLockSettings _appLock =
      widget.appLockSettings ?? AppLockSettings.disabled();
  // Only a lock that was already on at startup asks for authentication right
  // away; turning it on from Ajustes already required authenticating.
  late bool _lockedAtStartup = _appLock.enabled;
  final _ocr = MlKitEngine();

  /// Reads shared images; created here so a share that opens the app is
  /// queued before the interface exists.
  late final _capture = CaptureController(CaptureService(db: db, ocr: _ocr));
  StreamSubscription<SharedMedia>? _sub;

  @override
  void initState() {
    super.initState();
    _appLock.addListener(() => _lockedAtStartup = false);
    // Defer startup work so the first frame is not blocked.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final startTime = DateTime.now();
    try {
      await Future.wait([_initServices(), _initShareHandler()]);
    } catch (e) {
      _debugLog('❌ [STARTUP] Bootstrap error: $e');
    }
    _debugLog(
      '🚀 [STARTUP] Bootstrap completed in '
      '${DateTime.now().difference(startTime).inMilliseconds}ms',
    );
  }

  Future<void> _initServices() async {
    CategoryService().initialize(db);

    const importHistoricalCsv = bool.fromEnvironment(
      'IMPORT_HISTORICAL_CSV',
      defaultValue: false,
    );
    if (kDebugMode && importHistoricalCsv) {
      await runHistoricalImport(db, _debugLog);
    }
    // Prototype data for visual checks: --dart-define=DEMO_DATA=true.
    if (kDebugMode &&
        DemoSeed.enabled &&
        (await db.select(db.expenses).get()).isEmpty) {
      await DemoSeedV3.load(db);
    }

    final interruptedCaptures = await db.failInterruptedCaptures();
    if (interruptedCaptures > 0) {
      _debugLog(
        '⚠️ [STARTUP] Recovered $interruptedCaptures interrupted capture(s)',
      );
    }
  }

  Future<void> _initShareHandler() async {
    try {
      final share = ShareHandlerPlatform.instance;
      _sub = share.sharedMediaStream.listen(_handleShare);
      final initial = await share.getInitialSharedMedia();
      if (initial != null && mounted) unawaited(_handleShare(initial));
    } catch (e) {
      _debugLog('❌ [STARTUP] Share handler error: $e');
    }
  }

  /// "Compartir" from Yape, a bank or the gallery: one or several images.
  Future<void> _handleShare(SharedMedia media) async {
    final paths = [
      for (final a in media.attachments ?? const <SharedAttachment?>[])
        if (a != null && a.type == SharedAttachmentType.image) a.path,
    ];
    if (paths.isEmpty) return;
    AppObservability.metric('capture_share_images', paths.length);
    await _capture.start(paths);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _capture.dispose();
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (context, child) => AppLockScope(
      settings: _appLock,
      child: ValueListenableBuilder<bool>(
        valueListenable: _appLock,
        builder: (context, enabled, _) => enabled
            ? AppLockGate(startUnlocked: !_lockedAtStartup, child: child!)
            : child!,
      ),
    ),
    theme: buildDesignTheme(),
    // The v3 design is light only.
    themeMode: ThemeMode.light,
    home: AppHome(db: db, capture: _capture),
  );
}
