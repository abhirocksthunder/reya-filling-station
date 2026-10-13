import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/date_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../models/station_settings.dart';
import '../../models/user_profile.dart';
import '../../services/app_version_service.dart';
import '../../services/sentinel_alert_agent.dart';
import '../../services/station_state_provider.dart';
import '../common/pagination_control.dart';
import 'user_form_screen.dart';
import 'permissions_screen.dart';

class PeopleManagementScreen extends StatefulWidget {
  const PeopleManagementScreen({super.key});

  @override
  State<PeopleManagementScreen> createState() => _PeopleManagementScreenState();
}

class _PeopleManagementScreenState extends State<PeopleManagementScreen> {
  int _currentPage = 1;
  static const int _pageSize = 10;
  String _searchQuery = '';
  String _roleFilter = 'All';
  String _statusFilter = 'All';

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _versionedApkUrl(StationStateProvider state) {
    return AppVersionService.resolveDownloadUrl(
      state.settings.updateUrl,
      version: state.settings.latestVersion,
      buildNumber: state.settings.latestBuildNumber,
    );
  }

  void _shareApkForUser(
    BuildContext context,
    StationStateProvider state,
    UserProfile? targetUser,
  ) {
    final apkUrl = _versionedApkUrl(state);
    final ver =
        'v${state.settings.latestVersion}+${state.settings.latestBuildNumber}';
    final String msg = targetUser != null
        ? '⛽ *Reya Filling Station App ($ver)*\n'
              'Hello ${targetUser.name} (${targetUser.effectiveRoleDisplayName}),\n'
              '📲 Download & Install Android APK:\n$apkUrl\n\n'
              '🔐 Login Mobile: ${targetUser.phoneNumber}\n'
              '🔑 Security PIN: ${targetUser.securityPin}\n'
              '🌐 Web Portal: https://reya-filling-station-chatrai.web.app'
        : '⛽ *Reya Filling Station App ($ver)*\n'
              '📲 Download & Install Latest Android APK:\n$apkUrl\n'
              '🌐 Web Portal: https://reya-filling-station-chatrai.web.app';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.install_mobile_rounded,
                    color: StationColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      targetUser != null
                          ? 'Share APK & Login with ${targetUser.name}'
                          : 'Share / Download Station APK ($ver)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: StationColors.divider),
                ),
                child: SelectableText(
                  apkUrl,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: StationColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Send on WhatsApp',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      minimumSize: const Size(150, 44),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      SentinelAlertAgent.openWhatsAppAlert(msg);
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text(
                      'Copy APK Link & Details',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(150, 44),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: msg));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'APK download link & login instructions copied to clipboard!',
                          ),
                          backgroundColor: StationColors.successGreen,
                        ),
                      );
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(
                      Icons.download_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Download APK ($ver)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StationColors.primary,
                      minimumSize: const Size(150, 44),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      AppVersionService.launchDownload(
                        apkUrl,
                        version: state.settings.latestVersion,
                        buildNumber: state.settings.latestBuildNumber,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMapForUser(double lat, double lon) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lon',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _showUserScreensDialog(
    BuildContext context,
    StationStateProvider state,
    UserProfile user,
  ) {
    if (!state.currentUser.hasOwnerPrivileges) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: state,
          child: Scaffold(
            appBar: AppBar(title: const Text('Permissions')),
            body: PermissionsScreen(initialUser: user),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final allUsers = state.allUsers;
    final isOwner = state.currentUser.hasOwnerPrivileges;
    final isManager = state.currentUser.role == UserRole.manager && !isOwner;
    final pendingUsers = state.pendingApprovalUsers;

    // Filter users dynamically (Managers only see/manage non-Owner/non-Admin staff & manager accounts)
    final filteredUsers = allUsers.where((u) {
      if (isManager && u.hasOwnerPrivileges) return false;
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          u.name.toLowerCase().contains(q) ||
          u.phoneNumber.replaceAll(' ', '').contains(q.replaceAll(' ', '')) ||
          u.email.toLowerCase().contains(q) ||
          u.village.toLowerCase().contains(q);

      final matchesRole =
          _roleFilter == 'All' ||
          u.effectiveRoleDisplayName.toLowerCase() ==
              _roleFilter.toLowerCase() ||
          u.role.displayName.toLowerCase() == _roleFilter.toLowerCase();

      final isOnline = state.isUserOnline(u.id);
      final matchesStatus =
          _statusFilter == 'All' ||
          (_statusFilter == 'Active' && u.active && !u.isPendingApproval) ||
          (_statusFilter == 'Pending Approval' && u.isPendingApproval) ||
          (_statusFilter == 'Suspended' && !u.active && !u.isPendingApproval) ||
          (_statusFilter == 'Online' && isOnline);

      return matchesSearch && matchesRole && matchesStatus;
    }).toList();

    // Paginate filtered users (10 per page)
    final totalItems = filteredUsers.length;
    final int startIndex = (_currentPage - 1) * _pageSize;
    final int endIndex = (startIndex + _pageSize).clamp(0, totalItems);
    final displayedUsers = (startIndex < totalItems)
        ? filteredUsers.sublist(startIndex, endIndex)
        : <UserProfile>[];

    return LayoutBuilder(
      builder: (context, screenConstraints) {
        final isMobile = screenConstraints.maxWidth < 650;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Responsive Header
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.get('users', lang),
                        style: TextStyle(
                          fontSize: isMobile ? 22 : 26,
                          fontWeight: FontWeight.w800,
                          color: StationColors.textDark,
                        ),
                      ),
                      if (isManager)
                        const Text(
                          'Manager Portal • Add/edit staff (Owner approval required) & share APK',
                          style: TextStyle(
                            fontSize: 12,
                            color: StationColors.textMedium,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.share_rounded, size: 17),
                        label: const Text(
                          'Share / Download APK',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: StationColors.primary,
                          side: const BorderSide(color: StationColors.primary),
                          minimumSize: const Size(120, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _shareApkForUser(context, state, null),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(
                          isManager ? '+ Request New Person' : '+ Add person',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: StationColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(120, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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
                                      content: Text(
                                        isManager
                                            ? 'Submitted "${newUser.name}" to Station Owner for approval!'
                                            : 'Added user "${newUser.name}" successfully.',
                                      ),
                                      backgroundColor:
                                          StationColors.successGreen,
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
                ],
              ),
              const SizedBox(height: 16),

              // Owner Roles & Screen Permissions Matrix Card

              // Pending User Approvals Banner (Owner can Approve/Reject in 1 tap; Manager sees status)
              if (pendingUsers.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(
                      StationDimensions.cardRadius,
                    ),
                    border: Border.all(
                      color: Colors.orange.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.how_to_reg_rounded,
                            color: Colors.orange.shade900,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pending Owner User Approvals (${pendingUsers.length})',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isOwner
                            ? 'Review manager-submitted user additions and edits below. Approved users can log in immediately.'
                            : 'These user requests were submitted by a Manager and are awaiting Station Owner approval.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...pendingUsers.map((pu) {
                        final bool isEdit = pu.hasPendingEdit;
                        final Map<String, dynamic>? editMap =
                            pu.pendingEditData;
                        final String proposedSummary = isEdit && editMap != null
                            ? 'Proposed Edit → Name: ${editMap["name"]}, Role: ${editMap["role"]}, Shift: ${editMap["assignedShift"] ?? "None"}, Phone: ${editMap["phoneNumber"]}'
                            : 'New User Request → Role: ${pu.role.displayName}, Shift: ${pu.assignedShift ?? "None"}, Phone: ${pu.phoneNumber}';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${pu.name} • Requested by ${pu.requestedBy ?? "Manager"}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    proposedSummary,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: StationColors.textMedium,
                                    ),
                                  ),
                                ],
                              ),
                              if (isOwner)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      label: const Text(
                                        'Approve',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            StationColors.successGreen,
                                        minimumSize: const Size(96, 44),
                                      ),
                                      onPressed: () {
                                        state.approveUserRequest(pu.id);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Approved user "${pu.name}"!',
                                            ),
                                            backgroundColor:
                                                StationColors.successGreen,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.cancel_outlined,
                                        size: 16,
                                        color: StationColors.errorRed,
                                      ),
                                      label: const Text(
                                        'Reject',
                                        style: TextStyle(
                                          color: StationColors.errorRed,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: StationColors.errorRed,
                                        ),
                                        minimumSize: const Size(88, 44),
                                      ),
                                      onPressed: () {
                                        state.rejectUserRequest(pu.id);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Rejected request for "${pu.name}".',
                                            ),
                                            backgroundColor:
                                                StationColors.errorRed,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '⏳ Awaiting Owner Approval',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],

              // Filters Bar (Search + Role + Status)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: StationColors.divider),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Search Field
                    SizedBox(
                      width: isMobile ? double.infinity : 260,
                      child: TextField(
                        controller: _searchCtrl,
                        maxLength: 30,
                        inputFormatters: [LengthLimitingTextInputFormatter(30)],
                        onChanged: (val) => setState(() {
                          _searchQuery = val;
                          _currentPage = 1;
                        }),
                        decoration: InputDecoration(
                          hintText: 'Search name, phone, village...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          counterText: '',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    // Role Filter Dropdown
                    Container(
                      constraints: const BoxConstraints(
                        maxWidth: 220,
                        minHeight: 44,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: StationColors.divider),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _roleFilter,
                          isDense: true,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: 'All',
                              child: Text('All Roles'),
                            ),
                            if (isOwner)
                              const DropdownMenuItem(
                                value: 'Owner',
                                child: Text('Owner'),
                              ),
                            if (isOwner)
                              const DropdownMenuItem(
                                value: 'Admin',
                                child: Text('Admin'),
                              ),
                            const DropdownMenuItem(
                              value: 'Manager',
                              child: Text('Manager'),
                            ),
                            const DropdownMenuItem(
                              value: 'Shift staff',
                              child: Text('Shift staff'),
                            ),
                            ...state.settings.customRoles.map(
                              (cr) => DropdownMenuItem(
                                value: cr.name,
                                child: Text(cr.name),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null)
                              setState(() {
                                _roleFilter = val;
                                _currentPage = 1;
                              });
                          },
                        ),
                      ),
                    ),

                    // Status Filter Dropdown
                    Container(
                      constraints: const BoxConstraints(
                        maxWidth: 220,
                        minHeight: 44,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: StationColors.divider),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _statusFilter,
                          isDense: true,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'All',
                              child: Text('All Status'),
                            ),
                            DropdownMenuItem(
                              value: 'Active',
                              child: Text('Active'),
                            ),
                            DropdownMenuItem(
                              value: 'Pending Approval',
                              child: Text('Pending Approval'),
                            ),
                            DropdownMenuItem(
                              value: 'Suspended',
                              child: Text('Suspended'),
                            ),
                            DropdownMenuItem(
                              value: 'Online',
                              child: Text('Logged In (Online)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null)
                              setState(() {
                                _statusFilter = val;
                                _currentPage = 1;
                              });
                          },
                        ),
                      ),
                    ),

                    if (_searchQuery.isNotEmpty ||
                        _roleFilter != 'All' ||
                        _statusFilter != 'All')
                      TextButton.icon(
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Reset filters'),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _searchQuery = '';
                            _roleFilter = 'All';
                            _statusFilter = 'All';
                            _currentPage = 1;
                          });
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Mobile User Cards or Desktop Users Table
              if (isMobile || isManager) ...[
                if (displayedUsers.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        StationDimensions.cardRadius,
                      ),
                      border: Border.all(color: StationColors.divider),
                    ),
                    child: const Center(
                      child: Text(
                        'No users match current filters',
                        style: TextStyle(color: StationColors.textLight),
                      ),
                    ),
                  )
                else
                  ...displayedUsers.map((u) {
                    final bool isStaff = !u.hasOwnerPrivileges;
                    final String shiftDisplay = isStaff
                        ? (u.assignedShift ?? 'Unassigned')
                        : '—';
                    final bool isOnline = state.isUserOnline(u.id);
                    final bool hasLocation =
                        u.lastLatitude != null && u.lastLongitude != null;
                    final bool isSelf = state.isSelfUser(u);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          StationDimensions.cardRadius,
                        ),
                        border: Border.all(
                          color: u.isPendingApproval
                              ? Colors.orange.shade400
                              : (isSelf
                                    ? StationColors.primary.withOpacity(0.55)
                                    : StationColors.divider),
                          width: (u.isPendingApproval || isSelf) ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: u.hasOwnerPrivileges
                                    ? StationColors.primaryLight.withOpacity(
                                        0.2,
                                      )
                                    : Colors.grey.shade200,
                                child: Text(
                                  u.name.isNotEmpty ? u.name[0] : 'U',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: u.hasOwnerPrivileges
                                        ? StationColors.primary
                                        : StationColors.textDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          isSelf ? '${u.name} (Self)' : u.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (isSelf)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: StationColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Text(
                                              'Self',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${u.phoneNumber} · ${u.village.isNotEmpty ? u.village : 'Chatrai'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: StationColors.textMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: u.hasOwnerPrivileges
                                      ? StationColors.primaryLight.withOpacity(
                                          0.15,
                                        )
                                      : StationColors.accentOrangeLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  u.effectiveRoleDisplayName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: u.hasOwnerPrivileges
                                        ? StationColors.primary
                                        : StationColors.accentOrange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(
                            height: 18,
                            color: StationColors.divider,
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (isSelf)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: StationColors.primary.withOpacity(
                                      0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: StationColors.primary.withOpacity(
                                        0.35,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    '● Self (Your Login)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: StationColors.primary,
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'PIN: ${u.securityPin}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              ),
                              if (isStaff)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Shift: $shiftDisplay',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ),
                              if (u.isPendingApproval)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.orange.shade400,
                                    ),
                                  ),
                                  child: Text(
                                    u.hasPendingEdit
                                        ? '⏳ Edit Pending Approval (by ${u.requestedBy ?? "Manager"})'
                                        : '⏳ Pending Owner Approval (by ${u.requestedBy ?? "Manager"})',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                )
                              else
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: u.active
                                            ? StationColors.successGreen
                                            : StationColors.errorRed,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      u.active ? 'Active' : 'Suspended',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: u.active
                                            ? StationColors.successGreen
                                            : StationColors.errorRed,
                                      ),
                                    ),
                                  ],
                                ),
                              if (isOnline)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '● Online',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                ),
                              if (isOwner)
                                InkWell(
                                  onTap: () =>
                                      _showUserScreensDialog(context, state, u),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: u.permissions.isNotEmpty
                                          ? Colors.deepPurple.withOpacity(0.1)
                                          : Colors.blueGrey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: u.permissions.isNotEmpty
                                            ? Colors.deepPurple.withOpacity(
                                                0.35,
                                              )
                                            : Colors.blueGrey.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.admin_panel_settings_outlined,
                                          size: 11,
                                          color: u.permissions.isNotEmpty
                                              ? Colors.deepPurple[800]
                                              : Colors.blueGrey[800],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Screens: ${state.getAllowedScreensForUser(u).length} (${u.permissions.isNotEmpty ? "Custom" : "Role Default"})',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: u.permissions.isNotEmpty
                                                ? Colors.deepPurple[800]
                                                : Colors.blueGrey[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (isOwner)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: u.appVersion.isNotEmpty
                                        ? StationColors.primary.withOpacity(0.1)
                                        : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: u.appVersion.isNotEmpty
                                          ? StationColors.primary.withOpacity(
                                              0.3,
                                            )
                                          : Colors.orange.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.system_update_alt_rounded,
                                        size: 11,
                                        color: u.appVersion.isNotEmpty
                                            ? StationColors.primary
                                            : StationColors.accentOrange,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        u.appVersion.isNotEmpty
                                            ? 'App: ${u.appVersion}'
                                            : 'App: Not logged in yet',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: u.appVersion.isNotEmpty
                                              ? StationColors.primary
                                              : StationColors.accentOrange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // Live 1-Minute Location Telemetry Pill (Owner Dashboard Only)
                              if (isOwner && hasLocation)
                                InkWell(
                                  onTap: () => _openMapForUser(
                                    u.lastLatitude!,
                                    u.lastLongitude!,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (u.isAtStation ?? true)
                                          ? Colors.teal.withOpacity(0.1)
                                          : Colors.deepOrange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: (u.isAtStation ?? true)
                                            ? Colors.teal.withOpacity(0.4)
                                            : Colors.deepOrange.withOpacity(
                                                0.4,
                                              ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.my_location_rounded,
                                          size: 11,
                                          color: (u.isAtStation ?? true)
                                              ? Colors.teal[800]
                                              : Colors.deepOrange[800],
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '${state.resolveUserLocationName(u)} • ${(u.isAtStation ?? true) ? "At Station" : "Outside"} (${(u.lastDistanceMeters ?? 0).toStringAsFixed(1)}m) • ${u.lastLatitude!.toStringAsFixed(4)}°N, ${u.lastLongitude!.toStringAsFixed(4)}°E',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: (u.isAtStation ?? true)
                                                  ? Colors.teal[900]
                                                  : Colors.deepOrange[900],
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (isOwner && u.locationUpdatedAt != null)
                                Text(
                                  'GPS (1m sync): ${DateFormatter.formatTimeIST(u.locationUpdatedAt!)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: StationColors.textLight,
                                  ),
                                )
                              else if (isOwner && u.lastSeenAt != null)
                                Text(
                                  'Last active: ${DateFormatter.formatDateTimeIST(u.lastSeenAt!)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: StationColors.textLight,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            children: [
                              if (isOwner && u.isPendingApproval) ...[
                                ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.check,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Approve',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: StationColors.successGreen,
                                    minimumSize: const Size(44, 44),
                                  ),
                                  onPressed: () {
                                    state.approveUserRequest(u.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Approved "${u.name}".'),
                                        backgroundColor:
                                            StationColors.successGreen,
                                      ),
                                    );
                                  },
                                ),
                              ],
                              if (isOwner)
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.admin_panel_settings_outlined,
                                    size: 15,
                                  ),
                                  label: const Text(
                                    'Screens',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.deepPurple[800],
                                    side: BorderSide(
                                      color: Colors.deepPurple.shade300,
                                    ),
                                    minimumSize: const Size(44, 44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _showUserScreensDialog(context, state, u),
                                ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.share_rounded, size: 15),
                                label: const Text(
                                  'Share APK',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.teal[800],
                                  side: BorderSide(color: Colors.teal.shade300),
                                  minimumSize: const Size(44, 44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                onPressed: () =>
                                    _shareApkForUser(context, state, u),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.edit_outlined, size: 15),
                                label: const Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: StationColors.primary,
                                  minimumSize: const Size(44, 44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => UserFormScreen(
                                        userToEdit: u,
                                        onSave: (updated) {
                                          state.updateUser(updated);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                isManager
                                                    ? 'Edit request for "${updated.name}" sent to Owner for approval!'
                                                    : 'Updated user "${updated.name}" successfully.',
                                              ),
                                              backgroundColor:
                                                  StationColors.successGreen,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (isOwner)
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 15,
                                    color: StationColors.errorRed,
                                  ),
                                  label: const Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: StationColors.errorRed,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: StationColors.errorRed,
                                    ),
                                    minimumSize: const Size(44, 44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _showDeleteUserDialog(context, state, u),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ] else ...[
                Container(
                  width: double.infinity,
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
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 1120),
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(
                          const Color(0xFFF7F9F9),
                        ),
                        dataRowMinHeight: 58,
                        dataRowMaxHeight: 82,
                        horizontalMargin: 16,
                        columnSpacing: 18,
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Name',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Phone & PIN',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Role, Shift & Screens',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'App Version',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Live Location (1m Sync)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Status & Approval',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Actions',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                        rows: displayedUsers.map((u) {
                          final bool isStaff = !u.hasOwnerPrivileges;
                          final String shiftDisplay = isStaff
                              ? (u.assignedShift ?? 'Unassigned')
                              : '—';
                          final bool isOnline = state.isUserOnline(u.id);
                          final bool hasLocation =
                              u.lastLatitude != null && u.lastLongitude != null;
                          final bool isSelf = state.isSelfUser(u);

                          return DataRow(
                            cells: [
                              // 1. Name & Village
                              DataCell(
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: u.hasOwnerPrivileges
                                          ? StationColors.primaryLight
                                                .withOpacity(0.2)
                                          : Colors.grey.shade200,
                                      child: Text(
                                        u.name.isNotEmpty ? u.name[0] : 'U',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: u.hasOwnerPrivileges
                                              ? StationColors.primary
                                              : StationColors.textDark,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              isSelf
                                                  ? '${u.name} (Self)'
                                                  : u.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (isSelf) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1.5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: StationColors.primary,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'Self',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          u.village.isNotEmpty
                                              ? u.village
                                              : 'Chatrai',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: StationColors.textLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // 2. Phone & Security PIN
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      u.phoneNumber,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: StationColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.withOpacity(
                                          0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'PIN: ${u.securityPin}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueGrey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 3. Role, Shift & Screens
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: u.hasOwnerPrivileges
                                                ? StationColors.primaryLight
                                                      .withOpacity(0.15)
                                                : StationColors
                                                      .accentOrangeLight,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            u.effectiveRoleDisplayName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: u.hasOwnerPrivileges
                                                  ? StationColors.primary
                                                  : StationColors.accentOrange,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () => _showUserScreensDialog(
                                            context,
                                            state,
                                            u,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: u.permissions.isNotEmpty
                                                  ? Colors.deepPurple
                                                        .withOpacity(0.1)
                                                  : Colors.blueGrey.withOpacity(
                                                      0.1,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${state.getAllowedScreensForUser(u).length} screens',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: u.permissions.isNotEmpty
                                                    ? Colors.deepPurple[800]
                                                    : Colors.blueGrey[800],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isStaff) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        'Shift: $shiftDisplay',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: StationColors.textMedium,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // 4. App Version & Last Seen
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: u.appVersion.isNotEmpty
                                            ? StationColors.primary.withOpacity(
                                                0.1,
                                              )
                                            : Colors.orange.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        u.appVersion.isNotEmpty
                                            ? u.appVersion
                                            : 'Not logged in yet',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: u.appVersion.isNotEmpty
                                              ? StationColors.primary
                                              : StationColors.accentOrange,
                                        ),
                                      ),
                                    ),
                                    if (u.lastSeenAt != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormatter.formatDateTimeIST(
                                          u.lastSeenAt!,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: StationColors.textLight,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // 5. Live Location (1m Sync)
                              DataCell(
                                hasLocation
                                    ? InkWell(
                                        onTap: () => _openMapForUser(
                                          u.lastLatitude!,
                                          u.lastLongitude!,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: (u.isAtStation ?? true)
                                                    ? Colors.teal.withOpacity(
                                                        0.12,
                                                      )
                                                    : Colors.deepOrange
                                                          .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${state.resolveUserLocationName(u)} • ${(u.isAtStation ?? true) ? "● At Station" : "▲ Outside"} (${(u.lastDistanceMeters ?? 0).toStringAsFixed(1)}m)',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: (u.isAtStation ?? true)
                                                      ? Colors.teal[800]
                                                      : Colors.deepOrange[800],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${u.lastLatitude!.toStringAsFixed(4)}°N, ${u.lastLongitude!.toStringAsFixed(4)}°E',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: StationColors.primary,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                            if (u.locationUpdatedAt != null)
                                              Text(
                                                'Updated ${DateFormatter.formatTimeIST(u.locationUpdatedAt!)}',
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  color:
                                                      StationColors.textLight,
                                                ),
                                              ),
                                          ],
                                        ),
                                      )
                                    : const Text(
                                        'Awaiting GPS sync',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: StationColors.textLight,
                                        ),
                                      ),
                              ),
                              // 6. Status & Approval
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (u.isPendingApproval)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(
                                            0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          u.hasPendingEdit
                                              ? '⏳ Edit Pending'
                                              : '⏳ Pending Approval',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade900,
                                          ),
                                        ),
                                      )
                                    else
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: u.active
                                                  ? StationColors.successGreen
                                                  : StationColors.errorRed,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            u.active ? 'Active' : 'Suspended',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: u.active
                                                  ? StationColors.successGreen
                                                  : StationColors.errorRed,
                                            ),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isOnline
                                            ? Colors.green.withOpacity(0.12)
                                            : Colors.grey.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isOnline
                                            ? '● Logged In Now'
                                            : 'Offline',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isOnline
                                              ? Colors.green[800]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 7. Actions (Approve, Screens, Share APK, Edit, Delete)
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isOwner && u.isPendingApproval)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.check_circle_rounded,
                                          size: 20,
                                          color: StationColors.successGreen,
                                        ),
                                        tooltip: 'Approve User Request',
                                        onPressed: () {
                                          state.approveUserRequest(u.id);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Approved "${u.name}"!',
                                              ),
                                              backgroundColor:
                                                  StationColors.successGreen,
                                            ),
                                          );
                                        },
                                      ),
                                    if (isOwner)
                                      IconButton(
                                        icon: Icon(
                                          Icons.admin_panel_settings_outlined,
                                          size: 18,
                                          color: Colors.deepPurple[700],
                                        ),
                                        tooltip: 'Configure Screen Permissions',
                                        onPressed: () => _showUserScreensDialog(
                                          context,
                                          state,
                                          u,
                                        ),
                                      ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.share_rounded,
                                        size: 18,
                                        color: Colors.teal[700],
                                      ),
                                      tooltip: 'Share APK & Login on WhatsApp',
                                      onPressed: () =>
                                          _shareApkForUser(context, state, u),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: StationColors.primary,
                                      ),
                                      tooltip: 'Edit User',
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => UserFormScreen(
                                              userToEdit: u,
                                              onSave: (updated) {
                                                state.updateUser(updated);
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      isManager
                                                          ? 'Edit request for "${updated.name}" sent to Owner for approval!'
                                                          : 'Updated user "${updated.name}" successfully.',
                                                    ),
                                                    backgroundColor:
                                                        StationColors
                                                            .successGreen,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    if (isOwner)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: StationColors.errorRed,
                                        ),
                                        tooltip: 'Delete User',
                                        onPressed: () {
                                          _showDeleteUserDialog(
                                            context,
                                            state,
                                            u,
                                          );
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
              ],
              const SizedBox(height: 16),

              // Pagination Control
              PaginationControl(
                currentPage: _currentPage,
                pageSize: _pageSize,
                totalItems: totalItems,
                onPageChanged: (newPage) {
                  setState(() => _currentPage = newPage);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteUserDialog(
    BuildContext context,
    StationStateProvider state,
    UserProfile user,
  ) {
    if (user.role == UserRole.owner &&
        state.allUsers.where((u) => u.role == UserRole.owner).length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the sole station owner account.'),
          backgroundColor: StationColors.errorRed,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User Account'),
        content: Text(
          'Are you sure you want to delete ${user.name} (${user.role.displayName})?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: StationColors.errorRed,
            ),
            onPressed: () {
              state.deleteUser(user.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted user "${user.name}".'),
                  backgroundColor: StationColors.successGreen,
                ),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
