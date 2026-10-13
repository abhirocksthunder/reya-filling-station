import 'package:flutter_test/flutter_test.dart';
import 'package:reya_filling_station/models/receipt_scan.dart';
import 'package:reya_filling_station/models/transaction_entry.dart';
import 'package:reya_filling_station/services/station_state_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Station Day Calculation & Date Isolation Tests', () {
    late StationStateProvider provider;

    setUp(() {
      provider = StationStateProvider();
    });

    test('1. Starts with 0.0 L static data and calculates live dispenser totals when readings are updated', () {
      final today = DateTime.now();
      // Initially 0.0 L sold (no static seed sales)
      final initialCalc = provider.getDayCalculation(today);
      expect(initialCalc.totalNetLitres, equals(0.0));
      expect(initialCalc.totalFuelSalesPaise, equals(0));

      // Apply live totaliser readings for Pump 1 and Pump 2 via saveReceiptScan
      final dateStr = '${today.day.toString().padLeft(2, "0")}/${today.month.toString().padLeft(2, "0")}/${today.year}';
      provider.saveReceiptScan(ReceiptScan(
        id: 'scan_p1_live',
        pumpSerialNumber: '202501001272',
        fpId: '1',
        printedDate: dateStr,
        printedTime: '18:00:00',
        nozzleCumVolumeMl: const {
          1: 168971850, // 168676720 + 295,130 ml (+295.13 L gross)
          2: 273901000, // 273287210 + 613,790 ml (+613.79 L gross)
        },
        imagePath: 'test/p1.jpg',
        validationStatus: ReceiptValidationStatus.valid,
        statusMessage: 'Valid',
        capturedBy: 'Srinivas',
        capturedAt: today,
        reviewStatus: 'approved',
      ));
      provider.saveReceiptScan(ReceiptScan(
        id: 'scan_p2_live',
        pumpSerialNumber: '202501001289',
        fpId: '2',
        printedDate: dateStr,
        printedTime: '18:05:00',
        nozzleCumVolumeMl: const {
          1: 83713500,  // 83398950 + 314,550 ml (+314.55 L gross)
          2: 122597130, // 121958960 + 638,170 ml (+638.17 L gross)
        },
        imagePath: 'test/p2.jpg',
        validationStatus: ReceiptValidationStatus.valid,
        statusMessage: 'Valid',
        capturedBy: 'Srinivas',
        capturedAt: today,
        reviewStatus: 'approved',
      ));

      final dayCalc = provider.getDayCalculation(today);
      expect(dayCalc.pumpResults.length, greaterThanOrEqualTo(2));

      // Pump 1
      final p1 = dayCalc.pumpResults.firstWhere((p) => p.pump.id == 'pump_1');
      expect(p1.nozzleResults.length, 2);
      final p1N1 = p1.nozzleResults.firstWhere((n) => n.nozzleNumber == 1);
      final p1N2 = p1.nozzleResults.firstWhere((n) => n.nozzleNumber == 2);

      // N1: Gross 295.13 L, Mandatory 5.00 L test deduction -> Net 290.13 L
      expect(p1N1.grossLitres, closeTo(295.13, 0.05));
      expect(p1N1.testLitres, closeTo(5.00, 0.01));
      expect(p1N1.billableLitres, closeTo(290.13, 0.05));
      expect(p1N1.fuelSalesRupees, closeTo(34096.0, 1.0));

      // N2: Gross 613.79 L, Mandatory 5.00 L test deduction -> Net 608.79 L
      expect(p1N2.grossLitres, closeTo(613.79, 0.05));
      expect(p1N2.testLitres, closeTo(5.00, 0.01));
      expect(p1N2.billableLitres, closeTo(608.79, 0.05));
      expect(p1N2.fuelSalesRupees, closeTo(64050.0, 1.0));

      // Pump 1 Total Fuel Sales (₹98,146.88)
      expect(p1.totalFuelSalesPaise, closeTo(9814600, 100));

      // Pump 2
      final p2 = dayCalc.pumpResults.firstWhere((p) => p.pump.id == 'pump_2');
      expect(p2.nozzleResults.length, 2);
      final p2N1 = p2.nozzleResults.firstWhere((n) => n.nozzleNumber == 1);
      final p2N2 = p2.nozzleResults.firstWhere((n) => n.nozzleNumber == 2);

      // N1: Gross 314.55 L, Mandatory 5.00 L test -> Net 309.55 L
      expect(p2N1.grossLitres, closeTo(314.55, 0.05));
      expect(p2N1.testLitres, closeTo(5.00, 0.01));
      expect(p2N1.billableLitres, closeTo(309.55, 0.05));
      expect(p2N1.fuelSalesRupees, closeTo(36378.0, 1.0));

      // N2: Gross 638.17 L, Mandatory 5.00 L test -> Net 633.17 L
      expect(p2N2.grossLitres, closeTo(638.17, 0.05));
      expect(p2N2.testLitres, closeTo(5.00, 0.01));
      expect(p2N2.billableLitres, closeTo(633.17, 0.05));
      expect(p2N2.fuelSalesRupees, closeTo(66615.0, 1.0));

      // Station Totals
      expect(dayCalc.totalMsLitres, closeTo(599.68, 0.1));
      expect(dayCalc.totalHsdLitres, closeTo(1241.96, 0.1));
      expect(dayCalc.totalNetLitres, closeTo(1841.64, 0.1));
      expect(dayCalc.totalFuelSalesPaise, closeTo(20113900, 300)); // ₹2,01,139~₹2,01,141
    });

    test('2. Multiple scans on a date resolve first recording as opening and latest recording as closing', () {
      final testDate = DateTime(2026, 11, 15);

      // Morning scan (first recording of the day)
      final morningScan = ReceiptScan(
        id: 'scan_morning_1',
        pumpSerialNumber: '202501001272',
        fpId: '1',
        printedDate: '15/11/2026',
        printedTime: '06:00:00',
        nozzleCumVolumeMl: const {
          1: 170000000, // 170,000.00 L
          2: 275000000, // 275,000.00 L
        },
        imagePath: 'test/path/morning.jpg',
        validationStatus: ReceiptValidationStatus.valid,
        statusMessage: 'Morning baseline recorded',
        capturedBy: 'Srikanth',
        capturedAt: DateTime(2026, 11, 15, 6, 0),
        reviewStatus: 'approved',
      );

      // Evening scan (ending recording of the day)
      final eveningScan = ReceiptScan(
        id: 'scan_evening_1',
        pumpSerialNumber: '202501001272',
        fpId: '1',
        printedDate: '15/11/2026',
        printedTime: '21:00:00',
        nozzleCumVolumeMl: const {
          1: 170305000, // 170,305.00 L (+305 L gross)
          2: 275505000, // 275,505.00 L (+505 L gross)
        },
        imagePath: 'test/path/evening.jpg',
        validationStatus: ReceiptValidationStatus.valid,
        statusMessage: 'Evening shift closing recorded',
        capturedBy: 'Srikanth',
        capturedAt: DateTime(2026, 11, 15, 21, 0),
        reviewStatus: 'approved',
      );

      provider.saveReceiptScan(morningScan);
      provider.saveReceiptScan(eveningScan);

      final dayCalc = provider.getDayCalculation(testDate);
      final p1 = dayCalc.pumpResults.firstWhere((p) => p.pump.id == 'pump_1');
      final p1N1 = p1.nozzleResults.firstWhere((n) => n.nozzleNumber == 1);

      // Opening is first scan (170,000 L)
      expect(p1N1.openingLitres, closeTo(170000.0, 0.01));
      // Closing is evening scan (170,305 L)
      expect(p1N1.closingLitres, closeTo(170305.0, 0.01));
      // Gross is 305 L
      expect(p1N1.grossLitres, closeTo(305.0, 0.01));
      // Mandatory test deduction is 5 L
      expect(p1N1.testLitres, closeTo(5.0, 0.01));
      // Net sold is 300 L
      expect(p1N1.billableLitres, closeTo(300.0, 0.01));
      // At rate ₹117.52, amount is 300 * 117.52 = ₹35,256
      expect(p1N1.fuelSalesRupees, closeTo(35256.0, 1.0));
    });

    test('3. Date isolation: Past or future date with no scans or entries returns zero and hasData false', () {
      final emptyDate = DateTime(2025, 5, 20);
      final dayCalc = provider.getDayCalculation(emptyDate);

      expect(dayCalc.hasData, isFalse);
      expect(dayCalc.totalGrossLitres, 0.0);
      expect(dayCalc.totalNetLitres, 0.0);
      expect(dayCalc.totalFuelSalesPaise, 0);
      expect(dayCalc.recordedSalesPaise, 0);
      expect(dayCalc.cashSalesPaise, 0);
      expect(dayCalc.phonePeSalesPaise, 0);
      expect(dayCalc.creditSalesPaise, 0);
      expect(dayCalc.cashGivenToOwnerPaise, 0);
    });

    test('4. Live update: Adding a transaction entry immediately affects date calculation', () {
      final today = DateTime.now();
      final beforeCalc = provider.getDayCalculation(today);
      final beforeCash = beforeCalc.cashSalesPaise;

      final entry = TransactionEntry(
        id: 'test_cash_${DateTime.now().millisecondsSinceEpoch}',
        shiftId: 'shift_morning',
        category: EntryCategory.cash,
        direction: EntryDirection.received,
        amountPaise: 150000, // ₹1,500
        reference: 'Live forecourt test cash',
        createdAt: today,
        createdBy: 'Srikanth',
      );

      provider.addTransactionEntry(entry);

      final afterCalc = provider.getDayCalculation(today);
      expect(afterCalc.cashSalesPaise, beforeCash + 150000);
      expect(afterCalc.recordedSalesPaise, beforeCalc.recordedSalesPaise + 150000);
    });

    test('5. Mid-day fuel price change partitions volumes and updates total amount accurately from time of change', () {
      final testDate = DateTime(2026, 11, 20);

      // Morning scan (06:00) with rate ₹105.00/L (10500 paise)
      final morningScan = ReceiptScan(
        id: 'scan_price_test_morning',
        pumpSerialNumber: '202501001272',
        fpId: '1',
        printedDate: '20/11/2026',
        printedTime: '06:00:00',
        nozzleCumVolumeMl: const {1: 170000000, 2: 275000000},
        nozzleRatesPaisePerLitre: const {1: 10500, 2: 9500},
        imagePath: 'test/path/morning.jpg',
        validationStatus: ReceiptValidationStatus.valid,
        statusMessage: 'Morning opening readings',
        capturedBy: 'Srikanth',
        capturedAt: DateTime(2026, 11, 20, 6, 0),
        reviewStatus: 'approved',
      );

      // Mid-day scan (14:00) where petrol price increased to ₹107.50/L (10750 paise)
      final midDayScan = ReceiptScan(
        id: 'scan_price_test_midday',
        pumpSerialNumber: '202501001272',
        fpId: '1',
        printedDate: '20/11/2026',
        printedTime: '14:00:00',
        nozzleCumVolumeMl: const {
          1: 170305000, // 305 L gross sold before price change
          2: 275200000,
        },
        nozzleRatesPaisePerLitre: const {1: 10750, 2: 9500}, // New petrol rate from 14:00 onwards
        imagePath: 'test/path/midday.jpg',
        validationStatus: ReceiptValidationStatus.valid,
        statusMessage: 'Price revision reading captured',
        capturedBy: 'Srikanth',
        capturedAt: DateTime(2026, 11, 20, 14, 0),
        reviewStatus: 'approved',
      );

      // Evening closing scan (22:00)
      final eveningScan = ReceiptScan(
        id: 'scan_price_test_evening',
        pumpSerialNumber: '202501001272',
        fpId: '1',
        printedDate: '20/11/2026',
        printedTime: '22:00:00',
        nozzleCumVolumeMl: const {
          1: 170805000, // 500 L gross sold after price change
          2: 275600000,
        },
        nozzleRatesPaisePerLitre: const {1: 10750, 2: 9500},
        imagePath: 'test/path/evening.jpg',
        validationStatus: ReceiptValidationStatus.valid,
        statusMessage: 'Day closing reading',
        capturedBy: 'Srikanth',
        capturedAt: DateTime(2026, 11, 20, 22, 0),
        reviewStatus: 'approved',
      );

      provider.saveReceiptScan(morningScan);
      provider.saveReceiptScan(midDayScan);
      provider.saveReceiptScan(eveningScan);

      final dayCalc = provider.getDayCalculation(testDate);
      final p1 = dayCalc.pumpResults.firstWhere((p) => p.pump.id == 'pump_1');
      final p1N1 = p1.nozzleResults.firstWhere((n) => n.nozzleNumber == 1);

      // Verify segmentation
      expect(p1N1.hasPriceChange, isTrue);
      expect(p1N1.segments.length, 2);

      // Total gross: 805 L, test: 5 L, billable: 800 L
      expect(p1N1.grossLitres, closeTo(805.0, 0.01));
      expect(p1N1.testLitres, closeTo(5.0, 0.01));
      expect(p1N1.billableLitres, closeTo(800.0, 0.01));

      // Segment 1 (pre-price-change): 305 L gross - 5 L test = 300 L net @ ₹105.00 = ₹31,500.00
      final seg1 = p1N1.segments[0];
      expect(seg1.grossLitres, closeTo(305.0, 0.01));
      expect(seg1.testLitres, closeTo(5.0, 0.01));
      expect(seg1.billableLitres, closeTo(300.0, 0.01));
      expect(seg1.rateRupees, closeTo(105.00, 0.01));
      expect(seg1.amountRupees, closeTo(31500.00, 0.01));

      // Segment 2 (post-price-change): 500 L gross - 0 L test = 500 L net @ ₹107.50 = ₹53,750.00
      final seg2 = p1N1.segments[1];
      expect(seg2.grossLitres, closeTo(500.0, 0.01));
      expect(seg2.testLitres, closeTo(0.0, 0.01));
      expect(seg2.billableLitres, closeTo(500.0, 0.01));
      expect(seg2.rateRupees, closeTo(107.50, 0.01));
      expect(seg2.amountRupees, closeTo(53750.00, 0.01));

      // Total fuel sales amount: ₹31,500 + ₹53,750 = ₹85,250.00
      expect(p1N1.fuelSalesPaise, 8525000);
      expect(p1N1.fuelSalesRupees, closeTo(85250.00, 0.01));
    });
  });
}
