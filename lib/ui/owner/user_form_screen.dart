import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../models/station_settings.dart';
import '../../models/user_profile.dart';
import '../../services/station_state_provider.dart';
import 'roles_screen.dart';

class UserFormScreen extends StatefulWidget {
  final UserProfile? userToEdit;
  final Function(UserProfile) onSave;

  const UserFormScreen({super.key, this.userToEdit, required this.onSave});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _villageController;
  late TextEditingController _addressController;
  late TextEditingController _pinController;

  late UserRole _selectedRole;
  String? _selectedCustomRoleId;
  String? _selectedCustomRoleName;
  String? _selectedShift;
  late bool _isActive;
  late bool _useRoleDefaultScreens;
  late List<String> _customScreenPermissions;

  @override
  void initState() {
    super.initState();
    final u = widget.userToEdit;
    _nameController = TextEditingController(text: u?.name ?? '');
    _emailController = TextEditingController(text: u?.email ?? '');
    _phoneController = TextEditingController(text: u?.phoneNumber ?? '');
    _villageController = TextEditingController(text: u?.village ?? 'Chatrai');
    _addressController = TextEditingController(
      text: u?.address ?? 'Chatrai, Andhra Pradesh',
    );
    _pinController = TextEditingController(text: u?.securityPin ?? '123456');

    _selectedRole = u?.role ?? UserRole.shiftStaff;
    _selectedCustomRoleId = u?.customRoleId;
    _selectedCustomRoleName = u?.customRoleName;
    _selectedShift = (u?.hasOwnerPrivileges ?? false)
        ? null
        : (u?.assignedShift ?? 'Morning');
    _isActive = u?.active ?? true;
    _useRoleDefaultScreens = u == null || u.permissions.isEmpty;
    final effectiveKey = _selectedCustomRoleId ?? _selectedRole.name;
    _customScreenPermissions = u != null && u.permissions.isNotEmpty
        ? List<String>.from(u.permissions)
        : List<String>.from(
            StationSettings.defaultRoleScreenPermissions[effectiveKey] ??
                StationSettings.defaultRoleScreenPermissions[_selectedRole
                    .name] ??
                const ['my_shift'],
          );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _villageController.dispose();
    _addressController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final bool isEditing = widget.userToEdit != null;
    final bool isOwnerActor = state.currentUser.hasOwnerPrivileges;
    final bool isManagerActor =
        state.currentUser.role == UserRole.manager && !isOwnerActor;

    // Dynamic shift names from StationSettings (no hardcoded deleted shifts)
    final List<String> shiftKeys = state.settings.shiftTimings.keys.toList();
    if (shiftKeys.isEmpty) {
      shiftKeys.add('Morning');
    }
    if (!_selectedRole.hasOwnerPrivileges &&
        (_selectedShift == null || !shiftKeys.contains(_selectedShift))) {
      _selectedShift = shiftKeys.first;
    }

    final String activeRoleKey =
        (_selectedCustomRoleId != null &&
            state.settings.customRoles.any(
              (r) => r.id == _selectedCustomRoleId,
            ))
        ? _selectedCustomRoleId!
        : _selectedRole.name;

    return Scaffold(
      backgroundColor: StationColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'Edit Person: ${widget.userToEdit!.name}${state.isSelfUser(widget.userToEdit!) ? " (Self)" : ""}'
              : 'Add New Person',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  StationDimensions.cardRadius,
                ),
                border: Border.all(color: StationColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isManagerActor) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: Colors.orange.shade800,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Manager Approval Policy: Adding or editing a user submits an approval request to the Station Owner before activation.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Text(
                    'Personal Information',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),

                  // Name
                  TextField(
                    controller: _nameController,
                    maxLength: 30,
                    inputFormatters: [LengthLimitingTextInputFormatter(30)],
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      hintText: 'e.g. Kalyan Kumar Golla',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    maxLength: 30,
                    inputFormatters: [LengthLimitingTextInputFormatter(30)],
                    decoration: InputDecoration(
                      labelText: 'Email Address *',
                      hintText: 'e.g. kalyan@rfs.com',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phone Number (Strictly 10 digits)
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Phone Number (10 Digits) *',
                      hintText: 'e.g. 9848011111',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Security PIN (Admin set, max 6 digits)
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Security PIN (4-6 Digits) *',
                      hintText: 'e.g. 123456',
                      helperText:
                          'Admin configured PIN for station login (4-6 digits)',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.pin_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Divider(),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Role & Responsibilities',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (isOwnerActor)
                        TextButton.icon(
                          icon: const Icon(
                            Icons.add_moderator_rounded,
                            size: 16,
                          ),
                          label: const Text(
                            '+ Create New Role',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: StationColors.accentOrange,
                            minimumSize: const Size(44, 44),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChangeNotifierProvider.value(
                                value: state,
                                child: Scaffold(
                                  appBar: AppBar(title: const Text('Roles')),
                                  body: const RolesScreen(),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Role Dropdown (Built-in Owner, Admin, Manager, Shift Staff + Custom Roles)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: activeRoleKey,
                    decoration: InputDecoration(
                      labelText: 'Assigned Role *',
                      helperText: 'Admin has the same full privileges as Owner',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    items: [
                      if (!isManagerActor || _selectedRole == UserRole.owner)
                        const DropdownMenuItem(
                          value: 'owner',
                          child: Text('Owner (Full Station Access)'),
                        ),
                      if (!isManagerActor || _selectedRole == UserRole.admin)
                        const DropdownMenuItem(
                          value: 'admin',
                          child: Text('Admin (Same Privileges as Owner)'),
                        ),
                      const DropdownMenuItem(
                        value: 'manager',
                        child: Text('Manager'),
                      ),
                      const DropdownMenuItem(
                        value: 'shiftStaff',
                        child: Text('Shift staff'),
                      ),
                      ...state.settings.customRoles
                          .where(
                            (cr) => !isManagerActor || !cr.hasOwnerPrivileges,
                          )
                          .map(
                            (cr) => DropdownMenuItem(
                              value: cr.id,
                              child: Text(
                                '${cr.name} (${cr.hasOwnerPrivileges ? "Owner/Admin Privileges" : cr.baseRole})',
                              ),
                            ),
                          ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          final customMatch = state.settings.customRoles
                              .where((r) => r.id == val)
                              .firstOrNull;
                          if (customMatch != null) {
                            _selectedCustomRoleId = customMatch.id;
                            _selectedCustomRoleName = customMatch.name;
                            _selectedRole = customMatch.mappedUserRole;
                          } else {
                            _selectedCustomRoleId = null;
                            _selectedCustomRoleName = null;
                            _selectedRole = UserRole.values.firstWhere(
                              (r) => r.name == val,
                              orElse: () => UserRole.shiftStaff,
                            );
                          }
                          if (_selectedRole.hasOwnerPrivileges) {
                            _selectedShift =
                                null; // Owner & Admin have no shift
                          } else if (_selectedShift == null &&
                              shiftKeys.isNotEmpty) {
                            _selectedShift = shiftKeys.first;
                          }
                          if (_useRoleDefaultScreens) {
                            _customScreenPermissions = List<String>.from(
                              state.settings.roleScreenPermissions[val] ??
                                  StationSettings
                                      .defaultRoleScreenPermissions[_selectedRole
                                      .name] ??
                                  const ['my_shift'],
                            );
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Shift Selection: Dynamic from settings.shiftTimings, NEVER shown for Owner or Admin
                  if (!_selectedRole.hasOwnerPrivileges) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedShift ?? shiftKeys.first,
                      decoration: InputDecoration(
                        labelText:
                            'Assigned Shift (dynamic from station timings) *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.access_time_outlined),
                      ),
                      items: shiftKeys.map((shiftName) {
                        final timing =
                            state.settings.shiftTimings[shiftName] ?? '';
                        return DropdownMenuItem(
                          value: shiftName,
                          child: Text(
                            timing.isNotEmpty
                                ? '$shiftName Shift ($timing)'
                                : '$shiftName Shift',
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedShift = val);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (isOwnerActor)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Assign screen access on the separate Permissions screen after saving this user.',
                      ),
                    ),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'Location & Address',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),

                  // Village
                  TextField(
                    controller: _villageController,
                    maxLength: 30,
                    inputFormatters: [LengthLimitingTextInputFormatter(30)],
                    decoration: InputDecoration(
                      labelText: 'Village / Town *',
                      hintText: 'e.g. Chatrai',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.location_city_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Address
                  TextField(
                    controller: _addressController,
                    maxLines: 2,
                    maxLength: 30,
                    inputFormatters: [LengthLimitingTextInputFormatter(30)],
                    decoration: InputDecoration(
                      labelText: 'Address Details',
                      hintText: 'House no, Street, Landmark',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.home_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Active Switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Status',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Inactive users cannot log in to the station',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isActive,
                        activeColor: StationColors.successGreen,
                        onChanged: (val) => setState(() => _isActive = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Submit Actions
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check, color: Colors.white),
                            label: Text(
                              isManagerActor
                                  ? 'Submit for Approval'
                                  : (isEditing ? 'Update User' : 'Save User'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: StationColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              if (_nameController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter full name.'),
                                  ),
                                );
                                return;
                              }

                              final pin = _pinController.text.trim();
                              if (pin.length < 4 ||
                                  pin.length > 6 ||
                                  int.tryParse(pin) == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Security PIN must be 4 to 6 numeric digits.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              final existing = widget.userToEdit;
                              final List<String> savedPermissions = isOwnerActor
                                  ? (_useRoleDefaultScreens
                                        ? const []
                                        : _customScreenPermissions)
                                  : (existing?.permissions ?? const []);

                              final profile = UserProfile(
                                id:
                                    existing?.id ??
                                    'user_${DateTime.now().millisecondsSinceEpoch}',
                                name: _nameController.text.trim(),
                                email: _emailController.text.trim(),
                                phoneNumber: _phoneController.text.trim(),
                                securityPin: pin,
                                role: _selectedRole,
                                customRoleId: _selectedCustomRoleId,
                                customRoleName: _selectedCustomRoleName,
                                assignedShift: _selectedRole.hasOwnerPrivileges
                                    ? null
                                    : _selectedShift,
                                village: _villageController.text.trim(),
                                address: _addressController.text.trim(),
                                active: _isActive,
                                isOnline: existing?.isOnline ?? false,
                                appVersion: existing?.appVersion ?? '',
                                lastSeenAt: existing?.lastSeenAt,
                                lastLatitude: existing?.lastLatitude,
                                lastLongitude: existing?.lastLongitude,
                                lastDistanceMeters:
                                    existing?.lastDistanceMeters,
                                lastAccuracyMeters:
                                    existing?.lastAccuracyMeters,
                                isAtStation: existing?.isAtStation,
                                locationUpdatedAt: existing?.locationUpdatedAt,
                                permissions: savedPermissions,
                                approvalStatus:
                                    existing?.approvalStatus ?? 'approved',
                                requestedBy: existing?.requestedBy,
                                pendingEditData: existing?.pendingEditData,
                              );

                              widget.onSave(profile);
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
