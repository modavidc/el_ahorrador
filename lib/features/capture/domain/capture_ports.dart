import 'package:el_ahorrador/features/capture/domain/capture_models.dart';
import 'package:el_ahorrador/features/capture/domain/capture_rule.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';

/// Ports the capture use cases need; `data/` implements them.

final class OcrResult {
  const OcrResult(this.text, {this.confidence});

  final String text;

  /// Average confidence of the recognised words, 0–100.
  final int? confidence;
}

/// Reads the text of an image.
abstract interface class OcrEngine {
  Future<OcrResult> run(String imagePath);
}

/// Keeps a private copy of each capture image.
abstract interface class CaptureImageStore {
  /// Stores the image and returns where.
  Future<String> persist(String path);

  /// Content hash, to spot the same image shared twice.
  Future<String> hash(String path);
}

abstract interface class CaptureRuleRepository {
  Stream<List<CaptureRule>> watch();
  Future<List<CaptureRule>> load();
  Future<void> save(List<CaptureRule> rules);
  Future<void> update(CaptureRule rule);
}

enum CaptureRecordStatus { processing, processed, review, discarded, failed }

/// A stored capture that still counts: registered, or waiting in Por
/// revisar.
final class CaptureRecord {
  const CaptureRecord({required this.id, this.draft, this.movementId});

  final String id;
  final CaptureDraft? draft;
  final String? movementId;
}

/// Every image received and what came of it.
abstract interface class CaptureRecords {
  /// A registered capture (whose movement still exists) or one waiting in
  /// Por revisar, with the same image [hash] or the same [operation].
  Future<CaptureRecord?> findActive({
    String? hash,
    String? operation,
    String? except,
  });

  /// Stores a new capture being read and returns its id.
  Future<String> create({required String imagePath, required String hash});

  Future<void> saveReading(
    String id, {
    required String text,
    required MovementOrigin origin,
    int? confidence,
    String? operation,
    String? sourceApp,
    CaptureDraft? draft,
  });

  Future<void> setStatus(String id, CaptureRecordStatus status);

  /// App or bank the capture came from ("Yape").
  Future<String?> sourceApp(String id);

  /// Payments waiting in Por revisar, newest first.
  Stream<List<InboxItem>> watchInbox();
}
