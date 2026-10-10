import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../l10n/app_strings.dart';
import '../../models/user_profile.dart';
import '../../services/station_state_provider.dart';
import '../common/pagination_control.dart';
import 'user_form_screen.dart';

class PeopleManagementScreen extends StatefulWidget {
  const PeopleManagementScreen({super.key});

  @override
  State<PeopleManagementScreen> createState() => _PeopleManagementScreenState();
}

class _PeopleManagementScreenState extends State<PeopleManagementScreen> {
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final allUsers = state.allUsers;

    // Paginate users (10 per page)
    final totalItems = allUsers.length;
    final int startIndex = (_currentPage - 1) * _pageSize;
    final int endIndex = (startIndex + _pageSize).clamp(0, totalItems);
    final displayedUsers = (startIndex < totalItems)
        ? allUsers.sublist(startIndex, endIndex)
        : <UserProfile>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.get('peopleAndRoles', lang),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: StationColors.textDark,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('+ Add person', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StationColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserFormScreen(
                        onSave: (newUser) {
                          state.addNewUser(newUser);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added user "${newUser.name}" successfully.'),
                              backgroundColor: StationColors.successGreen,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Users Table Container
          Container(
            width: double.infinity,
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 920),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFF7F9F9)),
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 64,
                  horizontalMargin: 16,
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    DataColumn(label: Text('Shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    DataColumn(label: Text('Village & Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  ],
                  rows: displayedUsers.map((u) {
                    final bool isStaff = u.role == UserRole.shiftStaff;
                    final String shiftDisplay = isStaff ? (u.assignedShift ?? 'Unassigned') : '—';

                    return DataRow(
                      cells: [
                        // 1. Name
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: u.role == UserRole.owner
                                    ? StationColors.primaryLight.withOpacity(0.2)
                                    : Colors.grey.shade200,
                                child: Text(
                                  u.name.isNotEmpty ? u.name[0] : 'U',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: u.role == UserRole.owner
                                        ? StationColors.primary
                                        : StationColors.textDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                u.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        // 2. Phone
                        DataCell(
                          Text(u.phoneNumber, style: const TextStyle(fontSize: 13, color: StationColors.textDark)),
                        ),
                        // 3. Role
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: u.role == UserRole.owner
                                  ? StationColors.primaryLight.withOpacity(0.15)
                                  : StationColors.accentOrangeLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              u.role.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: u.role == UserRole.owner
                                    ? StationColors.primary
                                    : StationColors.accentOrange,
                              ),
                            ),
                          ),
                        ),
                        // 4. Shift (for Shift Staff only, '—' for Owner)
                        DataCell(
                          Text(
                            shiftDisplay,
                            style: TextStyle(
                              fontSize: 13,
                              color: isStaff ? StationColors.textDark : StationColors.textLight,
                              fontWeight: isStaff ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ),
                        // 5. Email
                        DataCell(
                          Text(
                            u.email.isNotEmpty ? u.email : '—',
                            style: const TextStyle(fontSize: 12, color: StationColors.textMedium),
                          ),
                        ),
                        // 6. Village & Address
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                u.village.isNotEmpty ? u.village : 'Chatrai',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                              if (u.address.isNotEmpty)
                                Text(
                                  u.address,
                                  style: const TextStyle(fontSize: 11, color: StationColors.textLight),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        // 7. Status
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: u.active ? StationColors.successGreen : StationColors.errorRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 8. Actions (Edit & Delete)
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Edit Button
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: StationColors.primary),
                                tooltip: 'Edit User',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => UserFormScreen(
                                        userToEdit: u,
                                        onSave: (updated) {
                                          state.updateUser(updated);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Updated user "${updated.name}" successfully.'),
                                              backgroundColor: StationColors.successGreen,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Delete Button
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: StationColors.errorRed),
                                tooltip: 'Delete User',
                                onPressed: () {
                                  _showDeleteConfirmationDialog(context, state, u);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 10-Item Pagination Control
          PaginationControl(
            currentPage: _currentPage,
            totalItems: totalItems,
            pageSize: _pageSize,
            onPageChanged: (newPage) {
              setState(() => _currentPage = newPage);
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, StationStateProvider state, UserProfile user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User Account'),
        content: Text('Are you sure you want to permanently remove "${user.name}" (${user.email.isNotEmpty ? user.email : user.phoneNumber})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: StationColors.errorRed),
            onPressed: () {
              state.deleteUser(user.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed "${user.name}".'),
                  backgroundColor: StationColors.errorRed,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
