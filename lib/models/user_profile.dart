enum UserRole {
  owner,
  manager,
  shiftStaff;

  String get displayName {
    switch (this) {
      case UserRole.owner:
        return 'Owner';
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
  final String? assignedShift; // "Morning", "Evening", "Night" (null for owner)
  final String village;
  final String address;
  final String preferredLanguage; // "te" or "en"
  final bool active;
  final bool isOnline;
  final List<String> permissions;

  const UserProfile({
    required this.id,
    required this.name,
    this.email = '',
    required this.phoneNumber,
    required this.role,
    this.assignedShift,
    this.village = 'Chatrai',
    this.address = 'Chatrai, Andhra Pradesh',
    this.preferredLanguage = 'te',
    this.active = true,
    this.isOnline = false,
    this.permissions = const [],
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    UserRole? role,
    String? assignedShift,
    String? village,
    String? address,
    String? preferredLanguage,
    bool? active,
    bool? isOnline,
    List<String>? permissions,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      assignedShift: assignedShift ?? this.assignedShift,
      village: village ?? this.village,
      address: address ?? this.address,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      active: active ?? this.active,
      isOnline: isOnline ?? this.isOnline,
      permissions: permissions ?? this.permissions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role.name,
      'assignedShift': assignedShift,
      'village': village,
      'address': address,
      'preferredLanguage': preferredLanguage,
      'active': active,
      'isOnline': isOnline,
      'permissions': permissions,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.shiftStaff,
      ),
      assignedShift: map['assignedShift'],
      village: map['village'] ?? 'Chatrai',
      address: map['address'] ?? 'Chatrai, Andhra Pradesh',
      preferredLanguage: map['preferredLanguage'] ?? 'te',
      active: map['active'] ?? true,
      isOnline: map['isOnline'] ?? false,
      permissions: List<String>.from(map['permissions'] ?? []),
    );
  }
}
