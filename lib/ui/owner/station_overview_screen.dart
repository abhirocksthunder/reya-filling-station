import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../services/station_state_provider.dart';

class StationOverviewScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const StationOverviewScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.get('stationOverview', lang),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: StationColors.textDark),
                  ),
                  const SizedBox(height: 2),
                  const Text('10 Oct 2026', style: TextStyle(fontSize: 14, color: StationColors.textMedium)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Illustrative sample data', style: TextStyle(fontSize: 11, color: Colors.black54)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Alert Banner: 2 shifts need review
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: StationColors.warningBg,
              borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
              border: Border.all(color: StationColors.warningBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: StationColors.warningAmber, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '2 shifts need review',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: StationColors.warningAmber),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppStrings.get('unverifiedEntriesNotice', lang),
                        style: const TextStyle(fontSize: 13, color: StationColors.textMedium),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                  label: Text(AppStrings.get('reviewShifts', lang), style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StationColors.accentOrange,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => onNavigate(2), // Navigate to Shifts tab
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Stat Cards: Owner cash received & Credit balance
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: AppStrings.get('ownerCashReceived', lang),
                  amount: '₹13,074',
                  subtitle: 'Illustrative sample',
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: StationColors.successGreen,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: AppStrings.get('creditBalance', lang),
                  amount: '₹30,000',
                  subtitle: 'Illustrative sample',
                  icon: Icons.credit_score_outlined,
                  iconColor: StationColors.creditTeal,
                  onTap: () => onNavigate(4), // Credit tab
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Today's Shifts Table
          Text(
            AppStrings.get('todaysShifts', lang),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StationColors.textDark),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
              border: Border.all(color: StationColors.divider),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(1.8),
              },
              children: [
                _buildTableHeader(['Shift', 'Staff (sample)', 'Time', 'Status']),
                _buildShiftRow('Morning', 'Ravi', '6:00 AM - 2:00 PM', 'In progress', StationColors.successGreen),
                _buildShiftRow('Evening', 'Srikant', '2:00 PM - 10:00 PM', 'Needs category review', StationColors.warningAmber),
                _buildShiftRow('Night', 'Kishore', '10:00 PM - 6:00 AM', 'Scheduled', StationColors.textLight),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Latest Receipt (historical)
          Text(
            AppStrings.get('latestReceipt', lang),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StationColors.textDark),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
              border: Border.all(color: StationColors.divider),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: StationColors.textMedium, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Pump 1 • 9 Oct 2026 21:50 • Captured by Ravi',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: StationColors.textDark),
                  ),
                ),
                TextButton(
                  onPressed: () => onNavigate(1), // Receipts tab
                  child: const Text('View receipt →', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
          border: Border.all(color: StationColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: StationColors.textMedium)),
              ],
            ),
            const SizedBox(height: 14),
            Text(amount, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: StationColors.textDark)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: StationColors.textLight)),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableHeader(List<String> headers) {
    return TableRow(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(StationDimensions.cardRadius)),
      ),
      children: headers.map((h) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(h, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: StationColors.textMedium)),
        );
      }).toList(),
    );
  }

  TableRow _buildShiftRow(String shift, String staff, String time, String status, Color statusColor) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: StationColors.divider, width: 0.8)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(shift, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(staff, style: const TextStyle(fontSize: 14)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(time, style: const TextStyle(fontSize: 13, color: StationColors.textMedium)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(status, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: statusColor)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
