import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reya_filling_station/main.dart';
import 'package:reya_filling_station/models/user_profile.dart';
import 'package:reya_filling_station/services/station_state_provider.dart';
import 'package:reya_filling_station/ui/staff/staff_shell.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openShell(
    WidgetTester tester,
    UserRole role, {
    List<String> permissions = const [],
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = StationStateProvider();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    state.setLanguage('en');
    state.switchUser(
      UserProfile(
        id: 'footer_test',
        name: 'Footer Test',
        phoneNumber: '9888877777',
        role: role,
        permissions: permissions,
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const ReyaFillingStationApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder footer(WidgetTester tester) {
    final scaffold = tester.widget<Scaffold>(
      find
          .descendant(
            of: find.byType(StaffShell),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    expect(
      scaffold.bottomNavigationBar,
      isNotNull,
      reason:
          'A permitted screen must retain its footer icon even when it is the only tab.',
    );
    return find.byWidget(scaffold.bottomNavigationBar!);
  }

  for (final role in [UserRole.manager, UserRole.shiftStaff]) {
    testWidgets(
      '${role.name} retains default footer icons and navigates to Scan',
      (tester) async {
        await openShell(tester, role);
        final bar = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(bar.items.length, role == UserRole.manager ? 5 : 4);
        final nav = footer(tester);
        expect(
          find.descendant(
            of: nav,
            matching: find.byIcon(Icons.camera_alt_outlined),
          ),
          findsOneWidget,
        );
        await tester.tap(find.descendant(of: nav, matching: find.text('Scan')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
              .currentIndex,
          1,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final width in [360.0, 430.0, 3840.0]) {
    testWidgets('manager with Users Only retains Users footer at ${width}px', (
      tester,
    ) async {
      await openShell(
        tester,
        UserRole.manager,
        permissions: ['people_management'],
        width: width,
      );
      if (width >= 1024) {
        final menu = find.byKey(const ValueKey('staff-desktop-menu'));
        expect(menu, findsOneWidget);
        expect(find.text('Users'), findsWidgets);
        expect(find.text('Scan'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        return;
      }
      final nav = footer(tester);
      expect(
        find.descendant(of: nav, matching: find.byIcon(Icons.people_rounded)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: nav, matching: find.text('Users')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: nav, matching: find.text('Scan')),
        findsNothing,
      );
      expect(tester.getSize(nav).height, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('staff with only My Shift retains permitted home footer', (
    tester,
  ) async {
    await openShell(tester, UserRole.shiftStaff, permissions: ['my_shift']);
    final nav = footer(tester);
    expect(
      find.descendant(of: nav, matching: find.byIcon(Icons.home)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: nav,
        matching: find.byIcon(Icons.camera_alt_outlined),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
