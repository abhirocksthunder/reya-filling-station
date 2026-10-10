import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../models/user_profile.dart';

class UserFormScreen extends StatefulWidget {
  final UserProfile? userToEdit;
  final Function(UserProfile) onSave;

  const UserFormScreen({
    super.key,
    this.userToEdit,
    required this.onSave,
  });

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
  String? _selectedShift;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final u = widget.userToEdit;
    _nameController = TextEditingController(text: u?.name ?? '');
    _emailController = TextEditingController(text: u?.email ?? '');
    _phoneController = TextEditingController(text: u?.phoneNumber ?? '');
    _villageController = TextEditingController(text: u?.village ?? 'Chatrai');
    _addressController = TextEditingController(text: u?.address ?? 'Chatrai, Andhra Pradesh');
    _pinController = TextEditingController(text: u?.securityPin ?? '123456');

    _selectedRole = u?.role ?? UserRole.shiftStaff;
    _selectedShift = u?.role == UserRole.owner ? null : (u?.assignedShift ?? 'Morning');
    _isActive = u?.active ?? true;
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
    bool isEditing = widget.userToEdit != null;

    return Scaffold(
      backgroundColor: StationColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Person: ${widget.userToEdit!.name}' : 'Add New Person',
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
                borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
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
                  const Text('Personal Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                      helperText: 'Admin configured PIN for station login (4-6 digits)',
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.pin_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Divider(),
                  const SizedBox(height: 12),
                  const Text('Role & Responsibilities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),

                  // Role Dropdown
                  DropdownButtonFormField<UserRole>(
                    value: _selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Assigned Role *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    items: UserRole.values.map((r) {
                      return DropdownMenuItem(value: r, child: Text(r.displayName));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedRole = val;
                          if (val == UserRole.owner) {
                            _selectedShift = null; // Owner has no shift
                          } else if (_selectedShift == null) {
                            _selectedShift = 'Morning';
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Shift Selection: Only shown for Shift Staff / Manager, NEVER for Owner!
                  if (_selectedRole != UserRole.owner) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedShift ?? 'Morning',
                      decoration: InputDecoration(
                        labelText: 'Assigned Shift (for shift staff) *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.access_time_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Morning', child: Text('Morning Shift (6:00 AM - 2:00 PM)')),
                        DropdownMenuItem(value: 'Evening', child: Text('Evening Shift (2:00 PM - 10:00 PM)')),
                        DropdownMenuItem(value: 'Night', child: Text('Night Shift (10:00 PM - 6:00 AM)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedShift = val);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Divider(),
                  const SizedBox(height: 12),
                  const Text('Location & Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                          Text('Active Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Inactive users cannot log in to the station', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                              isEditing ? 'Update User' : 'Save User',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: StationColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              if (_nameController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter full name.')),
                                );
                                return;
                              }

                              final pin = _pinController.text.trim();
                              if (pin.length < 4 || pin.length > 6 || int.tryParse(pin) == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Security PIN must be 4 to 6 numeric digits.')),
                                );
                                return;
                              }

                              final profile = UserProfile(
                                id: widget.userToEdit?.id ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
                                name: _nameController.text.trim(),
                                email: _emailController.text.trim(),
                                phoneNumber: _phoneController.text.trim(),
                                securityPin: pin,
                                role: _selectedRole,
                                assignedShift: _selectedRole == UserRole.owner ? null : _selectedShift,
                                village: _villageController.text.trim(),
                                address: _addressController.text.trim(),
                                active: _isActive,
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
