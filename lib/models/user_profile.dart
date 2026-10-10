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
  final String phoneNumber;
  final UserRole role;
  final String assignedShift; // e.g. "Morning", "Evening", "Night", "All"
  final String preferredLanguage; // "te" or "en"
  final bool active;
  final List<String> permissions;

  const UserProfile({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.role,
    this.assignedShift = 'Morning',
    this.preferredLanguage = 'te',
    this.active = true,
    this.permissions = const [],
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    UserRole? role,
    String? assignedShift,
    String? preferredLanguage,
    bool? active,
    List<String>? permissions,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      assignedShift: assignedShift ?? this.assignedShift,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      active: active ?? this.active,
      permissions: permissions ?? this.permissions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'role': role.name,
      'assignedShift': assignedShift,
      'preferredLanguage': preferredLanguage,
      'active': active,
      'permissions': permissions,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.shiftStaff,
      ),
      assignedShift: map['assignedShift'] ?? 'Morning',
      preferredLanguage: map['preferredLanguage'] ?? 'te',
      active: map['active'] ?? true,
      permissions: List<String>.from(map['permissions'] ?? []),
    );
  }
}
