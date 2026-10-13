enum UserRole {
  owner,
  admin,
  manager,
  shiftStaff;

  bool get hasOwnerPrivileges => this == UserRole.owner || this == UserRole.admin;

  String get displayName {
    switch (this) {
      case UserRole.owner:
        return 'Owner';
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Manager';
      case UserRole.shiftStaff:
        return 'Shift staff';
    }
  }

  String get teluguName {
    switch (this) {
      case UserRole.owner:
        return 'యజమాని (Owner)';
      case UserRole.admin:
        return 'అడ్మిన్ (Admin)';
      case UserRole.manager:
        return 'మేనేజర్ (Manager)';
      case UserRole.shiftStaff:
        return 'సిబ్బంది (Staff)';
    }
  }
}

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final UserRole role;
  final String? customRoleId; // Optional custom role ID created in Role Management
  final String? customRoleName; // Optional custom role display label
  final String? assignedShift; // "Morning", "Evening", "Night" (null for owner/admin)
  final String village;
  final String address;
  final String preferredLanguage; // "te" or "en"
  final bool active;
  final bool isOnline;
  final List<String> permissions;
  final String securityPin; // Admin-configured 4-6 digit Security PIN
  final String appVersion; // Tracked installed app version e.g. "v1.0.29+30 (Android)"
  final DateTime? lastSeenAt; // Last login/session timestamp
  final String approvalStatus; // 'approved', 'pending_approval', 'rejected'
  final String? requestedBy; // Manager name who requested user creation/update
  final Map<String, dynamic>? pendingEditData; // Pending user edit payload awaiting Owner approval
  final double? lastLatitude; // Live 1-minute tracked latitude
  final double? lastLongitude; // Live 1-minute tracked longitude
  final double? lastDistanceMeters; // Distance from station center in meters
  final double? lastAccuracyMeters; // GPS accuracy in meters
  final bool? isAtStation; // Whether inside station geofence radius
  final DateTime? locationUpdatedAt; // Last 1-minute location telemetry timestamp
  final String? lastLocationName; // Resolved human-readable location or area name

  const UserProfile({
    required this.id,
    required this.name,
    this.email = '',
    required this.phoneNumber,
    required this.role,
    this.customRoleId,
    this.customRoleName,
    this.assignedShift,
    this.village = 'Chatrai',
    this.address = 'Chatrai, Andhra Pradesh',
    this.preferredLanguage = 'te',
    this.active = true,
    this.isOnline = false,
    this.permissions = const [],
    this.securityPin = '123456',
    this.appVersion = '',
    this.lastSeenAt,
    this.approvalStatus = 'approved',
    this.requestedBy,
    this.pendingEditData,
    this.lastLatitude,
    this.lastLongitude,
    this.lastDistanceMeters,
    this.lastAccuracyMeters,
    this.isAtStation,
    this.locationUpdatedAt,
    this.lastLocationName,
  });

  bool get hasOwnerPrivileges => role.hasOwnerPrivileges;
  String get effectiveRoleKey =>
      (customRoleId != null && customRoleId!.trim().isNotEmpty)
          ? customRoleId!.trim()
          : role.name;
  String get effectiveRoleDisplayName =>
      (customRoleName != null && customRoleName!.trim().isNotEmpty)
          ? customRoleName!.trim()
          : role.displayName;

  bool get isPendingApproval => approvalStatus == 'pending_approval';
  bool get hasPendingEdit => pendingEditData != null && pendingEditData!.isNotEmpty;

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    UserRole? role,
    String? customRoleId,
    String? customRoleName,
    bool clearCustomRole = false,
    String? assignedShift,
    bool clearAssignedShift = false,
    String? village,
    String? address,
    String? preferredLanguage,
    bool? active,
    bool? isOnline,
    List<String>? permissions,
    String? securityPin,
    String? appVersion,
    DateTime? lastSeenAt,
    String? approvalStatus,
    String? requestedBy,
    bool clearRequestedBy = false,
    Map<String, dynamic>? pendingEditData,
    bool clearPendingEditData = false,
    double? lastLatitude,
    double? lastLongitude,
    double? lastDistanceMeters,
    double? lastAccuracyMeters,
    bool? isAtStation,
    DateTime? locationUpdatedAt,
    String? lastLocationName,
    bool clearLocation = false,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      customRoleId: clearCustomRole ? null : (customRoleId ?? this.customRoleId),
      customRoleName: clearCustomRole ? null : (customRoleName ?? this.customRoleName),
      assignedShift: clearAssignedShift ? null : (assignedShift ?? this.assignedShift),
      village: village ?? this.village,
      address: address ?? this.address,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      active: active ?? this.active,
      isOnline: isOnline ?? this.isOnline,
      permissions: permissions ?? this.permissions,
      securityPin: securityPin ?? this.securityPin,
      appVersion: appVersion ?? this.appVersion,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      requestedBy: clearRequestedBy ? null : (requestedBy ?? this.requestedBy),
      pendingEditData: clearPendingEditData ? null : (pendingEditData ?? this.pendingEditData),
      lastLatitude: clearLocation ? null : (lastLatitude ?? this.lastLatitude),
      lastLongitude: clearLocation ? null : (lastLongitude ?? this.lastLongitude),
      lastDistanceMeters: clearLocation ? null : (lastDistanceMeters ?? this.lastDistanceMeters),
      lastAccuracyMeters: clearLocation ? null : (lastAccuracyMeters ?? this.lastAccuracyMeters),
      isAtStation: clearLocation ? null : (isAtStation ?? this.isAtStation),
      locationUpdatedAt: clearLocation ? null : (locationUpdatedAt ?? this.locationUpdatedAt),
      lastLocationName: clearLocation ? null : (lastLocationName ?? this.lastLocationName),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role.name,
      if (customRoleId != null) 'customRoleId': customRoleId,
      if (customRoleName != null) 'customRoleName': customRoleName,
      'assignedShift': assignedShift,
      'village': village,
      'address': address,
      'preferredLanguage': preferredLanguage,
      'active': active,
      'isOnline': isOnline,
      'permissions': permissions,
      'securityPin': securityPin,
      'appVersion': appVersion,
      if (lastSeenAt != null) 'lastSeenAt': lastSeenAt!.toIso8601String(),
      'approvalStatus': approvalStatus,
      if (requestedBy != null) 'requestedBy': requestedBy,
      if (pendingEditData != null) 'pendingEditData': pendingEditData,
      'lastLatitude': lastLatitude,
      'lastLongitude': lastLongitude,
      'lastDistanceMeters': lastDistanceMeters,
      'lastAccuracyMeters': lastAccuracyMeters,
      'isAtStation': isAtStation,
      'locationUpdatedAt': locationUpdatedAt?.toIso8601String(),
      'lastLocationName': lastLocationName,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final double? rawLat = (map['lastLatitude'] as num?)?.toDouble();
    final double? rawLon = (map['lastLongitude'] as num?)?.toDouble();
    final double? rawAcc = (map['lastAccuracyMeters'] as num?)?.toDouble();
    // Ignore legacy simulated 6.5m accuracy coordinates so only genuine GPS is shown
    final bool isLegacySim = rawAcc != null && (rawAcc - 6.5).abs() < 0.01;

    return UserProfile(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.shiftStaff,
      ),
      customRoleId: map['customRoleId']?.toString(),
      customRoleName: map['customRoleName']?.toString(),
      assignedShift: map['assignedShift'],
      village: map['village'] ?? 'Chatrai',
      address: map['address'] ?? 'Chatrai, Andhra Pradesh',
      preferredLanguage: map['preferredLanguage'] ?? 'te',
      active: map['active'] ?? true,
      isOnline: map['isOnline'] ?? false,
      permissions: map['permissions'] is List ? List<String>.from(map['permissions']) : const [],
      securityPin: map['securityPin'] ?? '123456',
      appVersion: map['appVersion']?.toString() ?? '',
      lastSeenAt: map['lastSeenAt'] != null ? DateTime.tryParse(map['lastSeenAt'].toString()) : null,
      approvalStatus: map['approvalStatus']?.toString() ?? 'approved',
      requestedBy: map['requestedBy']?.toString(),
      pendingEditData: map['pendingEditData'] is Map
          ? Map<String, dynamic>.from(map['pendingEditData'] as Map)
          : null,
      lastLatitude: isLegacySim ? null : rawLat,
      lastLongitude: isLegacySim ? null : rawLon,
      lastDistanceMeters: isLegacySim ? null : (map['lastDistanceMeters'] as num?)?.toDouble(),
      lastAccuracyMeters: isLegacySim ? null : rawAcc,
      isAtStation: isLegacySim ? null : (map['isAtStation'] as bool?),
      locationUpdatedAt: isLegacySim
          ? null
          : (map['locationUpdatedAt'] != null
              ? DateTime.tryParse(map['locationUpdatedAt'].toString())
              : null),
      lastLocationName: isLegacySim ? null : map['lastLocationName']?.toString(),
    );
  }
}
