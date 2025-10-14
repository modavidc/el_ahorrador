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
  print('🚀 [STARTUP] WidgetsFlutterBinding initialized (${DateTime.now().difference(startTime).inMilliseconds}ms)');
  
  runApp(const MisGastosApp());
  print('🚀 [STARTUP] runApp() called (${DateTime.now().difference(startTime).inMilliseconds}ms)');
}

class MisGastosApp extends StatefulWidget {
  const MisGastosApp({super.key});

  @override
  State<MisGastosApp> createState() => _MisGastosAppState();
}

class _MisGastosAppState extends State<MisGastosApp> {
  final db = AppDatabase();
  final _uuid = const Uuid();
  MlKitEngine? _ocr;
  StreamSubscription<SharedMedia>? _sub;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _isProcessingShare = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    print('🚀 [STARTUP] initState() called');
    _initServices();
    _initShareHandler();
  }

  void _initServices() {
    // Inicializar el servicio de categorías
    CategoryService().initialize(db);
    
    // Inicializar OCR en background para no bloquear la UI
    _initOcrAsync();
  }

  Future<void> _initOcrAsync() async {
    print('🚀 [STARTUP] Initializing ML Kit...');
    final start = DateTime.now();
    
    // Inicializar OCR en background
    _ocr = MlKitEngine();
    
    final duration = DateTime.now().difference(start).inMilliseconds;
    print('🚀 [STARTUP] ML Kit initialized in ${duration}ms');
    
    setState(() {
      _isInitialized = true;
    });
    print('🚀 [STARTUP] App ready! Total time from initState');
  }

  Future<void> _initShareHandler() async {
    final share = ShareHandlerPlatform.instance;
    final initial = await share.getInitialSharedMedia();
    if (initial != null) {
      _handleShare(initial);
    }
    _sub = share.sharedMediaStream.listen(_handleShare);
  }

  Future<void> _handleShare(SharedMedia media) async {
    // Evitar procesamiento múltiple
    if (_isProcessingShare) return;
    _isProcessingShare = true;
    
    // Iniciar tracking de tiempo
    TimeTracker.startShareTracking();
    
    final attachments = media.attachments;
    if (attachments != null) {
      for (final att in attachments) {
        if (att != null && att.type == SharedAttachmentType.image) {
          // Mostrar mensaje inmediatamente
          _showQuickProcessingMessage();
          
          // Procesar inmediatamente sin esperar
          _processSharedImage(att);
        }
      }
    }
  }

  Future<void> _processSharedImage(SharedAttachment att) async {
    try {
      // Marcar inicio del procesamiento
      TimeTracker.startProcessing();
      
      // Mostrar alerta antes del OCR
      _showOcrAlert();
      
      // Procesamiento en paralelo para máxima velocidad
      final futures = await Future.wait([
        // 1. Persistir archivo
        FileStore.persistIncomingFile(att.path),
        // 2. Generar ID
        Future.value(_uuid.v4()),
        // 3. Obtener timestamp actual
        Future.value(DateTime.now().millisecondsSinceEpoch),
      ]);
      
      final localPath = futures[0] as String;
      final id = futures[1] as String;
      final currentTime = futures[2] as int;
      
      // Operaciones de base de datos en paralelo
      await Future.wait([
        db.insertCapture(id: id, imagePath: localPath),
        db.setProcessing(id),
      ]);
      
      // OCR optimizado - esperar a que esté inicializado si es necesario
      if (_ocr == null) {
        // Esperar a que el OCR esté listo
        while (_ocr == null) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      final res = await _ocr!.run(localPath);
      final confidence = res.meta['confidence']?.toString();
      
      // Validar y procesar en paralelo
      final captureType = CaptureValidator.validateCapture(res.text);
      
      // Guardar resultado OCR en paralelo con el parsing
      final ocrSaveFuture = db.setOcrResult(id: id, text: res.text, confidence: confidence);
      
      // Solo procesar si es una captura válida
      if (CaptureValidator.isProcessable(captureType)) {
        // Parse → expense (usando parser rápido)
        final parsed = await FastParser.fromOcr(
          res.text,
          fallbackDateEpoch: currentTime,
          ocrConfidence: confidence,
        );
      
        // Solo registrar si tiene monto válido
        if (parsed.amountCents > 0) {
          // Esperar a que se complete el guardado del OCR
          await ocrSaveFuture;
          
          // Insertar gasto
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
          
          // Marcar fin del procesamiento
          TimeTracker.endProcessing();
          
          // Mostrar animación de éxito con tiempo ahorrado
          _showSuccessAnimation(parsed);
        } else {
          // Si no hay monto válido, marcar fin del procesamiento
          TimeTracker.endProcessing();
          _showErrorAnimation("No se pudo detectar un monto válido");
        }
      } else {
        // Si no es procesable, marcar fin del procesamiento
        TimeTracker.endProcessing();
        _showErrorAnimation("Tipo de captura no reconocido");
      }
    } catch (e) {
      TimeTracker.endProcessing();
      _showErrorAnimation("Error al procesar la captura: $e");
    } finally {
      // Resetear el flag de procesamiento
      _isProcessingShare = false;
    }
  }



  void _showQuickProcessingMessage() {
    // Mostrar mensaje instantáneamente sin esperar
    final context = _navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Procesando tu captura...',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue.shade600,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      // Si no hay context, intentar de nuevo en el siguiente frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showQuickProcessingMessage();
      });
    }
  }

  void _showOcrAlert() {
    // Mostrar alerta instantáneamente antes del OCR
    final context = _navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Analizando captura...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Esto puede tomar unos segundos',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else {
      // Si no hay context, intentar de nuevo en el siguiente frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOcrAlert();
      });
    }
  }


  void _showSuccessAnimation(ParsedExpense expense) {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      // Cerrar diálogo de OCR si está abierto
      Navigator.of(context).pop();
      
      // Mostrar animación de éxito directamente
      final timeSaved = TimeTracker.generateShortTimeSavedMessage();
      final totalTime = TimeTracker.getTotalProcessingTime();
      final totalTimeStr = totalTime != null 
          ? TimeTracker.formatDuration(totalTime) 
          : 'N/A';
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => SuccessAnimation(
          title: '¡Registrado!',
          message: 'Transacción de ${expense.sourceApp} procesada en $totalTimeStr\n'
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

  void _showErrorAnimation(String message) {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      // Cerrar diálogo de OCR si está abierto
      Navigator.of(context).pop();
      
      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 14),
                ),
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
                  content: Text('Gasto actualizado: S/ ${updatedExpense.amountCents / 100} - ${updatedExpense.vendor}'),
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
              child: const Icon(
                Icons.savings,
                color: Colors.white,
                size: 40,
              ),
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
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue.shade600,
              ),
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
    _ocr?.dispose();
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
