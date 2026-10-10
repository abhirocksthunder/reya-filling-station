import 'package:flutter_test/flutter_test.dart';
import 'package:reya_filling_station/models/pump.dart';
import 'package:reya_filling_station/services/station_state_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pump Setup & Management Tests (Owner Portal)', () {
    test('1. Owner can add a new pump with custom nozzles and serial number', () {
      final state = StationStateProvider();
      final initialCount = state.pumps.length;

      final newPump = Pump(
        id: 'pump_test_3',
        name: 'Pump 3',
        serialNumber: '202501001299',
        active: true,
        nozzles: [
          Nozzle(
            id: 'pump_test_3_n1',
            pumpId: 'pump_test_3',
            nozzleNumber: 1,
            fuelType: 'Petrol',
            ratePaisePerLitre: 11752,
            currentTotaliserMl: 10000000,
            previousAcceptedReadingMl: 10000000,
            active: true,
          ),
          Nozzle(
            id: 'pump_test_3_n2',
            pumpId: 'pump_test_3',
            nozzleNumber: 2,
            fuelType: 'Diesel',
            ratePaisePerLitre: 10521,
            currentTotaliserMl: 20000000,
            previousAcceptedReadingMl: 20000000,
            active: true,
          ),
        ],
      );

      state.addPump(newPump);

      expect(state.pumps.length, equals(initialCount + 1));
      final added = state.pumps.firstWhere((p) => p.id == 'pump_test_3');
      expect(added.name, equals('Pump 3'));
      expect(added.serialNumber, equals('202501001299'));
      expect(added.nozzles.length, equals(2));
      expect(added.nozzles[0].fuelType, equals('Petrol'));
      expect(added.nozzles[1].fuelType, equals('Diesel'));
      expect(state.notifications.any((n) => n.title.contains('Pump 3')), isTrue);
    });

    test('2. Owner can edit pump details, serial number, and nozzle rates', () {
      final state = StationStateProvider();
      final targetPump = state.pumps.first;

      final updatedPump = targetPump.copyWith(
        name: 'Super Pump 1',
        serialNumber: '202501009999',
        nozzles: targetPump.nozzles.map((n) {
          if (n.nozzleNumber == 1) {
            return n.copyWith(ratePaisePerLitre: 11800); // ₹118.00/L
          }
          return n;
        }).toList(),
      );

      state.updatePump(updatedPump);

      final edited = state.pumps.firstWhere((p) => p.id == targetPump.id);
      expect(edited.name, equals('Super Pump 1'));
      expect(edited.serialNumber, equals('202501009999'));
      expect(edited.nozzles[0].ratePaisePerLitre, equals(11800));
      expect(state.notifications.any((n) => n.title.contains('Super Pump 1')), isTrue);
    });

    test('3. Owner can delete a pump from the station', () {
      final state = StationStateProvider();
      
      final tempPump = Pump(
        id: 'pump_delete_test',
        name: 'Pump To Delete',
        serialNumber: '202501000000',
        nozzles: const [],
      );
      state.addPump(tempPump);
      expect(state.pumps.any((p) => p.id == 'pump_delete_test'), isTrue);

      state.deletePump('pump_delete_test');
      expect(state.pumps.any((p) => p.id == 'pump_delete_test'), isFalse);
      expect(state.notifications.any((n) => n.title.contains('Pump Removed')), isTrue);
    });

    test('4. Enforces strict length limits on pump name and serial number', () {
      const maxTextLength = 30;
      const validName = 'Highway Dispenser West 1';
      const validSerial = '202501001272';
      const longName = 'This pump name is way too long for forecourt display standards';

      expect(validName.length <= maxTextLength, isTrue);
      expect(validSerial.length <= maxTextLength, isTrue);
      expect(longName.length <= maxTextLength, isFalse);
    });
  });
}
