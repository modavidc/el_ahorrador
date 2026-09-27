import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/capture/application/capture_controller.dart';
import 'package:el_ahorrador/features/capture/data/drift_capture_records.dart';
import 'package:el_ahorrador/features/capture/data/drift_capture_rule_repository.dart';
import 'package:el_ahorrador/features/capture/data/encrypted_capture_image_store.dart';
import 'package:el_ahorrador/features/capture/data/mlkit_ocr_engine.dart';
import 'package:el_ahorrador/features/capture/domain/capture_ports.dart';
import 'package:el_ahorrador/features/capture/domain/capture_service.dart';
import 'package:el_ahorrador/features/ledger/data/drift_ledger_repository.dart';
import 'package:el_ahorrador/features/ledger/domain/ledger_repository.dart';
import 'package:el_ahorrador/features/settings/data/drift_app_preferences.dart';
import 'package:el_ahorrador/features/settings/domain/app_preferences.dart';

/// Composition root: the only place that knows which implementation backs
/// each port. Screens receive the interfaces.
final class AppDependencies {
  factory AppDependencies(
    AppDatabase db, {
    OcrEngine? ocr,
    CaptureImageStore images = const EncryptedCaptureImageStore(),
    DateTime Function()? now,
  }) {
    final ledger = DriftLedgerRepository(db);
    final captureRules = DriftCaptureRuleRepository(db);
    final captureService = CaptureService(
      ocr: ocr ?? MlKitEngine(),
      images: images,
      records: DriftCaptureRecords(db),
      rules: captureRules,
      ledger: ledger,
      now: now,
    );
    return AppDependencies._(
      database: db,
      ledger: ledger,
      preferences: DriftAppPreferences(db),
      captureRules: captureRules,
      capture: CaptureController(captureService),
    );
  }

  AppDependencies._({
    required this.database,
    required this.ledger,
    required this.preferences,
    required this.captureRules,
    required this.capture,
  });

  /// Raw database, only for the screens not yet moved to repositories
  /// (legacy account editing, debug import).
  final AppDatabase database;
  final LedgerRepository ledger;
  final AppPreferences preferences;
  final CaptureRuleRepository captureRules;

  /// Reads shared images for the whole life of the app.
  final CaptureController capture;

  void dispose() => capture.dispose();
}
