import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reya_filling_station/models/cash_handover_record.dart';
import 'package:reya_filling_station/models/station_settings.dart';
import 'package:reya_filling_station/models/transaction_entry.dart';
import 'package:reya_filling_station/models/user_profile.dart';
import 'package:reya_filling_station/services/station_state_provider.dart';
import 'package:reya_filling_station/ui/staff/close_shift_screen.dart';
import 'package:reya_filling_station/ui/staff/money_entries_screen.dart';
import 'package:reya_filling_station/ui/staff/widgets/cash_handover_workflow_card.dart';
import 'package:reya_filling_station/ui/owner/station_settings_screen.dart';
import 'package:reya_filling_station/ui/owner/station_overview_screen.dart';
import 'package:reya_filling_station/ui/owner/widgets/owner_ai_analytics_panel.dart';
import 'package:reya_filling_station/ui/owner/widgets/role_management_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('v1.0.28 Use-Cases, IST Time Display, Mobile Alignment & Owner AI Analytics Tests', () {
    test('1. addTransactionEntry guarantees non-empty IST timeString even when empty or null', () {
      final state = StationStateProvider();
      final now = DateTime(2026, 10, 12, 14, 35);

      state.addTransactionEntry(
        TransactionEntry(
          id: 'test_empty_time',
          shiftId: 'shift_morning',
          category: EntryCategory.phonePe,
          direction: EntryDirection.received,
          amountPaise: 125050,
          phonePeNumber: '9848011111',
          createdAt: now,
          timeString: '   ', // Blank string
          createdBy: 'Srinivas',
        ),
      );

      final saved = state.entries.firstWhere((e) => e.id == 'test_empty_time');
      expect(saved.timeString, isNotNull);
      expect(saved.timeString!.trim().isNotEmpty, isTrue);
      expect(saved.timeString, contains('PM'));
    });

    test('2. seedSampleUseCaseDataToFirestore populates multi-user, multi-pump, multi-shift dataset and reconciles Owner Reports', () async {
      final state = StationStateProvider();
      final msg = await state.seedSampleUseCaseDataToFirestore();

      expect(msg, contains('8 Users'));
      expect(state.allUsers.length, 8);
      expect(state.pumps.length, 2);
      expect(state.receipts.length, 4);
      expect(state.entries.length, 13);
      expect(state.creditCustomers.length, 3);
      expect(state.allShifts.length, 2);

      // Every single entry must have an explicit non-empty timeString
      for (final entry in state.entries) {
        expect(entry.timeString, isNotNull);
        expect(entry.timeString!.trim().isNotEmpty, isTrue);
      }

      // Verify Owner Day Calculation for Today
      final dayCalc = state.getDayCalculation(DateTime.now());
      expect(dayCalc.hasData, isTrue);
      // Net litres: Pump 1 (850L MS + 1200L HSD = 2050L) + Pump 2 (640L MS + 950L HSD = 1590L) = 3640.0 L
      expect(dayCalc.totalMsLitres, closeTo(1490.0, 0.01));
      expect(dayCalc.totalHsdLitres, closeTo(2150.0, 0.01));
      expect(dayCalc.totalNetLitres, closeTo(3640.0, 0.01));

      // Total Fuel Sales = ₹4,01,306.30 (40130630 paise)
      expect(dayCalc.totalFuelSalesPaise, 40130630);
      // Recorded Sales = Cash (13185580) + PhonePe (16065050) + Card (6880000) + Credit (4000000) = 40130630 paise
      expect(dayCalc.cashSalesPaise, 13185580);
      expect(dayCalc.phonePeSalesPaise, 16065050);
      expect(dayCalc.cardSalesPaise, 6880000);
      expect(dayCalc.creditSalesPaise, 4000000);
      expect(dayCalc.recordedSalesPaise, 40130630);

      // Paid Out: To Owner = ₹1,10,000.00 (11000000 paise), Food = ₹450.00 (45000), Other = ₹1,200.00 (120000)
      expect(dayCalc.cashGivenToOwnerPaise, 11000000);
      expect(dayCalc.foodExpensesPaise, 45000);
      expect(dayCalc.otherExpensesPaise, 120000);

      // Total Credit Khata pending balance = ₹40,000.00 (4000000 paise)
      final totalKhataPaise = state.creditCustomers.fold<int>(0, (sum, c) => sum + c.pendingAmountPaise);
      expect(totalKhataPaise, 4000000);

      // Shift reconciliation report has zero sales difference
      final report = state.sampleShiftReport;
      expect(report.totalCalculatedFuelSalesPaise, 40130630);
      expect(report.salesVariancePaise, 0);
    });

    testWidgets('3. Mobile viewport (375x812) renders MoneyEntriesScreen with visible IST times and zero overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = StationStateProvider();
      await state.seedSampleUseCaseDataToFirestore();
      final srinivas = state.allUsers.firstWhere((u) => u.name == 'Srinivas');
      state.switchUser(srinivas);

      await tester.pumpWidget(
        ChangeNotifierProvider<StationStateProvider>.value(
          value: state,
          child: const MaterialApp(
            home: Scaffold(
              body: MoneyEntriesScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify explicit IST time pills are visible on mobile cards
      expect(find.text('08:40 AM'), findsWidgets);
      expect(find.text('08:30 AM'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Mobile viewport (375x812) renders StationSettingsScreen tabs for Owner without overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = StationStateProvider();
      await state.seedSampleUseCaseDataToFirestore();
      final kalyan = state.allUsers.firstWhere((u) => u.role == UserRole.owner);
      state.switchUser(kalyan);

      await tester.pumpWidget(
        ChangeNotifierProvider<StationStateProvider>.value(
          value: state,
          child: const MaterialApp(
            home: Scaffold(
              body: StationSettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. Owner-only Minimalistic AI Sales Coach renders Today/Weekly/Monthly graphs, Pie Charts & AI Growth Tips for Owner and hides for Manager/Staff', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = StationStateProvider();
      await state.seedSampleUseCaseDataToFirestore();
      final kalyan = state.allUsers.firstWhere((u) => u.role == UserRole.owner);
      state.switchUser(kalyan);

      await tester.pumpWidget(
        ChangeNotifierProvider<StationStateProvider>.value(
          value: state,
          child: MaterialApp(
            home: Scaffold(
              body: StationOverviewScreen(onNavigate: (_) {}),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 750));

      await tester.ensureVisible(find.byKey(const ValueKey('overview-section-insights')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('overview-section-insights')));
      await tester.pump(const Duration(milliseconds: 750));

      // Verify Owner sees Minimalistic AI Sales Coach, Pie Charts, and AI Tips
      expect(find.byType(OwnerAiAnalyticsPanel), findsOneWidget);
      expect(find.text('AI Sales Intelligence & Weekly/Monthly Analytics'), findsOneWidget);
      expect(find.text('Weekly (7D)'), findsOneWidget);
      expect(find.text('Monthly (30D)'), findsOneWidget);
      expect(find.text('Payment Collections Pie Chart'), findsOneWidget);
      expect(find.text('Fuel Grade Revenue Pie Chart'), findsOneWidget);
      expect(find.text('AI Tips to Increase Station Sales'), findsOneWidget);

      // Switch to Monthly (30D)
      await tester.ensureVisible(find.text('Monthly (30D)'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Monthly (30D)'));
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text('Monthly Sales Trend Graph (Last 30 Days)'), findsOneWidget);

      // Switch to Manager role and verify OwnerAiAnalyticsPanel is hidden
      final rameshManager = state.allUsers.firstWhere((u) => u.role == UserRole.manager);
      state.switchUser(rameshManager);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(OwnerAiAnalyticsPanel), findsNothing);
    });

    testWidgets('6. Admin role shares full Owner privileges (13 screens + AI dashboard) and Custom Roles can be created & managed', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = StationStateProvider();
      await state.seedSampleUseCaseDataToFirestore();

      // Create an Admin user and switch to them
      const adminUser = UserProfile(
        id: 'user_admin_test',
        name: 'Vikram Admin',
        phoneNumber: '9848099988',
        role: UserRole.admin,
      );
      expect(adminUser.hasOwnerPrivileges, isTrue);
      expect(adminUser.role.displayName, 'Admin');
      expect(state.getAllowedScreensForUser(adminUser).length, 13);

      state.switchUser(adminUser);

      await tester.pumpWidget(
        ChangeNotifierProvider<StationStateProvider>.value(
          value: state,
          child: MaterialApp(
            home: Scaffold(
              body: StationOverviewScreen(onNavigate: (_) {}),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 750));

      await tester.ensureVisible(find.byKey(const ValueKey('overview-section-insights')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('overview-section-insights')));
      await tester.pump(const Duration(milliseconds: 750));

      // Admin sees the Owner AI Sales Intelligence panel just like Owner
      expect(find.byType(OwnerAiAnalyticsPanel), findsOneWidget);

      // Create a custom role via addOrUpdateCustomRole
      const customAuditorRole = CustomRoleItem(
        id: 'role_auditor',
        name: 'Station Auditor',
        baseRole: 'manager',
        hasOwnerPrivileges: false,
        screenPermissions: ['station_overview', 'daily_report', 'money_ledger', 'credit_khata'],
      );
      state.addOrUpdateCustomRole(customAuditorRole);

      expect(state.settings.customRoles.any((r) => r.id == 'role_auditor'), isTrue);
      expect(state.settings.getRoleDisplayName('role_auditor'), 'Station Auditor');

      const auditorUser = UserProfile(
        id: 'user_auditor_1',
        name: 'Srinivas Auditor',
        phoneNumber: '9848077766',
        role: UserRole.manager,
        customRoleId: 'role_auditor',
        customRoleName: 'Station Auditor',
      );
      expect(auditorUser.effectiveRoleDisplayName, 'Station Auditor');
      expect(state.getAllowedScreensForUser(auditorUser), ['station_overview', 'daily_report', 'money_ledger', 'credit_khata']);

      // Render RoleManagementDialog and verify no overflow or errors
      await tester.pumpWidget(
        ChangeNotifierProvider<StationStateProvider>.value(
          value: state,
          child: MaterialApp(
            home: Scaffold(
              body: RoleManagementDialog(state: state),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Roles & Create New Role'), findsOneWidget);
      expect(find.text('Admin (Built-in)'), findsOneWidget);
      expect(find.text('Station Auditor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '7. Cash Handover Hierarchy enforces Manager -> Owner/Admin only, clean person names in dropdown, and full Handover Workflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final state = StationStateProvider();
        await state.seedSampleUseCaseDataToFirestore();

        // 1. Login as Manager (Venkat Rao)
        final venkatMgr = state.allUsers.firstWhere((u) => u.name == 'Venkat Rao');
        state.switchUser(venkatMgr);

        final managerEligibleNames = state.getEligibleHandoverReceiverNames();
        // Manager can ONLY hand over to Owners/Admins (Kalyan, Ranjit, Abhilash)
        expect(managerEligibleNames, containsAll(['Kalyan', 'Ranjit', 'Abhilash']));
        // Manager CANNOT hand over to Shift Staff or another Manager or themselves
        expect(managerEligibleNames.contains('Srinivas'), isFalse);
        expect(managerEligibleNames.contains('Anjaneyulu'), isFalse);
        expect(managerEligibleNames.contains('Ramesh Babu'), isFalse);
        expect(managerEligibleNames.contains('Venkat Rao'), isFalse);
        // Dropdown shows ONLY clean names without role prefixes or nameless 'Owner'
        expect(managerEligibleNames.contains('Owner'), isFalse);
        expect(managerEligibleNames.any((n) => n.contains('(') || n.contains(')')), isFalse);

        // Manager attempting to hand over to Shift Staff or another Manager is rejected
        expect(
          state.initiateCashHandover(receiverName: 'Srinivas', amountPaise: 500000),
          isNull,
        );
        expect(
          state.initiateCashHandover(receiverName: 'Ramesh Babu', amountPaise: 500000),
          isNull,
        );

        // 2. Login as Shift Staff (Srinivas) -> can hand over to Manager or Owner/Admin, never Shift Staff
        final srinivasStaff = state.allUsers.firstWhere((u) => u.name == 'Srinivas');
        state.switchUser(srinivasStaff);
        final staffEligibleNames = state.getEligibleHandoverReceiverNames();
        expect(staffEligibleNames, containsAll(['Ramesh Babu', 'Venkat Rao', 'Kalyan', 'Ranjit', 'Abhilash']));
        expect(staffEligibleNames.contains('Srinivas'), isFalse);
        expect(staffEligibleNames.contains('Anjaneyulu'), isFalse);

        // Staff initiates ₹25,000.00 handover to Manager Venkat Rao
        final staffHandover = state.initiateCashHandover(
          receiverName: 'Venkat Rao',
          amountPaise: 2500000,
          note: 'Morning shift collection',
        );
        expect(staffHandover, isNotNull);
        expect(staffHandover!.status, CashHandoverStatus.pending);
        expect(staffHandover.toUserName, 'Venkat Rao');

        // 3. Manager Venkat Rao logs in, accepts cash from Srinivas, and forwards to Owner Kalyan
        state.switchUser(venkatMgr);
        expect(
          state.incomingPendingHandoversForCurrentUser.any((h) => h.id == staffHandover.id),
          isTrue,
        );
        state.acceptCashHandover(staffHandover.id);
        expect(state.managerAcceptedCashFromStaffPaise, 2500000);

        final forwarded = state.forwardHandoverToOwner(
          staffHandover.id,
          ownerReceiverName: 'Kalyan',
        );
        expect(forwarded, isNotNull);
        expect(forwarded!.fromUserName, 'Venkat Rao');
        expect(forwarded.toUserName, 'Kalyan');
        expect(forwarded.status, CashHandoverStatus.pending);

        // 4. Render CloseShiftScreen for Manager Venkat Rao and verify clean dropdown & workflow card
        await tester.pumpWidget(
          ChangeNotifierProvider<StationStateProvider>.value(
            value: state,
            child: const MaterialApp(
              home: Scaffold(
                body: CloseShiftScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CashHandoverWorkflowCard), findsOneWidget);
        expect(find.text('Venkat Rao → Kalyan'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
