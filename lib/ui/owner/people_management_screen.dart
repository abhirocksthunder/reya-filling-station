import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../l10n/app_strings.dart';
import '../../models/user_profile.dart';
import '../../services/station_state_provider.dart';

class PeopleManagementScreen extends StatefulWidget {
  const PeopleManagementScreen({super.key});

  @override
  State<PeopleManagementScreen> createState() => _PeopleManagementScreenState();
}

class _PeopleManagementScreenState extends State<PeopleManagementScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  UserRole _selectedRole = UserRole.shiftStaff;
  String _selectedShift = 'Morning';
  String _selectedLanguage = 'Telugu';
  bool _isSuspended = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final users = state.allUsers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.get('peopleAndRoles', lang),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: StationColors.textDark),
                  ),
                  const SizedBox(height: 2),
                  const Text('Demo • UI review', style: TextStyle(fontSize: 14, color: StationColors.textMedium)),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('+ Add person', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StationColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Two-column Layout: Table & Add Person Form
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 800;

              Widget tableCard = Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                  border: Border.all(color: StationColors.divider),
                ),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.2),
                    1: FlexColumnWidth(1.2),
                    2: FlexColumnWidth(1.3),
                    3: FlexColumnWidth(1.1),
                  },
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(
                        color: Color(0xFFF7F9F9),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(StationDimensions.cardRadius)),
                      ),
                      children: [
                        Padding(padding: EdgeInsets.all(14), child: Text('Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        Padding(padding: EdgeInsets.all(14), child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        Padding(padding: EdgeInsets.all(14), child: Text('Assigned shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        Padding(padding: EdgeInsets.all(14), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      ],
                    ),
                    ...users.map((u) {
                      return TableRow(
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: StationColors.divider, width: 0.8))),
                        children: [
                          Padding(padding: const EdgeInsets.all(14), child: Text(u.role.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                          Padding(padding: const EdgeInsets.all(14), child: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                          Padding(padding: const EdgeInsets.all(14), child: Text(u.assignedShift, style: const TextStyle(fontSize: 13, color: StationColors.textMedium))),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: u.active ? StationColors.successGreen : StationColors.errorRed,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  u.active ? 'Active' : 'Suspended',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: u.active ? StationColors.successGreen : StationColors.errorRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              );

              Widget addPersonCard = Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                  border: Border.all(color: StationColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add new person', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        hintText: 'Enter full name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone number',
                        hintText: 'Enter phone number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UserRole>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: UserRole.values.map((r) {
                        return DropdownMenuItem(value: r, child: Text(r.displayName));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRole = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedShift,
                      decoration: InputDecoration(
                        labelText: 'Assigned shift',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Morning', child: Text('Morning')),
                        DropdownMenuItem(value: 'Evening', child: Text('Evening')),
                        DropdownMenuItem(value: 'Night', child: Text('Night')),
                        DropdownMenuItem(value: 'All', child: Text('All shifts')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedShift = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedLanguage,
                      decoration: InputDecoration(
                        labelText: 'Language',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Telugu', child: Text('Telugu (తెలుగు)')),
                        DropdownMenuItem(value: 'English', child: Text('English')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedLanguage = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Permissions breakdown
                    const Text('Permissions (for Shift staff)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: StationColors.successGreen),
                        SizedBox(width: 8),
                        Text('Can scan assigned pumps', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.cancel, size: 16, color: StationColors.errorRed),
                        SizedBox(width: 8),
                        Text('Cannot change rates or users', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Send Invite Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                        label: const Text('Send invite', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: StationColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          if (_nameController.text.trim().isEmpty) return;
                          final newProfile = UserProfile(
                            id: 'user_${DateTime.now().millisecondsSinceEpoch}',
                            name: _nameController.text.trim(),
                            phoneNumber: _phoneController.text.trim(),
                            role: _selectedRole,
                            assignedShift: _selectedShift,
                            preferredLanguage: _selectedLanguage == 'Telugu' ? 'te' : 'en',
                          );
                          state.addNewUser(newProfile);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Invited ${_nameController.text} as ${_selectedRole.displayName}.'),
                              backgroundColor: StationColors.successGreen,
                            ),
                          );
                          _nameController.clear();
                          _phoneController.clear();
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Suspension Toggle (Owner Only)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Suspension (owner only)', style: TextStyle(fontSize: 12, color: StationColors.textLight)),
                        Switch(
                          value: _isSuspended,
                          onChanged: (val) => setState(() => _isSuspended = val),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              if (!isWide) {
                return Column(
                  children: [
                    tableCard,
                    const SizedBox(height: 20),
                    addPersonCard,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: tableCard),
                  const SizedBox(width: 20),
                  Expanded(flex: 4, child: addPersonCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
