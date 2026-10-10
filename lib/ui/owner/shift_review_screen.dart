import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/currency_formatter.dart';
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
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final shifts = state.allShifts;
    final shift = shifts[_selectedShiftIdx.clamp(0, shifts.length - 1)];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Date Picker Stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.get('shiftReview', lang),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: StationColors.textDark),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: StationColors.divider),
                ),
                child: Row(
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

          // Shifts Table
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
                6: FixedColumnWidth(40),
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
                  bool isSelected = i == _selectedShiftIdx;
                  return TableRow(
                    decoration: BoxDecoration(
                      color: isSelected ? StationColors.primaryLight.withOpacity(0.06) : Colors.transparent,
                      border: const Border(top: BorderSide(color: StationColors.divider, width: 0.8)),
                    ),
                    children: [
                      Padding(padding: const EdgeInsets.all(12), child: Text(s.shiftName, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(12), child: Text(s.staffName)),
                      Padding(padding: const EdgeInsets.all(12), child: Text(s.pumpName)),
                      const Padding(padding: EdgeInsets.all(12), child: Text('Uploaded', style: TextStyle(color: StationColors.primary))),
                      Padding(padding: const EdgeInsets.all(12), child: Text(CurrencyFormatter.formatPaise(s.cashHandoverPaise), style: const TextStyle(fontWeight: FontWeight.bold))),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(width: 7, height: 7, decoration: const BoxDecoration(color: StationColors.warningAmber, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Flexible(child: Text(s.status.displayName, style: const TextStyle(color: StationColors.warningAmber, fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: IconButton(
                          icon: const Icon(Icons.chevron_right, size: 18),
                          onPressed: () => setState(() => _selectedShiftIdx = i + 1),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Two-column Bottom Section: Shift Details & Timeline
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 700;

              Widget detailsCol = Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                  border: Border.all(color: StationColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shift details — ${shift.shiftName} shift',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: StationColors.textDark),
                    ),
                    const SizedBox(height: 14),
                    _buildDetailLine('Staff', shift.staffName),
                    _buildDetailLine('Pump', shift.pumpName),
                    _buildDetailLine('Shift time', shift.timeRange),
                    _buildDetailLine('Receipts', 'Uploaded'),
                    _buildDetailLine('Cash handover', CurrencyFormatter.formatPaise(shift.cashHandoverPaise), isBold: true, color: StationColors.accentOrange),
                    _buildDetailLine('Receiver', shift.handoverReceiver),
                    _buildDetailLine('Status', shift.status.displayName, color: StationColors.warningAmber),
                    _buildDetailLine('Note', shift.note ?? '—'),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StationColors.accentOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        if (widget.onNavigateToReports != null) {
                          widget.onNavigateToReports!(8); // Navigate to Daily Station Report
                        }
                      },
                      child: const Text('Review shift →', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      sub: 'Recorded (in receipt)',
                      isCompleted: true,
                    ),
                    _buildTimelineStep(
                      title: 'Entries',
                      sub: 'Fuel sales during shift',
                      isCompleted: true,
                    ),
                    _buildTimelineStep(
                      title: 'Handover',
                      sub: 'Cash given to owner: ${CurrencyFormatter.formatPaise(shift.cashHandoverPaise)}',
                      isPending: true,
                    ),
                    _buildTimelineStep(
                      title: 'Review',
                      sub: 'Category mapping pending',
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
