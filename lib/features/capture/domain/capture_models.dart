import 'package:el_ahorrador/features/ledger/domain/entities.dart';

enum CaptureStatus {
  /// Saved as a movement.
  registered,

  /// Same image or same operation already captured; nothing saved.
  duplicate,

  /// Not a payment receipt.
  notReceipt,

  /// Waiting in Por revisar for a missing amount or category.
  review,

  /// OCR or storage failed.
  failed,
}

/// What a capture understood, before or after it becomes a movement.
final class CaptureDraft {
  const CaptureDraft({
    required this.note,
    required this.type,
    required this.account,
    required this.at,
    this.amountCents,
    this.category,
    this.ocrPercent,
    this.ruleLabel,
    this.why,
  });

  final String note;
  final MovementType type;
  final String account;
  final DateTime at;
  final int? amountCents;
  final String? category;
  final int? ocrPercent;

  /// 'Regla “Yapeaste” → Gasto · Yape'
  final String? ruleLabel;

  /// Why it is waiting in Por revisar ("Falta la categoría").
  final String? why;
}

final class CaptureOutcome {
  const CaptureOutcome({
    required this.status,
    required this.fileName,
    this.captureId,
    this.movementId,
    this.originalMovementId,
    this.draft,
  });

  final CaptureStatus status;

  /// Shown when nothing else identifies the image ("IMG_2291.jpg").
  final String fileName;
  final String? captureId;
  final String? movementId;

  /// For duplicates: the movement that was already registered.
  final String? originalMovementId;
  final CaptureDraft? draft;
}

/// A payment waiting in Por revisar.
final class InboxItem {
  const InboxItem({
    required this.captureId,
    required this.draft,
    required this.origin,
    required this.receivedAt,
  });

  final String captureId;
  final CaptureDraft draft;
  final MovementOrigin origin;
  final DateTime receivedAt;
}

/// A ticket read by Escanear boleta, waiting for "Guardar".
final class ReceiptScan {
  const ReceiptScan({required this.captureId, required this.draft});

  final String captureId;
  final CaptureDraft draft;
}

/// Why a scanned ticket cannot be saved; [message] is shown as is.
final class ScanException implements Exception {
  const ScanException(this.message, {this.originalMovementId});

  final String message;

  /// The movement already registered from the same ticket.
  final String? originalMovementId;

  @override
  String toString() => message;
}
