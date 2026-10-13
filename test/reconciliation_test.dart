import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reya_filling_station/core/formatting/currency_formatter.dart';
import 'package:reya_filling_station/core/formatting/volume_formatter.dart';
import 'package:reya_filling_station/models/shift.dart';
import 'package:reya_filling_station/services/reconciliation_service.dart';
import 'package:reya_filling_station/services/station_state_provider.dart';
import 'package:reya_filling_station/ui/staff/close_shift_screen.dart';
import 'package:reya_filling_station/ui/owner/station_overview_screen.dart';
import 'package:reya_filling_station/ui/owner/shift_review_screen.dart';

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

  group('Shift Submission, Notification, Details Modal & Owner Approval Workflow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('submitShiftForReview updates status, dispatches owner notification, and approveShift/rejectShift update status', () {
      final provider = StationStateProvider();
      final initialNotifs = provider.notifications.length;

      provider.submitShiftForReview(1525000, handoverReceiver: 'Manager Ravi');

      final shift = provider.activeShift;
      expect(shift.status, equals(ShiftStatus.needsReview));
      expect(shift.cashHandoverPaise, equals(1525000));
      expect(shift.handoverReceiver, equals('Manager Ravi'));
      expect(provider.selectedReviewShiftId, equals(shift.id));
      expect(provider.notifications.length, equals(initialNotifs + 1));
      expect(provider.notifications.first.title, contains('Shift Approval Requested'));

      // Approve shift
      provider.approveShift(shift.id);
      expect(provider.activeShift.status, equals(ShiftStatus.approved));
      expect(provider.notifications.first.title, contains('Shift Approved'));

      // Reject / Request correction
      provider.rejectShift(shift.id, reason: 'Recount cash float');
      expect(provider.activeShift.status, equals(ShiftStatus.inProgress));
      expect(provider.activeShift.note, equals('Recount cash float'));
      expect(provider.notifications.first.title, contains('Shift Returned for Correction'));
    });

    testWidgets('CloseShiftScreen View details opens Shift Reconciliation Details modal and Submit notifies owner', (tester) async {
      final provider = StationStateProvider();
      await tester.pumpWidget(
        ChangeNotifierProvider<StationStateProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(
              body: CloseShiftScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "View details" button
      final viewDetailsBtn = find.text('View details');
      expect(viewDetailsBtn, findsOneWidget);
      await tester.ensureVisible(viewDetailsBtn);
      await tester.pumpAndSettle();
      await tester.tap(viewDetailsBtn);
      await tester.pumpAndSettle();

      expect(find.text('Shift Reconciliation Details'), findsOneWidget);
      expect(find.text('Payment & Cash Summary'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Tap "Submit shift for review"
      final submitBtn = find.text('Submit shift for review');
      expect(submitBtn, findsOneWidget);
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(provider.activeShift.status, equals(ShiftStatus.needsReview));
      expect(find.text('Submitted — Awaiting Owner Approval'), findsOneWidget);
    });

    testWidgets('StationOverviewScreen shows Shift Approval Request and navigates to ShiftReviewScreen on tap', (tester) async {
      final provider = StationStateProvider();
      provider.submitShiftForReview(2500000, handoverReceiver: 'Owner');

      int? navigatedTab;
      await tester.pumpWidget(
        ChangeNotifierProvider<StationStateProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: StationOverviewScreen(
                onNavigate: (tabIndex) => navigatedTab = tabIndex,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('overview-section-operations')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('overview-section-operations')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Shift Approval Request'), findsOneWidget);
      final reviewCardBtn = find.text('Approve / Review').first;
      await tester.ensureVisible(reviewCardBtn);
      await tester.pumpAndSettle();
      await tester.tap(reviewCardBtn);
      await tester.pumpAndSettle();

      expect(navigatedTab, equals(2));
      expect(provider.selectedReviewShiftId, equals(provider.activeShift.id));

      // Render ShiftReviewScreen and verify Approve Shift & Handover works
      await tester.pumpWidget(
        ChangeNotifierProvider<StationStateProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(
              body: ShiftReviewScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final approveBtn = find.text('Approve Shift & Handover');
      expect(approveBtn, findsOneWidget);
      await tester.ensureVisible(approveBtn);
      await tester.pumpAndSettle();
      await tester.tap(approveBtn);
      await tester.pumpAndSettle();

      expect(provider.activeShift.status, equals(ShiftStatus.approved));
      expect(find.text('Shift Approved'), findsOneWidget);
    });
  });
}
