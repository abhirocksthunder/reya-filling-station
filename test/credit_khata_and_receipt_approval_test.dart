import 'package:flutter_test/flutter_test.dart';
import 'package:reya_filling_station/models/receipt_scan.dart';
import 'package:reya_filling_station/models/transaction_entry.dart';
import 'package:reya_filling_station/services/station_state_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Credit Customer Auto-Registration & Khata Tests', () {
    test('1. Recording credit sale auto-registers new customer and sends notification', () {
      final state = StationStateProvider();
      expect(state.creditCustomers.isEmpty, isTrue);

      state.recordCreditSale(
        customerName: 'Ramesh Reddy',
        subtitle: 'Tractor AP16 XX1234',
        amountPaise: 500000, // ₹5,000
        reference: 'Diesel 50L',
        staffName: 'Srikanth',
      );

      // Verify customer registered
      expect(state.creditCustomers.length, equals(1));
      final cust = state.creditCustomers.first;
      expect(cust.name, equals('Ramesh Reddy'));
      expect(cust.subtitle, equals('Tractor AP16 XX1234'));
      expect(cust.pendingAmountPaise, equals(500000));
      expect(cust.formattedPending, equals('₹5,000'));

      // Verify entry was added
      expect(state.entries.length, equals(1));
      expect(state.entries.first.category, equals(EntryCategory.credit));
      expect(state.entries.first.amountPaise, equals(500000));

      // Verify dynamic notification dispatched
      expect(state.notifications.isNotEmpty, isTrue);
      expect(state.notifications.first.title, contains('Credit Sale: ₹5,000'));
    });

    test('2. Additional credit sale for existing customer accumulates pending amount', () {
      final state = StationStateProvider();
      state.recordCreditSale(
        customerName: 'Sri Sai Travels',
        subtitle: 'Bus AP16 YY5678',
        amountPaise: 1000000, // ₹10,000
        staffName: 'Srikanth',
      );

      expect(state.creditCustomers.length, equals(1));
      expect(state.creditCustomers.first.pendingAmountPaise, equals(1000000));

      // Add second credit entry for same customer
      state.recordCreditSale(
        customerName: 'Sri Sai Travels',
        subtitle: 'Bus AP16 YY5678',
        amountPaise: 800000, // ₹8,000
        staffName: 'Srikanth',
      );

      // Still 1 unique customer with combined balance of ₹18,000
      expect(state.creditCustomers.length, equals(1));
      expect(state.creditCustomers.first.pendingAmountPaise, equals(1800000));
      expect(state.creditCustomers.first.formattedPending, equals('₹18,000'));
    });

    test('3. Recording credit payment deducts balance and records payment history', () {
      final state = StationStateProvider();
      state.recordCreditSale(
        customerName: 'Kishore Farmer',
        subtitle: 'Field Pump',
        amountPaise: 1500000, // ₹15,000
        staffName: 'Srikanth',
      );

      final custId = state.creditCustomers.first.id;

      // Partial payment
      state.recordCreditPayment(custId, 500000, 'Cash'); // ₹5,000 paid

      final updated = state.creditCustomers.first;
      expect(updated.pendingAmountPaise, equals(1000000)); // ₹10,000 remaining
      expect(updated.payments.length, equals(1));
      expect(updated.payments.first.amountPaise, equals(500000));
      expect(updated.payments.first.mode, equals('Cash'));
    });
  });

  group('Receipt Approval Workflow & Owner Direct Upload Tests', () {
    test('4. Staff scan defaults to pending review and can be approved by owner', () {
      final state = StationStateProvider();

      final staffScan = ReceiptScan(
        id: 'scan_staff_1',
        pumpSerialNumber: '202501001272',
        fpId: '1',
        printedDate: '10/10/2026',
        printedTime: '18:30:00',
        nozzleCumVolumeMl: {1: 175000000, 2: 280000000},
        imagePath: 'assets/images/media_1791616403909.jpg',
        validationStatus: ReceiptValidationStatus.valid,
        statusMessage: 'Verified OCR capture',
        capturedBy: 'Srikanth (live capture)',
        capturedAt: DateTime.now(),
        reviewStatus: 'pending',
      );

      state.saveReceiptScan(staffScan);

      expect(state.receipts.length, equals(1));
      expect(state.receipts.first.reviewStatus, equals('pending'));

      // Owner approves the receipt
      state.approveReceipt('scan_staff_1');

      expect(state.receipts.first.reviewStatus, equals('approved'));
      expect(state.receipts.first.statusMessage, contains('Approved by Owner'));

      // Nozzles updated to approved readings
      final pump1 = state.pumps.firstWhere((p) => p.id == 'pump_1');
      expect(pump1.nozzles[0].currentTotaliserMl, equals(175000000));
      expect(pump1.nozzles[1].currentTotaliserMl, equals(280000000));
    });

    test('5. Owner uploaded receipts are automatically approved without requiring review', () {
      final state = StationStateProvider();

      final ownerScan = ReceiptScan(
        id: 'scan_owner_1',
        pumpSerialNumber: '202501001272',
        fpId: '1',
        printedDate: '10/10/2026',
        printedTime: '19:00:00',
        nozzleCumVolumeMl: {1: 176000000, 2: 281000000},
        imagePath: 'assets/images/media_1791616403909.jpg',
        validationStatus: ReceiptValidationStatus.valid,
        statusMessage: 'Owner upload',
        capturedBy: 'Kalyan (Owner Upload)',
        capturedAt: DateTime.now(),
      );

      state.saveReceiptScan(ownerScan);

      expect(state.receipts.length, equals(1));
      expect(state.receipts.first.reviewStatus, equals('approved'));
    });
  });
}
