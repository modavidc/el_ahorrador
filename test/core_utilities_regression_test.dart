import 'package:el_ahorrador/core/ai_notes_generator.dart';
import 'package:el_ahorrador/core/capture_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CaptureValidator regressions', () {
    test('recognizes correctly encoded Spanish banking text', () {
      expect(
        CaptureValidator.validateCapture('Depósito recibido'),
        CaptureType.banco,
      );
      expect(
        CaptureValidator.validateCapture('Operación bancaria completada'),
        CaptureType.banco,
      );
      expect(CaptureValidator.validateCapture('¡Yapeaste!'), CaptureType.yape);
    });

    test('validation messages exist for every enum value', () {
      for (final type in CaptureType.values) {
        expect(CaptureValidator.getValidationMessage(type), isNotEmpty);
      }
    });
  });

  group('AINotesGenerator invariants', () {
    test('generated notes are bounded and include useful context', () {
      final note = AINotesGenerator.generateNote(
        category: 'Comida',
        subcategory: 'Restaurante',
        vendor: 'Mercado Central',
        amount: 80,
      );
      expect(note.split(RegExp(r'\s+')).length, lessThanOrEqualTo(15));
      expect(note, contains('Mercado Central'));
    });

    test('unknown categories safely fall back to a non-empty note', () {
      final note = AINotesGenerator.generateNote(category: 'No configurada');
      expect(note, isNotEmpty);
      expect(note.split(RegExp(r'\s+')).length, lessThanOrEqualTo(15));
    });
  });
}
