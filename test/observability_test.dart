import 'package:el_ahorrador/core/observability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps only allowlisted scalar operational dimensions', () {
    final sanitized = AppObservability.sanitizeAttributes({
      'duration_ms': 12,
      'result': true,
      'stage': 'raw OCR text',
      'context': {'ocr': 'secret'},
      'amount': 99.90,
      'path': '/private/receipt.jpg',
    });

    expect(sanitized, {'duration_ms': '12', 'result': 'true'});
  });

  test('rejects collections even when their key is allowlisted', () {
    expect(
      AppObservability.sanitizeAttributes({
        'result': ['secret'],
        'operation': {'text': 'secret'},
      }),
      isEmpty,
    );
  });
}
