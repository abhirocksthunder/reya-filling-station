import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:reya_filling_station/main.dart';
import 'package:reya_filling_station/services/station_state_provider.dart';

void main() {
  testWidgets('App renders Reya Filling Station and basic forecourt controls', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => StationStateProvider(),
        child: const ReyaFillingStationApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reya Filling Station'), findsWidgets);
    expect(find.text('Scan totaliser'), findsOneWidget);
  });
}
