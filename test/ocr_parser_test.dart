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

    test('5. Accurately extracts October 10 receipt with pen marks and line breaks (media_1791650227874)', () {
      const String oct10Receipt = '''
IndianOil
FP. ID :1
Pump SNo :202501001272
Date :10/10/2026
Time :22:05:14

Nozzle No1
Shif1Sale:1777.600
Shif1Vol :15.130
Shif2Sale:20951.850
Shif2Vol :178.310
Shif3Sale:18751.730
Shif3Vol :158.420
ShDaySale:
41461.180
ShDayVol :352.860
ShMTHSale:
392689.850
ShMTHVol :3341.620
CumVolume:
171054.450
CumSale :18989346.490

Nozzle No2
Shif1Sale:1226.050
Shif1Vol :11.650
Shif2Sale:12080.400
Shif2Vol :114.820
Shif3Sale:49593.900
Shif3Vol :471.370
ShDaySale:
62900.350
ShDayVol :597.840
ShMTHSale:
640908.950
ShMTHVol :6091.540
CumVolume: /
275912.820
CumSale :27916133.280
''';

      final result = OcrParserService.parseIndianOilReceipt(oct10Receipt);
      expect(result.success, isTrue);
      expect(result.pumpSerialNumber, equals('202501001272'));
      expect(result.fpId, equals('1'));
      expect(result.printedDate, equals('10/10/2026'));
      expect(result.printedTime, equals('22:05:14'));
      expect(result.nozzleCumVolumeMl[1], equals(171054450)); // 171,054.450 L
      expect(result.nozzleCumVolumeMl[2], equals(275912820)); // 275,912.820 L
    });
  });
}
