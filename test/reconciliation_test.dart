import 'package:flutter_test/flutter_test.dart';
import 'package:reya_filling_station/core/formatting/currency_formatter.dart';
import 'package:reya_filling_station/core/formatting/volume_formatter.dart';
import 'package:reya_filling_station/services/reconciliation_service.dart';

void main() {
  group('ReconciliationService Golden Fixtures', () {
    test('1. Exact Petrol Calculation (Single Nozzle)', () {
      int openingMl = VolumeFormatter.parseToMl('168676.720');
      int closingMl = VolumeFormatter.parseToMl('168971.850');
      int testMl = VolumeFormatter.parseToMl('5.000');
      int ratePaise = CurrencyFormatter.parseToPaise('117.52'); // 11752 paise/L

      expect(openingMl, equals(168676720));
      expect(closingMl, equals(168971850));
      expect(testMl, equals(5000));
      expect(ratePaise, equals(11752));

      NozzleCalculationResult result = ReconciliationService.calculateNozzle(
        nozzleNumber: 1,
        fuelType: 'Petrol',
        openingReadingMl: openingMl,
        closingReadingMl: closingMl,
        testVolumeMl: testMl,
        ratePaisePerLitre: ratePaise,
      );

      expect(result.grossVolumeMl, equals(295130)); // 295.130 L
      expect(result.billableVolumeMl, equals(290130)); // 290.130 L
      expect(result.fuelSalesPaise, equals(3409608)); // ₹34,096.08

      expect(CurrencyFormatter.formatPaise(result.fuelSalesPaise, forceDecimals: true), equals('₹34,096.08'));
    });

    test('2. Exact Diesel Calculation (Second Nozzle)', () {
      int openingMl = VolumeFormatter.parseToMl('273287.210');
      int closingMl = VolumeFormatter.parseToMl('273901.000');
      int testMl = VolumeFormatter.parseToMl('5.000');
      int ratePaise = CurrencyFormatter.parseToPaise('105.21'); // 10521 paise/L

      NozzleCalculationResult result = ReconciliationService.calculateNozzle(
        nozzleNumber: 2,
        fuelType: 'Diesel',
        openingReadingMl: openingMl,
        closingReadingMl: closingMl,
        testVolumeMl: testMl,
        ratePaisePerLitre: ratePaise,
      );

      expect(result.grossVolumeMl, equals(613790)); // 613.790 L
      expect(result.billableVolumeMl, equals(608790)); // 608.790 L
      expect(result.fuelSalesPaise, equals(6405080)); // ₹64,050.80

      expect(CurrencyFormatter.formatPaise(result.fuelSalesPaise, forceDecimals: true), equals('₹64,050.80'));
    });

    test('3. Combined Two-Nozzle Sales Total and Exact Variances', () {
      NozzleCalculationResult petrol = ReconciliationService.calculateNozzle(
        nozzleNumber: 1,
        fuelType: 'Petrol',
        openingReadingMl: 168676720,
        closingReadingMl: 168971850,
        testVolumeMl: 5000,
        ratePaisePerLitre: 11752,
      );

      NozzleCalculationResult diesel = ReconciliationService.calculateNozzle(
        nozzleNumber: 2,
        fuelType: 'Diesel',
        openingReadingMl: 273287210,
        closingReadingMl: 273901000,
        testVolumeMl: 5000,
        ratePaisePerLitre: 10521,
      );

      int totalSalesPaise = petrol.fuelSalesPaise + diesel.fuelSalesPaise;
      expect(totalSalesPaise, equals(9814688)); // ₹98,146.88

      ShiftReconciliationReport report = ReconciliationService.reconcileShift(
        nozzleResults: [petrol, diesel],
        cashSalesPaise: 3054700, // ₹30,547.00
        phonePeSalesPaise: 3306700, // ₹33,067.00
        cardSalesPaise: 453200, // ₹4,532.00
        creditSalesPaise: 3000000, // ₹30,000.00
        openingCashFloatPaise: 0,
        otherCashDebitsPaise: 1737300, // ₹17,373.00 (Bus Bill)
        foodExpensesPaise: 10000, // ₹100.00 (food)
        salaryExpensesPaise: 0,
        cashGivenToOwnerPaise: 1307400, // ₹13,074.00
        countedClosingCashPaise: 0,
      );

      // Accounted payments total = 30547 + 33067 + 4532 + 30000 = ₹98,146.00
      expect(report.totalAccountedPaymentsPaise, equals(9814600));
      // Sales shortage variance due to paper rounding = -88 paise
      expect(report.salesVariancePaise, equals(-88));

      // Cash reconciliation: Cash Sales (30547) - Debits (17373 + 100) - Handover (13074) = 0
      expect(report.expectedClosingCashPaise, equals(0));
      expect(report.cashVariancePaise, equals(0)); // Zero cash variance!
    });

    test('4. Monotonic counter continuity error on lower closing meter', () {
      expect(
        () => ReconciliationService.calculateNozzle(
          nozzleNumber: 1,
          fuelType: 'Petrol',
          openingReadingMl: 100000,
          closingReadingMl: 90000, // Lower!
          testVolumeMl: 0,
          ratePaisePerLitre: 10000,
        ),
        throwsArgumentError,
      );
    });

    test('5. Test volume exceeding gross volume throws ArgumentError', () {
      expect(
        () => ReconciliationService.calculateNozzle(
          nozzleNumber: 1,
          fuelType: 'Petrol',
          openingReadingMl: 100000,
          closingReadingMl: 104000, // Gross 4.000 L
          testVolumeMl: 5000, // Test 5.000 L > Gross
          ratePaisePerLitre: 10000,
        ),
        throwsArgumentError,
      );
    });
  });
}
