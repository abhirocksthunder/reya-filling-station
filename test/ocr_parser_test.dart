import 'package:flutter_test/flutter_test.dart';
import 'package:reya_filling_station/models/receipt_scan.dart';
import 'package:reya_filling_station/services/ocr_parser_service.dart';

void main() {
  group('OcrParserService Tests', () {
    const String sampleReceiptText = '''
INDIANOIL FORECOURT AUTOMATION
FP. ID : 1
Pump SNo : 202501001272
Date : 09/10/2026
Time : 21:50:29

Nozzle No1
Shif1Sale: 295.130
CumVolume: 169923.720
CumSale: 18989346.490

Nozzle No2
ShDayVol: 613.790
CumVolume: 274487.190
CumSale: 27916133.280

THANK YOU VISIT AGAIN
''';

    test('1. Extracts Pump SNo, Date, Time and Hierarchical Nozzles', () {
      OcrParseResult result = OcrParserService.parseIndianOilReceipt(sampleReceiptText);

      expect(result.success, isTrue);
      expect(result.pumpSerialNumber, equals('202501001272'));
      expect(result.fpId, equals('1'));
      expect(result.printedDate, equals('09/10/2026'));
      expect(result.printedTime, equals('21:50:29'));

      expect(result.nozzleCumVolumeMl.containsKey(1), isTrue);
      expect(result.nozzleCumVolumeMl[1], equals(169923720)); // 169,923.720 L

      expect(result.nozzleCumVolumeMl.containsKey(2), isTrue);
      expect(result.nozzleCumVolumeMl[2], equals(274487190)); // 274,487.190 L
    });

    test('2. Rejects previous-day receipt when station business date is today', () {
      OcrParseResult result = OcrParserService.parseIndianOilReceipt(sampleReceiptText);

      String fingerprint = OcrParserService.calculateReceiptFingerprint(
        result.pumpSerialNumber!,
        result.printedDate!,
        result.printedTime!,
        result.nozzleCumVolumeMl,
      );

      ReceiptValidationStatus status = OcrParserService.validateReceipt(
        printedDate: result.printedDate!,
        currentBusinessDate: '10/10/2026', // Station date is 10 Oct, receipt is 9 Oct
        scannedVolumes: result.nozzleCumVolumeMl,
        previousVolumes: {1: 168676720, 2: 273287210},
        existingReceiptFingerprints: {},
        currentFingerprint: fingerprint,
      );

      expect(status, equals(ReceiptValidationStatus.previousDayReceipt));
    });

    test('3. Detects duplicate scan via SHA-256 fingerprint', () {
      OcrParseResult result = OcrParserService.parseIndianOilReceipt(sampleReceiptText);

      String fingerprint = OcrParserService.calculateReceiptFingerprint(
        result.pumpSerialNumber!,
        result.printedDate!,
        result.printedTime!,
        result.nozzleCumVolumeMl,
      );

      ReceiptValidationStatus status = OcrParserService.validateReceipt(
        printedDate: '10/10/2026',
        currentBusinessDate: '10/10/2026',
        scannedVolumes: result.nozzleCumVolumeMl,
        previousVolumes: {1: 168676720, 2: 273287210},
        existingReceiptFingerprints: {fingerprint}, // Already scanned!
        currentFingerprint: fingerprint,
      );

      expect(status, equals(ReceiptValidationStatus.duplicate));
    });

    test('4. Detects lower counter reduction/rollover needing approval', () {
      OcrParseResult result = OcrParserService.parseIndianOilReceipt(sampleReceiptText);

      String fingerprint = OcrParserService.calculateReceiptFingerprint(
        result.pumpSerialNumber!,
        '10/10/2026',
        result.printedTime!,
        result.nozzleCumVolumeMl,
      );

      ReceiptValidationStatus status = OcrParserService.validateReceipt(
        printedDate: '10/10/2026',
        currentBusinessDate: '10/10/2026',
        scannedVolumes: {1: 150000000}, // Lower than previous 168,676.720 L
        previousVolumes: {1: 168676720},
        existingReceiptFingerprints: {},
        currentFingerprint: fingerprint,
      );

      expect(status, equals(ReceiptValidationStatus.lowerCounter));
    });
  });
}
