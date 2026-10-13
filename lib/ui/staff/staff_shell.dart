import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/station_state_provider.dart';
import '../../services/app_version_service.dart';
import '../../widgets/biometric_setup_prompt.dart';
import '../../widgets/force_update_dialog.dart';
import '../common/station_top_bar.dart';
import '../owner/people_management_screen.dart';
import '../owner/station_overview_screen.dart';
import '../owner/daily_report_screen.dart';
import '../owner/receipt_inbox_screen.dart';
import '../owner/shift_review_screen.dart';
import '../owner/money_ledger_screen.dart';
import '../owner/credit_khata_screen.dart';
import '../owner/pump_setup_screen.dart';
import '../owner/station_settings_screen.dart';
import 'my_shift_screen.dart';
import 'scan_receipt_screen.dart';
import 'money_entries_screen.dart';
import 'close_shift_screen.dart';

class _PermittedTabDef {
  final String id;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget widget;
  final bool isWideScreen;

  const _PermittedTabDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.widget,
    this.isWideScreen = false,
  });
}

class StaffShell extends StatefulWidget {
  final VoidCallback? onSwitchToOwnerPortal;

  const StaffShell({super.key, this.onSwitchToOwnerPortal});

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final state = context.read<StationStateProvider>();
        AppVersionService.checkAndPromptUpdate(context, state.settings);
        BiometricSetupPrompt.checkAndShowPrompt(context, state.currentUser);
      }
    });
  }

  void _navigateToScreenId(List<_PermittedTabDef> tabs, String screenId) {
    final idx = tabs.indexWhere((t) => t.id == screenId);
    if (idx != -1) {
      setState(() => _currentTabIndex = idx);
    }
  }

  List<_PermittedTabDef> _buildPermittedTabs(
    StationStateProvider state,
    String lang,
  ) {
    final allowedIds = state.getAllowedScreensForUser(state.currentUser);
    final List<_PermittedTabDef> tabs = [];

    for (final id in allowedIds) {
      switch (id) {
        case 'my_shift':
          tabs.add(
            _PermittedTabDef(
              id: 'my_shift',
              label: AppStrings.get('myShift', lang),
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              widget: MyShiftScreen(
                onTabChange: (index) {
                  if (index == 1) {
                    _navigateToScreenId(tabs, 'scan_receipt');
                  } else if (index == 4) {
                    _navigateToScreenId(tabs, 'people_management');
                  } else if (index >= 0 && index < tabs.length) {
                    setState(() => _currentTabIndex = index);
                  }
                },
              ),
            ),
          );
          break;
        case 'scan_receipt':
          tabs.add(
            _PermittedTabDef(
              id: 'scan_receipt',
              label: AppStrings.get('scan', lang),
              icon: Icons.camera_alt_outlined,
              activeIcon: Icons.camera_alt,
              widget: ScanReceiptScreen(
                onNavigate: (index) {
                  if (index == 0) {
                    _navigateToScreenId(tabs, 'my_shift');
                  } else if (index >= 0 && index < tabs.length) {
                    setState(() => _currentTabIndex = index);
                  }
                },
              ),
            ),
          );
          break;
        case 'money_entries':
          tabs.add(
            _PermittedTabDef(
              id: 'money_entries',
              label: AppStrings.get('entries', lang),
              icon: Icons.format_list_bulleted_rounded,
              activeIcon: Icons.format_list_bulleted_rounded,
              widget: const MoneyEntriesScreen(),
            ),
          );
          break;
        case 'close_shift':
          tabs.add(
            _PermittedTabDef(
              id: 'close_shift',
              label: AppStrings.get('close', lang),
              icon: Icons.access_time_rounded,
              activeIcon: Icons.access_time_filled_rounded,
              widget: const CloseShiftScreen(),
            ),
          );
          break;
        case 'people_management':
          tabs.add(
            _PermittedTabDef(
              id: 'people_management',
              label: lang == 'te' ? 'సిబ్బంది' : 'Users',
              icon: Icons.people_outline_rounded,
              activeIcon: Icons.people_rounded,
              widget: const PeopleManagementScreen(),
              isWideScreen: true,
            ),
          );
          break;
        case 'station_overview':
          tabs.add(
            _PermittedTabDef(
              id: 'station_overview',
              label: lang == 'te' ? 'వివరాలు' : 'Overview',
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              widget: StationOverviewScreen(onNavigate: (_) {}),
              isWideScreen: true,
            ),
          );
          break;
        case 'daily_report':
          tabs.add(
            _PermittedTabDef(
              id: 'daily_report',
              label: lang == 'te' ? 'నివేదిక' : 'Reports',
              icon: Icons.assessment_outlined,
              activeIcon: Icons.assessment_rounded,
              widget: const DailyReportScreen(),
              isWideScreen: true,
            ),
          );
          break;
        case 'receipt_inbox':
          tabs.add(
            _PermittedTabDef(
              id: 'receipt_inbox',
              label: lang == 'te' ? 'రసీదులు' : 'Receipts',
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              widget: const ReceiptInboxScreen(),
              isWideScreen: true,
            ),
          );
          break;
        case 'shift_review':
          tabs.add(
            _PermittedTabDef(
              id: 'shift_review',
              label: lang == 'te' ? 'షిఫ్టులు' : 'Shifts',
              icon: Icons.fact_check_outlined,
              activeIcon: Icons.fact_check_rounded,
              widget: ShiftReviewScreen(onNavigateToReports: (_) {}),
              isWideScreen: true,
            ),
          );
          break;
        case 'money_ledger':
          tabs.add(
            _PermittedTabDef(
              id: 'money_ledger',
              label: lang == 'te' ? 'చిట్టా' : 'Ledger',
              icon: Icons.account_balance_wallet_outlined,
              activeIcon: Icons.account_balance_wallet_rounded,
              widget: const MoneyLedgerScreen(),
              isWideScreen: true,
            ),
          );
          break;
        case 'credit_khata':
          tabs.add(
            _PermittedTabDef(
              id: 'credit_khata',
              label: lang == 'te' ? 'అరువు' : 'Khata',
              icon: Icons.menu_book_outlined,
              activeIcon: Icons.menu_book_rounded,
              widget: const CreditKhataScreen(),
              isWideScreen: true,
            ),
          );
          break;
        case 'pump_setup':
          tabs.add(
            _PermittedTabDef(
              id: 'pump_setup',
              label: lang == 'te' ? 'పంపులు' : 'Pumps',
              icon: Icons.local_gas_station_outlined,
              activeIcon: Icons.local_gas_station_rounded,
              widget: const PumpSetupScreen(),
              isWideScreen: true,
            ),
          );
          break;
        case 'station_settings':
          tabs.add(
            _PermittedTabDef(
              id: 'station_settings',
              label: lang == 'te' ? 'సెట్టింగ్స్' : 'Settings',
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings_rounded,
              widget: const StationSettingsScreen(),
              isWideScreen: true,
            ),
          );
          break;
      }
    }

    if (tabs.isEmpty) {
      tabs.add(
        _PermittedTabDef(
          id: 'my_shift',
          label: AppStrings.get('myShift', lang),
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          widget: MyShiftScreen(onTabChange: (_) {}),
        ),
      );
    }
    return tabs;
  }

  void _showMorePermittedScreensSheet(
    BuildContext context,
    List<_PermittedTabDef> tabs,
    int safeIndex,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Permitted Screens',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tabs.length,
                  itemBuilder: (_, i) {
                    final tab = tabs[i];
                    final selected = i == safeIndex;
                    return ListTile(
                      leading: Icon(
                        selected ? tab.activeIcon : tab.icon,
                        color: selected
                            ? StationColors.primary
                            : StationColors.textMedium,
                      ),
                      title: Text(
                        tab.label,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: selected
                              ? StationColors.primary
                              : StationColors.textDark,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_circle,
                              color: StationColors.primary,
                              size: 18,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _currentTabIndex = i);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final hasUpdate = AppVersionService.isUpdateAvailable(state.settings);

    if (hasUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppVersionService.checkAndPromptUpdate(context, state.settings);
        }
      });
    }

    final tabs = _buildPermittedTabs(state, lang);
    final int safeIndex = _currentTabIndex >= tabs.length
        ? 0
        : _currentTabIndex;
    final activeTab = tabs[safeIndex];
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final maxShellWidth = activeTab.isWideScreen ? 960.0 : 480.0;
    final barWidth = screenWidth < 480.0 ? screenWidth : 480.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F4),
      appBar: StationTopBar(
        onLogout: () => state.logout(),
        onNavigateTab: (ownerTabIndex) {
          if (ownerTabIndex == 5) {
            _navigateToScreenId(tabs, 'people_management');
          } else if (ownerTabIndex == 2) {
            _navigateToScreenId(tabs, 'shift_review');
          } else if (ownerTabIndex == 1) {
            _navigateToScreenId(tabs, 'receipt_inbox');
          }
        },
      ),
      body: Row(
        children: [
          if (isDesktop)
            SizedBox(
              key: const ValueKey('staff-desktop-menu'),
              width: 220,
              child: ListView(
                children: [
                  for (int index = 0; index < tabs.length; index++)
                    ListTile(
                      minTileHeight: 48,
                      selected: safeIndex == index,
                      leading: Icon(tabs[index].icon),
                      title: Text(tabs[index].label),
                      onTap: () => setState(() => _currentTabIndex = index),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxShellWidth),
                width: double.infinity,
                height: double.infinity,
                color: StationColors.scaffoldBg,
                child: Column(
                  children: [
                    if (hasUpdate)
                      Material(
                        color: const Color(0xFFFFF7ED),
                        child: InkWell(
                          onTap: () => ForceUpdateDialog.show(
                            context,
                            state.settings,
                            previewMode: !state.settings.forceUpdate,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: StationColors.accentOrangeBorder,
                                ),
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
                                    'Update Available (v${state.settings.latestVersion}+${state.settings.latestBuildNumber}) • Tap to Install',
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
                      ),
                    Expanded(child: activeTab.widget),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: StationColors.divider, width: 0.8),
                ),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: barWidth,
                      // BottomNavigationBar requires at least two items. Keep a
                      // visible, selected destination for a single permitted screen.
                      child: tabs.length == 1
                          ? Semantics(
                              selected: true,
                              button: true,
                              label: activeTab.label,
                              child: Material(
                                color: Colors.white,
                                child: InkWell(
                                  key: const ValueKey(
                                    'staff-single-tab-footer',
                                  ),
                                  onTap: () =>
                                      setState(() => _currentTabIndex = 0),
                                  child: SizedBox(
                                    height: 64,
                                    child: ExcludeSemantics(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            activeTab.activeIcon,
                                            color: StationColors.primary,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            activeTab.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: StationColors.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : BottomNavigationBar(
                              currentIndex: tabs.length <= 5
                                  ? safeIndex
                                  : (safeIndex < 4 ? safeIndex : 4),
                              onTap: (index) {
                                if (tabs.length <= 5) {
                                  setState(() => _currentTabIndex = index);
                                } else {
                                  if (index < 4) {
                                    setState(() => _currentTabIndex = index);
                                  } else {
                                    _showMorePermittedScreensSheet(
                                      context,
                                      tabs,
                                      safeIndex,
                                    );
                                  }
                                }
                              },
                              type: BottomNavigationBarType.fixed,
                              backgroundColor: Colors.white,
                              selectedItemColor: StationColors.primary,
                              unselectedItemColor: StationColors.textLight,
                              selectedFontSize: 12,
                              unselectedFontSize: 11,
                              selectedLabelStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              items: tabs.length <= 5
                                  ? tabs
                                        .map(
                                          (t) => BottomNavigationBarItem(
                                            icon: Icon(t.icon),
                                            activeIcon: Icon(t.activeIcon),
                                            label: t.label,
                                          ),
                                        )
                                        .toList()
                                  : [
                                      ...tabs
                                          .take(4)
                                          .map(
                                            (t) => BottomNavigationBarItem(
                                              icon: Icon(t.icon),
                                              activeIcon: Icon(t.activeIcon),
                                              label: t.label,
                                            ),
                                          ),
                                      const BottomNavigationBarItem(
                                        icon: Icon(Icons.more_horiz_rounded),
                                        activeIcon: Icon(
                                          Icons.more_horiz_rounded,
                                        ),
                                        label: 'More',
                                      ),
                                    ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
