import 'user_profile.dart';

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

class ScreenPermissionItem {
  final String id;
  final String title;
  final String teluguTitle;
  final String subtitle;
  final String group; // 'forecourt' or 'management'

  const ScreenPermissionItem({
    required this.id,
    required this.title,
    required this.teluguTitle,
    required this.subtitle,
    required this.group,
  });
}

class CustomRoleItem {
  final String id;
  final String name;
  final String baseRole; // 'owner', 'admin', 'manager', 'shiftStaff'
  final bool hasOwnerPrivileges;
  final List<String> screenPermissions;

  const CustomRoleItem({
    required this.id,
    required this.name,
    this.baseRole = 'admin',
    this.hasOwnerPrivileges = true,
    required this.screenPermissions,
  });

  UserRole get mappedUserRole {
    if (hasOwnerPrivileges) {
      return baseRole == 'owner' ? UserRole.owner : UserRole.admin;
    }
    return baseRole == 'manager' ? UserRole.manager : UserRole.shiftStaff;
  }

  CustomRoleItem copyWith({
    String? id,
    String? name,
    String? baseRole,
    bool? hasOwnerPrivileges,
    List<String>? screenPermissions,
  }) {
    return CustomRoleItem(
      id: id ?? this.id,
      name: name ?? this.name,
      baseRole: baseRole ?? this.baseRole,
      hasOwnerPrivileges: hasOwnerPrivileges ?? this.hasOwnerPrivileges,
      screenPermissions: screenPermissions ?? this.screenPermissions,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'baseRole': baseRole,
        'hasOwnerPrivileges': hasOwnerPrivileges,
        'screenPermissions': screenPermissions,
      };

  factory CustomRoleItem.fromMap(Map<String, dynamic> map) {
    final perms = map['screenPermissions'] is List
        ? (map['screenPermissions'] as List).map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList()
        : const <String>['my_shift'];
    return CustomRoleItem(
      id: map['id']?.toString() ?? 'role_${DateTime.now().millisecondsSinceEpoch}',
      name: map['name']?.toString() ?? 'Custom Role',
      baseRole: map['baseRole']?.toString() ?? 'admin',
      hasOwnerPrivileges: map['hasOwnerPrivileges'] == true,
      screenPermissions: perms,
    );
  }
}

class StationSettings {
  static const List<ScreenPermissionItem> allScreenPermissions = [
    // Forecourt / Staff Screens
    ScreenPermissionItem(
      id: 'my_shift',
      title: 'My Shift',
      teluguTitle: 'నా షిఫ్ట్',
      subtitle: 'Forecourt shift home & nozzle readings',
      group: 'forecourt',
    ),
    ScreenPermissionItem(
      id: 'scan_receipt',
      title: 'Scan Receipt',
      teluguTitle: 'రసీదు స్కాన్',
      subtitle: 'Camera & OCR scan for IndianOil pump slips',
      group: 'forecourt',
    ),
    ScreenPermissionItem(
      id: 'money_entries',
      title: 'Money Entries',
      teluguTitle: 'డబ్బు పద్దులు',
      subtitle: 'Shift Cash, PhonePe, Card & Expense entries',
      group: 'forecourt',
    ),
    ScreenPermissionItem(
      id: 'close_shift',
      title: 'Close Shift',
      teluguTitle: 'షిఫ్ట్ ముగింపు',
      subtitle: 'Shift reconciliation details & handover submission',
      group: 'forecourt',
    ),
    // Operations / Management Screens
    ScreenPermissionItem(
      id: 'people_management',
      title: 'People & Roles (Users)',
      teluguTitle: 'సిబ్బంది & పాత్రలు',
      subtitle: 'Add/update users (with Owner approval) & share APK',
      group: 'management',
    ),
    ScreenPermissionItem(
      id: 'station_overview',
      title: 'Station Overview',
      teluguTitle: 'స్టేషన్ వివరాలు',
      subtitle: 'Live station sales, shifts & team GPS dashboard',
      group: 'management',
    ),
    ScreenPermissionItem(
      id: 'daily_report',
      title: 'Daily Reports',
      teluguTitle: 'రోజువారీ నివేదిక',
      subtitle: 'Date-isolated daily fuel & cash reconciliation reports',
      group: 'management',
    ),
    ScreenPermissionItem(
      id: 'receipt_inbox',
      title: 'Receipts Inbox',
      teluguTitle: 'రసీదుల ఇన్‌బాక్స్',
      subtitle: 'Verify & approve scanned dispenser receipts',
      group: 'management',
    ),
    ScreenPermissionItem(
      id: 'shift_review',
      title: 'Shift Reviews',
      teluguTitle: 'షిఫ్ట్ సమీక్ష',
      subtitle: 'Approve shift handovers & request staff corrections',
      group: 'management',
    ),
    ScreenPermissionItem(
      id: 'money_ledger',
      title: 'Money Ledger',
      teluguTitle: 'నగదు చిట్టా',
      subtitle: 'Full station received/paid financial ledger',
      group: 'management',
    ),
    ScreenPermissionItem(
      id: 'credit_khata',
      title: 'Credit Khata',
      teluguTitle: 'అరువు ఖాతా',
      subtitle: 'Customer credit balances & payment collections',
      group: 'management',
    ),
    ScreenPermissionItem(
      id: 'pump_setup',
      title: 'Pump Setup',
      teluguTitle: 'పంప్ సెటప్',
      subtitle: 'Configure pumps, nozzles, fuel rates & baselines',
      group: 'management',
    ),
    ScreenPermissionItem(
      id: 'station_settings',
      title: 'Station Settings',
      teluguTitle: 'స్టేషన్ సెట్టింగ్స్',
      subtitle: 'Geofence, categories, shift timings, roles & APK updates',
      group: 'management',
    ),
  ];

  static const Map<String, List<String>> defaultRoleScreenPermissions = {
    'owner': [
      'station_overview',
      'daily_report',
      'receipt_inbox',
      'shift_review',
      'money_ledger',
      'credit_khata',
      'people_management',
      'pump_setup',
      'station_settings',
      'my_shift',
      'scan_receipt',
      'money_entries',
      'close_shift',
    ],
    'admin': [
      'station_overview',
      'daily_report',
      'receipt_inbox',
      'shift_review',
      'money_ledger',
      'credit_khata',
      'people_management',
      'pump_setup',
      'station_settings',
      'my_shift',
      'scan_receipt',
      'money_entries',
      'close_shift',
    ],
    'manager': [
      'my_shift',
      'scan_receipt',
      'money_entries',
      'close_shift',
      'people_management',
    ],
    'shiftStaff': [
      'my_shift',
      'scan_receipt',
      'money_entries',
      'close_shift',
    ],
  };

  final String stationName;
  final double latitude;
  final double longitude;
  final double radiusMeters; // 100 - 200 meters (default 150)
  final bool checkLocationBeforeScan;
  final bool enableLiveLocationTracking; // Feature flag: track user location during active shift
  final bool allowStaffTotaliserCameraScan; // Owner setting: whether staff can take totaliser image
  final String ocrDebugIconAccess; // 'everyone', 'owner_only', 'disabled'
  final List<CategoryItem> categories;
  final Map<String, String> shiftTimings;
  final String defaultLanguage; // "te" or "en"
  final String latestVersion; // Target release version e.g. "1.0.8"
  final int latestBuildNumber; // Target versionCode e.g. 9
  final String updateUrl; // Link to download the updated APK
  final bool forceUpdate; // If true, older app versions must update before continuing
  final String releaseNotes; // Summary of improvements for the user
  final List<String> deletedEntryIds; // Tombstone IDs of permanently deleted entries to prevent stale cache resurrection
  final Map<String, List<String>> roleScreenPermissions; // Role -> allowed screen IDs configured by Owner
  final List<CustomRoleItem> customRoles; // Dynamic custom roles created by Owner/Admin

  const StationSettings({
    this.stationName = 'RFS (Chatrai)',
    this.latitude = 16.5062,
    this.longitude = 80.6480,
    this.radiusMeters = 150.0,
    this.checkLocationBeforeScan = true,
    this.enableLiveLocationTracking = true,
    this.allowStaffTotaliserCameraScan = true,
    this.ocrDebugIconAccess = 'everyone',
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
      'Morning': '9:00 AM - 9:00 PM',
      'Night': '9:00 PM - 9:00 AM',
    },
    this.defaultLanguage = 'te',
    this.latestVersion = '1.0.32',
    this.latestBuildNumber = 33,
    this.updateUrl = 'https://reya-filling-station-chatrai.web.app/static/reya-filling-station-v1.0.32+33.apk',
    this.forceUpdate = true,
    this.releaseNotes = 'v1.0.32: Removed duplicate owner top navigation, hamburger drawer and desktop sidebar. Footer is now the main navigation on all devices; More retains Shifts, Credit, Users, Pumps and Settings. Overview section tabs remain available.',
    this.deletedEntryIds = const ['entry_1791680675746'],
    this.roleScreenPermissions = defaultRoleScreenPermissions,
    this.customRoles = const [],
  });

  List<String> get allRoleKeys => [
        'owner',
        'admin',
        'manager',
        'shiftStaff',
        ...customRoles.map((r) => r.id),
      ];

  String getRoleDisplayName(String roleKey) {
    switch (roleKey) {
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Admin';
      case 'manager':
        return 'Manager';
      case 'shiftStaff':
        return 'Shift staff';
      default:
        for (final cr in customRoles) {
          if (cr.id == roleKey) return cr.name;
        }
        return roleKey;
    }
  }

  bool isOwnerPrivilegedRoleKey(String roleKey) {
    if (roleKey == 'owner' || roleKey == 'admin') return true;
    for (final cr in customRoles) {
      if (cr.id == roleKey) return cr.hasOwnerPrivileges;
    }
    return false;
  }

  /// Returns the effective list of allowed screen IDs for a given user
  List<String> getScreensForUser(UserProfile user) {
    final validIds = allScreenPermissions.map((s) => s.id).toSet();
    List<String> base;
    if (user.permissions.isNotEmpty) {
      base = user.permissions.where((id) => validIds.contains(id)).toList();
    } else {
      final effKey = user.effectiveRoleKey;
      List<String>? customRolePerms;
      for (final cr in customRoles) {
        if (cr.id == effKey) {
          customRolePerms = cr.screenPermissions;
          break;
        }
      }
      final roleList = roleScreenPermissions[effKey] ??
          customRolePerms ??
          roleScreenPermissions[user.role.name] ??
          defaultRoleScreenPermissions[user.role.name] ??
          defaultRoleScreenPermissions['shiftStaff']!;
      base = roleList.where((id) => validIds.contains(id)).toList();
    }

    if (user.hasOwnerPrivileges) {
      // Ensure Owner & Admin always retain access to Overview, People & Roles, and Settings
      for (final requiredOwnerScreen in ['station_overview', 'people_management', 'station_settings']) {
        if (!base.contains(requiredOwnerScreen)) {
          base.add(requiredOwnerScreen);
        }
      }
    }

    if (base.isEmpty) {
      return user.role == UserRole.manager
          ? const ['people_management']
          : const ['my_shift'];
    }
    return base;
  }

  // Backward compatibility getter
  Map<String, bool> get enabledCategories => {
    for (var c in categories) c.id: c.enabled,
  };

  /// Feature flag check for OCR debug icon visibility
  bool canUserSeeOcrDebug(UserProfile? user) {
    if (ocrDebugIconAccess == 'disabled') return false;
    if (ocrDebugIconAccess == 'owner_only') {
      return user != null && (user.hasOwnerPrivileges || user.role == UserRole.manager);
    }
    return true; // 'everyone'
  }

  StationSettings copyWith({
    String? stationName,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? checkLocationBeforeScan,
    bool? enableLiveLocationTracking,
    bool? allowStaffTotaliserCameraScan,
    String? ocrDebugIconAccess,
    List<CategoryItem>? categories,
    Map<String, String>? shiftTimings,
    String? defaultLanguage,
    String? latestVersion,
    int? latestBuildNumber,
    String? updateUrl,
    bool? forceUpdate,
    String? releaseNotes,
    List<String>? deletedEntryIds,
    Map<String, List<String>>? roleScreenPermissions,
    List<CustomRoleItem>? customRoles,
  }) {
    return StationSettings(
      stationName: stationName ?? this.stationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      checkLocationBeforeScan: checkLocationBeforeScan ?? this.checkLocationBeforeScan,
      enableLiveLocationTracking: enableLiveLocationTracking ?? this.enableLiveLocationTracking,
      allowStaffTotaliserCameraScan: allowStaffTotaliserCameraScan ?? this.allowStaffTotaliserCameraScan,
      ocrDebugIconAccess: ocrDebugIconAccess ?? this.ocrDebugIconAccess,
      categories: categories ?? this.categories,
      shiftTimings: shiftTimings ?? this.shiftTimings,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      latestVersion: latestVersion ?? this.latestVersion,
      latestBuildNumber: latestBuildNumber ?? this.latestBuildNumber,
      updateUrl: updateUrl ?? this.updateUrl,
      forceUpdate: forceUpdate ?? this.forceUpdate,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      deletedEntryIds: deletedEntryIds ?? this.deletedEntryIds,
      roleScreenPermissions: roleScreenPermissions ?? this.roleScreenPermissions,
      customRoles: customRoles ?? this.customRoles,
    );
  }

  Map<String, dynamic> toMap() => {
    'stationName': stationName,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
    'checkLocationBeforeScan': checkLocationBeforeScan,
    'enableLiveLocationTracking': enableLiveLocationTracking,
    'allowStaffTotaliserCameraScan': allowStaffTotaliserCameraScan,
    'ocrDebugIconAccess': ocrDebugIconAccess,
    'categories': categories.map((c) => c.toMap()).toList(),
    'shiftTimings': shiftTimings,
    'defaultLanguage': defaultLanguage,
    'latestVersion': latestVersion,
    'latestBuildNumber': latestBuildNumber,
    'updateUrl': updateUrl,
    'forceUpdate': forceUpdate,
    'releaseNotes': releaseNotes,
    'deletedEntryIds': deletedEntryIds,
    'roleScreenPermissions': roleScreenPermissions,
    'customRoles': customRoles.map((r) => r.toMap()).toList(),
  };

  factory StationSettings.fromMap(Map<String, dynamic> map) {
    List<CategoryItem> parsedCategories = [];
    if (map['categories'] is List) {
      parsedCategories = (map['categories'] as List)
          .map((c) => CategoryItem.fromMap(Map<String, dynamic>.from(c)))
          .toList();
    }

    final parsedDeletedIds = <String>{'entry_1791680675746'};
    if (map['deletedEntryIds'] is List) {
      for (final item in (map['deletedEntryIds'] as List)) {
        if (item != null && item.toString().trim().isNotEmpty) {
          parsedDeletedIds.add(item.toString().trim());
        }
      }
    }

    final List<CustomRoleItem> parsedCustomRoles = [];
    if (map['customRoles'] is List) {
      for (final item in (map['customRoles'] as List)) {
        if (item is Map) {
          parsedCustomRoles.add(CustomRoleItem.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    final Map<String, List<String>> parsedRolePerms = {
      for (final entry in defaultRoleScreenPermissions.entries)
        entry.key: List<String>.from(entry.value),
      for (final cr in parsedCustomRoles)
        cr.id: List<String>.from(cr.screenPermissions),
    };
    if (map['roleScreenPermissions'] is Map) {
      final rawMap = Map<String, dynamic>.from(map['roleScreenPermissions'] as Map);
      for (final entry in rawMap.entries) {
        if (entry.value is List) {
          final screens = (entry.value as List)
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();
          if (screens.isNotEmpty) {
            parsedRolePerms[entry.key] = screens;
          }
        }
      }
    }

    final parsedVer = (map['latestVersion'] as String?) ?? '1.0.29';
    final parsedBuild = (map['latestBuildNumber'] as num?)?.toInt() ?? 30;
    final rawUpdateUrl = (map['updateUrl'] as String?) ?? '';
    final resolvedUpdateUrl = (rawUpdateUrl.isEmpty ||
            rawUpdateUrl.contains('/static/reya-filling-station'))
        ? 'https://reya-filling-station-chatrai.web.app/static/reya-filling-station-v$parsedVer+$parsedBuild.apk'
        : rawUpdateUrl;

    return StationSettings(
      stationName: map['stationName'] ?? 'RFS (Chatrai)',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 16.5062,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 80.6480,
      radiusMeters: (map['radiusMeters'] as num?)?.toDouble() ?? 150.0,
      checkLocationBeforeScan: map['checkLocationBeforeScan'] ?? true,
      enableLiveLocationTracking: map['enableLiveLocationTracking'] ?? true,
      allowStaffTotaliserCameraScan: map['allowStaffTotaliserCameraScan'] ?? true,
      ocrDebugIconAccess: map['ocrDebugIconAccess'] ?? 'everyone',
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
        'Morning': '9:00 AM - 9:00 PM',
        'Night': '9:00 PM - 9:00 AM',
      },
      defaultLanguage: map['defaultLanguage'] ?? 'te',
      latestVersion: parsedVer,
      latestBuildNumber: parsedBuild,
      updateUrl: resolvedUpdateUrl,
      forceUpdate: map['forceUpdate'] ?? true,
      releaseNotes: map['releaseNotes'] ?? 'v1.0.29: Added Admin role with full Owner privileges plus a dedicated Role Management & Create Custom Role screen.',
      deletedEntryIds: parsedDeletedIds.toList(),
      roleScreenPermissions: parsedRolePerms,
      customRoles: parsedCustomRoles,
    );
  }
}
