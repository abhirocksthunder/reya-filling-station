import 'dart:async';
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'ocr_engine.dart';

class OcrEngineImpl implements OcrEngine {
  @override
  Future<String> recognizeTextFromPath(String filePath) async {
    final completer = Completer<String>();

    try {
      if (js.context.hasProperty('performWebOcr')) {
        debugPrint('Invoking in-browser Tesseract Web OCR for: $filePath');
        js.context.callMethod('performWebOcr', [
          filePath,
          js.allowInterop((dynamic text) {
            final str = text?.toString() ?? '';
            debugPrint('Web OCR completed successfully with ${str.length} characters');
            if (!completer.isCompleted) {
              completer.complete(str);
            }
          }),
          js.allowInterop((dynamic error) {
            debugPrint('Web OCR error returned from JS: $error');
            if (!completer.isCompleted) {
              completer.complete('');
            }
          }),
        ]);

        return await completer.future.timeout(
          const Duration(seconds: 25),
          onTimeout: () {
            debugPrint('Web OCR timed out after 25s');
            return '';
          },
        );
      } else {
        debugPrint('performWebOcr not found on window object');
      }
    } catch (e) {
      debugPrint('Error invoking Web OCR: $e');
    }

    return '';
  }
}
