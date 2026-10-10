import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../l10n/app_strings.dart';
import '../../models/user_profile.dart';
import '../../services/station_state_provider.dart';

class StationTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onNotificationTap;
  final bool isOwnerView;

  const StationTopBar({
    super.key,
    this.onNotificationTap,
    this.isOwnerView = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64.0);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      surfaceTintColor: Colors.transparent,
      titleSpacing: StationDimensions.paddingMedium,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: StationColors.primaryLight.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_gas_station_rounded, color: StationColors.primary, size: 24),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.get('appName', lang),
                style: const TextStyle(
                  color: StationColors.textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                AppStrings.get('demoSampleData', lang),
                style: const TextStyle(
                  color: StationColors.textLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Language Toggle Pill
        Container(
          margin: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: StationColors.accentOrangeLight,
            borderRadius: BorderRadius.circular(StationDimensions.pillRadius),
            border: Border.all(color: StationColors.accentOrangeBorder.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLangOption(context, 'తెలుగు', 'te', lang == 'te'),
              Container(width: 1, height: 16, color: StationColors.accentOrangeBorder),
              _buildLangOption(context, 'EN', 'en', lang == 'en'),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Notifications Bell (with badge)
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: StationColors.textDark),
              tooltip: 'Notifications',
              onPressed: onNotificationTap ?? () => _showNotificationSheet(context),
            ),
            if (state.notifications.isNotEmpty)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: StationColors.accentOrange,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),

        // Persona / Role Switcher Menu
        PopupMenuButton<UserProfile>(
          tooltip: 'Switch Persona',
          offset: const Offset(0, 50),
          initialValue: state.currentUser,
          child: Container(
            margin: const EdgeInsets.only(right: 16, left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: StationColors.primaryDark,
              borderRadius: BorderRadius.circular(StationDimensions.pillRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.white24,
                  child: Text(
                    state.currentUser.name[0],
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  state.currentUser.role == UserRole.owner ? 'Owner' : state.currentUser.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
              ],
            ),
          ),
          onSelected: (user) => state.switchUser(user),
          itemBuilder: (context) {
            return [
              const PopupMenuItem<UserProfile>(
                enabled: false,
                child: Text(
                  'Switch Active Persona (Demo)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                ),
              ),
              ...state.allUsers.map((user) {
                bool isSelected = user.id == state.currentUser.id;
                return PopupMenuItem<UserProfile>(
                  value: user,
                  child: Row(
                    children: [
                      Icon(
                        user.role == UserRole.owner
                            ? Icons.admin_panel_settings_rounded
                            : user.role == UserRole.manager
                                ? Icons.manage_accounts_rounded
                                : Icons.person_rounded,
                        size: 20,
                        color: isSelected ? StationColors.primary : Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? StationColors.primary : Colors.black87,
                              ),
                            ),
                            Text(
                              '${user.role.displayName} • ${user.assignedShift}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected) const Icon(Icons.check, size: 18, color: StationColors.primary),
                    ],
                  ),
                );
              }),
              const PopupMenuDivider(),
              // Geofence Simulation Toggle
              PopupMenuItem<UserProfile>(
                enabled: false,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    state.toggleGeofenceSimulation();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          state.simulateInsideGeofence ? Icons.location_on : Icons.location_off,
                          color: state.simulateInsideGeofence ? StationColors.successGreen : StationColors.errorRed,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            state.simulateInsideGeofence
                                ? 'Simulate: Outside Geofence'
                                : 'Simulate: Inside Geofence (150m)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
        ),
      ],
    );
  }

  Widget _buildLangOption(BuildContext context, String title, String code, bool isSelected) {
    return InkWell(
      onTap: () => context.read<StationStateProvider>().setLanguage(code),
      borderRadius: BorderRadius.circular(StationDimensions.pillRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? StationColors.accentOrange : StationColors.textMedium,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _showNotificationSheet(BuildContext context) {
    final state = context.read<StationStateProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Station Notifications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              if (state.notifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('No new notifications')),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: state.notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final item = state.notifications[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item.isWarning
                              ? StationColors.warningBg
                              : StationColors.successBg,
                          child: Icon(
                            item.isWarning ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                            color: item.isWarning ? StationColors.warningAmber : StationColors.successGreen,
                            size: 20,
                          ),
                        ),
                        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(item.subtitle, style: const TextStyle(fontSize: 12)),
                        dense: true,
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
