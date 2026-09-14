import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_handler/share_handler.dart';
import 'package:uuid/uuid.dart';
import 'core/file_store.dart';
import 'core/ocr_engine.dart';
import 'core/parser.dart';
import 'core/fast_parser.dart';
import 'core/capture_validator.dart';
import 'core/category_service.dart';
import 'core/time_tracker.dart';
import 'core/observability.dart';
import 'features/capture/application/bounded_serial_queue.dart';
import 'features/capture/application/attachment_batch_processor.dart';
import 'data/app_database.dart';
import 'data/daos.dart';
import 'data/historical_import.dart';
import 'screens/home_screen.dart';
import 'widgets/expense_edit_dialog.dart';
import 'widgets/processing_animation.dart';
import 'widgets/immediate_loading_overlay.dart';
import 'widgets/loading_dialog_tracker.dart';
import 'security/app_lock_gate.dart';
import 'config/security_config.dart';

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
  await AppObservability.run(const MisGastosApp());
  AppObservability.metric(
    'startup_duration',
    DateTime.now().difference(startTime).inMilliseconds,
  );
}

class MisGastosApp extends StatefulWidget {
  const MisGastosApp({super.key});

  @override
  State<MisGastosApp> createState() => _MisGastosAppState();
}

class _MisGastosAppState extends State<MisGastosApp> {
  final db = AppDatabase();
  final _uuid = const Uuid();
  MlKitEngine? _ocr; // OCR engine (lazy init)
  StreamSubscription<SharedMedia>? _sub;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final _shareQueue = BoundedSerialQueue<SharedMedia, void>(maxPending: 10);
  bool _isInitialized = false;
  OverlayEntry? _spinnerEntry;
  String _spinnerMessage = 'Procesando captura...';
  final _loadingDialog = LoadingDialogTracker();

  @override
  void initState() {
    super.initState();
    _debugLog('🚀 [STARTUP] initState() called');

    // ✅ OPTIMIZACIÓN: Diferir todo al siguiente frame para no bloquear el primer render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _debugLog('🚀 [STARTUP] Post-frame callback executing...');
      _bootstrap();
    });
  }

  /// Bootstrap asíncrono que no bloquea el primer frame
  Future<void> _bootstrap() async {
    final startTime = DateTime.now();
    _debugLog('🚀 [STARTUP] Bootstrap started');

    try {
      // Inicializar servicios en paralelo (sin bloquear UI)
      await Future.wait([_initServices(), _initShareHandler()]);

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      _debugLog('🚀 [STARTUP] Bootstrap completed in ${duration}ms');

      // Marcar como inicializado
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      _debugLog('❌ [STARTUP] Bootstrap error: $e');
      // Aún así marcar como inicializado para mostrar la app
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _initServices() async {
    _debugLog('🚀 [STARTUP] Initializing services...');
    final start = DateTime.now();

    // Inicializar el servicio de categorías (sincrónico, rápido)
    CategoryService().initialize(db);

    const importHistoricalCsv = bool.fromEnvironment(
      'IMPORT_HISTORICAL_CSV',
      defaultValue: false,
    );
    if (kDebugMode && importHistoricalCsv) {
      await runHistoricalImport(db, _debugLog);
    }

    final interruptedCaptures = await db.failInterruptedCaptures();
    if (interruptedCaptures > 0) {
      _debugLog(
        '⚠️ [STARTUP] Recovered $interruptedCaptures interrupted OCR capture(s)',
      );
    }

    final duration = DateTime.now().difference(start).inMilliseconds;
    _debugLog('🚀 [STARTUP] Services initialized in ${duration}ms');
  }

  /// ✅ OPTIMIZACIÓN: Share handler perezoso - no bloquea el render
  Future<void> _initShareHandler() async {
    _debugLog('🚀 [STARTUP] Initializing share handler...');
    final start = DateTime.now();

    try {
      final share = ShareHandlerPlatform.instance;

      // Primero suscribirse al stream (no bloquea)
      _sub = share.sharedMediaStream.listen(_handleShare);

      // Luego obtener el intent inicial (sin bloquear)
      final initial = await share.getInitialSharedMedia();
      if (initial != null && mounted) {
        // No esperar, procesar en background
        unawaited(_handleShare(initial));
      }

      final duration = DateTime.now().difference(start).inMilliseconds;
      _debugLog('🚀 [STARTUP] Share handler initialized in ${duration}ms');
    } catch (e) {
      _debugLog('❌ [STARTUP] Share handler error: $e');
    }
  }

  Future<void> _handleShare(SharedMedia media) async {
    try {
      await _shareQueue.enqueue(media, _processSharedMedia);
    } on QueueFullException catch (error) {
      _debugLog('Share rejected explicitly: $error');
    }
  }

  Future<void> _processSharedMedia(SharedMedia media) async {
    // Acknowledge the Android share as soon as Flutter has a Navigator. Startup
    // maintenance may continue behind this UI; the user should never interpret
    // an incoming capture as a fresh application initialization.
    await _waitForNavigatorUi();
    _showSpinnerOverlay(message: 'Captura recibida');

    // Database/share services still need to be ready before OCR can begin.
    await _waitForShareUi();

    // ⏱️ INICIO DEL CRONÓMETRO TOTAL
    final shareStartTime = DateTime.now();
    _debugLog('⏱️  [TIMER] ========================================');
    _debugLog(
      '⏱️  [TIMER] SHARE STARTED at ${shareStartTime.toIso8601String()}',
    );
    _debugLog('⏱️  [TIMER] ========================================');

    // Iniciar tracking de tiempo
    TimeTracker.startShareTracking();

    _debugLog('📤 [SHARE] Received shared media');

    final attachments = media.attachments;
    if (attachments != null) {
      await const AttachmentBatchProcessor<SharedAttachment>().process(
        attachments: attachments,
        isEligible: (attachment) =>
            attachment.type == SharedAttachmentType.image,
        processAttachment: (attachment) async {
          _debugLog('📤 [SHARE] Processing image attachment');
          await _processSharedImage(attachment, shareStartTime);
        },
      );
    }
  }

  /// ✅ OPTIMIZACIÓN: Procesamiento asíncrono optimizado
  Future<void> _waitForShareUi() async {
    while (mounted &&
        (!_isInitialized || _navigatorKey.currentState?.overlay == null)) {
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) {
      throw StateError('App disposed before shared media could be processed.');
    }
  }

  Future<void> _waitForNavigatorUi() async {
    while (mounted && _navigatorKey.currentState?.overlay == null) {
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) {
      throw StateError('App disposed before shared media could be displayed.');
    }
  }

  Future<void> _processSharedImage(
    SharedAttachment att,
    DateTime shareStartTime,
  ) async {
    String? captureId;
    try {
      // Marcar inicio del procesamiento
      TimeTracker.startProcessing();

      // ✅ Mostrar UI de carga
      _showSpinnerOverlay(message: 'Procesando captura...');

      // ⏱️ Tiempo desde que se compartió hasta aquí
      final uiDelay = DateTime.now().difference(shareStartTime).inMilliseconds;
      _debugLog('⏱️  [TIMER] UI shown after ${uiDelay}ms from share click');

      // Persist the encrypted durable copy and OCR the incoming file in
      // parallel. The shared path remains available during this callback.
      _debugLog('📁 [PROCESS] Persisting file...');
      final persistStart = DateTime.now();
      final persistFuture = FileStore.persistIncomingFile(att.path);

      _debugLog('🔍 [PROCESS] Running OCR...');
      final ocrStart = DateTime.now();
      _ocr ??= MlKitEngine();
      final ocrFuture = _ocr!.run(att.path);

      final localPath = await persistFuture;
      final persistDuration = DateTime.now()
          .difference(persistStart)
          .inMilliseconds;
      _debugLog('📁 [PROCESS] File persisted in ${persistDuration}ms');
      _debugLog(
        '⏱️  [TIMER] Elapsed: ${DateTime.now().difference(shareStartTime).inMilliseconds}ms',
      );

      // Generar ID y timestamp
      final id = _uuid.v4();
      captureId = id;
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      // ✅ PASO 2: Operaciones de base de datos en transacción (más rápido)
      _debugLog('💾 [PROCESS] Inserting capture in DB...');
      final dbStart = DateTime.now();
      await db.transaction(() async {
        await db.insertCapture(id: id, imagePath: localPath);
        await db.setProcessing(id);
      });
      final dbDuration = DateTime.now().difference(dbStart).inMilliseconds;
      _debugLog('💾 [PROCESS] DB operations completed in ${dbDuration}ms');
      _debugLog(
        '⏱️  [TIMER] Elapsed: ${DateTime.now().difference(shareStartTime).inMilliseconds}ms',
      );

      // OCR started alongside persistence; await the already-running work.
      final res = await ocrFuture;
      final ocrDuration = DateTime.now().difference(ocrStart).inMilliseconds;
      _debugLog('🔍 [PROCESS] OCR completed in ${ocrDuration}ms');
      _debugLog(
        '⏱️  [TIMER] Elapsed: ${DateTime.now().difference(shareStartTime).inMilliseconds}ms',
      );

      final confidence = res.meta['confidence']?.toString();

      // Validar tipo de captura
      final captureType = CaptureValidator.validateCapture(res.text);

      // Guardar resultado OCR (en paralelo con validación)
      final ocrSaveFuture = db.setOcrResult(
        id: id,
        text: res.text,
        confidence: confidence,
      );

      // Solo procesar si es una captura válida
      if (CaptureValidator.isProcessable(captureType)) {
        // ✅ PASO 4: Parse (asíncrono)
        _debugLog('📝 [PROCESS] Parsing...');
        final parseStart = DateTime.now();
        final parsed = await FastParser.fromOcr(
          res.text,
          fallbackDateEpoch: currentTime,
          ocrConfidence: confidence,
        );
        final parseDuration = DateTime.now()
            .difference(parseStart)
            .inMilliseconds;
        _debugLog('📝 [PROCESS] Parsing completed in ${parseDuration}ms');
        _debugLog(
          '⏱️  [TIMER] Elapsed: ${DateTime.now().difference(shareStartTime).inMilliseconds}ms',
        );

        // Solo registrar si tiene monto válido
        if (parsed.amountCents > 0) {
          // Esperar a que se complete el guardado del OCR
          await ocrSaveFuture;

          // Insertar gasto
          _debugLog('💰 [PROCESS] Inserting expense...');
          final dbInsertStart = DateTime.now();
          await db.insertExpenseFromParser(
            id: _uuid.v4(),
            captureId: id,
            dateEpochMs: parsed.dateEpochMs,
            // ParsedExpense exposes the detected magnitude. Daily stores
            // expenses as negative values and income as positive values.
            amountCents: -parsed.amountCents.abs(),
            currency: parsed.currency,
            categoryId: parsed.category,
            subcategoryId: parsed.subcategory,
            account: parsed.account,
            vendor: parsed.vendor,
            description: parsed.description,
            notes: parsed.notes,
            sourceApp: parsed.sourceApp,
          );
          final dbInsertDuration = DateTime.now()
              .difference(dbInsertStart)
              .inMilliseconds;
          _debugLog('💰 [PROCESS] Expense inserted in ${dbInsertDuration}ms');

          // ⏱️ TIEMPO TOTAL
          final totalTime = DateTime.now()
              .difference(shareStartTime)
              .inMilliseconds;
          _debugLog('⏱️  [TIMER] ========================================');
          _debugLog(
            '⏱️  [TIMER] TOTAL TIME: ${totalTime}ms (${(totalTime / 1000).toStringAsFixed(2)}s)',
          );
          _debugLog('⏱️  [TIMER] Breakdown:');
          _debugLog('⏱️  [TIMER]   UI delay: ${uiDelay}ms');
          _debugLog('⏱️  [TIMER]   File persist: ${persistDuration}ms');
          _debugLog('⏱️  [TIMER]   DB insert: ${dbDuration}ms');
          _debugLog('⏱️  [TIMER]   OCR: ${ocrDuration}ms');
          _debugLog('⏱️  [TIMER]   Parse: ${parseDuration}ms');
          _debugLog('⏱️  [TIMER]   Save expense: ${dbInsertDuration}ms');
          _debugLog('⏱️  [TIMER] ========================================');

          // Marcar fin del procesamiento
          TimeTracker.endProcessing();

          // Ocultar spinner y mostrar animación de éxito
          _hideSpinnerOverlay();
          _showSuccessAnimation(parsed);
        } else {
          // Si no hay monto válido, marcar fin del procesamiento
          TimeTracker.endProcessing();
          _hideSpinnerOverlay();
          _showErrorAnimation("No se pudo detectar un monto válido");
        }
      } else {
        // Si no es procesable, marcar fin del procesamiento
        TimeTracker.endProcessing();
        _hideSpinnerOverlay();
        _showErrorAnimation("Tipo de captura no reconocido");
      }
    } catch (e) {
      _debugLog('❌ [PROCESS] Error: $e');
      if (captureId != null) {
        try {
          await db.setFailed(captureId);
        } catch (statusError) {
          _debugLog(
            '❌ [PROCESS] Could not mark capture as failed: $statusError',
          );
        }
      }
      TimeTracker.endProcessing();
      _hideSpinnerOverlay();
      _showErrorAnimation(
        'No pudimos procesar la captura. Inténtalo nuevamente o regístrala manualmente.',
      );
    }
  }

  /// ✅ Mostrar overlay liviano para procesamiento (no modal, no bloquea)
  void _showSpinnerOverlay({required String message}) {
    _spinnerMessage = message;
    final context = _navigatorKey.currentContext;
    if (_spinnerEntry != null) {
      _spinnerEntry!.markNeedsBuild();
      return;
    }
    if (context != null) {
      try {
        // Intentar obtener el overlay - puede no estar listo aún
        final overlay = Overlay.of(context, rootOverlay: true);
        _spinnerEntry = OverlayEntry(
          builder: (_) => ImmediateLoadingOverlay(message: _spinnerMessage),
        );
        overlay.insert(_spinnerEntry!);
        _debugLog('🎨 [UI] Spinner overlay shown');
      } catch (e) {
        _debugLog('⚠️  [UI] Overlay not ready yet, showing dialog instead');
        // Fallback: usar un diálogo simple si el overlay no está listo
        _showSimpleLoadingDialog();
      }
    }
  }

  /// Fallback: diálogo simple si el overlay no está disponible
  void _showSimpleLoadingDialog() {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      _loadingDialog.show(
        () => showDialog<void>(
          context: context,
          useRootNavigator: true,
          barrierDismissible: false,
          builder: (context) => PopScope(
            canPop: false,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text(
                      'Procesando captura...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  /// ✅ Ocultar overlay de procesamiento
  void _hideSpinnerOverlay() {
    final context = _navigatorKey.currentContext;

    if (_spinnerEntry != null) {
      // Si usamos overlay, removerlo
      _spinnerEntry?.remove();
      _spinnerEntry = null;
      _debugLog('🎨 [UI] Spinner overlay hidden');
    } else if (context != null) {
      // Si usamos diálogo fallback, cerrarlo
      try {
        if (_loadingDialog.dismiss(context)) {
          _debugLog('🎨 [UI] Loading dialog closed');
        }
      } catch (e) {
        // Si no hay diálogo, no pasa nada
      }
    }
  }

  /// ✅ Mostrar animación de éxito (sin pop, el overlay ya fue removido)
  void _showSuccessAnimation(ParsedExpense expense) {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      final manualSaved = TimeTracker.getTimeSavedVsManual();
      final delayedSaved = TimeTracker.getTimeSavedVsDelayed();
      final totalTime = TimeTracker.getTotalProcessingTime();
      final totalTimeStr = totalTime != null
          ? TimeTracker.formatDuration(totalTime)
          : 'N/A';

      _debugLog('✅ [UI] Showing success animation ($totalTimeStr)');

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => SuccessAnimation(
          title: '¡Registrado!',
          message:
              'Pago de ${expense.sourceApp} registrado\n'
              'Monto: S/ ${(expense.amountCents / 100).toStringAsFixed(2)}',
          manualTimeSaved: manualSaved == null
              ? null
              : TimeTracker.formatDuration(manualSaved),
          delayedTimeSaved: delayedSaved == null
              ? null
              : TimeTracker.formatDuration(delayedSaved),
          onClose: () {
            Navigator.of(context).pop();
            // Mostrar snackbar con opción de editar
            _showEditSnackBar(expense);
          },
        ),
      );
    }
  }

  /// ✅ Mostrar mensaje de error (sin pop, el overlay ya fue removido)
  void _showErrorAnimation(String message) {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      _debugLog('❌ [UI] Showing error message: $message');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(message, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showEditSnackBar(ParsedExpense expense) {
    // Mostrar snackbar con opción de editar usando el navigator key
    final context = _navigatorKey.currentContext;
    if (context != null) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '✅ Transacción registrada: S/ ${(expense.amountCents / 100).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Editar',
            textColor: Colors.white,
            onPressed: () => _showEditDialog(expense),
          ),
        ),
      );
    }
  }

  void _showEditDialog(ParsedExpense expense) {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        builder: (dialogContext) => ExpenseEditDialog(
          expense: expense,
          onSave: (updatedExpense) async {
            // Actualizar el gasto en la base de datos
            await db.insertExpenseFromParser(
              id: const Uuid().v4(),
              captureId: null, // No asociar con captura específica
              dateEpochMs: updatedExpense.dateEpochMs,
              amountCents: -updatedExpense.amountCents.abs(),
              currency: updatedExpense.currency,
              categoryId: updatedExpense.category,
              subcategoryId: updatedExpense.subcategory,
              account: updatedExpense.account,
              vendor: updatedExpense.vendor,
              description: updatedExpense.description,
              notes: updatedExpense.notes,
              sourceApp: updatedExpense.sourceApp,
            );

            // Mostrar confirmación usando el contexto del diálogo
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(
                  content: Text(
                    'Gasto actualizado: S/ ${updatedExpense.amountCents / 100} - ${updatedExpense.vendor}',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ocr?.dispose(); // Limpiar OCR engine
    _hideSpinnerOverlay(); // Limpiar overlay si existe
    TimeTracker.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _debugLog('🚀 [STARTUP] build() called, _isInitialized=$_isInitialized');
    return MaterialApp(
      navigatorKey: _navigatorKey,
      builder: (context, child) =>
          SecurityConfig.enableAppLock ? AppLockGate(child: child!) : child!,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system, // Sigue el tema del sistema
      // The home remains usable while optional startup maintenance finishes.
      // Incoming shares are already queued until bootstrap is ready.
      home: HomeScreen(db: db),
    );
  }
}
