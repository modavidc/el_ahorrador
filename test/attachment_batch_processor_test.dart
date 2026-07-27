import 'package:flutter_test/flutter_test.dart';
import 'package:el_ahorrador/features/capture/application/attachment_batch_processor.dart';

void main() {
  const processor = AttachmentBatchProcessor<TestAttachment>();

  test('preserves FIFO and continues after an item fails', () async {
    final attempted = <int>[];
    final summary = await processor.process(
      attachments: const [
        TestAttachment(1),
        TestAttachment(2),
        TestAttachment(3),
      ],
      isEligible: (attachment) => attachment.isImage,
      processAttachment: (attachment) async {
        attempted.add(attachment.id);
        if (attachment.id == 2) throw StateError('failed');
      },
    );
    expect(attempted, [1, 2, 3]);
    expect(summary.successCount, 2);
    expect(summary.failureCount, 1);
    expect(summary.results.map((result) => result.attachment.id), [1, 2, 3]);
  });

  test('skips null and non-image attachments', () async {
    final attempted = <int>[];
    final summary = await processor.process(
      attachments: const [
        null,
        TestAttachment(1, isImage: false),
        TestAttachment(2),
      ],
      isEligible: (attachment) => attachment.isImage,
      processAttachment: (attachment) async => attempted.add(attachment.id),
    );
    expect(attempted, [2]);
    expect(summary.processedCount, 1);
  });

  test('limits processing to ten eligible attachments', () async {
    final attempted = <int>[];
    final summary = await processor.process(
      attachments: [
        for (var index = 1; index <= 12; index++) TestAttachment(index),
      ],
      isEligible: (attachment) => attachment.isImage,
      processAttachment: (attachment) async => attempted.add(attachment.id),
    );
    expect(attempted, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    expect(summary.processedCount, 10);
  });
}

class TestAttachment {
  const TestAttachment(this.id, {this.isImage = true});
  final int id;
  final bool isImage;
}
