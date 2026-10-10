import 'package:flutter_test/flutter_test.dart';
import 'package:reya_filling_station/services/location_service.dart';

void main() {
  group('LocationService Uncertainty-Aware Geofence Tests', () {
    const double stationLat = 16.5062;
    const double stationLon = 80.6480;
    const double stationRadius = 150.0;

    test('1. Within station perimeter with high accuracy (Pass)', () {
      // Point approximately 20m away
      LocationCheckResult result = LocationService.evaluateGeofence(
        currentLat: 16.50635,
        currentLon: 80.64805,
        accuracyMeters: 8.0,
        stationLat: stationLat,
        stationLon: stationLon,
        stationRadiusMeters: stationRadius,
        locationServicesEnabled: true,
      );

      expect(result.state, equals(LocationVerificationState.atStation));
      expect(result.isEligibleForScan, isTrue);
    });

    test('2. Near boundary where distance + accuracy exceeds 150m (Move Closer)', () {
      // Point approximately 140m away with 20m accuracy (effective boundary = 160m > 150m)
      LocationCheckResult result = LocationService.evaluateGeofence(
        currentLat: 16.5074,
        currentLon: 80.6480,
        accuracyMeters: 20.0,
        stationLat: stationLat,
        stationLon: stationLon,
        stationRadiusMeters: stationRadius,
        locationServicesEnabled: true,
      );

      expect(result.state, equals(LocationVerificationState.moveCloser));
      expect(result.isEligibleForScan, isFalse);
    });

    test('3. Disabled location services returns turnOnLocation', () {
      LocationCheckResult result = LocationService.evaluateGeofence(
        currentLat: stationLat,
        currentLon: stationLon,
        accuracyMeters: 5.0,
        stationLat: stationLat,
        stationLon: stationLon,
        stationRadiusMeters: stationRadius,
        locationServicesEnabled: false,
      );

      expect(result.state, equals(LocationVerificationState.turnOnLocation));
      expect(result.isEligibleForScan, isFalse);
    });

    test('4. Degraded GPS accuracy (> 25m) returns cannotVerifyLocation', () {
      LocationCheckResult result = LocationService.evaluateGeofence(
        currentLat: stationLat,
        currentLon: stationLon,
        accuracyMeters: 35.0, // Low accuracy!
        stationLat: stationLat,
        stationLon: stationLon,
        stationRadiusMeters: stationRadius,
        locationServicesEnabled: true,
      );

      expect(result.state, equals(LocationVerificationState.cannotVerifyLocation));
      expect(result.isEligibleForScan, isFalse);
    });
  });
}
