import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

enum LocationVerificationState {
  atStation,
  checkingLocation,
  moveCloser,
  turnOnLocation,
  cannotVerifyLocation;

  String get displayText {
    switch (this) {
      case LocationVerificationState.atStation:
        return 'At station';
      case LocationVerificationState.checkingLocation:
        return 'Checking location';
      case LocationVerificationState.moveCloser:
        return 'Move closer';
      case LocationVerificationState.turnOnLocation:
        return 'Turn on location';
      case LocationVerificationState.cannotVerifyLocation:
        return 'Cannot verify location';
    }
  }

  String get teluguText {
    switch (this) {
      case LocationVerificationState.atStation:
        return 'బంకు వద్ద ఉన్నారు (At station)';
      case LocationVerificationState.checkingLocation:
        return 'స్థానం తనిఖీ చేస్తోంది...';
      case LocationVerificationState.moveCloser:
        return 'బంకు పరిధిలోకి రండి';
      case LocationVerificationState.turnOnLocation:
        return 'లొకేషన్ ఆన్ చేయండి';
      case LocationVerificationState.cannotVerifyLocation:
        return 'లొకేషన్ ధృవీకరించలేకపోయింది';
    }
  }
}

class LocationCheckResult {
  final LocationVerificationState state;
  final double distanceMeters;
  final double accuracyMeters;
  final bool isEligibleForScan;
  final String statusDescription;

  const LocationCheckResult({
    required this.state,
    required this.distanceMeters,
    required this.accuracyMeters,
    required this.isEligibleForScan,
    required this.statusDescription,
  });
}

class LocationService {
  static const List<({String name, double lat, double lon, double maxKm})>
      _knownLocations = [
    (name: 'Chatrai, Eluru Dist, AP', lat: 16.9881, lon: 80.7850, maxKm: 12.0),
    (name: 'Vissannapeta, NTR Dist, AP', lat: 16.9355, lon: 80.7939, maxKm: 15.0),
    (name: 'Nuzvid, Eluru Dist, AP', lat: 16.7885, lon: 80.8465, maxKm: 20.0),
    (name: 'Tiruvuru, NTR Dist, AP', lat: 17.1107, lon: 80.6083, maxKm: 20.0),
    (name: 'Chintalapudi, Eluru Dist, AP', lat: 17.0642, lon: 80.9859, maxKm: 20.0),
    (name: 'Vijayawada, AP', lat: 16.5062, lon: 80.6480, maxKm: 25.0),
    (name: 'Eluru, AP', lat: 16.7107, lon: 81.0952, maxKm: 25.0),
    (name: 'Guntur, AP', lat: 16.3067, lon: 80.4365, maxKm: 25.0),
    (name: 'Tirupati / Chittoor, AP', lat: 13.5500, lon: 79.4800, maxKm: 35.0),
    (name: 'Nellore, AP', lat: 14.4426, lon: 79.9865, maxKm: 30.0),
    (name: 'Rajahmundry, AP', lat: 17.0005, lon: 81.8040, maxKm: 30.0),
    (name: 'Visakhapatnam, AP', lat: 17.6868, lon: 83.2185, maxKm: 35.0),
    (name: 'Khammam, TS', lat: 17.2473, lon: 80.1514, maxKm: 30.0),
    (name: 'Hyderabad, TS', lat: 17.3850, lon: 78.4867, maxKm: 45.0),
    (name: 'Chennai, TN', lat: 13.0827, lon: 80.2707, maxKm: 45.0),
    (name: 'Bengaluru, KA', lat: 12.9716, lon: 77.5946, maxKm: 45.0),
  ];

  /// Returns a Google Maps deep link URL for the given coordinates
  static String googleMapsUrl(double lat, double lon) {
    return 'https://www.google.com/maps/search/?api=1&query=${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}';
  }

  /// Opens the given coordinates in Google Maps (external application / browser tab)
  static Future<bool> openInGoogleMaps({
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.parse(googleMapsUrl(lat, lon));
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Resolves a readable location name for display alongside coordinates
  static String resolveLocationName({
    required double lat,
    required double lon,
    double? stationLat,
    double? stationLon,
    double stationRadiusMeters = 150.0,
    String stationName = 'RFS (Chatrai)',
  }) {
    if (stationLat != null && stationLon != null) {
      final distMeters = calculateDistanceMeters(
        lat1: lat,
        lon1: lon,
        lat2: stationLat,
        lon2: stationLon,
      );
      if (distMeters <= stationRadiusMeters + 35.0) {
        return stationName;
      }
      if (distMeters <= 2000) {
        return 'Near $stationName (${distMeters.toStringAsFixed(0)}m)';
      }
    }

    String? bestMatch;
    double bestDistKm = double.infinity;

    for (final loc in _knownLocations) {
      final distKm = calculateDistanceMeters(
            lat1: lat,
            lon1: lon,
            lat2: loc.lat,
            lon2: loc.lon,
          ) /
          1000.0;
      if (distKm <= loc.maxKm && distKm < bestDistKm) {
        bestDistKm = distKm;
        bestMatch = distKm <= 5.0 ? loc.name : 'Near ${loc.name}';
      }
    }

    if (bestMatch != null) {
      return bestMatch;
    }

    return 'GPS (${lat.toStringAsFixed(4)}°N, ${lon.toStringAsFixed(4)}°E)';
  }

  /// Detects whether a stored coordinate pair came from the old 6.5m simulated jitter generator
  static bool isLegacySimulatedCoordinate({
    required double? lat,
    required double? lon,
    required double? accuracy,
  }) {
    if (lat == null || lon == null) return false;
    if (accuracy != null && (accuracy - 6.5).abs() < 0.01) {
      return true;
    }
    if ((lat - 16.5062).abs() < 0.004 && (lon - 80.6480).abs() < 0.004) {
      return true;
    }
    return false;
  }

  /// Acquires real hardware GPS coordinates from Android / iOS / Web browser
  static Future<({double lat, double lon, double accuracy})?> fetchRealDevicePosition() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      try {
        final Position pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
        return (
          lat: pos.latitude,
          lon: pos.longitude,
          accuracy: pos.accuracy > 0 ? pos.accuracy : 10.0,
        );
      } catch (_) {
        if (!kIsWeb) {
          final Position? lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            return (
              lat: lastKnown.latitude,
              lon: lastKnown.longitude,
              accuracy: lastKnown.accuracy > 0 ? lastKnown.accuracy : 15.0,
            );
          }
        }
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// Computes distance in metres between two coordinate pairs using the Haversine formula
  static double calculateDistanceMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double earthRadius = 6371000; // in metres
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) => degree * pi / 180.0;

  /// Uncertainty-aware geofence evaluation:
  /// Distance + Accuracy must be <= stationRadius
  static LocationCheckResult evaluateGeofence({
    required double currentLat,
    required double currentLon,
    required double accuracyMeters,
    required double stationLat,
    required double stationLon,
    required double stationRadiusMeters,
    required bool locationServicesEnabled,
  }) {
    if (!locationServicesEnabled) {
      return const LocationCheckResult(
        state: LocationVerificationState.turnOnLocation,
        distanceMeters: 0,
        accuracyMeters: 0,
        isEligibleForScan: false,
        statusDescription: 'Location services are disabled on this device.',
      );
    }

    if (accuracyMeters > 25.0) {
      return LocationCheckResult(
        state: LocationVerificationState.cannotVerifyLocation,
        distanceMeters: 0,
        accuracyMeters: accuracyMeters,
        isEligibleForScan: false,
        statusDescription: 'GPS accuracy (${accuracyMeters.toStringAsFixed(1)}m) is too low (target <= 25m).',
      );
    }

    double distance = calculateDistanceMeters(
      lat1: currentLat,
      lon1: currentLon,
      lat2: stationLat,
      lon2: stationLon,
    );

    // Uncertainty-aware boundary check:
    // (Distance + Accuracy) must fit inside radius
    double effectiveBoundary = distance + accuracyMeters;

    if (effectiveBoundary <= stationRadiusMeters) {
      return LocationCheckResult(
        state: LocationVerificationState.atStation,
        distanceMeters: distance,
        accuracyMeters: accuracyMeters,
        isEligibleForScan: true,
        statusDescription: 'Within verified station perimeter (${distance.toStringAsFixed(1)}m from center).',
      );
    } else {
      return LocationCheckResult(
        state: LocationVerificationState.moveCloser,
        distanceMeters: distance,
        accuracyMeters: accuracyMeters,
        isEligibleForScan: false,
        statusDescription: 'Outside perimeter (${distance.toStringAsFixed(1)}m > ${stationRadiusMeters.toInt()}m radius).',
      );
    }
  }
}

