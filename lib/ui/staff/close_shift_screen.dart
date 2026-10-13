import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../core/formatting/date_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../models/shift.dart';
import '../../services/reconciliation_service.dart';
import '../../services/station_state_provider.dart';
import 'widgets/cash_handover_workflow_card.dart';

class CloseShiftScreen extends StatefulWidget {
  final VoidCallback? onViewDetails;

  const CloseShiftScreen({super.key, this.onViewDetails});

  @override
  State<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends State<CloseShiftScreen> {
  String _selectedHandover = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final report = state.sampleShiftReport;
    final shift = state.activeShift;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      '${shift.shiftName} Shift • ${shift.staffName} (${shift.pumpName})',
                      style: const TextStyle(fontSize: 13, color: StationColors.textMedium, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              _buildShiftStatusBadge(shift.status),
            ],
          ),
          const SizedBox(height: 14),

          // Live Approval Status Banner (when submitted for review or approved)
          if (shift.status == ShiftStatus.needsReview) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: StationColors.warningBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: StationColors.warningBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.pending_actions_rounded, color: StationColors.warningAmber, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Submitted — Awaiting Owner Approval',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: StationColors.warningAmber),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Handover of ${CurrencyFormatter.formatPaise(shift.cashHandoverPaise > 0 ? shift.cashHandoverPaise : report.cashGivenToOwnerPaise)} to ${shift.handoverReceiver} sent to Owner dashboard.',
                          style: const TextStyle(fontSize: 12, color: StationColors.textMedium),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (shift.status == ShiftStatus.approved) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: StationColors.successBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: StationColors.successGreen.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_rounded, color: StationColors.successGreen, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Shift Approved by Owner',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: StationColors.successGreen),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shift.note ?? 'Cash handover verified and shift closed.',
                          style: const TextStyle(fontSize: 12, color: StationColors.textMedium),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (shift.note != null && shift.note!.toLowerCase().contains('returned')) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: StationColors.errorBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: StationColors.errorRed.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: StationColors.errorRed, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Correction Requested by Owner',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: StationColors.errorRed),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shift.note!,
                          style: const TextStyle(fontSize: 12, color: StationColors.textDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

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

          // Handover to & Date-Time pickers (Stack on mobile viewports)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 480;

              final handoverField = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.get('handoverTo', lang),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: StationColors.textMedium),
                  ),
                  const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      final eligibleNames = state.getEligibleHandoverReceiverNames();
                      final receiverList = eligibleNames.isNotEmpty
                          ? eligibleNames
                          : const ['Kalyan'];
                      final activeValue = receiverList.contains(_selectedHandover)
                          ? _selectedHandover
                          : receiverList.first;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: StationColors.divider),
                        ),
                        child: DropdownButton<String>(
                          value: activeValue,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: receiverList
                              .map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedHandover = val);
                          },
                        ),
                      );
                    },
                  ),
                ],
              );

              final dateTimeField = Column(
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
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormatter.formatDisplayDateTime(shift.handoverTime ?? DateTime.now()),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.access_time, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    handoverField,
                    const SizedBox(height: 12),
                    dateTimeField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: handoverField),
                  const SizedBox(width: 12),
                  Expanded(child: dateTimeField),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Primary Action Buttons (Stack on mobile so labels never clip)
          LayoutBuilder(
            builder: (context, btnConstraints) {
              final isNarrowBtns = btnConstraints.maxWidth < 460;
              final eligibleNames = state.getEligibleHandoverReceiverNames();
              final receiverList = eligibleNames.isNotEmpty ? eligibleNames : const ['Kalyan'];
              final activeReceiver = receiverList.contains(_selectedHandover)
                  ? _selectedHandover
                  : receiverList.first;

              final submitBtn = SizedBox(
                height: StationDimensions.primaryButtonHeight,
                child: ElevatedButton.icon(
                  icon: Icon(
                    shift.status == ShiftStatus.approved ? Icons.verified : Icons.check,
                    color: Colors.white,
                  ),
                  label: Text(
                    shift.status == ShiftStatus.needsReview
                        ? 'Resubmit Shift Review'
                        : shift.status == ShiftStatus.approved
                            ? 'Shift Approved'
                            : AppStrings.get('submitShiftReview', lang),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: shift.status == ShiftStatus.approved
                        ? StationColors.successGreen
                        : StationColors.primary,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(StationDimensions.buttonRadius),
                    ),
                  ),
                  onPressed: shift.status == ShiftStatus.approved
                      ? null
                      : () {
                          state.submitShiftForReview(
                            report.cashGivenToOwnerPaise,
                            handoverReceiver: activeReceiver,
                          );
                          if (report.cashGivenToOwnerPaise > 0) {
                            state.initiateCashHandover(
                              receiverName: activeReceiver,
                              amountPaise: report.cashGivenToOwnerPaise,
                              note: '${shift.shiftName} shift close handover',
                              createTransactionEntry: false,
                            );
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Shift (${shift.shiftName}) submitted for approval! Handover: ${CurrencyFormatter.formatPaise(report.cashGivenToOwnerPaise)} to $activeReceiver.',
                              ),
                              backgroundColor: StationColors.successGreen,
                            ),
                          );
                        },
                ),
              );

              final detailsBtn = SizedBox(
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
                  onPressed: () {
                    _showDetailsDialog(context, state, report);
                    if (widget.onViewDetails != null) {
                      widget.onViewDetails!();
                    }
                  },
                ),
              );

              if (isNarrowBtns) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    submitBtn,
                    const SizedBox(height: 10),
                    detailsBtn,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: submitBtn),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: detailsBtn),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Hierarchical Cash Handover Workflow Panel
          const CashHandoverWorkflowCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildShiftStatusBadge(ShiftStatus status) {
    final Color color = status == ShiftStatus.approved
        ? StationColors.successGreen
        : status == ShiftStatus.needsReview
            ? StationColors.warningAmber
            : StationColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(StationDimensions.pillRadius),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                  color: isBold ? StationColors.textDark : StationColors.textMedium,
                ),
              ),
              if (badge != null)
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        title: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.orange[900], size: 22),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'What does "Needs owner category" mean?',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        content: const Text(
                          'When staff records a cash payout under "Paid out → Expense" or "Salary" (other than food/tea), it is grouped here as "Other cash debit".\n\n'
                          'Because staff only enters a short note, the Station Owner reviews these entries in the Owner Money Ledger and assigns each payout to its final accounting category (for example: Generator Diesel, Station Maintenance, Staff Advance, or Supplies).',
                          style: TextStyle(fontSize: 14, height: 1.45, color: StationColors.textDark),
                        ),
                        actions: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: StationColors.primary),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Got it', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            badge,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange[900]),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.help_outline_rounded, size: 11, color: Colors.orange[900]),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
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

  void _showDetailsDialog(BuildContext context, StationStateProvider state, ShiftReconciliationReport report) {
    final shift = state.activeShift;
    final entries = state.userEntries.take(8).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Shift Reconciliation Details',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: StationColors.textDark),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Shift metadata pill box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: StationColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${shift.shiftName} Shift (${shift.pumpName})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: StationColors.textDark),
                            ),
                            _buildShiftStatusBadge(shift.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Attendant: ${shift.staffName} • ${shift.timeRange}',
                          style: const TextStyle(fontSize: 12, color: StationColors.textMedium),
                        ),
                        Text(
                          'Handover Receiver: ${shift.handoverReceiver} • Date: ${shift.businessDate}',
                          style: const TextStyle(fontSize: 12, color: StationColors.textMedium),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Nozzle Sales Section
                  const Text(
                    'Dispenser Nozzle Breakdown (5L Mandatory Test Deducted)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: StationColors.primary),
                  ),
                  const SizedBox(height: 8),
                  ...report.nozzleResults.map((n) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: StationColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${n.pumpName.isNotEmpty ? "${n.pumpName} • " : ""}Nozzle ${n.nozzleNumber} (${n.fuelType})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                CurrencyFormatter.formatPaise(n.fuelSalesPaise),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: StationColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Open: ${(n.openingReadingMl / 1000.0).toStringAsFixed(2)} L → Close: ${(n.closingReadingMl / 1000.0).toStringAsFixed(2)} L',
                            style: const TextStyle(fontSize: 11, color: StationColors.textMedium),
                          ),
                          Text(
                            'Gross: ${n.grossLitres.toStringAsFixed(2)} L | Test: -${n.testLitres.toStringAsFixed(2)} L | Net Sold: ${n.billableLitres.toStringAsFixed(2)} L @ ${CurrencyFormatter.formatRate(n.ratePaisePerLitre)}/L',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: StationColors.textDark),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 20),

                  // Financial Reconciliation Summary
                  const Text(
                    'Payment & Cash Summary',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: StationColors.primary),
                  ),
                  const SizedBox(height: 8),
                  _buildModalKvRow('Total Fuel Sales', CurrencyFormatter.formatPaise(report.totalCalculatedFuelSalesPaise), isBold: true),
                  _buildModalKvRow('Cash Available', CurrencyFormatter.formatPaise(report.cashSalesPaise)),
                  _buildModalKvRow('PhonePe / UPI', CurrencyFormatter.formatPaise(report.phonePeSalesPaise)),
                  _buildModalKvRow('Card Swipes', CurrencyFormatter.formatPaise(report.cardSalesPaise)),
                  _buildModalKvRow('Credit (Khata)', CurrencyFormatter.formatPaise(report.creditSalesPaise)),
                  _buildModalKvRow('Expenses & Debits', CurrencyFormatter.formatPaise(report.otherCashDebitsPaise + report.foodExpensesPaise)),
                  const Divider(height: 16),
                  _buildModalKvRow(
                    'Cash Handover to $_selectedHandover',
                    CurrencyFormatter.formatPaise(report.cashGivenToOwnerPaise),
                    isBold: true,
                    color: StationColors.accentOrange,
                  ),
                  _buildModalKvRow(
                    'Cash Remaining / Variance',
                    CurrencyFormatter.formatPaise(report.cashVariancePaise),
                    isBold: true,
                    color: StationColors.successGreen,
                  ),

                  if (entries.isNotEmpty) ...[
                    const Divider(height: 20),
                    const Text(
                      'Recent Shift Money Entries',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: StationColors.primary),
                    ),
                    const SizedBox(height: 6),
                    ...entries.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${e.category.displayName}${e.reference != null && e.reference!.isNotEmpty ? " (${e.reference})" : ""}',
                                  style: const TextStyle(fontSize: 12, color: StationColors.textMedium),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.formatPaise(e.amountPaise),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: StationColors.textDark),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: StationColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(88, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModalKvRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? StationColors.textDark : StationColors.textMedium,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? StationColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
