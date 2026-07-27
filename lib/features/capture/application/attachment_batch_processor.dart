/// Processes eligible attachments sequentially while isolating per-item errors.
class AttachmentBatchProcessor<T> {
  const AttachmentBatchProcessor({this.maxEligibleAttachments = 10});

  final int maxEligibleAttachments;

  Future<AttachmentBatchSummary<T>> process({
    required Iterable<T?> attachments,
    required bool Function(T attachment) isEligible,
    required Future<void> Function(T attachment) processAttachment,
  }) async {
    final results = <AttachmentProcessingResult<T>>[];
    var eligibleCount = 0;
    for (final attachment in attachments) {
      if (attachment == null || !isEligible(attachment)) continue;
      if (eligibleCount >= maxEligibleAttachments) break;
      eligibleCount++;
      try {
        await processAttachment(attachment);
        results.add(AttachmentProcessingSuccess(attachment));
      } catch (error, stackTrace) {
        results.add(AttachmentProcessingFailure(attachment, error, stackTrace));
      }
    }
    return AttachmentBatchSummary(results);
  }
}

class AttachmentBatchSummary<T> {
  const AttachmentBatchSummary(this.results);
  final List<AttachmentProcessingResult<T>> results;
  int get processedCount => results.length;
  int get successCount =>
      results.whereType<AttachmentProcessingSuccess<T>>().length;
  int get failureCount =>
      results.whereType<AttachmentProcessingFailure<T>>().length;
}

sealed class AttachmentProcessingResult<T> {
  const AttachmentProcessingResult(this.attachment);
  final T attachment;
}

final class AttachmentProcessingSuccess<T>
    extends AttachmentProcessingResult<T> {
  const AttachmentProcessingSuccess(super.attachment);
}

final class AttachmentProcessingFailure<T>
    extends AttachmentProcessingResult<T> {
  const AttachmentProcessingFailure(
    super.attachment,
    this.error,
    this.stackTrace,
  );
  final Object error;
  final StackTrace stackTrace;
}
