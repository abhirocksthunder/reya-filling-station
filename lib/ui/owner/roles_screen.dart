import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/station_settings.dart';
import '../../services/station_state_provider.dart';
import '../common/pagination_control.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});
  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  int _page = 1;
  Future<void> _edit(StationStateProvider state, [CustomRoleItem? role]) async {
    final name = TextEditingController(text: role?.name ?? '');
    String tier = role?.baseRole ?? 'manager';
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(role == null ? 'Create role' : 'Edit role'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: name,
                    maxLength: 30,
                    decoration: InputDecoration(
                      labelText: 'Role name',
                      errorText: error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: tier,
                    decoration: const InputDecoration(
                      labelText: 'Base privilege tier',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'admin',
                        child: Text('Owner / Admin'),
                      ),
                      DropdownMenuItem(
                        value: 'manager',
                        child: Text('Manager'),
                      ),
                      DropdownMenuItem(
                        value: 'shiftStaff',
                        child: Text('Shift staff'),
                      ),
                    ],
                    onChanged: (value) => update(() => tier = value ?? tier),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Assign screen access in Permissions. Editing a name preserves existing permissions.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final clean = name.text.trim();
                final reserved = ['owner', 'admin', 'manager', 'shift staff'];
                final duplicate = state.settings.customRoles.any(
                  (r) =>
                      r.id != role?.id &&
                      r.name.toLowerCase() == clean.toLowerCase(),
                );
                if (clean.isEmpty ||
                    reserved.contains(clean.toLowerCase()) ||
                    duplicate) {
                  update(() => error = 'Enter a unique role name');
                  return;
                }
                state.addOrUpdateCustomRole(
                  CustomRoleItem(
                    id:
                        role?.id ??
                        'role_${DateTime.now().microsecondsSinceEpoch}',
                    name: clean,
                    baseRole: tier,
                    hasOwnerPrivileges: tier == 'admin',
                    screenPermissions:
                        role?.screenPermissions ??
                        StationSettings.defaultRoleScreenPermissions[tier] ??
                        ['my_shift'],
                  ),
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    // Wait for the dialog transition before disposing its controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    if (!state.currentUser.hasOwnerPrivileges) {
      return const Center(child: Text('Owner access required'));
    }
    final roles = state.settings.customRoles;
    final total = roles.length + 4;
    _page = _page.clamp(1, ((total + 9) ~/ 10));
    final rows = <Widget>[
      for (final key in ['owner', 'admin', 'manager', 'shiftStaff'])
        ListTile(
          title: Text(state.settings.getRoleDisplayName(key)),
          subtitle: const Text('Built-in role'),
          leading: const Icon(Icons.badge_outlined),
        ),
      for (final role in roles)
        ListTile(
          title: Text(role.name),
          subtitle: Text('Base tier: ${role.baseRole}'),
          leading: const Icon(Icons.badge_outlined),
          trailing: Wrap(
            children: [
              IconButton(
                tooltip: 'Edit role',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _edit(state, role),
              ),
              IconButton(
                tooltip: 'Delete role',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Delete ${role.name}?'),
                      content: const Text(
                        'Assigned users return to their base role.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && mounted)
                    state.deleteCustomRole(role.id);
                },
              ),
            ],
          ),
        ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Roles',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _edit(state),
            icon: const Icon(Icons.add),
            label: const Text('Create role'),
            style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
          ),
          const SizedBox(height: 12),
          ...rows.skip((_page - 1) * 10).take(10),
          PaginationControl(
            currentPage: _page,
            totalItems: total,
            pageSize: 10,
            onPageChanged: (page) => setState(() => _page = page),
          ),
        ],
      ),
    );
  }
}
