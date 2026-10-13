import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/station_state_provider.dart';
import '../common/station_top_bar.dart';
import 'station_overview_screen.dart';
import 'receipt_inbox_screen.dart';
import 'shift_review_screen.dart';
import 'money_ledger_screen.dart';
import 'credit_khata_screen.dart';
import 'people_management_screen.dart';
import 'roles_screen.dart';
import 'permissions_screen.dart';
import 'pump_setup_screen.dart';
import 'station_settings_screen.dart';
import 'daily_report_screen.dart';
import '../../services/app_version_service.dart';
import '../../widgets/biometric_setup_prompt.dart';
import '../../services/remote_logging_service.dart';

import '../../widgets/force_update_dialog.dart';
import '../../models/shift.dart';

class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    RemoteLoggingService().logScreenView('OwnerShell:StationOverview');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final state = context.read<StationStateProvider>();
        AppVersionService.checkAndPromptUpdate(context, state.settings);
        BiometricSetupPrompt.checkAndShowPrompt(context, state.currentUser);
      }
    });
  }

  void _onSelectTab(int index) {
    if (_selectedNavIndex != index) {
      setState(() => _selectedNavIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final hasUpdate = AppVersionService.isUpdateAvailable(state.settings);

    if (hasUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppVersionService.checkAndPromptUpdate(context, state.settings);
        }
      });
    }

    final List<Widget> screens = [
      StationOverviewScreen(onNavigate: (i) => _onSelectTab(i)), // 0
      const ReceiptInboxScreen(), // 1
      ShiftReviewScreen(onNavigateToReports: (i) => _onSelectTab(i)), // 2
      const MoneyLedgerScreen(), // 3
      const CreditKhataScreen(), // 4
      const PeopleManagementScreen(), // 5
      const PumpSetupScreen(), // 6
      const StationSettingsScreen(), // 7
      const DailyReportScreen(), // 8
      const RolesScreen(), // 9
      const PermissionsScreen(), // 10
    ];

    return Scaffold(
      backgroundColor: StationColors.scaffoldBg,
      appBar: StationTopBar(
        isOwnerView: true,
        onNavigateTab: (i) => _onSelectTab(i),
      ),
      bottomNavigationBar: isDesktop
          ? null
          : _buildBottomNav(context, state, lang),
      body: Row(
        children: [
          if (isDesktop) _buildDesktopMenu(),
          Expanded(
            child: Column(
              children: [
                if (hasUpdate) _buildUpdateBanner(context, state),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: screens[_selectedNavIndex],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopMenu() {
    final destinations = <(int, String, IconData)>[
      (0, 'Overview', Icons.dashboard_rounded),
      (8, 'Reports', Icons.bar_chart_rounded),
      (3, 'Ledger', Icons.account_balance_wallet_rounded),
      (1, 'Receipts', Icons.receipt_long_rounded),
      (2, 'Shifts', Icons.assignment_rounded),
      (4, 'Credit', Icons.credit_score_rounded),
      (5, 'Users', Icons.people_rounded),
      (9, 'Roles', Icons.badge_outlined),
      (10, 'Permissions', Icons.admin_panel_settings_outlined),
      (6, 'Pumps', Icons.local_gas_station_rounded),
      (7, 'Settings', Icons.settings_rounded),
    ];
    return Container(
      key: const ValueKey('owner-desktop-menu'),
      width: 220,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: StationColors.divider)),
      ),
      // Fixed application destinations are not a record feed; keep every link reachable.
      child: ListView(
        children: [
          for (final item in destinations)
            ListTile(
              selected: _selectedNavIndex == item.$1,
              minTileHeight: 48,
              leading: Icon(item.$3),
              title: Text(item.$2),
              onTap: () => _onSelectTab(item.$1),
            ),
        ],
      ),
    );
  }

  Widget _buildUpdateBanner(BuildContext context, StationStateProvider state) {
    final targetVer =
        'v${state.settings.latestVersion}+${state.settings.latestBuildNumber}';
    return Material(
      color: const Color(0xFFFFF7ED),
      child: InkWell(
        onTap: () => ForceUpdateDialog.show(
          context,
          state.settings,
          previewMode: !state.settings.forceUpdate,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: StationColors.accentOrangeBorder),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.system_update_alt_rounded,
                color: StationColors.accentOrange,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'New App Update Available ($targetVer) • Tap to download & install latest APK',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9A3412),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: StationColors.accentOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Update',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(
    BuildContext context,
    StationStateProvider state,
    String lang,
  ) {
    int currentBottomIdx;
    if (_selectedNavIndex == 0) {
      currentBottomIdx = 0;
    } else if (_selectedNavIndex == 8) {
      currentBottomIdx = 1;
    } else if (_selectedNavIndex == 3) {
      currentBottomIdx = 2;
    } else if (_selectedNavIndex == 1) {
      currentBottomIdx = 3;
    } else {
      currentBottomIdx = 4; // More (Shifts, Credit, Users, Pumps, Settings)
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: StationColors.divider)),
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: BottomNavigationBar(
            currentIndex: currentBottomIdx,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: StationColors.primary,
            unselectedItemColor: StationColors.textMedium,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            iconSize: 22,
            elevation: 0,
            onTap: (navIdx) {
              switch (navIdx) {
                case 0:
                  _onSelectTab(0); // Overview
                  break;
                case 1:
                  _onSelectTab(8); // Reports
                  break;
                case 2:
                  _onSelectTab(3); // Money Ledger
                  break;
                case 3:
                  _onSelectTab(1); // Receipts
                  break;
                case 4:
                  _showMoreNavigationSheet(context, state, lang);
                  break;
              }
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_rounded),
                label: 'Overview',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_rounded),
                label: 'Reports',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Ledger',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_rounded),
                label: 'Receipts',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_rounded),
                label: 'More',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreNavigationSheet(
    BuildContext context,
    StationStateProvider state,
    String lang,
  ) {
    final pendingShiftsCount = state.allShifts
        .where((s) => s.status == ShiftStatus.needsReview)
        .length;
    final List<Map<String, dynamic>> moreItems = [
      {
        'index': 2,
        'title': AppStrings.get('shifts', lang),
        'subtitle': pendingShiftsCount > 0
            ? '$pendingShiftsCount shift(s) awaiting approval'
            : 'Review & approve shift handovers',
        'icon': Icons.assignment_rounded,
        'badge': pendingShiftsCount > 0 ? '$pendingShiftsCount' : null,
      },
      {
        'index': 4,
        'title': AppStrings.get('credit', lang),
        'subtitle':
            '${state.creditCustomers.length} credit customer account(s)',
        'icon': Icons.credit_score_rounded,
        'badge': null,
      },
      {
        'index': 5,
        'title': AppStrings.get('users', lang),
        'subtitle': 'Manage station users',
        'icon': Icons.people_rounded,
        'badge': null,
      },
      {
        'index': 9,
        'title': 'Roles',
        'subtitle': 'Create and manage roles',
        'icon': Icons.badge_outlined,
        'badge': null,
      },
      {
        'index': 10,
        'title': 'Permissions',
        'subtitle': 'Assign screen access by role',
        'icon': Icons.admin_panel_settings_outlined,
        'badge': null,
      },
      {
        'index': 6,
        'title': AppStrings.get('pumps', lang),
        'subtitle': 'Configure dispensers, nozzles & fuel rates',
        'icon': Icons.local_gas_station_rounded,
        'badge': null,
      },
      {
        'index': 7,
        'title': AppStrings.get('settings', lang),
        'subtitle': 'Shift timings, database purge & APK releases',
        'icon': Icons.settings_rounded,
        'badge': null,
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'More Station Controls',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: StationColors.textDark,
                      ),
                    ),
                    const Divider(height: 12),
                    ...moreItems.map((item) {
                      final int idx = item['index'] as int;
                      final bool isSelected = _selectedNavIndex == idx;
                      final String? badge = item['badge'] as String?;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected
                                  ? StationColors.primary
                                  : StationColors.divider,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          tileColor: isSelected
                              ? StationColors.primaryLight.withOpacity(0.1)
                              : const Color(0xFFF8FAFC),
                          leading: CircleAvatar(
                            backgroundColor: isSelected
                                ? StationColors.primary
                                : Colors.white,
                            child: Icon(
                              item['icon'] as IconData,
                              color: isSelected
                                  ? Colors.white
                                  : StationColors.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            item['title'] as String,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isSelected
                                  ? StationColors.primary
                                  : StationColors.textDark,
                            ),
                          ),
                          subtitle: Text(
                            item['subtitle'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              color: StationColors.textMedium,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (badge != null)
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: StationColors.accentOrange,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    badge,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: StationColors.textLight,
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            _onSelectTab(idx);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
