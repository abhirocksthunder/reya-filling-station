import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reya_filling_station/models/user_profile.dart';
import 'package:reya_filling_station/services/station_state_provider.dart';
import 'package:reya_filling_station/ui/owner/station_overview_screen.dart';
import 'package:reya_filling_station/ui/owner/daily_report_screen.dart';
import 'package:reya_filling_station/ui/owner/widgets/owner_ai_analytics_panel.dart';
import 'package:reya_filling_station/ui/staff/widgets/cash_handover_workflow_card.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<StationStateProvider> open(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, width > 1000 ? 1600 : 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = StationStateProvider();
    await state.seedSampleUseCaseDataToFirestore();
    state.switchUser(
      state.allUsers.firstWhere((u) => u.role == UserRole.owner),
    );
    state.setLanguage('en');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          home: Scaffold(body: StationOverviewScreen(onNavigate: (_) {})),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> select(WidgetTester tester, String id) async {
    final tab = find.byKey(ValueKey('overview-section-$id'));
    await tester.ensureVisible(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  for (final width in [360.0, 430.0, 3840.0]) {
    testWidgets(
      'Focused overview sections render and remain accessible at ${width}px',
      (tester) async {
        await open(tester, width);
        expect(find.text('Fuel Sales (To Receive)'), findsOneWidget);
        expect(find.byType(OwnerAiAnalyticsPanel), findsNothing);
        expect(find.byType(CashHandoverWorkflowCard), findsNothing);
        expect(
          find.text('Team App Versions & Live Location (1m Sync)'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await select(tester, 'operations');
        expect(
          find.text("Today's Dispenser Meter Readings & Fuel Sales"),
          findsOneWidget,
        );
        expect(find.byType(OwnerAiAnalyticsPanel), findsNothing);
        expect(tester.takeException(), isNull);
        await select(tester, 'team');
        expect(find.textContaining('Team App Versions'), findsOneWidget);
        expect(find.text('Fuel Sales (To Receive)'), findsNothing);
        expect(tester.takeException(), isNull);
        await select(tester, 'reports');
        expect(find.byType(DailyReportScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await select(tester, 'insights');
        expect(find.byType(OwnerAiAnalyticsPanel), findsOneWidget);
        expect(
          find.text("Today's Dispenser Meter Readings & Fuel Sales"),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        final content = find.byKey(const ValueKey('overview-content-insights'));
        await tester.drag(content, const Offset(0, -700));
        await tester.pumpAndSettle();
        final summary = find.byKey(const ValueKey('overview-section-summary'));
        await tester.ensureVisible(summary);
        await tester.pumpAndSettle();
        expect(tester.getRect(summary).top, lessThan(220));
        await select(tester, 'summary');
        expect(find.byType(OwnerAiAnalyticsPanel), findsNothing);
      },
    );
  }
  testWidgets(
    'Team paging shows only ten people and reaches the remaining users',
    (tester) async {
      final state = await open(tester, 390);
      for (var i = 0; i < 14; i++) {
        state.addNewUser(
          UserProfile(
            id: 'pager-$i',
            name: 'Pager person $i',
            phoneNumber: '9888877777',
            role: UserRole.shiftStaff,
          ),
        );
      }
      await tester.pumpAndSettle();
      await select(tester, 'team');
      expect(find.text('Pager person 13'), findsNothing);
      final next = find.text('Next');
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.textContaining('Showing 11–20'), findsOneWidget);
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('Pager person 13'), findsOneWidget);
      await select(tester, 'summary');
      await select(tester, 'team');
      expect(find.textContaining('Showing 1–10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Restricted manager does not gain AI, Users or Reports from overview tabs',
    (tester) async {
      final state = await open(tester, 390);
      await select(tester, 'insights');
      state.switchUser(
        const UserProfile(
          id: 'auditor',
          name: 'Auditor',
          phoneNumber: '9888877777',
          role: UserRole.manager,
          permissions: ['station_overview'],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OwnerAiAnalyticsPanel), findsNothing);
      expect(find.byKey(const ValueKey('overview-section-team')), findsNothing);
      expect(
        find.byKey(const ValueKey('overview-section-reports')),
        findsNothing,
      );
      expect(find.text('Fuel Sales (To Receive)'), findsOneWidget);
    },
  );
}
