import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:reya_filling_station/main.dart';
import 'package:reya_filling_station/models/user_profile.dart';
import 'package:reya_filling_station/services/station_state_provider.dart';
import 'package:reya_filling_station/ui/staff/staff_shell.dart';
import 'package:reya_filling_station/ui/owner/owner_shell.dart';

void main() {
  testWidgets('Zero-Trust Gate: unauthenticated user sees LoginScreen', (WidgetTester tester) async {
    final provider = StationStateProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const ReyaFillingStationApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reya Filling Station'), findsWidgets);
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
}
