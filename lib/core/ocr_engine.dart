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
  TextRecognizer? _cachedRecognizer;
  
  @override
  Future<OcrResult> run(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    
    // Reutilizar el recognizer para evitar recrearlo
    _cachedRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    
    try {
      final res = await _cachedRecognizer!.processImage(input);
      final blocks = res.blocks.length;
      final lines = res.blocks.fold<int>(0, (a, b) => a + b.lines.length);
      
      // Calcular confianza de forma más eficiente
      double totalConfidence = 0.0;
      int totalElements = 0;
      
      // Optimización: solo calcular confianza si es necesario
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
      
      // Logging optimizado (solo en debug)
      if (false) { // Cambiar a true para debug
        print('=== OCR RESULT ===');
        print('Image path: $imagePath');
        print('Total blocks: $blocks');
        print('Total lines: $lines');
        print('Confidence: $confidencePercentage%');
        print('--- RAW TEXT ---');
        print(res.text);
        print('--- END RAW TEXT ---');
      }
      
      return OcrResult(res.text, {
        'engine': 'mlkit', 
        'blocks': blocks, 
        'lines': lines,
        'confidence': confidencePercentage,
        'totalElements': totalElements,
      });
    } catch (e) {
      // En caso de error, cerrar el recognizer y recrearlo
      await _cachedRecognizer?.close();
      _cachedRecognizer = null;
      rethrow;
    }
  }
  
  // Método para cerrar el recognizer cuando no se necesite
  Future<void> dispose() async {
    await _cachedRecognizer?.close();
    _cachedRecognizer = null;
  }
}
