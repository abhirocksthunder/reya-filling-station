import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../core/formatting/date_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../models/shift.dart';
import '../../services/station_state_provider.dart';

class ShiftReviewScreen extends StatefulWidget {
  final Function(int)? onNavigateToReports;

  const ShiftReviewScreen({super.key, this.onNavigateToReports});

  @override
  State<ShiftReviewScreen> createState() => _ShiftReviewScreenState();
}

class _ShiftReviewScreenState extends State<ShiftReviewScreen> {
  int _selectedShiftIdx = 0;
  DateTime _selectedDate = DateTime.now();

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _formatDate(DateTime dt) => '${dt.day} ${_months[dt.month - 1]} ${dt.year}';

  void _stepDate(int days) {
    context.read<StationStateProvider>().selectShiftForReview(null);
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _selectedShiftIdx = 0;
    });
  }

  Color _statusColor(ShiftStatus status) {
    switch (status) {
      case ShiftStatus.approved:
        return StationColors.successGreen;
      case ShiftStatus.needsReview:
        return StationColors.warningAmber;
      case ShiftStatus.inProgress:
        return StationColors.primary;
      case ShiftStatus.scheduled:
        return StationColors.textLight;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2027),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: StationColors.primary,
            onPrimary: Colors.white,
            onSurface: StationColors.textDark,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      context.read<StationStateProvider>().selectShiftForReview(null);
      setState(() {
        _selectedDate = picked;
        _selectedShiftIdx = 0;
      });
    }
  }

  void _showRejectDialog(BuildContext context, StationStateProvider state, Shift shift) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Return ${shift.shiftName} Shift for Correction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter a short note for ${shift.staffName} explaining what needs correction:',
                style: const TextStyle(fontSize: 13, color: StationColors.textMedium),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLength: 30,
                decoration: InputDecoration(
                  hintText: 'e.g. Recount cash handover',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: StationColors.errorRed,
                foregroundColor: Colors.white,
                minimumSize: const Size(88, 44),
              ),
              onPressed: () {
                final reason = controller.text.trim();
                Navigator.pop(dialogCtx);
                state.rejectShift(shift.id, reason: reason);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${shift.shiftName} shift returned to ${shift.staffName} for correction.'),
                    backgroundColor: StationColors.warningAmber,
                  ),
                );
              },
              child: const Text('Return Shift'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final shifts = state.getVisibleShiftsForDate(_selectedDate);
    final dayCalc = state.getDayCalculation(_selectedDate);
    final int receiptCount = state.receipts.where((r) => state.isReceiptOnDate(r, _selectedDate)).length;
    final int entriesCount = state.entries.where((e) =>
        e.createdAt.year == _selectedDate.year &&
        e.createdAt.month == _selectedDate.month &&
        e.createdAt.day == _selectedDate.day).length;
    final hasReceiptsForDate = receiptCount > 0;
    final hasEntriesForDate = entriesCount > 0;

    return LayoutBuilder(
      builder: (context, screenConstraints) {
        final isMobile = screenConstraints.maxWidth < 650;

        if (shifts.isEmpty) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 14 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      AppStrings.get('shiftReview', lang),
                      style: TextStyle(
                        fontSize: isMobile ? 22 : 26,
                        fontWeight: FontWeight.w800,
                        color: StationColors.textDark,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: StationColors.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, size: 20),
                            tooltip: 'Previous day',
                            onPressed: () => _stepDate(-1),
                          ),
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_month, size: 16, color: StationColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatDate(_selectedDate),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, size: 20),
                            tooltip: 'Next day',
                            onPressed: () => _stepDate(1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                    border: Border.all(color: StationColors.divider),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.assignment_ind_outlined, size: 48, color: StationColors.textLight),
                      const SizedBox(height: 12),
                      Text(
                        'No active or submitted shifts for ${_formatDate(_selectedDate)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: StationColors.textDark),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Shift details and approval actions appear automatically once an assigned staff member logs in and starts or submits their shift on the selected date.',
                        style: TextStyle(fontSize: 13, color: StationColors.textMedium),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Honor deep-linked shift selection from Overview or Notifications
        int effectiveIdx = _selectedShiftIdx.clamp(0, shifts.length - 1);
        if (state.selectedReviewShiftId != null) {
          final matchedIdx = shifts.indexWhere((s) => s.id == state.selectedReviewShiftId);
          if (matchedIdx != -1) {
            effectiveIdx = matchedIdx;
          }
        }
        final shift = shifts[effectiveIdx];
        final shiftToOwnerPaise = state.getShiftHandoverToOwnerPaise(shift, date: _selectedDate);
        final effectiveHandoverPaise = shiftToOwnerPaise > 0
            ? shiftToOwnerPaise
            : dayCalc.cashGivenToOwnerPaise;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Responsive Header & Date Picker Stepper
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    AppStrings.get('shiftReview', lang),
                    style: TextStyle(
                      fontSize: isMobile ? 22 : 26,
                      fontWeight: FontWeight.w800,
                      color: StationColors.textDark,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: StationColors.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 20),
                          tooltip: 'Previous day',
                          onPressed: () => _stepDate(-1),
                        ),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_month, size: 16, color: StationColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  _formatDate(_selectedDate),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 20),
                          tooltip: 'Next day',
                          onPressed: () => _stepDate(1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Mobile Shift Cards or Desktop Shifts Table
              if (isMobile) ...[
                ...List.generate(shifts.length, (i) {
                  final s = shifts[i];
                  final bool isSelected = i == effectiveIdx;
                  final Color sColor = _statusColor(s.status);
                  final int handoverDisplay = state.getShiftHandoverToOwnerPaise(s, date: _selectedDate);
                  return InkWell(
                    onTap: () {
                      state.selectShiftForReview(s.id);
                      setState(() => _selectedShiftIdx = i);
                    },
                    borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? StationColors.primaryLight.withOpacity(0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                        border: Border.all(color: isSelected ? StationColors.primary : StationColors.divider, width: isSelected ? 1.5 : 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: sColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              s.status == ShiftStatus.approved
                                  ? Icons.verified_rounded
                                  : s.status == ShiftStatus.needsReview
                                      ? Icons.pending_actions_rounded
                                      : Icons.schedule,
                              color: sColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.shiftName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text('${s.staffName} · ${s.pumpName}', style: const TextStyle(fontSize: 12, color: StationColors.textMedium)),
                                const SizedBox(height: 2),
                                Text(
                                  'Handover: ${CurrencyFormatter.formatPaise(handoverDisplay)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: StationColors.accentOrange),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: sColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.status.displayName,
                              style: TextStyle(color: sColor, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ] else ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                    border: Border.all(color: StationColors.divider),
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.2),
                      1: FlexColumnWidth(1.2),
                      2: FlexColumnWidth(1.0),
                      3: FlexColumnWidth(1.2),
                      4: FlexColumnWidth(1.4),
                      5: FlexColumnWidth(1.8),
                      6: FixedColumnWidth(44),
                    },
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(
                          color: Color(0xFFF7F9F9),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(StationDimensions.cardRadius)),
                        ),
                        children: [
                          Padding(padding: EdgeInsets.all(12), child: Text('Shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(12), child: Text('Staff', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(12), child: Text('Pump', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(12), child: Text('Receipts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(12), child: Text('Owner cash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(12), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(12), child: SizedBox()),
                        ],
                      ),
                      ...List.generate(shifts.length, (i) {
                        final s = shifts[i];
                        final bool isSelected = i == effectiveIdx;
                        final Color sColor = _statusColor(s.status);
                        final int handoverDisplay = state.getShiftHandoverToOwnerPaise(s, date: _selectedDate);
                        void selectRow() {
                          state.selectShiftForReview(s.id);
                          setState(() => _selectedShiftIdx = i);
                        }

                        return TableRow(
                          decoration: BoxDecoration(
                            color: isSelected ? StationColors.primaryLight.withOpacity(0.06) : Colors.transparent,
                            border: const Border(top: BorderSide(color: StationColors.divider, width: 0.8)),
                          ),
                          children: [
                            TableRowInkWell(
                              onTap: selectRow,
                              child: Padding(padding: const EdgeInsets.all(12), child: Text(s.shiftName, style: const TextStyle(fontWeight: FontWeight.bold))),
                            ),
                            TableRowInkWell(
                              onTap: selectRow,
                              child: Padding(padding: const EdgeInsets.all(12), child: Text(s.staffName)),
                            ),
                            TableRowInkWell(
                              onTap: selectRow,
                              child: Padding(padding: const EdgeInsets.all(12), child: Text(s.pumpName)),
                            ),
                            TableRowInkWell(
                              onTap: selectRow,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  hasReceiptsForDate ? '$receiptCount uploaded' : 'Pending',
                                  style: TextStyle(
                                    color: hasReceiptsForDate ? StationColors.primary : StationColors.textLight,
                                    fontWeight: hasReceiptsForDate ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                            TableRowInkWell(
                              onTap: selectRow,
                              child: Padding(padding: const EdgeInsets.all(12), child: Text(CurrencyFormatter.formatPaise(handoverDisplay), style: const TextStyle(fontWeight: FontWeight.bold))),
                            ),
                            TableRowInkWell(
                              onTap: selectRow,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(width: 7, height: 7, decoration: BoxDecoration(color: sColor, shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Flexible(child: Text(s.status.displayName, style: TextStyle(color: sColor, fontWeight: FontWeight.bold, fontSize: 12))),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: IconButton(
                                icon: const Icon(Icons.chevron_right, size: 18),
                                onPressed: selectRow,
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Two-column Bottom Section: Shift Details & Approval Actions + Timeline
              LayoutBuilder(
                builder: (context, constraints) {
                  bool isWide = constraints.maxWidth > 700;
                  final Color activeStatusColor = _statusColor(shift.status);

                  Widget detailsCol = Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                      border: Border.all(
                        color: shift.status == ShiftStatus.needsReview
                            ? StationColors.warningBorder
                            : StationColors.divider,
                        width: shift.status == ShiftStatus.needsReview ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Shift details — ${shift.shiftName} shift',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: StationColors.textDark),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: activeStatusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(StationDimensions.pillRadius),
                              ),
                              child: Text(
                                shift.status.displayName,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: activeStatusColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildDetailLine('Staff', shift.staffName),
                        _buildDetailLine('Pump', shift.pumpName),
                        _buildDetailLine('Shift time', shift.timeRange),
                        _buildDetailLine('Business date', shift.businessDate),
                        _buildDetailLine(
                          'Cash handover',
                          CurrencyFormatter.formatPaise(effectiveHandoverPaise),
                          isBold: true,
                          color: StationColors.accentOrange,
                        ),
                        _buildDetailLine('Receiver', shift.handoverReceiver),
                        if (shift.handoverTime != null)
                          _buildDetailLine('Submitted at', DateFormatter.formatDateTimeIST(shift.handoverTime!)),
                        _buildDetailLine('Status', shift.status.displayName, color: activeStatusColor, isBold: true),
                        _buildDetailLine('Note', shift.note ?? '—'),
                        const SizedBox(height: 18),

                        // Owner Approval Action Buttons (never show Approve when scheduled or already approved)
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (shift.status != ShiftStatus.approved && shift.status != ShiftStatus.scheduled)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: StationColors.successGreen,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(160, 44),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  state.approveShift(shift.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${shift.shiftName} shift (${shift.staffName}) approved! Handover of ${CurrencyFormatter.formatPaise(effectiveHandoverPaise)} verified.',
                                      ),
                                      backgroundColor: StationColors.successGreen,
                                    ),
                                  );
                                },
                                label: const Text('Approve Shift & Handover', style: TextStyle(fontWeight: FontWeight.bold)),
                              )
                            else if (shift.status == ShiftStatus.approved)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: StationColors.successBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: StationColors.successGreen.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded, color: StationColors.successGreen, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Shift Approved',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: StationColors.successGreen, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            if (shift.status == ShiftStatus.needsReview || shift.status == ShiftStatus.approved)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.replay_rounded, size: 17, color: StationColors.errorRed),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: StationColors.errorRed,
                                  side: const BorderSide(color: StationColors.errorRed),
                                  minimumSize: const Size(140, 44),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _showRejectDialog(context, state, shift),
                                label: const Text('Request Correction', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.analytics_outlined, size: 17),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: StationColors.primary,
                                side: const BorderSide(color: StationColors.primary),
                                minimumSize: const Size(140, 44),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                if (widget.onNavigateToReports != null) {
                                  widget.onNavigateToReports!(8); // Navigate to Daily Station Report
                                }
                              },
                              label: const Text('Daily Report →', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );

                  Widget timelineCol = Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                      border: Border.all(color: StationColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Shift timeline',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: StationColors.textDark),
                        ),
                        const SizedBox(height: 16),
                        _buildTimelineStep(
                          title: 'Opening reading',
                          sub: hasReceiptsForDate
                              ? 'Recorded ($receiptCount slip${receiptCount == 1 ? "" : "s"} uploaded)'
                              : 'Awaiting first totaliser slip upload',
                          isCompleted: hasReceiptsForDate,
                          isPending: !hasReceiptsForDate && shift.status == ShiftStatus.inProgress,
                        ),
                        _buildTimelineStep(
                          title: 'Entries & Nozzle Scans',
                          sub: (hasEntriesForDate || hasReceiptsForDate)
                              ? '$entriesCount money entr${entriesCount == 1 ? "y" : "ies"} & $receiptCount scan${receiptCount == 1 ? "" : "s"} recorded'
                              : 'No money entries or scans recorded yet',
                          isCompleted: hasEntriesForDate || hasReceiptsForDate,
                          isPending: !hasEntriesForDate && !hasReceiptsForDate && shift.status == ShiftStatus.inProgress,
                        ),
                        _buildTimelineStep(
                          title: 'Cash Handover',
                          sub: 'Cash given to ${shift.handoverReceiver}: ${CurrencyFormatter.formatPaise(effectiveHandoverPaise)}',
                          isCompleted: shift.status == ShiftStatus.needsReview || shift.status == ShiftStatus.approved,
                          isPending: shift.status == ShiftStatus.inProgress,
                        ),
                        _buildTimelineStep(
                          title: 'Owner Review & Approval',
                          sub: shift.status == ShiftStatus.approved
                              ? (shift.note ?? 'Approved & reconciled by owner')
                              : shift.status == ShiftStatus.needsReview
                                  ? 'Submitted by ${shift.staffName} — awaiting owner approval'
                                  : 'Pending shift submission',
                          isCompleted: shift.status == ShiftStatus.approved,
                          isPending: shift.status == ShiftStatus.needsReview,
                          isLast: true,
                        ),
                      ],
                    ),
                  );

                  if (!isWide) {
                    return Column(
                      children: [
                        detailsCol,
                        const SizedBox(height: 16),
                        timelineCol,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: detailsCol),
                      const SizedBox(width: 20),
                      Expanded(flex: 5, child: timelineCol),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailLine(String key, String val, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(key, style: const TextStyle(fontSize: 13, color: StationColors.textLight)),
          ),
          Expanded(
            child: Text(
              val,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color ?? StationColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String sub,
    bool isCompleted = false,
    bool isPending = false,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isCompleted
                    ? StationColors.successGreen
                    : isPending
                        ? StationColors.accentOrange
                        : Colors.grey.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted ? Icons.check : Icons.circle,
                size: 14,
                color: Colors.white,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                color: isCompleted ? StationColors.successGreen : Colors.grey.withOpacity(0.3),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(sub, style: const TextStyle(fontSize: 12, color: StationColors.textLight)),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ],
    );
  }
}
