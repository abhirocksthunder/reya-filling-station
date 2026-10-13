import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/date_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../models/user_profile.dart';
import '../../services/station_state_provider.dart';
import '../../services/app_version_service.dart';
import '../../widgets/version_footer.dart';
import '../../widgets/force_update_dialog.dart';

class StationTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onNotificationTap;
  final Function(int)? onNavigateTab;
  final bool isOwnerView;
  final VoidCallback? onLogout;
  final Widget? leading;

  const StationTopBar({
    super.key,
    this.onNotificationTap,
    this.onNavigateTab,
    this.isOwnerView = false,
    this.onLogout,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64.0);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final user = state.currentUser;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return AppBar(
      leading: leading,
      backgroundColor: Colors.white,
      elevation: 0.5,
      surfaceTintColor: Colors.transparent,
      titleSpacing: leading != null ? 0 : StationDimensions.paddingMedium,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: StationColors.primaryLight.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_gas_station_rounded, color: StationColors.primary, size: 22),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.get('appName', lang),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: StationColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const VersionFooter(compact: true),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Live Dynamic IST Date Badge (hidden on compact mobile to prevent crowding)
        if (!isMobile) ...[
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(StationDimensions.pillRadius),
              border: Border.all(color: StationColors.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.today, size: 14, color: StationColors.primary),
                const SizedBox(width: 5),
                Text(
                  DateFormatter.formatDisplayDate(DateTime.now()),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: StationColors.textDark),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],

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
        const SizedBox(width: 4),

        // Notifications Bell
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: StationColors.textDark, size: 22),
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

        // User Profile & Logout (Strictly isolated: NO dropdown of other users!)
        PopupMenuButton<String>(
          tooltip: 'My Account',
          offset: const Offset(0, 50),
          child: Container(
            margin: EdgeInsets.only(right: isMobile ? 8 : 16, left: 2),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: 6),
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
                    user.name.isNotEmpty ? user.name[0] : 'U',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 8),
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
              ],
            ),
          ),
          itemBuilder: (context) {
            return [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '${user.name} (Self)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: StationColors.textDark),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: StationColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Self',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${user.role.displayName}${user.assignedShift != null ? ' • ${user.assignedShift}' : ''}',
                      style: const TextStyle(fontSize: 12, color: StationColors.primary, fontWeight: FontWeight.w600),
                    ),
                    if (user.email.isNotEmpty)
                      Text(user.email, style: const TextStyle(fontSize: 11, color: StationColors.textLight)),
                    Text(user.phoneNumber, style: const TextStyle(fontSize: 11, color: StationColors.textLight)),
                    const SizedBox(height: 6),
                    const VersionFooter(),
                    const Divider(),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'apk',
                child: Row(
                  children: const [
                    Icon(Icons.system_update_alt, size: 18, color: StationColors.primary),
                    SizedBox(width: 10),
                    Text('Download / Share APK', style: TextStyle(color: StationColors.primary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: const [
                    Icon(Icons.logout, size: 18, color: StationColors.errorRed),
                    SizedBox(width: 10),
                    Text('Logout', style: TextStyle(color: StationColors.errorRed, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ];
          },
          onSelected: (val) {
            if (val == 'apk') {
              ForceUpdateDialog.show(
                context,
                state.settings,
                previewMode: true,
              );
            } else if (val == 'logout') {
              if (onLogout != null) {
                onLogout!();
              } else {
                state.logout();
              }
            }
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
                    itemBuilder: (sheetContext, i) {
                      final item = state.notifications[i];
                      final lower = item.title.toLowerCase();
                      final isApkOrUpdate = lower.contains('apk') || lower.contains('update');
                      return ListTile(
                        onTap: (onNavigateTab == null && !isApkOrUpdate)
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                if (isApkOrUpdate) {
                                  ForceUpdateDialog.show(
                                    context,
                                    state.settings,
                                    previewMode: !state.settings.forceUpdate,
                                  );
                                  if (onNavigateTab != null && !AppVersionService.isUpdateAvailable(state.settings)) {
                                    onNavigateTab!(7); // Settings
                                  }
                                } else if (onNavigateTab != null) {
                                  if (lower.contains('user')) {
                                    onNavigateTab!(5); // People Management
                                  } else if (lower.contains('shift')) {
                                    onNavigateTab!(2); // Shift Review
                                  } else if (lower.contains('receipt')) {
                                    onNavigateTab!(1); // Receipts Inbox
                                  } else if (lower.contains('credit')) {
                                    onNavigateTab!(4); // Credit Khata
                                  } else if (lower.contains('pump')) {
                                    onNavigateTab!(6); // Pump Setup
                                  } else if (lower.contains('settings')) {
                                    onNavigateTab!(7); // Settings
                                  } else {
                                    onNavigateTab!(3); // Money Ledger
                                  }
                                }
                              },
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
                        subtitle: Text(
                          '${item.subtitle} • ${DateFormatter.formatTimeIST(item.timestamp)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: (onNavigateTab != null || isApkOrUpdate)
                            ? const Icon(Icons.chevron_right, size: 18, color: StationColors.textLight)
                            : null,
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
