import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_handler/share_handler.dart';
import 'core/time_tracker.dart';
import 'core/app_lock.dart';
import 'core/file_store.dart';
import 'core/observability.dart';
import 'core/category_service.dart';
import 'data/app_database.dart';
import 'data/category_repository.dart';
import 'data/daos.dart';
import 'features/capture/application/attachment_batch_processor.dart';
import 'features/capture/application/serial_task_queue.dart';
import 'features/capture/shared_capture_runtime.dart';
import 'screens/home_screen.dart';
import 'widgets/expense_edit_dialog.dart';
import 'widgets/processing_animation.dart';
import 'widgets/immediate_loading_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppObservability.run(const MisGastosApp());
}

class MisGastosApp extends StatefulWidget {
  const MisGastosApp({super.key});

  @override
  State<MisGastosApp> createState() => _MisGastosAppState();
}

class _MisGastosAppState extends State<MisGastosApp> {
  final db = AppDatabase();
  late final CategoryService _categoryService;
  // SharedCaptureCoordinator is owned behind this production runtime facade.
  late final SharedCaptureRuntime _captureRuntime;
  final _attachmentBatchProcessor =
      const AttachmentBatchProcessor<SharedAttachment>();
  StreamSubscription<SharedMedia>? _sub;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final _shareQueue = SerialTaskQueue();
  bool _isInitialized = false;
  OverlayEntry? _spinnerEntry;
  DialogRoute<void>? _processingDialogRoute;

  @override
  void initState() {
    super.initState();
    _categoryService = CategoryService(CategoryRepository(db));
    _captureRuntime = SharedCaptureRuntime.create(db);
    AppObservability.info('app_init_state');

    // âœ… OPTIMIZACIÃ“N: Diferir todo al siguiente frame para no bloquear el primer render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppObservability.info('bootstrap_scheduled');
      _bootstrap();
    });
  }

  /// Bootstrap asÃ­ncrono que no bloquea el primer frame
  Future<void> _bootstrap() async {
    final startTime = DateTime.now();
    AppObservability.info('bootstrap_started');

    try {
      // Inicializar servicios en paralelo (sin bloquear UI)
      await Future.wait([_initServices(), _initShareHandler()]);

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      AppObservability.metric('bootstrap_duration', duration);

      // Marcar como inicializado
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (error, stackTrace) {
      unawaited(AppObservability.error('bootstrap_failed', error, stackTrace));
      // AÃºn asÃ­ marcar como inicializado para mostrar la app
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _initServices() async {
    AppObservability.info('services_initialization_started');
    final start = DateTime.now();

    await db.purgePendingCaptureDeletions(deleteFile: FileStore.securelyDelete);

    final duration = DateTime.now().difference(start).inMilliseconds;
    AppObservability.metric('services_initialization_duration', duration);
  }

  /// âœ… OPTIMIZACIÃ“N: Share handler perezoso - no bloquea el render
  Future<void> _initShareHandler() async {
    AppObservability.info('share_handler_initialization_started');
    final start = DateTime.now();

    try {
      final share = ShareHandlerPlatform.instance;

      // Primero suscribirse al stream (no bloquea)
      _sub = share.sharedMediaStream.listen(_handleShare);

      // Luego obtener el intent inicial (sin bloquear)
      final initial = await share.getInitialSharedMedia();
      if (initial != null && mounted) {
        // No esperar, procesar en background
        _handleShare(initial);
      }

      final duration = DateTime.now().difference(start).inMilliseconds;
      AppObservability.metric(
        'share_handler_initialization_duration',
        duration,
      );
    } catch (error, stackTrace) {
      unawaited(
        AppObservability.error('share_handler_failed', error, stackTrace),
      );
    }
  }

  void _handleShare(SharedMedia media) {
    // Serialize incoming shares so none is silently discarded while OCR runs.
    // _processShare already catches internally, but the queue itself must
    // not depend on that: it stays resilient even if a future ever escaped.
    unawaited(_shareQueue.add(() => _processShare(media)));
  }

  Future<void> _processShare(SharedMedia media) async {
    final shareStartTime = DateTime.now();
    AppObservability.info('share_processing_started');
    TimeTracker.startShareTracking();
    try {
      final attachments = media.attachments;
      if (attachments == null) return;
      final summary = await _attachmentBatchProcessor.process(
        attachments: attachments,
        isEligible: (attachment) =>
            attachment.type == SharedAttachmentType.image,
        processAttachment: (attachment) =>
            _processSharedImage(attachment, shareStartTime),
      );
      for (final failure
          in summary.results
              .whereType<AttachmentProcessingFailure<SharedAttachment>>()) {
        unawaited(
          AppObservability.error(
            'shared_attachment_processing_failed',
            failure.error,
            failure.stackTrace,
          ),
        );
      }
    } catch (error, stackTrace) {
      unawaited(
        AppObservability.error('share_processing_failed', error, stackTrace),
      );
      _showErrorAnimation(
        'No se pudo procesar la captura. Intenta nuevamente.',
      );
    }
  }

  Future<void> _processSharedImage(
    SharedAttachment attachment,
    DateTime shareStartTime,
  ) async {
    TimeTracker.startProcessing();
    AppObservability.metric(
      'share_ui_delay',
      DateTime.now().difference(shareStartTime).inMilliseconds,
    );
    final result = await _captureRuntime.process(
      attachment.path,
      fallbackDateEpoch: DateTime.now().millisecondsSinceEpoch,
    );
    TimeTracker.endProcessing();
    switch (result) {
      case CaptureSuccess(:final expenseId, :final expense):
        AppObservability.metric(
          'share_processing_duration',
          DateTime.now().difference(shareStartTime).inMilliseconds,
        );
        _showSuccessAnimation(expenseId, expense);
      case InvalidCapture():
        _showErrorAnimation('Tipo de captura no reconocido');
      case MissingAmount():
        _showErrorAnimation('No se pudo detectar un monto válido');
      case DuplicateCapture():
        _showErrorAnimation('Esta captura ya fue procesada');
      case CaptureBusy():
        AppObservability.warning('share_processing_already_active');
      case CaptureFailure(:final error, :final stackTrace, :final stage):
        unawaited(
          AppObservability.error(
            'share_processing_failed_at_${stage.name}',
            error,
            stackTrace,
          ),
        );
        _showErrorAnimation(
          'No se pudo procesar la captura. Intenta nuevamente.',
        );
    }
  }

  /// Mostrar overlay liviano para procesamiento.
  // Kept as a defensive fallback for platforms where MaterialApp's builder
  // cannot obtain an overlay during startup.
  // ignore: unused_element
  void _showSpinnerOverlay() {
    final context = _navigatorKey.currentContext;
    if (context != null && _spinnerEntry == null) {
      try {
        // Intentar obtener el overlay - puede no estar listo aÃºn
        final overlay = Overlay.of(context, rootOverlay: true);
        _spinnerEntry = OverlayEntry(
          builder: (_) =>
              const ImmediateLoadingOverlay(message: 'Procesando captura...'),
        );
        overlay.insert(_spinnerEntry!);
        AppObservability.info('processing_overlay_shown');
      } catch (error, stackTrace) {
        AppObservability.warning('processing_overlay_unavailable');
        unawaited(
          AppObservability.error(
            'processing_overlay_failed',
            error,
            stackTrace,
          ),
        );
        // Fallback: usar un diÃ¡logo simple si el overlay no estÃ¡ listo
        _showSimpleLoadingDialog();
      }
    }
  }

  /// Fallback: diÃ¡logo simple si el overlay no estÃ¡ disponible
  void _showSimpleLoadingDialog() {
    final navigator = _navigatorKey.currentState;
    if (navigator != null && _processingDialogRoute == null) {
      final route = DialogRoute<void>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (_) => PopScope(
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      _processingDialogRoute = route;
      unawaited(navigator.push(route));
    }
  }

  /// âœ… Ocultar overlay de procesamiento
  void _hideSpinnerOverlay() {
    if (_spinnerEntry != null) {
      // Si usamos overlay, removerlo
      _spinnerEntry?.remove();
      _spinnerEntry = null;
      AppObservability.info('processing_overlay_hidden');
    } else if (_processingDialogRoute case final route?) {
      _navigatorKey.currentState?.removeRoute(route);
      _processingDialogRoute = null;
      AppObservability.info('processing_dialog_closed');
    }
  }

  /// âœ… Mostrar animaciÃ³n de Ã©xito (sin pop, el overlay ya fue removido)
  void _showSuccessAnimation(String expenseId, ParsedExpense expense) {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      final timeSaved = TimeTracker.generateShortTimeSavedMessage();
      final totalTime = TimeTracker.getTotalProcessingTime();
      final totalTimeStr = totalTime != null
          ? TimeTracker.formatDuration(totalTime)
          : 'N/A';

      AppObservability.info('processing_success_presented');

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => SuccessAnimation(
          title: '¡Registrado!',
          message:
              'Transacción de ${expense.sourceApp} procesada en $totalTimeStr\n'
              'Monto: S/ ${(expense.amountCents / 100).toStringAsFixed(2)}',
          timeSaved: timeSaved,
          onClose: () {
            Navigator.of(context).pop();
            // Mostrar snackbar con opciÃ³n de editar
            _showEditSnackBar(expenseId, expense);
          },
        ),
      );
    }
  }

  /// âœ… Mostrar mensaje de error (sin pop, el overlay ya fue removido)
  void _showErrorAnimation(String message) {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      AppObservability.info('processing_error_presented');

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

  void _showEditSnackBar(String expenseId, ParsedExpense expense) {
    // Mostrar snackbar con opciÃ³n de editar usando el navigator key
    final context = _navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Transacción registrada: S/ ${(expense.amountCents / 100).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Editar',
            textColor: Colors.white,
            onPressed: () => _showEditDialog(expenseId, expense),
          ),
        ),
      );
    }
  }

  void _showEditDialog(String expenseId, ParsedExpense expense) {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        builder: (dialogContext) => ExpenseEditDialog(
          categoryService: _categoryService,
          expense: expense,
          onSave: (updatedExpense) async {
            // Actualizar el gasto en la base de datos
            await db.updateExpenseFromParser(
              id: expenseId,
              dateEpochMs: updatedExpense.dateEpochMs,
              amountCents: updatedExpense.amountCents,
              currency: updatedExpense.currency,
              categoryId: updatedExpense.category,
              subcategoryId: updatedExpense.subcategory,
              account: updatedExpense.account,
              vendor: updatedExpense.vendor,
              description: updatedExpense.description,
              notes: updatedExpense.notes,
            );

            // Mostrar confirmaciÃ³n usando el contexto del diÃ¡logo
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

  Widget _buildInstantLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade200,
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.savings, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              'El Ahorrador',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Inicializando...',
              style: TextStyle(fontSize: 16, color: Colors.blue.shade600),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    unawaited(_captureRuntime.dispose());
    unawaited(db.close());
    _hideSpinnerOverlay(); // Limpiar overlay si existe
    TimeTracker.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      builder: (context, child) => StreamBuilder<CaptureProcessingState>(
        stream: _captureRuntime.states,
        initialData: _captureRuntime.state,
        builder: (context, snapshot) => Stack(
          children: [
            if (child != null) child,
            if (snapshot.data is CaptureProcessing)
              const ImmediateLoadingOverlay(message: 'Procesando captura...'),
          ],
        ),
      ),
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
      home: AppLock(
        child: _isInitialized
            ? HomeScreen(db: db, categoryService: _categoryService)
            : _buildInstantLoadingScreen(),
      ),
    );
  }
}
