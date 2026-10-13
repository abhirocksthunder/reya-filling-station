import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reya_filling_station/main.dart';
import 'package:reya_filling_station/models/user_profile.dart';
import 'package:reya_filling_station/services/station_state_provider.dart';
import 'package:reya_filling_station/ui/owner/owner_shell.dart';
import 'package:reya_filling_station/ui/owner/station_overview_screen.dart';
import 'package:reya_filling_station/ui/owner/daily_report_screen.dart';
import 'package:reya_filling_station/ui/owner/people_management_screen.dart';
import 'package:reya_filling_station/ui/owner/station_settings_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [360.0, 430.0, 3840.0]) {
    testWidgets(
      'Responsive owner navigation retains all destinations at ${width}px',
      (tester) async {
        tester.view.physicalSize = Size(width, width > 1000 ? 2160 : 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final state = StationStateProvider();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        state.switchUser(
          state.allUsers.firstWhere((u) => u.role == UserRole.owner),
        );
        state.setLanguage('en');
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: state,
            child: const ReyaFillingStationApp(),
          ),
        );
        await tester.pumpAndSettle();
        final shellScaffold = find
            .descendant(
              of: find.byType(OwnerShell),
              matching: find.byType(Scaffold),
            )
            .first;
        final scaffold = tester.widget<Scaffold>(shellScaffold);
        expect(scaffold.drawer, isNull);
        expect(find.byIcon(Icons.menu_rounded), findsNothing);
        if (width >= 1024) {
          expect(find.byType(BottomNavigationBar), findsNothing);
          final menu = find.byKey(const ValueKey('owner-desktop-menu'));
          expect(menu, findsOneWidget);
          await tester.tap(
            find.descendant(of: menu, matching: find.text('Reports')),
          );
          await tester.pumpAndSettle();
          expect(find.byType(DailyReportScreen), findsOneWidget);
          for (final label in ['Roles', 'Permissions', 'Users', 'Settings']) {
            await tester.tap(
              find.descendant(of: menu, matching: find.text(label)),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
          return;
        }
        expect(find.byType(BottomNavigationBar), findsOneWidget);
        expect(find.text('Overview'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('overview-section-summary')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('overview-section-operations')),
          findsOneWidget,
        );
        expect(find.text('RFS'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final nav = find.byType(BottomNavigationBar);
        await tester.tap(
          find.descendant(of: nav, matching: find.text('Reports')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DailyReportScreen), findsOneWidget);
        await tester.tap(
          find.descendant(of: nav, matching: find.text('Overview')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(StationOverviewScreen), findsOneWidget);
        await tester.tap(find.descendant(of: nav, matching: find.text('More')));
        await tester.pumpAndSettle();
        expect(find.text('More Station Controls'), findsOneWidget);
        expect(find.text('Full Drawer'), findsNothing);
        for (final label in [
          'Shifts',
          'Credit',
          'Users',
          'Pumps',
          'Settings',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        await tester.tap(find.text('Users'));
        await tester.pumpAndSettle();
        expect(find.byType(PeopleManagementScreen), findsOneWidget);
        expect(tester.widget<BottomNavigationBar>(nav).currentIndex, 4);
        await tester.tap(find.descendant(of: nav, matching: find.text('More')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Settings'));
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(find.byType(StationSettingsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
