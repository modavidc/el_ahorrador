import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_handler/share_handler.dart';
import 'package:uuid/uuid.dart';
import 'core/file_store.dart';
import 'core/ocr_engine.dart';
import 'core/parser.dart';
import 'core/capture_validator.dart';
import 'core/category_service.dart';
import 'data/app_database.dart';
import 'data/daos.dart';
import 'screens/home_screen.dart';
import 'widgets/expense_edit_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MisGastosApp());
}

class MisGastosApp extends StatefulWidget {
  const MisGastosApp({super.key});

  @override
  State<MisGastosApp> createState() => _MisGastosAppState();
}

class _MisGastosAppState extends State<MisGastosApp> {
  final db = AppDatabase();
  final _uuid = const Uuid();
  final _ocr = MlKitEngine();
  StreamSubscription<SharedMedia>? _sub;

  @override
  void initState() {
    super.initState();
    _initServices();
    _initShareHandler();
  }

  void _initServices() {
    // Inicializar el servicio de categorías
    CategoryService().initialize(db);
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
    final attachments = media.attachments;
    if (attachments != null) {
      for (final att in attachments) {
        if (att != null && att.type == SharedAttachmentType.image) {
          final localPath = await FileStore.persistIncomingFile(att.path);
          final id = _uuid.v4();
          await db.insertCapture(id: id, imagePath: localPath);
          await db.setProcessing(id);
          
          // OCR
          final res = await _ocr.run(localPath);
          final confidence = res.meta['confidence']?.toString();
          await db.setOcrResult(id: id, text: res.text, confidence: confidence);
          
          // Validar tipo de captura
          final captureType = CaptureValidator.validateCapture(res.text);
          
          // Mostrar mensaje según el tipo de captura
          _showCaptureMessage(captureType);
          
            // Solo procesar si es una captura válida
            if (CaptureValidator.isProcessable(captureType)) {
              // Parse → expense
              final parsed = await Parser.fromOcr(
                res.text,
                fallbackDateEpoch: DateTime.now().millisecondsSinceEpoch,
                ocrConfidence: confidence,
              );
            
            // Solo registrar si tiene monto válido
            if (parsed.amountCents > 0) {
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
              
              // Mostrar mensaje de confirmación y navegar a la pantalla principal
              _showSuccessMessage(parsed);
            }
          }
        }
      }
    }
  }

  void _showCaptureMessage(CaptureType type) {
    // Mostrar mensaje según el tipo de captura
    final message = CaptureValidator.getValidationMessage(type);
    
    // Usar un delay para asegurar que el MaterialApp esté listo
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: type == CaptureType.invalid 
                ? Colors.red 
                : type == CaptureType.unknown 
                    ? Colors.orange 
                    : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _showSuccessMessage(ParsedExpense expense) {
    // Mostrar mensaje de éxito sin abrir dialog
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✅ Transacción de ${expense.sourceApp} registrada: S/ ${(expense.amountCents / 100).toStringAsFixed(2)}',
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
    });
  }

  void _showEditDialog(ParsedExpense expense) {
    showDialog(
      context: context,
      builder: (context) => ExpenseEditDialog(
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
          
          // Mostrar confirmación
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gasto actualizado: S/ ${updatedExpense.amountCents / 100} - ${updatedExpense.vendor}'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: HomeScreen(db: db),
    );
  }
}
