import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:el_ahorrador/features/capture/domain/capture_ports.dart';

/// [OcrEngine] with Google ML Kit, on the device. The recognizer is created
/// once and reused.
class MlKitEngine implements OcrEngine {
  TextRecognizer? _recognizer;

  @override
  Future<OcrResult> run(String imagePath) async {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await _recognizer!.processImage(
        InputImage.fromFilePath(imagePath),
      );
      var total = 0.0;
      var count = 0;
      for (final block in result.blocks) {
        for (final line in block.lines) {
          for (final element in line.elements) {
            total += element.confidence ?? 0;
            count++;
          }
        }
      }
      return OcrResult(
        result.text,
        confidence: count == 0 ? null : (total / count * 100).round(),
      );
    } catch (_) {
      // A failed recognizer is recreated on the next image.
      await dispose();
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
