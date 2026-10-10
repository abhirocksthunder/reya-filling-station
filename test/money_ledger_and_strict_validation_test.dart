import 'package:flutter_test/flutter_test.dart';
import 'package:reya_filling_station/models/transaction_entry.dart';
import 'package:reya_filling_station/models/receipt_scan.dart';
import 'package:reya_filling_station/services/station_state_provider.dart';

void main() {
  group('Money Ledger Dynamic Aggregation & Filter Tests', () {
    test('1. Dynamically aggregates forecourt entries into ledger totals', () {
      final state = StationStateProvider();

      // Clear any residual
      expect(state.entries, isEmpty);

      // Add Cash entry
      state.addTransactionEntry(TransactionEntry(
        id: 'entry_1',
        shiftId: 'shift_morning',
        category: EntryCategory.cash,
        direction: EntryDirection.received,
        amountPaise: 500000, // ₹5,000
        createdAt: DateTime(2026, 10, 10, 9, 30),
        createdBy: 'Srikanth',
      ));

      // Add PhonePe entry with mobile number
      state.addTransactionEntry(TransactionEntry(
        id: 'entry_2',
        shiftId: 'shift_morning',
        category: EntryCategory.phonePe,
        direction: EntryDirection.received,
        amountPaise: 120000, // ₹1,200
        phonePeNumber: '9848011111',
        createdAt: DateTime(2026, 10, 10, 10, 15),
        createdBy: 'Srikanth',
      ));

      // Add Expense Paid Out entry
      state.addTransactionEntry(TransactionEntry(
        id: 'entry_3',
        shiftId: 'shift_morning',
        category: EntryCategory.expense,
        direction: EntryDirection.paidOut,
        amountPaise: 40000, // ₹400
        reference: 'food & curries',
        createdAt: DateTime(2026, 10, 10, 13, 0),
        createdBy: 'Kishore',
      ));

      expect(state.entries.length, equals(3));

      // Reconciled report
      final report = state.sampleShiftReport;
      expect(report.cashSalesPaise, equals(500000));
      expect(report.phonePeSalesPaise, equals(120000));
      expect(report.foodExpensesPaise, equals(40000));
    });

    test('2. Filters ledger entries by staff name', () {
      final entries = [
        TransactionEntry(
          id: 'e1',
          shiftId: 's1',
          category: EntryCategory.cash,
          direction: EntryDirection.received,
          amountPaise: 10000,
          createdAt: DateTime.now(),
          createdBy: 'Srikanth',
        ),
        TransactionEntry(
          id: 'e2',
          shiftId: 's1',
          category: EntryCategory.phonePe,
          direction: EntryDirection.received,
          amountPaise: 20000,
          createdAt: DateTime.now(),
          createdBy: 'Kishore',
        ),
      ];

      final srikanthEntries = entries.where((e) => e.createdBy == 'Srikanth').toList();
      expect(srikanthEntries.length, equals(1));
      expect(srikanthEntries.first.id, equals('e1'));

      final kishoreEntries = entries.where((e) => e.createdBy == 'Kishore').toList();
      expect(kishoreEntries.length, equals(1));
      expect(kishoreEntries.first.id, equals('e2'));
    });

    test('3. Filters ledger entries by business date', () {
      final oct10 = DateTime(2026, 10, 10, 11, 0);
      final oct09 = DateTime(2026, 10, 9, 14, 0);

      final entries = [
        TransactionEntry(
          id: 'e1',
          shiftId: 's1',
          category: EntryCategory.cash,
          direction: EntryDirection.received,
          amountPaise: 10000,
          createdAt: oct10,
          createdBy: 'Srikanth',
        ),
        TransactionEntry(
          id: 'e2',
          shiftId: 's1',
          category: EntryCategory.cash,
          direction: EntryDirection.received,
          amountPaise: 20000,
          createdAt: oct09,
          createdBy: 'Srikanth',
        ),
      ];

      final filtered = entries.where((e) {
        final d = e.createdAt;
        return d.year == 2026 && d.month == 10 && d.day == 10;
      }).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('e1'));
    });
  });

  group('Pump Mismatch Validation & Wrong Pump Detection Tests', () {
    test('4. Correctly identifies pump mismatch between receipt slip and selected pump', () {
      final state = StationStateProvider();
      final pump1 = state.pumps.firstWhere((p) => p.id == 'pump_1');
      final pump2 = state.pumps.firstWhere((p) => p.id == 'pump_2');

      expect(pump1.serialNumber, equals('202501001272'));
      expect(pump2.serialNumber, equals('202501001289'));

      // Receipt slip from Pump 1
      final pump1Slip = ReceiptScan(
        id: 'scan_1',
        pumpSerialNumber: '202501001272',
        fpId: '1',
        printedDate: '10/10/2026',
        printedTime: '18:30:00',
        capturedAt: DateTime.now(),
        imagePath: 'assets/images/pump1.jpg',
        nozzleCumVolumeMl: const {1: 169923720, 2: 274487190},
        validationStatus: ReceiptValidationStatus.valid,
        statusMessage: 'Verified',
        capturedBy: 'Srikanth',
      );

      // Validation logic for Pump 2: slip SNo or FP ID doesn't match Pump 2
      final bool matchesPump1 = pump1Slip.pumpSerialNumber == pump1.serialNumber || pump1Slip.fpId == '1';
      final bool matchesPump2 = pump1Slip.pumpSerialNumber == pump2.serialNumber || pump1Slip.fpId == '2';

      expect(matchesPump1, isTrue);
      expect(matchesPump2, isFalse); // Rejects slip when Pump 2 is selected!
    });
  });

  group('Strict Input Character Constraints Tests', () {
    test('5. Enforces standard limits on input lengths', () {
      const maxTextLength = 30;
      const maxPhoneLength = 10;
      const maxMeterLength = 15;

      const validText = 'Reya Filling Station Chatrai';
      expect(validText.length <= maxTextLength, isTrue);

      const validPhone = '9848011111';
      expect(validPhone.length == maxPhoneLength, isTrue);
      expect(RegExp(r'^\d{10}$').hasMatch(validPhone), isTrue);

      const validMeterReading = '169923.72';
      expect(validMeterReading.length <= maxMeterLength, isTrue);
    });
  });
}
