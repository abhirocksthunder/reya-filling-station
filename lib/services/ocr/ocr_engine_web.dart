import 'dart:async';
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'ocr_engine.dart';

class OcrEngineImpl implements OcrEngine {
  static String? lastError;
  static int lastDurationMs = 0;

  @override
  Future<String> recognizeTextFromPath(String filePath) async {
    final completer = Completer<String>();
    final stopwatch = Stopwatch()..start();

    try {
      if (js.context.hasProperty('performWebOcr')) {
        debugPrint('Invoking in-browser Tesseract Web OCR for: $filePath');
        js.context.callMethod('performWebOcr', [
          filePath,
          js.allowInterop((dynamic text) {
            final str = text?.toString() ?? '';
            stopwatch.stop();
            lastDurationMs = stopwatch.elapsedMilliseconds;
            lastError = null;
            debugPrint('Web OCR completed successfully with ${str.length} characters in ${lastDurationMs}ms');
            if (!completer.isCompleted) {
              completer.complete(str);
            }
          }),
          js.allowInterop((dynamic error) {
            stopwatch.stop();
            lastDurationMs = stopwatch.elapsedMilliseconds;
            lastError = error?.toString();
            debugPrint('Web OCR error returned from JS: $error');
            if (!completer.isCompleted) {
              completer.complete('');
            }
          }),
        ]);

        return await completer.future.timeout(
          const Duration(seconds: 25),
          onTimeout: () {
            stopwatch.stop();
            lastDurationMs = stopwatch.elapsedMilliseconds;
            lastError = 'Web OCR timed out after 25 seconds';
            debugPrint('Web OCR timed out after 25s');
            return '';
          },
        );
      } else {
        stopwatch.stop();
        lastDurationMs = stopwatch.elapsedMilliseconds;
        lastError = 'performWebOcr not found on window object';
        debugPrint('performWebOcr not found on window object');
      }
    } catch (e) {
      stopwatch.stop();
      lastDurationMs = stopwatch.elapsedMilliseconds;
      lastError = e.toString();
      debugPrint('Error invoking Web OCR: $e');
    }

    return '';
  }
}
