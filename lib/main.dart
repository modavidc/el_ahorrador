import 'dart:async';
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
import 'features/capture/application/bounded_serial_queue.dart';
import 'features/capture/application/attachment_batch_processor.dart';
import 'data/app_database.dart';
import 'data/daos.dart';
import 'screens/home_screen.dart';
import 'widgets/expense_edit_dialog.dart';
import 'widgets/processing_animation.dart';
import 'widgets/immediate_loading_overlay.dart';

void main() {
  final startTime = DateTime.now();
  print('🚀 [STARTUP] main() called at ${startTime.toIso8601String()}');

  WidgetsFlutterBinding.ensureInitialized();
  print(
    '🚀 [STARTUP] WidgetsFlutterBinding initialized (${DateTime.now().difference(startTime).inMilliseconds}ms)',
  );

  runApp(const MisGastosApp());
  print(
    '🚀 [STARTUP] runApp() called (${DateTime.now().difference(startTime).inMilliseconds}ms)',
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

  @override
  void initState() {
    super.initState();
    print('🚀 [STARTUP] initState() called');

    // ✅ OPTIMIZACIÓN: Diferir todo al siguiente frame para no bloquear el primer render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🚀 [STARTUP] Post-frame callback executing...');
      _bootstrap();
    });
  }

  /// Bootstrap asíncrono que no bloquea el primer frame
  Future<void> _bootstrap() async {
    final startTime = DateTime.now();
    print('🚀 [STARTUP] Bootstrap started');

    try {
      // Inicializar servicios en paralelo (sin bloquear UI)
      await Future.wait([_initServices(), _initShareHandler()]);

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      print('🚀 [STARTUP] Bootstrap completed in ${duration}ms');

      // Marcar como inicializado
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('❌ [STARTUP] Bootstrap error: $e');
      // Aún así marcar como inicializado para mostrar la app
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _initServices() async {
    print('🚀 [STARTUP] Initializing services...');
    final start = DateTime.now();

    // Inicializar el servicio de categorías (sincrónico, rápido)
    CategoryService().initialize(db);

    final duration = DateTime.now().difference(start).inMilliseconds;
    print('🚀 [STARTUP] Services initialized in ${duration}ms');
  }

  /// ✅ OPTIMIZACIÓN: Share handler perezoso - no bloquea el render
  Future<void> _initShareHandler() async {
    print('🚀 [STARTUP] Initializing share handler...');
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
      print('🚀 [STARTUP] Share handler initialized in ${duration}ms');
    } catch (e) {
      print('❌ [STARTUP] Share handler error: $e');
    }
  }

  Future<void> _handleShare(SharedMedia media) async {
    try {
      await _shareQueue.enqueue(media, _processSharedMedia);
    } on QueueFullException catch (error) {
      print('Share rejected explicitly: $error');
    }
  }

  Future<void> _processSharedMedia(SharedMedia media) async {
    // ⏱️ INICIO DEL CRONÓMETRO TOTAL
    final shareStartTime = DateTime.now();
    print('⏱️  [TIMER] ========================================');
    print('⏱️  [TIMER] SHARE STARTED at ${shareStartTime.toIso8601String()}');
    print('⏱️  [TIMER] ========================================');

    // Iniciar tracking de tiempo
    TimeTracker.startShareTracking();

    print('📤 [SHARE] Received shared media');

    final attachments = media.attachments;
    if (attachments != null) {
      await const AttachmentBatchProcessor<SharedAttachment>().process(
        attachments: attachments,
        isEligible: (attachment) =>
            attachment.type == SharedAttachmentType.image,
        processAttachment: (attachment) async {
          print('📤 [SHARE] Processing image attachment');
          await _processSharedImage(attachment, shareStartTime);
        },
      );
    }
  }

  /// ✅ OPTIMIZACIÓN: Procesamiento asíncrono optimizado
  Future<void> _processSharedImage(
    SharedAttachment att,
    DateTime shareStartTime,
  ) async {
    try {
      // Marcar inicio del procesamiento
      TimeTracker.startProcessing();

      // ✅ Mostrar UI de carga
      _showSpinnerOverlay();

      // ⏱️ Tiempo desde que se compartió hasta aquí
      final uiDelay = DateTime.now().difference(shareStartTime).inMilliseconds;
      print('⏱️  [TIMER] UI shown after ${uiDelay}ms from share click');

      // ✅ PASO 1: Persistir archivo (asíncrono, no bloquea UI)
      print('📁 [PROCESS] Persisting file...');
      final persistStart = DateTime.now();
      final localPath = await FileStore.persistIncomingFile(att.path);
      final persistDuration = DateTime.now()
          .difference(persistStart)
          .inMilliseconds;
      print('📁 [PROCESS] File persisted in ${persistDuration}ms');
      print(
        '⏱️  [TIMER] Elapsed: ${DateTime.now().difference(shareStartTime).inMilliseconds}ms',
      );

      // Generar ID y timestamp
      final id = _uuid.v4();
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      // ✅ PASO 2: Operaciones de base de datos en transacción (más rápido)
      print('💾 [PROCESS] Inserting capture in DB...');
      final dbStart = DateTime.now();
      await db.transaction(() async {
        await db.insertCapture(id: id, imagePath: localPath);
        await db.setProcessing(id);
      });
      final dbDuration = DateTime.now().difference(dbStart).inMilliseconds;
      print('💾 [PROCESS] DB operations completed in ${dbDuration}ms');
      print(
        '⏱️  [TIMER] Elapsed: ${DateTime.now().difference(shareStartTime).inMilliseconds}ms',
      );

      // ✅ PASO 3: OCR (asíncrono, la operación nativa es no-bloqueante)
      print('🔍 [PROCESS] Running OCR...');
      final ocrStart = DateTime.now();

      // Inicializar OCR si no existe
      _ocr ??= MlKitEngine();
      final res = await _ocr!.run(localPath);

      final ocrDuration = DateTime.now().difference(ocrStart).inMilliseconds;
      print('🔍 [PROCESS] OCR completed in ${ocrDuration}ms');
      print(
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
        print('📝 [PROCESS] Parsing...');
        final parseStart = DateTime.now();
        final parsed = await FastParser.fromOcr(
          res.text,
          fallbackDateEpoch: currentTime,
          ocrConfidence: confidence,
        );
        final parseDuration = DateTime.now()
            .difference(parseStart)
            .inMilliseconds;
        print('📝 [PROCESS] Parsing completed in ${parseDuration}ms');
        print(
          '⏱️  [TIMER] Elapsed: ${DateTime.now().difference(shareStartTime).inMilliseconds}ms',
        );

        // Solo registrar si tiene monto válido
        if (parsed.amountCents > 0) {
          // Esperar a que se complete el guardado del OCR
          await ocrSaveFuture;

          // Insertar gasto
          print('💰 [PROCESS] Inserting expense...');
          final dbInsertStart = DateTime.now();
          await db.insertExpenseFromParser(
            id: _uuid.v4(),
            captureId: id,
            dateEpochMs: parsed.dateEpochMs,
            amountCents: parsed.amountCents,
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
          print('💰 [PROCESS] Expense inserted in ${dbInsertDuration}ms');

          // ⏱️ TIEMPO TOTAL
          final totalTime = DateTime.now()
              .difference(shareStartTime)
              .inMilliseconds;
          print('⏱️  [TIMER] ========================================');
          print(
            '⏱️  [TIMER] TOTAL TIME: ${totalTime}ms (${(totalTime / 1000).toStringAsFixed(2)}s)',
          );
          print('⏱️  [TIMER] Breakdown:');
          print('⏱️  [TIMER]   UI delay: ${uiDelay}ms');
          print('⏱️  [TIMER]   File persist: ${persistDuration}ms');
          print('⏱️  [TIMER]   DB insert: ${dbDuration}ms');
          print('⏱️  [TIMER]   OCR: ${ocrDuration}ms');
          print('⏱️  [TIMER]   Parse: ${parseDuration}ms');
          print('⏱️  [TIMER]   Save expense: ${dbInsertDuration}ms');
          print('⏱️  [TIMER] ========================================');

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
      print('❌ [PROCESS] Error: $e');
      TimeTracker.endProcessing();
      _hideSpinnerOverlay();
      _showErrorAnimation("Error al procesar la captura: $e");
    }
  }

  /// ✅ Mostrar overlay liviano para procesamiento (no modal, no bloquea)
  void _showSpinnerOverlay() {
    final context = _navigatorKey.currentContext;
    if (context != null && _spinnerEntry == null) {
      try {
        // Intentar obtener el overlay - puede no estar listo aún
        final overlay = Overlay.of(context, rootOverlay: true);
        _spinnerEntry = OverlayEntry(
          builder: (_) =>
              const ImmediateLoadingOverlay(message: 'Procesando captura...'),
        );
        overlay.insert(_spinnerEntry!);
        print('🎨 [UI] Spinner overlay shown');
      } catch (e) {
        print('⚠️  [UI] Overlay not ready yet, showing dialog instead');
        // Fallback: usar un diálogo simple si el overlay no está listo
        _showSimpleLoadingDialog();
      }
    }
  }

  /// Fallback: diálogo simple si el overlay no está disponible
  void _showSimpleLoadingDialog() {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
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
    }
  }

  /// ✅ Ocultar overlay de procesamiento
  void _hideSpinnerOverlay() {
    final context = _navigatorKey.currentContext;

    if (_spinnerEntry != null) {
      // Si usamos overlay, removerlo
      _spinnerEntry?.remove();
      _spinnerEntry = null;
      print('🎨 [UI] Spinner overlay hidden');
    } else if (context != null) {
      // Si usamos diálogo fallback, cerrarlo
      try {
        Navigator.of(context).pop();
        print('🎨 [UI] Loading dialog closed');
      } catch (e) {
        // Si no hay diálogo, no pasa nada
      }
    }
  }

  /// ✅ Mostrar animación de éxito (sin pop, el overlay ya fue removido)
  void _showSuccessAnimation(ParsedExpense expense) {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      final timeSaved = TimeTracker.generateShortTimeSavedMessage();
      final totalTime = TimeTracker.getTotalProcessingTime();
      final totalTimeStr = totalTime != null
          ? TimeTracker.formatDuration(totalTime)
          : 'N/A';

      print('✅ [UI] Showing success animation (${totalTimeStr})');

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
      print('❌ [UI] Showing error message: $message');

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
      ScaffoldMessenger.of(context).showSnackBar(
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
          duration: const Duration(seconds: 4),
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
              amountCents: updatedExpense.amountCents,
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
    _sub?.cancel();
    _ocr?.dispose(); // Limpiar OCR engine
    _hideSpinnerOverlay(); // Limpiar overlay si existe
    TimeTracker.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🚀 [STARTUP] build() called, _isInitialized=$_isInitialized');
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
      home: _isInitialized ? HomeScreen(db: db) : _buildInstantLoadingScreen(),
    );
  }
}
