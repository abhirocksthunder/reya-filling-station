import 'package:flutter_test/flutter_test.dart';
import 'package:reya_filling_station/models/station_settings.dart';
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

    test('5. StationSettings location coordinates and perimeter update correctly', () {
      const defaultSettings = StationSettings();
      expect(defaultSettings.latitude, equals(16.5062));
      expect(defaultSettings.longitude, equals(80.6480));

      final updated = defaultSettings.copyWith(
        stationName: 'Chatrai Bypass Forecourt',
        latitude: 16.5085,
        longitude: 80.6495,
        radiusMeters: 175.0,
      );

      expect(updated.stationName, equals('Chatrai Bypass Forecourt'));
      expect(updated.latitude, equals(16.5085));
      expect(updated.longitude, equals(80.6495));
      expect(updated.radiusMeters, equals(175.0));
    });

    test('6. Geofence evaluation adapts to updated station coordinates', () {
      const newStationLat = 16.5085;
      const newStationLon = 80.6495;
      const newStationRadius = 175.0;

      // Old coordinates (16.5062, 80.6480) are now ~300m away, should fail
      LocationCheckResult oldPointResult = LocationService.evaluateGeofence(
        currentLat: 16.5062,
        currentLon: 80.6480,
        accuracyMeters: 10.0,
        stationLat: newStationLat,
        stationLon: newStationLon,
        stationRadiusMeters: newStationRadius,
        locationServicesEnabled: true,
      );
      expect(oldPointResult.isEligibleForScan, isFalse);
      expect(oldPointResult.state, equals(LocationVerificationState.moveCloser));

      // New point close to updated coordinates should pass
      LocationCheckResult newPointResult = LocationService.evaluateGeofence(
        currentLat: 16.5086,
        currentLon: 80.6495,
        accuracyMeters: 10.0,
        stationLat: newStationLat,
        stationLon: newStationLon,
        stationRadiusMeters: newStationRadius,
        locationServicesEnabled: true,
      );
      expect(newPointResult.isEligibleForScan, isTrue);
      expect(newPointResult.state, equals(LocationVerificationState.atStation));
    });
  });
}
