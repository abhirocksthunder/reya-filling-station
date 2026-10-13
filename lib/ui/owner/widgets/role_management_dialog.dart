import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';
import '../../../models/station_settings.dart';
import '../../../services/station_state_provider.dart';

Future<CustomRoleItem?> showRoleManagementDialog(
  BuildContext context,
  StationStateProvider state, {
  CustomRoleItem? initialEditRole,
}) {
  return showDialog<CustomRoleItem?>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => RoleManagementDialog(
      state: state,
      initialEditRole: initialEditRole,
    ),
  );
}

class RoleManagementDialog extends StatefulWidget {
  final StationStateProvider state;
  final CustomRoleItem? initialEditRole;

  const RoleManagementDialog({
    super.key,
    required this.state,
    this.initialEditRole,
  });

  @override
  State<RoleManagementDialog> createState() => _RoleManagementDialogState();
}

class _RoleManagementDialogState extends State<RoleManagementDialog> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedTier = 'admin'; // 'admin', 'manager', 'shiftStaff'
  Set<String> _selectedScreens = {};
  String? _editingRoleId;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (widget.initialEditRole != null) {
      _loadRoleForEditing(widget.initialEditRole!);
    } else {
      _applyTierDefaults('admin');
    }
  }

  void _loadRoleForEditing(CustomRoleItem role) {
    setState(() {
      _editingRoleId = role.id;
      _nameController.text = role.name;
      _selectedTier = role.hasOwnerPrivileges
          ? 'admin'
          : (role.baseRole == 'manager' ? 'manager' : 'shiftStaff');
      _selectedScreens = Set<String>.from(role.screenPermissions);
      _errorText = null;
    });
  }

  void _resetFormToNew() {
    setState(() {
      _editingRoleId = null;
      _nameController.clear();
      _selectedTier = 'admin';
      _applyTierDefaults('admin');
      _errorText = null;
    });
  }

  void _applyTierDefaults(String tier) {
    final defaults = StationSettings.defaultRoleScreenPermissions[tier] ??
        StationSettings.defaultRoleScreenPermissions['shiftStaff']!;
    _selectedScreens = Set<String>.from(defaults);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveCustomRole() {
    final cleanName = _nameController.text.trim();
    if (cleanName.isEmpty) {
      setState(() => _errorText = 'Please enter a role name (max 30 characters).');
      return;
    }
    final lower = cleanName.toLowerCase();
    if (_editingRoleId == null &&
        (lower == 'owner' || lower == 'admin' || lower == 'manager' || lower == 'shift staff')) {
      setState(() => _errorText = '"$cleanName" is already a built-in system role.');
      return;
    }
    if (_selectedScreens.isEmpty) {
      setState(() => _errorText = 'Select at least 1 screen for this role.');
      return;
    }

    final slug = cleanName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final roleId = _editingRoleId ?? 'role_${slug}_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final hasOwnerPriv = _selectedTier == 'admin';

    final screens = List<String>.from(_selectedScreens);
    if (hasOwnerPriv) {
      for (final core in ['station_overview', 'people_management', 'station_settings']) {
        if (!screens.contains(core)) screens.add(core);
      }
    }

    final newRole = CustomRoleItem(
      id: roleId,
      name: cleanName,
      baseRole: _selectedTier,
      hasOwnerPrivileges: hasOwnerPriv,
      screenPermissions: screens,
    );

    widget.state.addOrUpdateCustomRole(newRole);
    Navigator.of(context).pop(newRole);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 640;
    final customRoles = widget.state.settings.customRoles;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 16 : 28,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: StationColors.accentOrange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Color(0xFFFB923C),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editingRoleId != null ? 'Edit Custom Role' : 'Roles & Create New Role',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Built-in Owner & Admin share full privileges • Create custom roles with tailored screens',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Existing Built-In & Custom Roles Summary
                    const Text(
                      'ACTIVE STATION ROLES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: StationColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBuiltInRoleBadge(
                          label: 'Owner',
                          subtitle: 'Full Access (13 screens)',
                          color: const Color(0xFF9A3412),
                          bgColor: const Color(0xFFFFF7ED),
                        ),
                        _buildBuiltInRoleBadge(
                          label: 'Admin',
                          subtitle: 'Same as Owner (13 screens)',
                          color: const Color(0xFF4338CA),
                          bgColor: const Color(0xFFEEF2FF),
                        ),
                        _buildBuiltInRoleBadge(
                          label: 'Manager',
                          subtitle: 'People + Operations (8 screens)',
                          color: const Color(0xFF0369A1),
                          bgColor: const Color(0xFFF0F9FF),
                        ),
                        _buildBuiltInRoleBadge(
                          label: 'Shift staff',
                          subtitle: 'Shift Operations (7 screens)',
                          color: const Color(0xFF15803D),
                          bgColor: const Color(0xFFF0FDF4),
                        ),
                        ...customRoles.map((role) {
                          final isEditingThis = _editingRoleId == role.id;
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _loadRoleForEditing(role),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isEditingThis
                                    ? StationColors.accentOrange.withValues(alpha: 0.14)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isEditingThis
                                      ? StationColors.accentOrange
                                      : StationColors.divider,
                                  width: isEditingThis ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    role.hasOwnerPrivileges
                                        ? Icons.verified_user_rounded
                                        : Icons.badge_outlined,
                                    size: 14,
                                    color: role.hasOwnerPrivileges
                                        ? const Color(0xFF4338CA)
                                        : StationColors.textDark,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          role.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: StationColors.textDark,
                                          ),
                                        ),
                                        Text(
                                          '${role.hasOwnerPrivileges ? "Owner/Admin Tier" : role.baseRole} • ${role.screenPermissions.length} screens',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: StationColors.textMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () {
                                      widget.state.deleteCustomRole(role.id);
                                      if (_editingRoleId == role.id) {
                                        _resetFormToNew();
                                      } else {
                                        setState(() {});
                                      }
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Icon(
                                        Icons.delete_outline,
                                        size: 15,
                                        color: StationColors.errorRed,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    ),

                    // 2. Create / Edit Custom Role Form
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _editingRoleId != null
                              ? 'EDIT ROLE: ${_nameController.text}'
                              : 'CREATE NEW CUSTOM ROLE',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: StationColors.textDark,
                          ),
                        ),
                        if (_editingRoleId != null)
                          TextButton.icon(
                            onPressed: _resetFormToNew,
                            icon: const Icon(Icons.add, size: 15),
                            label: const Text('Switch to New Role', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_errorText != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: StationColors.errorBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: StationColors.errorRed.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: StationColors.errorRed),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorText!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: StationColors.errorRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Role Name Input (Strict maxLength: 30)
                    const Text(
                      'Role Name *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      maxLength: 30,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(30),
                      ],
                      decoration: InputDecoration(
                        hintText: 'e.g. Co-Admin, Accountant, Supervisor, Auditor',
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: StationColors.divider),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Base Privilege Tier Selection
                    const Text(
                      'Base Privilege Tier *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTierOption(
                          tierKey: 'admin',
                          title: 'Same as Owner / Admin',
                          subtitle: 'Full Owner dashboard, AI insights & approvals',
                          icon: Icons.admin_panel_settings_outlined,
                        ),
                        _buildTierOption(
                          tierKey: 'manager',
                          title: 'Manager Privileges',
                          subtitle: 'Manage staff & shifts + operational entry',
                          icon: Icons.manage_accounts_outlined,
                        ),
                        _buildTierOption(
                          tierKey: 'shiftStaff',
                          title: 'Shift Staff Privileges',
                          subtitle: 'Pump scanning, money entries & shift close',
                          icon: Icons.local_gas_station_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Screen Permissions Checklist
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Allowed Screens (${_selectedScreens.length} / ${StationSettings.allScreenPermissions.length})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedScreens = StationSettings.allScreenPermissions
                                      .map((s) => s.id)
                                      .toSet();
                                });
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(44, 32),
                              ),
                              child: const Text('Select All 13', style: TextStyle(fontSize: 11.5)),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() => _applyTierDefaults(_selectedTier));
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(44, 32),
                              ),
                              child: const Text('Reset to Tier Default', style: TextStyle(fontSize: 11.5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: StationSettings.allScreenPermissions.map((screen) {
                        final isSelected = _selectedScreens.contains(screen.id);
                        return FilterChip(
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedScreens.add(screen.id);
                              } else if (_selectedScreens.length > 1) {
                                _selectedScreens.remove(screen.id);
                              }
                            });
                          },
                          selectedColor: StationColors.accentOrange.withValues(alpha: 0.16),
                          checkmarkColor: StationColors.accentOrange,
                          label: Text(
                            screen.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? StationColors.accentOrange : StationColors.textDark,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                border: Border(top: BorderSide(color: StationColors.divider)),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(minimumSize: const Size(72, 44)),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _saveCustomRole,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(_editingRoleId != null ? 'Update Role' : 'Create Role'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StationColors.accentOrange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(130, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuiltInRoleBadge({
    required String label,
    required String subtitle,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label (Built-in)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierOption({
    required String tierKey,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedTier == tierKey;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          _selectedTier = tierKey;
          _applyTierDefaults(tierKey);
        });
      },
      child: Container(
        width: 215,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? StationColors.accentOrange.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? StationColors.accentOrange : StationColors.divider,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? StationColors.accentOrange : StationColors.textMedium,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? StationColors.accentOrange : StationColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: StationColors.textMedium,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
