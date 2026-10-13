import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../models/station_settings.dart';
import '../../models/user_profile.dart';
import '../../services/station_state_provider.dart';
import '../common/pagination_control.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, this.initialUser});
  final UserProfile? initialUser;
  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  String _selectedPermRoleKey = 'admin';
  bool _showRolePermissionsCard = true;
  int _rolePage = 1;
  int _userPage = 1;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    if (!state.currentUser.hasOwnerPrivileges) {
      return const Center(child: Text('Owner access required'));
    }
    _userPage = _userPage.clamp(
      1,
      ((state.allUsers.length + 9) ~/ 10).clamp(1, 100000),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Permissions',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildOwnerRolePermissionsMatrix(context, state),
          const SizedBox(height: 16),
          const Text(
            'User permission overrides',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (widget.initialUser != null)
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: Text('Edit ${widget.initialUser!.name} permissions'),
              onPressed: () => _showUserScreensDialog(
                context,
                state,
                state.allUsers.firstWhere(
                  (u) => u.id == widget.initialUser!.id,
                  orElse: () => widget.initialUser!,
                ),
              ),
            ),
          ...state.allUsers
              .skip((_userPage - 1) * 10)
              .take(10)
              .map(
                (user) => ListTile(
                  title: Text(user.name),
                  subtitle: Text(user.effectiveRoleDisplayName),
                  trailing: IconButton(
                    tooltip: 'Edit user permissions',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () =>
                        _showUserScreensDialog(context, state, user),
                  ),
                ),
              ),
          PaginationControl(
            currentPage: _userPage,
            totalItems: state.allUsers.length,
            pageSize: 10,
            onPageChanged: (page) => setState(() => _userPage = page),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerRolePermissionsMatrix(
    BuildContext context,
    StationStateProvider state,
  ) {
    final allRoleKeys = [
      'owner',
      'admin',
      'manager',
      'shiftStaff',
      ...state.settings.customRoles.map((r) => r.id),
    ];
    if (!allRoleKeys.contains(_selectedPermRoleKey)) {
      _selectedPermRoleKey = 'admin';
    }
    final rolePerms =
        state.settings.roleScreenPermissions[_selectedPermRoleKey] ??
        StationSettings.defaultRoleScreenPermissions[_selectedPermRoleKey] ??
        const ['my_shift'];
    final forecourtScreens = StationSettings.allScreenPermissions
        .where((s) => s.group == 'forecourt')
        .toList();
    final managementScreens = StationSettings.allScreenPermissions
        .where((s) => s.group == 'management')
        .toList();

    final totalRoles = allRoleKeys.length;
    final maxPage = ((totalRoles + 9) ~/ 10).clamp(1, 100000);
    _rolePage = _rolePage.clamp(1, maxPage);
    final visibleRoles = allRoleKeys.skip((_rolePage - 1) * 10).take(10);
    String roleDisplay(String key) => state.settings.getRoleDisplayName(key);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
        border: Border.all(
          color: StationColors.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: StationColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: StationColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Roles & Screen Permissions (Owner & Admin Access Control)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: StationColors.textDark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Admin shares full Owner privileges • Select any role or create custom roles below.',
                          style: TextStyle(
                            fontSize: 12,
                            color: StationColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _showRolePermissionsCard
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                    tooltip: _showRolePermissionsCard ? 'Collapse' : 'Expand',
                    onPressed: () => setState(
                      () =>
                          _showRolePermissionsCard = !_showRolePermissionsCard,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_showRolePermissionsCard) ...[
            const Divider(height: 24),
            // Role Selector Pills + Presets
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Select Role:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: StationColors.textDark,
                  ),
                ),
                ...visibleRoles.map((rKey) {
                  final count =
                      (state.settings.roleScreenPermissions[rKey] ??
                              StationSettings
                                  .defaultRoleScreenPermissions[rKey] ??
                              [])
                          .length;
                  final selected = _selectedPermRoleKey == rKey;
                  return ChoiceChip(
                    label: Text(
                      '${roleDisplay(rKey)} ($count/${StationSettings.allScreenPermissions.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: selected ? Colors.white : StationColors.textDark,
                      ),
                    ),
                    selected: selected,
                    selectedColor: StationColors.primary,
                    onSelected: (_) =>
                        setState(() => _selectedPermRoleKey = rKey),
                  );
                }),
                const SizedBox(width: 8),
                if (_selectedPermRoleKey == 'manager') ...[
                  ActionChip(
                    avatar: const Icon(
                      Icons.people_alt_outlined,
                      size: 15,
                      color: StationColors.primary,
                    ),
                    label: const Text(
                      'Preset: Users Only',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      state.updateRoleScreenPermissions('manager', [
                        'people_management',
                      ]);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Manager role set to Users Only (Add/Update Users & APK Share).',
                          ),
                          backgroundColor: StationColors.successGreen,
                        ),
                      );
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.local_gas_station_outlined,
                      size: 15,
                      color: StationColors.primary,
                    ),
                    label: const Text(
                      'Preset: Forecourt + Users',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      state.updateRoleScreenPermissions('manager', [
                        'my_shift',
                        'scan_receipt',
                        'money_entries',
                        'close_shift',
                        'people_management',
                      ]);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Manager role set to Forecourt + Users.',
                          ),
                          backgroundColor: StationColors.successGreen,
                        ),
                      );
                    },
                  ),
                ],
                TextButton.icon(
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: const Text(
                    'Reset Role Default',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    state.resetRoleScreenPermissionsToDefault(
                      _selectedPermRoleKey,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Reset ${roleDisplay(_selectedPermRoleKey)} screen permissions to default.',
                        ),
                        backgroundColor: StationColors.successGreen,
                      ),
                    );
                  },
                ),
              ],
            ),
            PaginationControl(
              currentPage: _rolePage,
              totalItems: totalRoles,
              pageSize: 10,
              onPageChanged: (page) => setState(() => _rolePage = page),
            ),
            const SizedBox(height: 14),
            const Text(
              '1. Forecourt & Shift Screens',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: StationColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: forecourtScreens.map((screen) {
                final enabled = rolePerms.contains(screen.id);
                return FilterChip(
                  selected: enabled,
                  selectedColor: StationColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: StationColors.primary,
                  label: Text(
                    screen.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: enabled ? FontWeight.bold : FontWeight.w500,
                      color: enabled
                          ? StationColors.primary
                          : StationColors.textDark,
                    ),
                  ),
                  tooltip: screen.subtitle,
                  onSelected: (val) {
                    state.toggleRoleScreenPermission(
                      _selectedPermRoleKey,
                      screen.id,
                      val,
                    );
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            const Text(
              '2. Operations & Management Screens',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: StationColors.accentOrange,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: managementScreens.map((screen) {
                final enabled = rolePerms.contains(screen.id);
                final isLockedOwnerScreen =
                    _selectedPermRoleKey == 'owner' &&
                    const [
                      'station_overview',
                      'people_management',
                      'station_settings',
                    ].contains(screen.id);
                return FilterChip(
                  selected: enabled,
                  selectedColor: StationColors.accentOrangeLight,
                  checkmarkColor: StationColors.accentOrange,
                  label: Text(
                    isLockedOwnerScreen
                        ? '${screen.title} (Required)'
                        : screen.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: enabled ? FontWeight.bold : FontWeight.w500,
                      color: enabled
                          ? StationColors.accentOrange
                          : StationColors.textDark,
                    ),
                  ),
                  tooltip: screen.subtitle,
                  onSelected: isLockedOwnerScreen
                      ? null
                      : (val) {
                          state.toggleRoleScreenPermission(
                            _selectedPermRoleKey,
                            screen.id,
                            val,
                          );
                        },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _showUserScreensDialog(
    BuildContext context,
    StationStateProvider state,
    UserProfile user,
  ) {
    int permissionPage = 1;
    bool useRoleDefault = user.permissions.isEmpty;
    List<String> selectedScreens = List<String>.from(
      state.getAllowedScreensForUser(user),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final roleDefault =
              state.settings.roleScreenPermissions[user.effectiveRoleKey] ??
              state.settings.roleScreenPermissions[user.role.name] ??
              StationSettings.defaultRoleScreenPermissions[user.role.name] ??
              const ['my_shift'];

          return AlertDialog(
            title: Row(
              children: [
                const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: StationColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Screen Permissions: ${user.name}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Role: ${user.effectiveRoleDisplayName}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: StationColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Use ${user.effectiveRoleDisplayName} Role Default Screens (${roleDefault.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Turn off to customize exact screens for this individual user.',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: useRoleDefault,
                      activeThumbColor: StationColors.primary,
                      onChanged: (val) {
                        setDialogState(() {
                          useRoleDefault = val;
                          if (val) {
                            selectedScreens = List<String>.from(roleDefault);
                          }
                        });
                      },
                    ),
                    const Divider(),
                    const Text(
                      'Permitted Screens:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: StationSettings.allScreenPermissions
                          .skip((permissionPage - 1) * 10)
                          .take(10)
                          .map((s) {
                            final activeList = useRoleDefault
                                ? roleDefault
                                : selectedScreens;
                            final isChecked = activeList.contains(s.id);
                            return FilterChip(
                              selected: isChecked,
                              label: Text(
                                s.title,
                                style: const TextStyle(fontSize: 11),
                              ),
                              selectedColor: StationColors.primary.withValues(
                                alpha: 0.15,
                              ),
                              checkmarkColor: StationColors.primary,
                              onSelected: useRoleDefault
                                  ? null
                                  : (val) {
                                      setDialogState(() {
                                        if (val) {
                                          if (!selectedScreens.contains(s.id))
                                            selectedScreens.add(s.id);
                                        } else if (selectedScreens.length > 1) {
                                          selectedScreens.remove(s.id);
                                        }
                                      });
                                    },
                            );
                          })
                          .toList(),
                    ),
                    PaginationControl(
                      currentPage: permissionPage,
                      totalItems: StationSettings.allScreenPermissions.length,
                      pageSize: 10,
                      onPageChanged: (page) =>
                          setDialogState(() => permissionPage = page),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: StationColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(100, 44),
                ),
                onPressed: () {
                  final updatedUser = user.copyWith(
                    permissions: useRoleDefault ? const [] : selectedScreens,
                  );
                  state.updateUser(updatedUser);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Updated screen permissions for ${user.name}.',
                      ),
                      backgroundColor: StationColors.successGreen,
                    ),
                  );
                },
                child: const Text(
                  'Save Permissions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
