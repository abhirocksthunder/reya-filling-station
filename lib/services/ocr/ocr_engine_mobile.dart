import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../ocr_parser_service.dart';
import 'ocr_engine.dart';

class OcrEngineImpl implements OcrEngine {
  static String? lastError;
  static int lastDurationMs = 0;

  /// Detects if a file path or byte buffer is in HEIC / HEIF / AVIF format
  static bool isHeicOrHeif(String pathOrMime, Uint8List? bytes) {
    final lower = pathOrMime.toLowerCase();
    if (lower.endsWith('.heic') ||
        lower.endsWith('.heif') ||
        lower.contains('image/heic') ||
        lower.contains('image/heif')) {
      return true;
    }
    if (bytes != null && bytes.length >= 12) {
      // ISO Base Media File Format: bytes 4..7 == 'ftyp' (0x66, 0x74, 0x79, 0x70)
      if (bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
        final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
        if (brand.contains('heic') ||
            brand.contains('heix') ||
            brand.contains('hevc') ||
            brand.contains('hevx') ||
            brand.contains('mif1') ||
            brand.contains('msf1') ||
            brand.contains('avif')) {
          return true;
        }
      }
    }
    return false;
  }

  /// Renders raw image bytes (including HEIC/HEIF) to a clean PNG file on disk,
  /// optionally rotating by [quarterTurns] * 90° clockwise.
  static Future<File?> renderBytesToTempPng(
    Uint8List bytes, {
    int quarterTurns = 0,
    int? maxDimension,
  }) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: maxDimension,
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image srcImage = frameInfo.image;

      ui.Image finalImage = srcImage;
      final int turns = quarterTurns % 4;
      if (turns != 0) {
        final int srcW = srcImage.width;
        final int srcH = srcImage.height;
        final int outW = (turns == 1 || turns == 3) ? srcH : srcW;
        final int outH = (turns == 1 || turns == 3) ? srcW : srcH;

        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.translate(outW / 2.0, outH / 2.0);
        canvas.rotate(turns * (math.pi / 2.0));
        canvas.translate(-srcW / 2.0, -srcH / 2.0);
        canvas.drawImage(srcImage, ui.Offset.zero, ui.Paint());
        final picture = recorder.endRecording();
        finalImage = await picture.toImage(outW, outH);
      }

      final ByteData? pngData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      if (pngData == null) return null;

      final tempFile = File(
        '${Directory.systemTemp.path}/rfs_ocr_${DateTime.now().microsecondsSinceEpoch}_rot$turns.png',
      );
      await tempFile.writeAsBytes(pngData.buffer.asUint8List(), flush: true);
      return tempFile;
    } catch (e) {
      debugPrint('renderBytesToTempPng error (rot=$quarterTurns): $e');
      return null;
    }
  }

  static int _scoreCandidateText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    int score = math.min(trimmed.length ~/ 10, 20);
    if (RegExp(r'Cum\s*\.?\s*Vol|Curn\s*Vol|Cun\s*Vol', caseSensitive: false).hasMatch(trimmed)) {
      score += 50;
    }
    if (RegExp(r'Nozzle', caseSensitive: false).hasMatch(trimmed)) {
      score += 25;
    }
    if (RegExp(r'IndianOil|Pump\s*S\.?No|FP\.?\s*ID', caseSensitive: false).hasMatch(trimmed)) {
      score += 20;
    }
    if (RegExp(r'\d{5,8}\.\d{2,3}').hasMatch(trimmed)) {
      score += 30;
    }
    final parsed = OcrParserService.parseIndianOilReceipt(trimmed);
    if (parsed.success && parsed.nozzleCumVolumeMl.isNotEmpty) {
      score += 100 + (parsed.nozzleCumVolumeMl.length * 40);
    }
    return score;
  }

  @override
  Future<String> recognizeTextFromPath(String filePath) async {
    final stopwatch = Stopwatch()..start();
    final List<File> tempFilesToCleanup = [];
    TextRecognizer? textRecognizer;

    try {
      String localPath = filePath;
      Uint8List? imageBytes;

      // 1. If a data: URI was passed on mobile, decode base64 to a local temp file first
      if (filePath.startsWith('data:')) {
        final commaIdx = filePath.indexOf(',');
        if (commaIdx != -1) {
          final b64 = filePath.substring(commaIdx + 1).trim();
          imageBytes = base64Decode(b64);
          final ext = isHeicOrHeif(filePath.substring(0, commaIdx), imageBytes) ? 'heic' : 'jpg';
          final tempInput = File(
            '${Directory.systemTemp.path}/rfs_ocr_input_${DateTime.now().microsecondsSinceEpoch}.$ext',
          );
          await tempInput.writeAsBytes(imageBytes, flush: true);
          tempFilesToCleanup.add(tempInput);
          localPath = tempInput.path;
        }
      } else {
        final file = File(localPath);
        if (await file.exists()) {
          imageBytes = await file.readAsBytes();
        }
      }

      textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      String bestText = '';
      int bestScore = 0;

      Future<bool> tryRecognizeFile(String pathToScan) async {
        final inputImage = InputImage.fromFilePath(pathToScan);
        final RecognizedText recognized = await textRecognizer!.processImage(inputImage);
        final candidate = recognized.text;
        final score = _scoreCandidateText(candidate);
        if (score > bestScore || (bestText.isEmpty && candidate.trim().isNotEmpty)) {
          bestScore = score;
          bestText = candidate;
        }
        // Score >= 180 means parseIndianOilReceipt succeeded with CumVolume
        return score >= 180;
      }

      final bool isHeic = isHeicOrHeif(localPath, imageBytes);

      // 2. If HEIC/HEIF, convert to standard PNG via dart:ui first because ML Kit / ExifInterface
      // on many Android devices fails or misreads raw .heic containers.
      if (isHeic && imageBytes != null && imageBytes.isNotEmpty) {
        final png0 = await renderBytesToTempPng(imageBytes, quarterTurns: 0);
        if (png0 != null) {
          tempFilesToCleanup.add(png0);
          if (await tryRecognizeFile(png0.path)) {
            stopwatch.stop();
            lastDurationMs = stopwatch.elapsedMilliseconds;
            lastError = null;
            return bestText;
          }
        }
      }

      // 3. Try direct file path recognition
      try {
        if (await tryRecognizeFile(localPath)) {
          stopwatch.stop();
          lastDurationMs = stopwatch.elapsedMilliseconds;
          lastError = null;
          return bestText;
        }
      } on MissingPluginException catch (e) {
        // Running inside headless unit test environment without native ML Kit channel
        stopwatch.stop();
        lastDurationMs = stopwatch.elapsedMilliseconds;
        lastError = e.toString();
        debugPrint('Mobile ML Kit OCR extraction error: $e');
        return '';
      } catch (e) {
        debugPrint('Direct InputImage.fromFilePath attempt note: $e');
      }

      // 4. Multi-pass decode & orientation recovery (handles HEIC irot 90°/270°/180° gallery photos)
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final rotations = isHeic ? <int>[1, 3, 2] : <int>[0, 1, 3, 2];
        for (final rot in rotations) {
          final rotatedPng = await renderBytesToTempPng(imageBytes, quarterTurns: rot);
          if (rotatedPng != null) {
            tempFilesToCleanup.add(rotatedPng);
            try {
              if (await tryRecognizeFile(rotatedPng.path)) {
                break;
              }
            } catch (e) {
              debugPrint('Rotated OCR attempt (rot=$rot) note: $e');
            }
          }
        }
      }

      stopwatch.stop();
      lastDurationMs = stopwatch.elapsedMilliseconds;
      lastError = bestText.trim().isEmpty ? 'No text detected across upright and rotated passes' : null;
      return bestText;
    } catch (e) {
      stopwatch.stop();
      lastDurationMs = stopwatch.elapsedMilliseconds;
      lastError = e.toString();
      debugPrint('Mobile ML Kit OCR extraction error: $e');
      return '';
    } finally {
      try {
        await textRecognizer?.close();
      } catch (_) {}
      for (final f in tempFilesToCleanup) {
        try {
          if (await f.exists()) {
            await f.delete();
          }
        } catch (_) {}
      }
    }
  }
}

