import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../core/formatting/date_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../models/shift.dart';
import '../../models/transaction_entry.dart';
import '../../services/station_state_provider.dart';

class StationOverviewScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const StationOverviewScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;

    // 1. Dynamic Pending Review Shifts Count
    final reviewShifts = state.allShifts.where((s) => s.status == ShiftStatus.needsReview).toList();

    // 2. Dynamic Owner Cash Received Calculation
    int ownerCashPaise = 0;
    for (var e in state.entries) {
      if (e.direction == EntryDirection.paidOut && e.category == EntryCategory.toOwner) {
        ownerCashPaise += e.amountPaise;
      }
    }
    if (ownerCashPaise == 0) {
      for (var s in state.allShifts) {
        ownerCashPaise += s.cashHandoverPaise;
      }
    }

    // 3. Dynamic Credit Outstanding Balance Calculation
    int totalCreditPaise = 0;
    for (var c in state.creditCustomers) {
      totalCreditPaise += c.pendingAmountPaise;
    }
    for (var e in state.entries) {
      if (e.category == EntryCategory.credit && e.direction == EntryDirection.received) {
        totalCreditPaise += e.amountPaise;
      }
    }

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
                  Text(DateFormatter.formatDisplayDate(DateTime.now()), style: const TextStyle(fontSize: 14, color: StationColors.textMedium)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Dynamic Status Banner: Pending Review vs All Reconciled
          if (reviewShifts.isNotEmpty) ...[
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
                        Text(
                          '${reviewShifts.length} shift(s) need review',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: StationColors.warningAmber),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Shifts: ${reviewShifts.map((s) => s.shiftName).join(", ")} have pending entries awaiting owner review.',
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
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: StationColors.successBg,
                borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                border: Border.all(color: StationColors.successGreen.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: StationColors.successGreen, size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All shifts reconciled & operational',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: StationColors.successGreen),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'No unverified entries or pending category reviews.',
                          style: TextStyle(fontSize: 13, color: StationColors.textMedium),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Stat Cards: Owner cash received & Credit balance (Fully Dynamic)
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: AppStrings.get('ownerCashReceived', lang),
                  amount: CurrencyFormatter.formatPaise(ownerCashPaise),
                  subtitle: ownerCashPaise > 0 ? 'Today handover recorded' : 'No handover yet today',
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: StationColors.successGreen,
                  onTap: () => onNavigate(3), // Money ledger
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: AppStrings.get('creditBalance', lang),
                  amount: CurrencyFormatter.formatPaise(totalCreditPaise),
                  subtitle: totalCreditPaise > 0 ? 'Total outstanding' : 'Zero credit balance',
                  icon: Icons.credit_score_outlined,
                  iconColor: StationColors.creditTeal,
                  onTap: () => onNavigate(4), // Credit tab
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Today's Shifts Table (Dynamic from state.allShifts)
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
                _buildTableHeader(['Shift', 'Staff', 'Time', 'Status']),
                if (state.allShifts.isEmpty) ...[
                  const TableRow(
                    children: [
                      Padding(padding: EdgeInsets.all(16), child: Text('No shifts scheduled today', style: TextStyle(color: Colors.grey))),
                      SizedBox(),
                      SizedBox(),
                      SizedBox(),
                    ],
                  ),
                ] else ...[
                  ...state.allShifts.map((s) {
                    Color statusColor = s.status == ShiftStatus.inProgress
                        ? StationColors.successGreen
                        : s.status == ShiftStatus.needsReview
                            ? StationColors.warningAmber
                            : StationColors.textLight;
                    return _buildShiftRow(s.shiftName, s.staffName, s.timeRange, s.status.displayName, statusColor);
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Latest Receipt
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
                Expanded(
                  child: Text(
                    state.receipts.isNotEmpty
                        ? 'Pump ${state.receipts.first.fpId} • ${state.receipts.first.printedDate} ${state.receipts.first.printedTime} • Captured by ${state.receipts.first.capturedBy}'
                        : 'No receipts uploaded yet today • Awaiting forecourt staff entries',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: StationColors.textDark),
                  ),
                ),
                TextButton(
                  onPressed: () => onNavigate(1), // Receipts tab
                  child: const Text('View receipts →', style: TextStyle(fontWeight: FontWeight.bold)),
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
            Text(
              amount,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: StationColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: StationColors.textLight)),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableHeader(List<String> headers) {
    return TableRow(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F9F9),
        border: Border(bottom: BorderSide(color: StationColors.divider)),
      ),
      children: headers
          .map((h) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text(h, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: StationColors.textMedium)),
              ))
          .toList(),
    );
  }

  TableRow _buildShiftRow(String shift, String staff, String time, String status, Color statusColor) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: StationColors.divider)),
      ),
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), child: Text(shift, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), child: Text(staff, style: const TextStyle(fontSize: 14))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), child: Text(time, style: const TextStyle(fontSize: 13, color: StationColors.textMedium))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
