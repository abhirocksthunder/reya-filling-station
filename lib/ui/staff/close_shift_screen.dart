import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../services/station_state_provider.dart';

class CloseShiftScreen extends StatefulWidget {
  final VoidCallback? onViewDetails;

  const CloseShiftScreen({super.key, this.onViewDetails});

  @override
  State<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends State<CloseShiftScreen> {
  String _selectedHandover = 'Owner';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final report = state.sampleShiftReport;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            AppStrings.get('closeMyShift', lang),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: StationColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.get('sampleReconciliation', lang),
            style: const TextStyle(fontSize: 14, color: StationColors.textMedium),
          ),
          const SizedBox(height: 16),

          // Big Highlight Card: Cash to give owner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: StationColors.accentOrangeLight,
              borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
              border: Border.all(color: StationColors.accentOrangeBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.get('cashToGiveOwner', lang),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: StationColors.accentOrange,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.formatPaise(report.cashGivenToOwnerPaise),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: StationColors.accentOrange,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Reconciliation Figures Breakdown
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
              border: Border.all(color: StationColors.divider),
            ),
            child: Column(
              children: [
                _buildBreakdownRow(
                  label: AppStrings.get('cashAvailable', lang),
                  value: CurrencyFormatter.formatPaise(report.cashSalesPaise),
                  isBold: true,
                ),
                const SizedBox(height: 12),
                _buildBreakdownRow(
                  label: AppStrings.get('otherCashDebit', lang),
                  value: CurrencyFormatter.formatPaise(report.otherCashDebitsPaise),
                  badge: AppStrings.get('needsOwnerCategory', lang),
                ),
                const SizedBox(height: 12),
                _buildBreakdownRow(
                  label: AppStrings.get('foodExpense', lang),
                  value: CurrencyFormatter.formatPaise(report.foodExpensesPaise),
                ),
                const SizedBox(height: 12),
                _buildBreakdownRow(
                  label: AppStrings.get('cashHandedOver', lang),
                  value: CurrencyFormatter.formatPaise(report.cashGivenToOwnerPaise),
                  valueColor: StationColors.accentOrange,
                  isBold: true,
                ),
                const Divider(height: 24, color: StationColors.divider),
                _buildBreakdownRow(
                  label: AppStrings.get('cashRemaining', lang),
                  value: CurrencyFormatter.formatPaise(report.cashVariancePaise),
                  isBold: true,
                  valueColor: StationColors.successGreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Step 1: Count cash and confirm
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.get('countCashStep', lang),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: StationColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppStrings.get('countCashDesc', lang),
                        style: const TextStyle(fontSize: 12, color: StationColors.textMedium),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Handover to & Date-Time pickers
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.get('handoverTo', lang),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: StationColors.textMedium),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: StationColors.divider),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedHandover,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'Owner', child: Text('Owner')),
                          DropdownMenuItem(value: 'Manager Ravi', child: Text('Manager Ravi')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedHandover = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.get('dateTime', lang),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: StationColors.textMedium),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: StationColors.divider),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            child: Text(
                              '9 Oct • 10:00 pm',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Icon(Icons.access_time, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Two Primary Action Buttons
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: StationDimensions.primaryButtonHeight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: Text(
                      AppStrings.get('submitShiftReview', lang),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StationColors.primary,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(StationDimensions.buttonRadius),
                      ),
                    ),
                    onPressed: () {
                      state.submitShiftForReview(report.cashGivenToOwnerPaise);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Shift submitted for Owner review! Cash handover registered.'),
                          backgroundColor: StationColors.successGreen,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: StationDimensions.primaryButtonHeight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.list_alt, size: 18),
                    label: Text(
                      AppStrings.get('viewDetails', lang),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: StationColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(StationDimensions.buttonRadius),
                      ),
                    ),
                    onPressed: widget.onViewDetails ?? () => _showDetailsDialog(context, report),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow({
    required String label,
    required String value,
    String? badge,
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                  color: isBold ? StationColors.textDark : StationColors.textMedium,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange[900]),
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? StationColors.textDark,
          ),
        ),
      ],
    );
  }

  void _showDetailsDialog(BuildContext context, report) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Shift Math Breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Fuel Sales Calculations:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                ...report.nozzleResults.map((n) {
                  return Text('• ${n.fuelType}: ${n.billableVolumeMl / 1000.0} L @ ${CurrencyFormatter.formatRate(n.ratePaisePerLitre)} = ${CurrencyFormatter.formatPaise(n.fuelSalesPaise)}');
                }),
                const Divider(),
                Text('Total Fuel Sales: ${CurrencyFormatter.formatPaise(report.totalCalculatedFuelSalesPaise)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Total Payments: ${CurrencyFormatter.formatPaise(report.totalAccountedPaymentsPaise)}'),
                Text('Sales Variance: ${CurrencyFormatter.formatPaise(report.salesVariancePaise)}'),
                const Divider(),
                Text('Cash Sales: ${CurrencyFormatter.formatPaise(report.cashSalesPaise)}'),
                Text('Expenses & Debits: ${CurrencyFormatter.formatPaise(report.otherCashDebitsPaise + report.foodExpensesPaise)}'),
                Text('Cash to Owner: ${CurrencyFormatter.formatPaise(report.cashGivenToOwnerPaise)}'),
                Text('Cash Variance: ${CurrencyFormatter.formatPaise(report.cashVariancePaise)}', style: const TextStyle(fontWeight: FontWeight.bold, color: StationColors.successGreen)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        );
      },
    );
  }
}
