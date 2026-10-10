import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../l10n/app_strings.dart';
import '../../services/station_state_provider.dart';
import '../common/station_top_bar.dart';
import 'station_overview_screen.dart';
import 'receipt_inbox_screen.dart';
import 'shift_review_screen.dart';
import 'money_ledger_screen.dart';
import 'credit_khata_screen.dart';
import 'people_management_screen.dart';
import 'pump_setup_screen.dart';
import 'station_settings_screen.dart';
import 'daily_report_screen.dart';
import '../../services/app_version_service.dart';
import '../../widgets/version_footer.dart';
import '../../widgets/biometric_setup_prompt.dart';

class OwnerShell extends StatefulWidget {
  final VoidCallback? onSwitchToStaffView;

  const OwnerShell({super.key, this.onSwitchToStaffView});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _selectedNavIndex = 0;

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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;

    final List<Widget> screens = [
      StationOverviewScreen(onNavigate: (i) => setState(() => _selectedNavIndex = i)), // 0
      const ReceiptInboxScreen(), // 1
      ShiftReviewScreen(onNavigateToReports: (i) => setState(() => _selectedNavIndex = i)), // 2
      const MoneyLedgerScreen(), // 3
      const CreditKhataScreen(), // 4
      const PeopleManagementScreen(), // 5
      const PumpSetupScreen(), // 6
      const StationSettingsScreen(), // 7
      const DailyReportScreen(), // 8
    ];

    return Scaffold(
      backgroundColor: StationColors.scaffoldBg,
      appBar: const StationTopBar(isOwnerView: true),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWide = constraints.maxWidth >= 900;

          if (!isWide) {
            // Mobile / Tablet Drawer Layout
            return Scaffold(
              drawer: Drawer(
                backgroundColor: StationColors.primaryDark,
                child: _buildSidebarContent(lang),
              ),
              appBar: AppBar(
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                title: Text(
                  _getSectionTitle(_selectedNavIndex, lang),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.white,
                elevation: 0,
              ),
              body: screens[_selectedNavIndex],
            );
          }

          // Desktop Side Navigation Layout
          return Row(
            children: [
              // Sidebar
              Container(
                width: 240,
                decoration: const BoxDecoration(
                  color: StationColors.primaryDark,
                ),
                child: _buildSidebarContent(lang),
              ),
              // Main Content
              Expanded(
                child: screens[_selectedNavIndex],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSidebarContent(String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // Operations Section
        _buildSectionHeader('Operations'),
        _buildSidebarItem(0, Icons.dashboard_outlined, AppStrings.get('overview', lang)),
        _buildSidebarItem(1, Icons.receipt_long_outlined, AppStrings.get('receipts', lang)),
        _buildSidebarItem(2, Icons.assignment_outlined, AppStrings.get('shifts', lang)),
        _buildSidebarItem(3, Icons.account_balance_wallet_outlined, AppStrings.get('money', lang)),
        _buildSidebarItem(4, Icons.credit_score_outlined, AppStrings.get('credit', lang)),
        const SizedBox(height: 16),
        // Administration Section
        _buildSectionHeader('Administration'),
        _buildSidebarItem(5, Icons.people_outline, AppStrings.get('users', lang)),
        _buildSidebarItem(6, Icons.local_gas_station_outlined, AppStrings.get('pumps', lang)),
        _buildSidebarItem(7, Icons.settings_outlined, AppStrings.get('settings', lang)),
        _buildSidebarItem(8, Icons.bar_chart_outlined, AppStrings.get('reports', lang)),
        const Spacer(),
        // Bottom Switch to Forecourt Staff View Button
        Container(
          margin: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.phone_android, size: 16, color: Colors.white70),
              label: const Text('Staff Phone View', style: TextStyle(color: Colors.white, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (widget.onSwitchToStaffView != null) {
                  widget.onSwitchToStaffView!();
                }
              },
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Center(
            child: VersionFooter(compact: true, color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    bool isSelected = _selectedNavIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _selectedNavIndex = index);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? StationColors.accentOrangeBorder : Colors.white70,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSectionTitle(int index, String lang) {
    switch (index) {
      case 0:
        return AppStrings.get('overview', lang);
      case 1:
        return AppStrings.get('receipts', lang);
      case 2:
        return AppStrings.get('shifts', lang);
      case 3:
        return AppStrings.get('money', lang);
      case 4:
        return AppStrings.get('credit', lang);
      case 5:
        return AppStrings.get('users', lang);
      case 6:
        return AppStrings.get('pumps', lang);
      case 7:
        return AppStrings.get('settings', lang);
      case 8:
        return AppStrings.get('reports', lang);
      default:
        return 'Operations';
    }
  }
}
