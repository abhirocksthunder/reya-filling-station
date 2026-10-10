class CategoryItem {
  final String id;
  final String name;
  final String subtitle;
  final bool enabled;
  final bool isDefault;

  const CategoryItem({
    required this.id,
    required this.name,
    this.subtitle = '',
    this.enabled = true,
    this.isDefault = false,
  });

  CategoryItem copyWith({
    String? id,
    String? name,
    String? subtitle,
    bool? enabled,
    bool? isDefault,
  }) {
    return CategoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      enabled: enabled ?? this.enabled,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'subtitle': subtitle,
    'enabled': enabled,
    'isDefault': isDefault,
  };

  factory CategoryItem.fromMap(Map<String, dynamic> map) => CategoryItem(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    subtitle: map['subtitle'] ?? '',
    enabled: map['enabled'] ?? true,
    isDefault: map['isDefault'] ?? false,
  );
}

class StationSettings {
  final String stationName;
  final double latitude;
  final double longitude;
  final double radiusMeters; // 100 - 200 meters (default 150)
  final bool checkLocationBeforeScan;
  final bool allowStaffTotaliserCameraScan; // Owner setting: whether staff can take totaliser image
  final List<CategoryItem> categories;
  final Map<String, String> shiftTimings;
  final String defaultLanguage; // "te" or "en"

  const StationSettings({
    this.stationName = 'Reya Filling Station (Chatrai)',
    this.latitude = 16.5062,
    this.longitude = 80.6480,
    this.radiusMeters = 150.0,
    this.checkLocationBeforeScan = true,
    this.allowStaffTotaliserCameraScan = true,
    this.categories = const [
      CategoryItem(id: 'phonePe', name: 'PhonePe', subtitle: 'Required number: 10 digits', enabled: true, isDefault: true),
      CategoryItem(id: 'cash', name: 'Cash', enabled: true, isDefault: true),
      CategoryItem(id: 'card', name: 'Card', enabled: true, isDefault: true),
      CategoryItem(id: 'credit', name: 'Credit', enabled: true, isDefault: true),
      CategoryItem(id: 'expenses', name: 'Expenses', enabled: true, isDefault: true),
      CategoryItem(id: 'salary', name: 'Salary', enabled: true, isDefault: true),
      CategoryItem(id: 'cashToOwner', name: 'Cash to owner', enabled: true, isDefault: true),
    ],
    this.shiftTimings = const {
      'Morning': '6:00 AM - 2:00 PM',
      'Evening': '2:00 PM - 10:00 PM',
      'Night': '10:00 PM - 6:00 AM',
    },
    this.defaultLanguage = 'te',
  });

  // Backward compatibility getter
  Map<String, bool> get enabledCategories => {
    for (var c in categories) c.id: c.enabled,
  };

  StationSettings copyWith({
    String? stationName,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? checkLocationBeforeScan,
    bool? allowStaffTotaliserCameraScan,
    List<CategoryItem>? categories,
    Map<String, String>? shiftTimings,
    String? defaultLanguage,
  }) {
    return StationSettings(
      stationName: stationName ?? this.stationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      checkLocationBeforeScan: checkLocationBeforeScan ?? this.checkLocationBeforeScan,
      allowStaffTotaliserCameraScan: allowStaffTotaliserCameraScan ?? this.allowStaffTotaliserCameraScan,
      categories: categories ?? this.categories,
      shiftTimings: shiftTimings ?? this.shiftTimings,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
    );
  }

  Map<String, dynamic> toMap() => {
    'stationName': stationName,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
    'checkLocationBeforeScan': checkLocationBeforeScan,
    'allowStaffTotaliserCameraScan': allowStaffTotaliserCameraScan,
    'categories': categories.map((c) => c.toMap()).toList(),
    'shiftTimings': shiftTimings,
    'defaultLanguage': defaultLanguage,
  };

  factory StationSettings.fromMap(Map<String, dynamic> map) {
    List<CategoryItem> parsedCategories = [];
    if (map['categories'] is List) {
      parsedCategories = (map['categories'] as List)
          .map((c) => CategoryItem.fromMap(Map<String, dynamic>.from(c)))
          .toList();
    }

    return StationSettings(
      stationName: map['stationName'] ?? 'Reya Filling Station (Chatrai)',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 16.5062,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 80.6480,
      radiusMeters: (map['radiusMeters'] as num?)?.toDouble() ?? 150.0,
      checkLocationBeforeScan: map['checkLocationBeforeScan'] ?? true,
      allowStaffTotaliserCameraScan: map['allowStaffTotaliserCameraScan'] ?? true,
      categories: parsedCategories.isNotEmpty ? parsedCategories : const [
        CategoryItem(id: 'phonePe', name: 'PhonePe', subtitle: 'Required number: 10 digits', enabled: true, isDefault: true),
        CategoryItem(id: 'cash', name: 'Cash', enabled: true, isDefault: true),
        CategoryItem(id: 'card', name: 'Card', enabled: true, isDefault: true),
        CategoryItem(id: 'credit', name: 'Credit', enabled: true, isDefault: true),
        CategoryItem(id: 'expenses', name: 'Expenses', enabled: true, isDefault: true),
        CategoryItem(id: 'salary', name: 'Salary', enabled: true, isDefault: true),
        CategoryItem(id: 'cashToOwner', name: 'Cash to owner', enabled: true, isDefault: true),
      ],
      shiftTimings: map['shiftTimings'] != null ? Map<String, String>.from(map['shiftTimings']) : const {
        'Morning': '6:00 AM - 2:00 PM',
        'Evening': '2:00 PM - 10:00 PM',
        'Night': '10:00 PM - 6:00 AM',
      },
      defaultLanguage: map['defaultLanguage'] ?? 'te',
    );
  }
}
