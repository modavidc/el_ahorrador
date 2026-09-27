import 'package:el_ahorrador/core/clock/app_clock.dart';
import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/capture/data/unsupported_background_capture.dart';
import 'package:el_ahorrador/features/capture/domain/background_capture.dart';
import 'package:el_ahorrador/features/coach/application/coach_controller.dart';
import 'package:el_ahorrador/features/coach/data/drift_conversation_repository.dart';
import 'package:el_ahorrador/features/coach/domain/coach.dart';
import 'package:el_ahorrador/features/import/data/historical_import.dart';
import 'package:el_ahorrador/features/accounts/data/drift_accounts_repository.dart';
import 'package:el_ahorrador/features/accounts/domain/accounts_repository.dart';
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
    BackgroundCapture backgroundCapture = const UnsupportedBackgroundCapture(),
    CoachAssistant coachAssistant = const LocalCoach(),
    DateTime Function()? now,
    bool historicalImport = false,
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
      accounts: DriftAccountsRepository(db),
      preferences: DriftAppPreferences(db),
      captureRules: captureRules,
      capture: CaptureController(captureService),
      backgroundCapture: backgroundCapture,
      coach: CoachController(
        assistant: coachAssistant,
        history: DriftConversationRepository(db),
        now: now ?? AppClock.now,
      ),
      runImport: historicalImport
          ? (log) => runHistoricalImport(db, log)
          : null,
    );
  }

  AppDependencies._({
    required this.database,
    required this.ledger,
    required this.accounts,
    required this.preferences,
    required this.captureRules,
    required this.capture,
    required this.backgroundCapture,
    required this.coach,
    required this.runImport,
  });

  final AppDatabase database;
  final LedgerRepository ledger;
  final AccountsRepository accounts;
  final AppPreferences preferences;
  final CaptureRuleRepository captureRules;

  /// Reads shared images for the whole life of the app.
  final CaptureController capture;
  final BackgroundCapture backgroundCapture;
  final CoachController coach;

  /// Debug builds: imports assets/import/importar.csv.
  final Future<void> Function(void Function(String line) log)? runImport;

  void dispose() {
    capture.dispose();
    coach.dispose();
  }
}
