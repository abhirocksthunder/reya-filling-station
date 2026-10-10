import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/station_state_provider.dart';
import '../common/station_top_bar.dart';
import 'my_shift_screen.dart';
import 'scan_receipt_screen.dart';
import 'money_entries_screen.dart';
import 'close_shift_screen.dart';

class StaffShell extends StatefulWidget {
  final VoidCallback? onSwitchToOwnerPortal;

  const StaffShell({super.key, this.onSwitchToOwnerPortal});

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;

    final List<Widget> screens = [
      MyShiftScreen(onTabChange: (index) => setState(() => _currentTabIndex = index)),
      ScanReceiptScreen(onNavigate: (index) => setState(() => _currentTabIndex = index)),
      const MoneyEntriesScreen(),
      CloseShiftScreen(
        onViewDetails: () {
          if (widget.onSwitchToOwnerPortal != null) {
            widget.onSwitchToOwnerPortal!();
          }
        },
      ),
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final maxShellWidth = 480.0;
    final barWidth = screenWidth < maxShellWidth ? screenWidth : maxShellWidth;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F4),
      appBar: StationTopBar(
        onLogout: () => state.logout(),
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxShellWidth),
          width: double.infinity,
          height: double.infinity,
          color: StationColors.scaffoldBg,
          child: screens[_currentTabIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: StationColors.divider, width: 0.8)),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: barWidth,
                child: BottomNavigationBar(
                  currentIndex: _currentTabIndex,
                  onTap: (index) => setState(() => _currentTabIndex = index),
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.white,
                  selectedItemColor: StationColors.primary,
                  unselectedItemColor: StationColors.textLight,
                  selectedFontSize: 12,
                  unselectedFontSize: 11,
                  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.home_outlined),
                      activeIcon: const Icon(Icons.home),
                      label: AppStrings.get('myShift', lang),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.camera_alt_outlined),
                      activeIcon: const Icon(Icons.camera_alt),
                      label: AppStrings.get('scan', lang),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.format_list_bulleted_rounded),
                      activeIcon: const Icon(Icons.format_list_bulleted_rounded),
                      label: AppStrings.get('entries', lang),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.access_time_rounded),
                      activeIcon: const Icon(Icons.access_time_filled_rounded),
                      label: AppStrings.get('close', lang),
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
