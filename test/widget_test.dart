import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reya_filling_station/core/formatting/currency_formatter.dart';
import 'package:reya_filling_station/main.dart';
import 'package:reya_filling_station/models/shift.dart';
import 'package:reya_filling_station/models/transaction_entry.dart';
import 'package:reya_filling_station/models/user_profile.dart';
import 'package:reya_filling_station/services/station_state_provider.dart';
import 'package:reya_filling_station/ui/staff/staff_shell.dart';
import 'package:reya_filling_station/ui/owner/owner_shell.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Zero-Trust Gate: unauthenticated user sees LoginScreen with RFS title', (WidgetTester tester) async {
    final provider = StationStateProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const ReyaFillingStationApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RFS'), findsWidgets);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Email or Mobile Number'), findsOneWidget);
  });

  testWidgets('Shift Staff login opens StaffShell forecourt controls', (WidgetTester tester) async {
    final provider = StationStateProvider();
    final staffUser = provider.allUsers.firstWhere((u) => u.role == UserRole.shiftStaff);
    provider.switchUser(staffUser);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const ReyaFillingStationApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StaffShell), findsOneWidget);
    expect(find.text('Scan totaliser'), findsOneWidget);
    expect(find.text('My shift'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Entries'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('Owner login opens OwnerShell operations portal', (WidgetTester tester) async {
    final provider = StationStateProvider();
    final ownerUser = provider.allUsers.firstWhere((u) => u.role == UserRole.owner);
    provider.switchUser(ownerUser);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const ReyaFillingStationApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OwnerShell), findsOneWidget);
    expect(find.text('Station overview'), findsOneWidget);
  });

  testWidgets('Manager login opens StaffShell with Users tab and never exposes OwnerShell pages', (WidgetTester tester) async {
    final provider = StationStateProvider();
    const managerUser = UserProfile(
      id: 'mgr_test_1',
      name: 'Ramesh Manager',
      phoneNumber: '9888877777',
      role: UserRole.manager,
      securityPin: '2222',
    );
    provider.addNewUser(managerUser);
    provider.switchUser(managerUser);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const ReyaFillingStationApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StaffShell), findsOneWidget);
    expect(find.byType(OwnerShell), findsNothing);
    expect(find.text('Users'), findsOneWidget);
    expect(find.text('Add / Update Users & Share APK'), findsOneWidget);
  });

  test('deleteTransactionEntry removes entry and records tombstone ID in settings', () async {
    final provider = StationStateProvider();
    final entry = TransactionEntry(
      id: 'entry_test_delete_1',
      shiftId: 'shift_morning',
      category: EntryCategory.phonePe,
      direction: EntryDirection.received,
      amountPaise: 500000,
      createdAt: DateTime.now(),
      createdBy: 'Srinivas',
    );
    provider.addTransactionEntry(entry);
    expect(provider.entries.any((e) => e.id == 'entry_test_delete_1'), isTrue);

    await provider.deleteTransactionEntry('entry_test_delete_1');
    expect(provider.entries.any((e) => e.id == 'entry_test_delete_1'), isFalse);
    expect(provider.settings.deletedEntryIds.contains('entry_test_delete_1'), isTrue);
    expect(provider.settings.deletedEntryIds.contains('entry_1791680675746'), isTrue);
  });

  testWidgets('ScanReceiptScreen hides GPS banner from staff and shows full nozzle labels on mobile', (WidgetTester tester) async {
    final provider = StationStateProvider();
    final staffUser = provider.allUsers.firstWhere((u) => u.role == UserRole.shiftStaff);
    provider.switchUser(staffUser);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const ReyaFillingStationApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Live GPS:'), findsNothing);
    expect(find.text('Refresh GPS'), findsNothing);
    expect(find.text('Nozzle 1 (Petrol) Litres'), findsOneWidget);
    expect(find.text('Nozzle 1 (Petrol) Rate (₹/L)'), findsOneWidget);
    expect(find.text('Nozzle 2 (Diesel) Litres'), findsOneWidget);
    expect(find.text('Nozzle 2 (Diesel) Rate (₹/L)'), findsOneWidget);
    expect(find.text('Update if price changed'), findsNWidgets(2));
  });

  test('CurrencyFormatter formats amounts with Indian commas and decimals, and syncs Paid out -> To owner as Cash Handover', () {
    expect(CurrencyFormatter.formatPaise(1200000), equals('₹12,000.00'));
    expect(CurrencyFormatter.formatPaise(12543250), equals('₹1,25,432.50'));
    expect(CurrencyFormatter.formatRupeesInput(1550050), equals('15,500.50'));
    expect(CurrencyFormatter.formatRawInputWithCommas('12000.5'), equals('12,000.5'));

    final provider = StationStateProvider();
    final staffUser = provider.allUsers.firstWhere((u) => u.role == UserRole.shiftStaff);
    provider.switchUser(staffUser);

    // Record Paid out -> To owner entry
    provider.addTransactionEntry(
      TransactionEntry(
        id: 'to_owner_test_1',
        shiftId: provider.activeShift.id,
        category: EntryCategory.toOwner,
        direction: EntryDirection.paidOut,
        amountPaise: 1550050, // ₹15,500.50
        createdAt: DateTime.now(),
        createdBy: staffUser.name,
      ),
    );

    expect(provider.activeShift.cashHandoverPaise, equals(1550050));
    expect(provider.getShiftHandoverToOwnerPaise(provider.activeShift), equals(1550050));
    expect(provider.sampleShiftReport.cashGivenToOwnerPaise, equals(1550050));

    // Verify shift date filtering does not leak today's Needs review onto yesterday
    provider.submitShiftForReview(1550050, handoverReceiver: 'Kalyan');
    expect(provider.activeShift.status, equals(ShiftStatus.needsReview));
    expect(provider.isUserShiftInProgress(staffUser), isFalse);
    expect(provider.isLiveLocationTrackingActive, isFalse);

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    expect(provider.getVisibleShiftsForDate(yesterday), isEmpty);
  });
}
