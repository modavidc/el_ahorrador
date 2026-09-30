import 'dart:async';

import 'package:drift/drift.dart' show TableUpdate;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

import 'package:el_ahorrador/core/clock/app_clock.dart';
import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/capture/data/android_background_capture.dart';
import 'package:el_ahorrador/features/capture/data/unsupported_background_capture.dart';
import 'package:el_ahorrador/features/capture/domain/background_capture.dart';
import 'package:el_ahorrador/features/coach/application/coach_controller.dart';
import 'package:el_ahorrador/features/coach/data/drift_conversation_repository.dart';
import 'package:el_ahorrador/features/coach/data/openai_coach.dart';
import 'package:el_ahorrador/features/coach/domain/coach.dart';
import 'package:el_ahorrador/features/coach/domain/coach_model.dart';
import 'package:el_ahorrador/features/import/data/historical_import.dart';
import 'package:el_ahorrador/features/accounts/data/drift_accounts_repository.dart';
import 'package:el_ahorrador/features/accounts/domain/accounts_repository.dart';
import 'package:el_ahorrador/features/capture/application/capture_controller.dart';
import 'package:el_ahorrador/features/capture/data/drift_capture_records.dart';
import 'package:el_ahorrador/features/capture/data/drift_capture_rule_repository.dart';
import 'package:el_ahorrador/features/capture/data/encrypted_capture_image_store.dart';
import 'package:el_ahorrador/features/capture/data/image_picker_receipt_camera.dart';
import 'package:el_ahorrador/features/capture/data/mlkit_ocr_engine.dart';
import 'package:el_ahorrador/features/capture/domain/capture_ports.dart';
import 'package:el_ahorrador/features/capture/domain/capture_service.dart';
import 'package:el_ahorrador/features/ledger/data/drift_ledger_repository.dart';
import 'package:el_ahorrador/features/ledger/data/speech_to_text_input.dart';
import 'package:el_ahorrador/features/ledger/domain/ledger_repository.dart';
import 'package:el_ahorrador/features/ledger/domain/speech_input.dart';
import 'package:el_ahorrador/features/reminders/data/android_reminder_scheduler.dart';
import 'package:el_ahorrador/features/reminders/domain/reminder_service.dart';
import 'package:el_ahorrador/features/reminders/domain/reminders.dart';
import 'package:el_ahorrador/features/settings/data/drift_app_preferences.dart';
import 'package:el_ahorrador/features/settings/domain/app_preferences.dart';

/// Composition root: the only place that knows which implementation backs
/// each port. Screens receive the interfaces.
final class AppDependencies {
  /// What the installed app uses: the Android capture service on Android
  /// and the Coach with OpenAI when the user connects a key.
  factory AppDependencies.forDevice(
    AppDatabase db, {
    bool historicalImport = false,
  }) {
    final android = defaultTargetPlatform == TargetPlatform.android;
    final openAi = OpenAiCoach();
    final dependencies = AppDependencies(
      db,
      historicalImport: historicalImport,
      backgroundCapture: android
          ? AndroidBackgroundCapture()
          : const UnsupportedBackgroundCapture(),
      reminderScheduler: android
          ? const AndroidReminderScheduler()
          : const NoReminderScheduler(),
      coachAssistant: openAi,
      coachModel: openAi,
    );
    dependencies._subscriptions.add(
      dependencies.reminders.keepScheduled().listen(null),
    );
    return dependencies;
  }

  factory AppDependencies(
    AppDatabase db, {
    OcrEngine? ocr,
    CaptureImageStore images = const EncryptedCaptureImageStore(),
    ReceiptCamera? camera,
    SpeechInput? speech,
    ReminderScheduler reminderScheduler = const NoReminderScheduler(),
    BackgroundCapture backgroundCapture = const UnsupportedBackgroundCapture(),
    CoachAssistant coachAssistant = const LocalCoach(),
    CoachModelAccess? coachModel,
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
    // Movements registered by the background engine come through another
    // database connection; refresh the open screens.
    backgroundCapture.captured.listen(
      (_) => db.notifyUpdates({
        TableUpdate.onTable(db.expenses),
        TableUpdate.onTable(db.captures),
      }),
    );
    final preferences = DriftAppPreferences(db);
    return AppDependencies._(
      database: db,
      ledger: ledger,
      accounts: DriftAccountsRepository(db),
      preferences: preferences,
      captureRules: captureRules,
      capture: CaptureController(captureService),
      camera: camera ?? ImagePickerReceiptCamera(),
      speech: speech ?? SpeechToTextInput(),
      backgroundCapture: backgroundCapture,
      coach: CoachController(
        assistant: coachAssistant,
        history: DriftConversationRepository(db),
        now: now ?? AppClock.now,
      ),
      coachModel: coachModel,
      reminders: ReminderService(
        ledger: ledger,
        preferences: preferences,
        scheduler: reminderScheduler,
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
    required this.camera,
    required this.speech,
    required this.backgroundCapture,
    required this.coach,
    required this.coachModel,
    required this.reminders,
    required this.runImport,
  });

  final AppDatabase database;
  final LedgerRepository ledger;
  final AccountsRepository accounts;
  final AppPreferences preferences;
  final CaptureRuleRepository captureRules;

  /// Reads shared images for the whole life of the app.
  final CaptureController capture;

  /// + → Escanear boleta and Dictar.
  final ReceiptCamera camera;
  final SpeechInput speech;
  final BackgroundCapture backgroundCapture;
  final CoachController coach;

  /// Ajustes → Modelo de IA; null hides the row.
  final CoachModelAccess? coachModel;

  /// Recordatorios: the phone's alarms and what each one notifies.
  final ReminderService reminders;

  /// Debug builds: imports assets/import/importar.csv.
  final Future<void> Function(void Function(String line) log)? runImport;

  final _subscriptions = <StreamSubscription<Object?>>[];

  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    capture.dispose();
    coach.dispose();
  }
}
