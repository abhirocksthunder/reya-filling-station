import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'ocr_engine.dart';

class OcrEngineImpl implements OcrEngine {
  @override
  Future<String> recognizeTextFromPath(String filePath) async {
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();
      return recognizedText.text;
    } catch (e) {
      debugPrint('Mobile ML Kit OCR extraction error: $e');
      return '';
    }
  }
}
