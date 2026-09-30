import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/features/capture/data/ocr_layout.dart';
import 'package:el_ahorrador/features/capture/domain/receipt_reader.dart';

void main() {
  // ML Kit blocks of a Yape receipt in the order it may return them: the
  // boxed message and the transaction data before the title.
  const blocks = [
    OcrLine('pasaje bus', top: 620, left: 130, height: 30),
    OcrLine('Nro. de celular', top: 880, left: 60, height: 30),
    OcrLine('*** *** 281', top: 882, left: 470, height: 28),
    OcrLine('Nro. de operación', top: 965, left: 60, height: 30),
    OcrLine('23760001', top: 966, left: 470, height: 28),
    OcrLine('¡Yapeaste!', top: 320, left: 60, height: 40),
    OcrLine('S/', top: 400, left: 60, height: 50),
    OcrLine('2', top: 390, left: 120, height: 80),
    OcrLine('Carla Nue*', top: 490, left: 60, height: 36),
    OcrLine('29 set. 2026', top: 545, left: 95, height: 28),
    OcrLine('05:33 p. m.', top: 546, left: 310, height: 28),
    OcrLine('CÓDIGO DE SEGURIDAD', top: 735, left: 60, height: 24),
    OcrLine('Destino', top: 922, left: 60, height: 30),
    OcrLine('Yape', top: 923, left: 530, height: 28),
  ];

  test('lines come back as the receipt looks, row by row', () {
    expect(readingOrder(blocks).split('\n'), [
      '¡Yapeaste!',
      'S/',
      '2',
      'Carla Nue*',
      '29 set. 2026',
      '05:33 p. m.',
      'pasaje bus',
      'CÓDIGO DE SEGURIDAD',
      'Nro. de celular',
      '*** *** 281',
      'Destino',
      'Yape',
      'Nro. de operación',
      '23760001',
    ]);
  });

  test('the reordered receipt reads its message and amount', () {
    final r = ReceiptReader.read(
      readingOrder(blocks),
      now: DateTime(2026, 9, 29),
    );
    expect(r.amountCents, 200);
    expect(r.counterpart, 'Carla Nue');
    expect(r.message, 'pasaje bus');
    expect(r.counterpartPhone, '281');
    expect(r.operation, '23760001');
  });
}
