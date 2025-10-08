import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String text;
  final Map<String, dynamic> meta;
  OcrResult(this.text, this.meta);
}

abstract class OcrEngine {
  Future<OcrResult> run(String imagePath);
}

class MlKitEngine implements OcrEngine {
  @override
  Future<OcrResult> run(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final res = await recognizer.processImage(input);
      final blocks = res.blocks.length;
      final lines = res.blocks.fold<int>(0, (a, b) => a + b.lines.length);
      
      // Calcular nivel de confianza promedio
      double totalConfidence = 0.0;
      int totalElements = 0;
      
      for (final block in res.blocks) {
        for (final line in block.lines) {
          for (final element in line.elements) {
            totalConfidence += element.confidence ?? 0.0;
            totalElements++;
          }
        }
      }
      
      final averageConfidence = totalElements > 0 ? (totalConfidence / totalElements) * 100 : 0.0;
      final confidencePercentage = averageConfidence.round();
      
      // Logging detallado del texto OCR
      print('=== OCR RESULT ===');
      print('Image path: $imagePath');
      print('Total blocks: $blocks');
      print('Total lines: $lines');
      print('Confidence: $confidencePercentage%');
      print('--- RAW TEXT ---');
      print(res.text);
      print('--- END RAW TEXT ---');
      
      // Logging por bloques
      for (int i = 0; i < res.blocks.length; i++) {
        final block = res.blocks[i];
        print('Block $i: "${block.text}"');
        print('  Lines: ${block.lines.length}');
        for (int j = 0; j < block.lines.length; j++) {
          final line = block.lines[j];
          print('    Line $j: "${line.text}"');
        }
      }
      print('=== END OCR RESULT ===');
      
      return OcrResult(res.text, {
        'engine': 'mlkit', 
        'blocks': blocks, 
        'lines': lines,
        'confidence': confidencePercentage,
        'totalElements': totalElements,
      });
    } finally {
      await recognizer.close();
    }
  }
}
