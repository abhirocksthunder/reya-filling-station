import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:reya_filling_station/models/receipt_scan.dart';
import 'package:reya_filling_station/models/user_profile.dart';
import 'package:reya_filling_station/services/station_state_provider.dart';
import 'package:reya_filling_station/services/ocr_service.dart';
import 'package:reya_filling_station/services/ocr_parser_service.dart';
import 'package:reya_filling_station/ui/auth/login_screen.dart';

void main() {
  group('Security PIN Authentication & Verification Tests', () {
    testWidgets('1. Correct Security PIN logs user in successfully', (WidgetTester tester) async {
      final state = StationStateProvider();
      UserProfile? authenticatedUser;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<StationStateProvider>.value(
            value: state,
            child: LoginScreen(
              onLoginSuccess: (user) {
                authenticatedUser = user;
              },
            ),
          ),
        ),
      );

      // Verify credentials chips are NOT shown
      expect(find.text('Select authorized user to fill credentials:'), findsNothing);

      // Enter email and correct PIN (default 123456)
      await tester.enterText(find.byType(TextField).first, 'kalyan@rfs.com');
      await tester.enterText(find.byType(TextField).last, '123456');
      await tester.pump();

      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(authenticatedUser, isNotNull);
      expect(authenticatedUser!.email, equals('kalyan@rfs.com'));
      expect(authenticatedUser!.role, equals(UserRole.owner));
    });

    testWidgets('2. Incorrect Security PIN is rejected with descriptive error', (WidgetTester tester) async {
      final state = StationStateProvider();
      UserProfile? authenticatedUser;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<StationStateProvider>.value(
            value: state,
            child: LoginScreen(
              onLoginSuccess: (user) {
                authenticatedUser = user;
              },
            ),
          ),
        ),
      );

      // Enter correct email but wrong PIN
      await tester.enterText(find.byType(TextField).first, 'kalyan@rfs.com');
      await tester.enterText(find.byType(TextField).last, '999999');
      await tester.pump();

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Must NOT be authenticated
      expect(authenticatedUser, isNull);
      expect(find.textContaining('Incorrect Security PIN'), findsOneWidget);
    });

    testWidgets('3. Empty Security PIN is rejected', (WidgetTester tester) async {
      final state = StationStateProvider();
      UserProfile? authenticatedUser;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<StationStateProvider>.value(
            value: state,
            child: LoginScreen(
              onLoginSuccess: (user) {
                authenticatedUser = user;
              },
            ),
          ),
        ),
      );

      // Enter email with empty PIN
      await tester.enterText(find.byType(TextField).first, 'kalyan@rfs.com');
      await tester.pump();

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(authenticatedUser, isNull);
      expect(find.textContaining('Please enter your 4-6 digit Security PIN'), findsOneWidget);
    });
  });

  group('OCR Receipt Parsing & CumVolume Extraction Tests', () {
    test('1. Extracts CumVolume, Date, Time for Nozzle 1 & 2', () async {
      final extraction = await OcrService.processReceiptImage(
        'assets/images/media_1791634198035.png',
        targetPumpId: 'pump_1',
      );

      expect(extraction.success, isTrue);
      expect(extraction.date, equals('09/10/2026'));
      expect(extraction.time, equals('21:50:29'));
      expect(extraction.fpId, equals('1'));
      expect(extraction.pumpSerialNumber, equals('202501001272'));
      expect(extraction.nozzleLitres[1], equals(169923.720));
      expect(extraction.nozzleLitres[2], equals(274487.190));
    });

    test('2. Supports Pump 2 OCR CumVolume Extraction', () async {
      final extraction = await OcrService.processReceiptImage(
        'mock_pump2_receipt.png',
        targetPumpId: 'pump_2',
      );

      expect(extraction.success, isTrue);
      expect(extraction.fpId, equals('2'));
      expect(extraction.pumpSerialNumber, equals('202501001289'));
      expect(extraction.nozzleLitres[1], equals(154210.350));
      expect(extraction.nozzleLitres[2], equals(248910.600));
    });

    test('3. Direct IndianOil Dispenser Slip Extraction with Exact Real Slip Text', () {
      const realSlip = '''
IndianOil

FP. ID :1
Pump SNo :202501001272
Date :09/10/2026
Time :21:50:29

Nozzle No1
Shif1Sale:1777.600
Shif1Vol :15.130
Shif2Sale:20951.850
Shif2Vol :178.310
Shif3Sale:18731.730
Shif3Vol :159.420
ShDaySale:
41461.180
ShDayVol :352.860
ShMTHSale:
392689.850
ShMTHVol :3341.620
CumVolume:
169923.720
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
CumVolume:
274487.190
CumSale :27916133.280
''';

      final res = OcrParserService.parseIndianOilReceipt(realSlip);

      expect(res.success, isTrue);
      expect(res.pumpSerialNumber, equals('202501001272'));
      expect(res.fpId, equals('1'));
      expect(res.printedDate, equals('09/10/2026'));
      expect(res.printedTime, equals('21:50:29'));
      expect(res.nozzleCumVolumeMl[1], equals(169923720));
      expect(res.nozzleCumVolumeMl[2], equals(274487190));
      // Must NOT match CumSale or intermediate counters
      expect(res.nozzleCumVolumeMl[1], isNot(equals(15130)));
      expect(res.nozzleCumVolumeMl[1], isNot(equals(352860)));
      expect(res.nozzleCumVolumeMl[1], isNot(equals(3341620)));
      expect(res.nozzleCumVolumeMl[1], isNot(equals(18989346490)));
    });

    test('4. Handles Noisy OCR with Nol, pen marks, commas, and line breaks', () {
      const noisySlip = '''
INDIANOIL AUTOMATION
FP. ID: 1
Pump S.No: 202501001272
Date: 10-10-2026
Time: 22:15:00

Nozzle Nol
Shif1Sale: 2100.500
Shif1Vol: 18.200
ShDayVol: 410.200
ShMTHVol: 4120.500
CumVolume:
 170450.250 L
CumSale: 19120400.00

Nozzle No 2
ShDayVol: 650.120
CumVolume:
/ 275120,800
CumSale: 28050000.00
''';

      final res = OcrParserService.parseIndianOilReceipt(noisySlip);

      expect(res.success, isTrue);
      expect(res.pumpSerialNumber, equals('202501001272'));
      expect(res.fpId, equals('1'));
      expect(res.printedDate, equals('10/10/2026'));
      expect(res.printedTime, equals('22:15:00'));
      expect(res.nozzleCumVolumeMl[1], equals(170450250));
      expect(res.nozzleCumVolumeMl[2], equals(275120800));
    });

    test('5. Handles Faint Thermal Printout Missing Decimal Dot (Integer mL)', () {
      const faintDotSlip = '''
IndianOil
FP. ID : 2
Pump SNo : 202501001289
Date : 10/10/2026
Time : 22:45:00

Nozzle No1
CumVolume:
154950350
CumSale: 16800000.00

Nozzle No2
CumVolume:
249820600
CumSale: 25900000.00
''';

      final res = OcrParserService.parseIndianOilReceipt(faintDotSlip);

      expect(res.success, isTrue);
      expect(res.pumpSerialNumber, equals('202501001289'));
      expect(res.fpId, equals('2'));
      expect(res.nozzleCumVolumeMl[1], equals(154950350));
      expect(res.nozzleCumVolumeMl[2], equals(249820600));
    });

    test('6. Monotonic Continuity Rejects Lower Counter Reading', () {
      final prev = {1: 169923720, 2: 274487190};
      // Scanned reading lower than previous
      final lower = {1: 169000000, 2: 274487190};

      final status = OcrParserService.validateReceipt(
        printedDate: '10/10/2026',
        currentBusinessDate: '10/10/2026',
        scannedVolumes: lower,
        previousVolumes: prev,
        existingReceiptFingerprints: {},
        currentFingerprint: 'fp_test',
      );

      expect(status, equals(ReceiptValidationStatus.lowerCounter));
    });

    test('7. Strictly rejects Shift2Sale and wrapped line shift counters, isolating CumVolume below line', () {
      const shift2Receipt = '''
IndianOil
FP. ID : 1
Pump SNo : 202501001272
Date : 10/10/2026
Time : 22:30:15

Nozzle No1
Shif1Sale: 1850.200
Shif1Vol : 16.200
Shift2Sale:
20951.850
Shift2Vol: 178.500
ShDaySale:
41461.180
ShDayVol : 352.860
ShMTHSale:
392689.850
CumVolume:
171054.450
CumSale : 18989346.490

Nozzle No2
Shift2Sale: 12080.400
ShDaySale: 62900.350
CumVolume:
275912.820
CumSale : 27916133.280
''';

      final res = OcrParserService.parseIndianOilReceipt(shift2Receipt);

      expect(res.success, isTrue);
      expect(res.nozzleCumVolumeMl[1], equals(171054450));
      expect(res.nozzleCumVolumeMl[2], equals(275912820));

      // CRITICAL: Must NEVER equal Shift2Sale (20951.850 / 12080.400) or ShDaySale or ShMTHSale
      expect(res.nozzleCumVolumeMl[1], isNot(equals(20951850)));
      expect(res.nozzleCumVolumeMl[1], isNot(equals(41461180)));
      expect(res.nozzleCumVolumeMl[1], isNot(equals(392689850)));
      expect(res.nozzleCumVolumeMl[2], isNot(equals(12080400)));
      expect(res.nozzleCumVolumeMl[2], isNot(equals(62900350)));
    });

    test('8. Handles CurnVolume and CumVo1 optical ambiguities with value on subsequent line', () {
      const opticalSlip = '''
IndianOil
FP. ID : 1
Pump SNo : 202501001272
Date : 10/10/2026
Time : 22:35:00

Nozzle No1
Shift2Sale: 20951.850
CurnVolume:
 171054.450
CumSale : 18989346.490

Nozzle No2
Shift2Sale: 12080.400
CumVo1:
 275912.820
CumSale : 27916133.280
''';

      final res = OcrParserService.parseIndianOilReceipt(opticalSlip);

      expect(res.success, isTrue);
      expect(res.nozzleCumVolumeMl[1], equals(171054450));
      expect(res.nozzleCumVolumeMl[2], equals(275912820));
      expect(res.nozzleCumVolumeMl[1], isNot(equals(20951850)));
      expect(res.nozzleCumVolumeMl[2], isNot(equals(12080400)));
    });

    test('9. Handles CumSale on the same line as CumVolume value without skipping', () {
      const mergedLineSlip = '''
IndianOil
FP. ID : 1
Pump SNo : 202501001272
Date : 10/10/2026
Time : 22:40:00

Nozzle No1
Shift2Sale: 20951.850
CumVolume:
171054.450 CumSale : 18989346.490

Nozzle No2
Shift2Sale: 12080.400
CumVolume:
275912.820 CumSale : 27916133.280
''';

      final res = OcrParserService.parseIndianOilReceipt(mergedLineSlip);

      expect(res.success, isTrue);
      expect(res.nozzleCumVolumeMl[1], equals(171054450));
      expect(res.nozzleCumVolumeMl[2], equals(275912820));
    });

    test('10. Parses real IndianOil slip with Nozzle Noló, split header labels, and offset CumVolume', () {
      const realSlip = '''
FP. ID
Date
IndianOil
Pump SNo :202501001346
Time
:3
:10/10/2026
:20:51:01
Nozzle Noló
shiflSale:7937.380
shi flvol :67.520
shif2sale: 12474.000
shif2Vol :106.140
shif3Sale:12926.350
shif3vol :109.970
shDaySale:
33337.730
shDayVol :283.630
shMTHSale:
450641.610
86106. 490
shMTHVol :3834.710
CumVolume:
CumSale :10038181.010
Nozzle No2
shif1sale:21825.610
shiflvol :207.430
Shif2Sale:22490.000
shif2Vol :213. 720
shif3sale:17995.770
shif3Vol :171.030
ShDaySale:
62311.380
ShDayVol :592.180
ShMTHSale:
580004. 620
shMTHVol :5512.540
Cumvolume:
125635.400
CumSale :12987914. 750
''';

      final res = OcrParserService.parseIndianOilReceipt(realSlip);

      expect(res.success, isTrue);
      expect(res.pumpSerialNumber, equals('202501001346'));
      expect(res.fpId, equals('3'));
      expect(res.printedDate, equals('10/10/2026'));
      expect(res.printedTime, equals('20:51:01'));
      expect(res.nozzleCumVolumeMl[1], equals(86106490));
      expect(res.nozzleCumVolumeMl[2], equals(125635400));
    });
  });
}
