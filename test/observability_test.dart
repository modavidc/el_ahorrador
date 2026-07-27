import 'package:flutter_test/flutter_test.dart';
import 'package:el_ahorrador/core/observability.dart';

void main() {
  group('AppObservability privacy filter', () {
    test('removes financial and identifying attribute keys', () {
      final safe = AppObservability.sanitizeAttributes({
        'duration_ms': 25,
        'success': true,
        'ocr_text': 'Saldo S/ 123.45',
        'account_id': 'secret',
        'file_path': r'C:\private\receipt.png',
        'vendor_name': 'Private merchant',
      });
      expect(safe, {'duration_ms': 25, 'success': true});
    });

    test('keeps telemetry-safe scalar representations', () {
      final safe = AppObservability.sanitizeAttributes({
        'item_count': 3,
        'timed_out': false,
        'stage': _Stage.completed,
        'optional': null,
      });
      expect(safe, {
        'item_count': 3,
        'timed_out': false,
        'stage': '_Stage.completed',
        'optional': null,
      });
    });
  });
}

enum _Stage { completed }
