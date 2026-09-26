import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/features/ledger/demo_seed.dart';

void main() {
  test('demo data is identical to the prototype genData()', () {
    // Produced by running genData() from design/Money Manager IA v2.dc.html
    // in Node.
    final reference =
        jsonDecode(
              File('test/fixtures/prototype_gen_data.json').readAsStringSync(),
            )
            as List;
    final generated = DemoSeed.generate();

    expect(generated, hasLength(reference.length));
    for (var i = 0; i < reference.length; i++) {
      final r = reference[i] as Map<String, dynamic>;
      final g = generated[i];
      final time =
          '${g.hour.toString().padLeft(2, '0')}:'
          '${g.minute.toString().padLeft(2, '0')}';
      expect(
        [
          g.id,
          g.month,
          g.day,
          g.type,
          g.category,
          g.subcategory,
          g.note,
          g.account,
          g.amount,
          time,
          g.method,
          g.toAccount,
          g.ocr,
        ],
        [
          r['id'],
          r['m'],
          r['d'],
          r['type'],
          r['cat'],
          r['sub'],
          r['note'],
          r['acc'],
          (r['amt'] as num).toDouble(),
          r['time'],
          r['method'],
          r['to'],
          r['ocr'],
        ],
        reason: 'transaction ${r['id']}',
      );
    }
  });
}
