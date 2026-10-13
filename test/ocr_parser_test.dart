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

    test('6. Parses two-column split header slip (FP. ID :3, Pump SNo :202501001346) from HEIC gallery photo', () {
      const splitColumnReceipt = '''
IndianOil
FP. ID
Pump SNo
Date
Time
:3
:2O2501001346
:10/10/2026
:20:51:01

Nozzle Noló
Shif1Sale:7937.380
Shif1Vol :67.520
Shif2Sale:12474.000
Shif2Vol :106.140
Shif3Sale:12926.350
Shif3Vol :109.970
ShDaySale:
33337.730
ShDayVol :283.630
ShMTHSale:
450641.610
ShMTHVol :3834.710
CumVolume:
86106.490
CumSale :10038181.010

Nozzle No2
Shif1Sale:21825.610
Shif1Vol :207.430
Shif2Sale:22490.000
Shif2Vol :213.720
Shif3Sale:17995.770
Shif3Vol :171.030
ShDaySale:
62311.380
ShDayVol :592.180
ShMTHSale:
580004.620
ShMTHVol :5512.540
CumVolume:
125635.400
CumSale :12987914.750
''';

      final result = OcrParserService.parseIndianOilReceipt(splitColumnReceipt);
      expect(result.success, isTrue);
      expect(result.pumpSerialNumber, equals('202501001346'));
      expect(result.fpId, equals('3'));
      expect(result.printedDate, equals('10/10/2026'));
      expect(result.printedTime, equals('20:51:01'));
      expect(result.nozzleCumVolumeMl[1], equals(86106490));
      expect(result.nozzleCumVolumeMl[2], equals(125635400));
    });

    test('7. Recovers Nozzle 1 section when Nozzle No1 header is blurred and only Nozzle No2 header is detected', () {
      const missingN1HeaderReceipt = '''
IndianOil
FP. ID : 3
Pump SNo : 202501001346
Date : 11/10/2026
Time : 20:51:38
ShDaySale: 35609.030
CumVolume:
91761.070
CumSale : 10700216.920

Nozzle No2
ShDaySale: 90629.530
455291.350
CumVolume:
CumSale :
127496.520
13895156.920
''';

      final result = OcrParserService.parseIndianOilReceipt(
        missingN1HeaderReceipt,
        expectedBaselineLitres: {1: 86106.490, 2: 125635.400},
      );
      expect(result.success, isTrue);
      expect(result.nozzleCumVolumeMl[1], equals(91761070));
      expect(result.nozzleCumVolumeMl[2], equals(127496520));
      expect(result.nozzleMatchedSnippet[2]!.contains('↑'), isFalse);
    });

    test('8. Rejects lakh-scale upward number (455291.350) above CumVolume and only accepts reading below CumVolume within 25,000L delta', () {
      const lakhJumpReceipt = '''
IndianOil
FP. ID : 3
Pump SNo : 202501001346
Date : 11/10/2026
Time : 20:51:38
Nozzle No1
CumVolume:
91761.070
Nozzle No2
455291.350
CumVolume:
''';

      // Here Nozzle 2 has NO reading below CumVolume, only 455291.350 above it (a +3.29 lakh jump from 125635.400).
      // Parser must reject 455291.350 so ScanReceiptScreen alerts user to "Scan Totaliser Again"!
      final result = OcrParserService.parseIndianOilReceipt(
        lakhJumpReceipt,
        expectedBaselineLitres: {1: 86106.490, 2: 125635.400},
      );
      expect(result.success, isTrue);
      expect(result.nozzleCumVolumeMl[1], equals(91761070));
      expect(result.nozzleCumVolumeMl.containsKey(2), isFalse);
    });
  });
}
