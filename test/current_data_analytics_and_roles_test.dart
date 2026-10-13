import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reya_filling_station/core/formatting/currency_formatter.dart';
import 'package:reya_filling_station/models/user_profile.dart';
import 'package:reya_filling_station/models/transaction_entry.dart';
import 'package:reya_filling_station/models/receipt_scan.dart';
import 'package:reya_filling_station/services/station_state_provider.dart';
import 'package:reya_filling_station/ui/owner/widgets/owner_ai_analytics_panel.dart';
import 'package:reya_filling_station/ui/owner/roles_screen.dart';
import 'package:reya_filling_station/ui/owner/permissions_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<StationStateProvider> seeded() async {
    final state = StationStateProvider();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await state.seedSampleUseCaseDataToFirestore();
    state.switchUser(
      state.allUsers.firstWhere((u) => u.role == UserRole.owner),
    );
    return state;
  }

  Widget app(StationStateProvider state, Widget child) =>
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );

  test(
    'Purge deletes persisted handovers and reload cannot resurrect them',
    () async {
      final state = await seeded();
      expect(state.cashHandovers, isNotEmpty);
      await state.clearAllFirestoreCollections();
      expect(state.cashHandovers, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString('rfs_cash_handovers_list_v4')!),
        isEmpty,
      );
      final reloaded = StationStateProvider();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(reloaded.cashHandovers, isEmpty);
      expect(reloaded.entries, isEmpty);
      expect(reloaded.getDayCalculation(DateTime.now()).totalFuelSalesPaise, 0);
    },
  );

  test('Purged handovers stay deleted when an old cached list returns', () async {
    final state = await seeded();
    final stale = jsonEncode(state.cashHandovers.map((h) => h.toMap()).toList());
    await state.clearAllFirestoreCollections();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rfs_cash_handovers_list_v4', stale);
    final reloaded = StationStateProvider();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(reloaded.cashHandovers, isEmpty);
    expect(prefs.getStringList('rfs_purged_handover_ids_v4'), isNotEmpty);
  });

  testWidgets('Empty data renders no invented charts or tips in every period', (
    tester,
  ) async {
    final state = await tester.runAsync(seeded);
    await tester.runAsync(() => state!.clearAllFirestoreCollections());
    await tester.pumpWidget(app(state!, OwnerAiAnalyticsPanel(state: state)));
    await tester.pumpAndSettle();
    for (final label in ['Today', 'Monthly (30D)', 'Weekly (7D)']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('Nothing to analyse'), findsOneWidget);
      expect(find.text('Payment Collections Pie Chart'), findsNothing);
      expect(find.textContaining('22,500'), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Weekly and monthly include only actual daily sales, without extrapolation',
    (tester) async {
      final state = (await tester.runAsync(seeded))!;
      final expected = CurrencyFormatter.formatPaise(
        state.getDayCalculation(DateTime.now()).totalFuelSalesPaise,
      );
      await tester.pumpWidget(app(state, OwnerAiAnalyticsPanel(state: state)));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Summary: $expected total sales'),
        findsOneWidget,
      );
      expect(find.text('No prior-period sales to compare'), findsOneWidget);
      await tester.tap(find.text('Monthly (30D)'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Summary: $expected total sales'),
        findsOneWidget,
      );
      expect(find.textContaining('14% Morning'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('A delayed upload belongs to printed business date, never two days', () {
    final state = StationStateProvider();
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final receipt = ReceiptScan(
      id: 'late',
      pumpSerialNumber: '1',
      fpId: '1',
      printedDate: '${yesterday.day}/${yesterday.month}/${yesterday.year}',
      printedTime: '10:00',
      nozzleCumVolumeMl: const {},
      imagePath: '',
      validationStatus: ReceiptValidationStatus.valid,
      statusMessage: '',
      capturedBy: 'Test',
      capturedAt: now,
    );
    expect(state.isReceiptOnDate(receipt, yesterday), isTrue);
    expect(state.isReceiptOnDate(receipt, now), isFalse);
  });

  testWidgets('Prior-period growth comes from real daily records', (
    tester,
  ) async {
    final state = (await tester.runAsync(seeded))!;
    await tester.runAsync(() => state.clearAllFirestoreCollections());
    final now = DateTime.now();
    state.entries.add(
      TransactionEntry(
        id: 'paid',
        shiftId: 's',
        category: EntryCategory.phonePe,
        direction: EntryDirection.received,
        amountPaise: 12345,
        createdAt: now,
        createdBy: 'Test',
      ),
    );
    await tester.pumpWidget(app(state, OwnerAiAnalyticsPanel(state: state)));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to analyse'), findsNothing);
    expect(find.textContaining('UPI represents 100.0%'), findsOneWidget);
    expect(find.textContaining('Maruthi Travels'), findsNothing);
    expect(find.textContaining('+12.6%'), findsNothing);
  });

  for (final width in [360.0, 430.0, 1024.0, 3840.0]) {
    testWidgets(
      'Roles and Permissions are separate, responsive destinations at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final state = (await tester.runAsync(seeded))!;
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: state,
            child: const MaterialApp(home: Scaffold(body: RolesScreen())),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Roles'), findsOneWidget);
        expect(find.text('User permission overrides'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: state,
            child: const MaterialApp(home: Scaffold(body: PermissionsScreen())),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Permissions'), findsOneWidget);
        expect(find.text('Create role'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Restricted manager cannot open role or permission editors', (
    tester,
  ) async {
    final state = (await tester.runAsync(seeded))!;
    state.switchUser(
      state.allUsers.firstWhere((u) => u.role == UserRole.manager),
    );
    for (final screen in [const RolesScreen(), const PermissionsScreen()]) {
      await tester.pumpWidget(app(state, screen));
      await tester.pumpAndSettle();
      expect(find.text('Owner access required'), findsOneWidget);
    }
  });
}
