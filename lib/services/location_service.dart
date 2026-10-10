import 'dart:math';

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
