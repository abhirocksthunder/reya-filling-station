class StationSettings {
  final String stationName;
  final double latitude;
  final double longitude;
  final double radiusMeters; // 100 - 200 meters (default 150)
  final bool checkLocationBeforeScan;
  final Map<String, bool> enabledCategories;
  final String defaultLanguage; // "te" or "en"

  const StationSettings({
    this.stationName = 'Reya Filling Station (Chatrai)',
    this.latitude = 16.5062,
    this.longitude = 80.6480,
    this.radiusMeters = 150.0,
    this.checkLocationBeforeScan = true,
    this.enabledCategories = const {
      'phonePe': true,
      'cash': true,
      'card': true,
      'credit': true,
      'expenses': true,
      'salary': true,
      'cashToOwner': true,
    },
    this.defaultLanguage = 'te',
  });

  StationSettings copyWith({
    String? stationName,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? checkLocationBeforeScan,
    Map<String, bool>? enabledCategories,
    String? defaultLanguage,
  }) {
    return StationSettings(
      stationName: stationName ?? this.stationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      checkLocationBeforeScan: checkLocationBeforeScan ?? this.checkLocationBeforeScan,
      enabledCategories: enabledCategories ?? this.enabledCategories,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
    );
  }
}
