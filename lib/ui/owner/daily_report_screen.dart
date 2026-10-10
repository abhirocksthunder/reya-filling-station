import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../services/station_state_provider.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  DateTime _selectedDate = DateTime(2026, 10, 9);
  String _selectedShift = 'Evening Shift';

  final List<String> _shiftOptions = const [
    'All Shifts',
    'Morning Shift',
    'Evening Shift',
    'Night Shift',
  ];

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  }

  void _stepDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2027),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: StationColors.primary,
              onPrimary: Colors.white,
              onSurface: StationColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final report = state.sampleShiftReport;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Date, Shift, and Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.get('dailyStationReport', lang),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: StationColors.textDark),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: const Text('Export report'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: StationColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Generating Daily Station Report PDF for ${_formatDate(_selectedDate)} (${_selectedShift}).')),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sent ${_formatDate(_selectedDate)} report to forecourt printer.')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date & Shift Selector (Interactive Calendar & Dropdown)
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: StationColors.divider),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 18),
                      tooltip: 'Previous day',
                      onPressed: () => _stepDate(-1),
                    ),
                    InkWell(
                      onTap: () => _pickDate(context),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, size: 16, color: StationColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              _formatDate(_selectedDate),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: StationColors.textDark),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 18),
                      tooltip: 'Next day',
                      onPressed: () => _stepDate(1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Shift Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: StationColors.divider),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedShift,
                    icon: const Icon(Icons.arrow_drop_down, color: StationColors.primary),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: StationColors.textDark),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedShift = val);
                    },
                    items: _shiftOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4 Summary Metrics Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard('Recorded sales', '₹98,146', StationColors.textDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard('PhonePe + card', '₹37,599', StationColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard('Credit', '₹30,000', StationColors.creditTeal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard('Cash given owner', '₹13,074', StationColors.accentOrange),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Fuel Calculation Table
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
              border: Border.all(color: StationColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fuel calculation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF7F9F9)),
                    dataRowMinHeight: 48,
                    horizontalMargin: 16,
                    columns: const [
                      DataColumn(label: Text('Nozzle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text('Opening (L)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text('Closing (L)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text('Gross (L)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text('Test (L)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text('Net (L)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    ],
                    rows: report.nozzleResults.map((n) {
                      return DataRow(
                        cells: [
                          DataCell(Text('N${n.nozzleNumber}', style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: n.fuelType == 'Petrol' ? Colors.orange.withOpacity(0.12) : Colors.blue.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                n.fuelType,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: n.fuelType == 'Petrol' ? StationColors.accentOrange : Colors.blue[800],
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text((n.openingReadingMl / 1000).toStringAsFixed(2))),
                          DataCell(Text((n.closingReadingMl / 1000).toStringAsFixed(2))),
                          DataCell(Text((n.grossVolumeMl / 1000).toStringAsFixed(2))),
                          DataCell(
                            Text(
                              '-${(n.testVolumeMl / 1000).toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataCell(Text((n.billableVolumeMl / 1000).toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(CurrencyFormatter.formatPaise(n.ratePaisePerLitre))),
                          DataCell(Text(CurrencyFormatter.formatPaise(n.fuelSalesPaise), style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Two-Column Cash & Reconciliation Summary
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 800;

              Widget cashSettlement = Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                  border: Border.all(color: StationColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cash settlement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    _buildRow('Total fuel sales', CurrencyFormatter.formatPaise(report.totalCalculatedFuelSalesPaise), isBold: true),
                    const Divider(height: 20),
                    _buildRow('PhonePe & UPI', '-${CurrencyFormatter.formatPaise(report.phonePeSalesPaise)}'),
                    const SizedBox(height: 8),
                    _buildRow('Card swipe', '-${CurrencyFormatter.formatPaise(report.cardSalesPaise)}'),
                    const SizedBox(height: 8),
                    _buildRow('Credit sales (Khata)', '-${CurrencyFormatter.formatPaise(report.creditSalesPaise)}'),
                    const Divider(height: 20),
                    _buildRow('Net cash collected', CurrencyFormatter.formatPaise(report.cashSalesPaise), isBold: true, color: StationColors.primary),
                  ],
                ),
              );

              Widget reconciliationPane = Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                  border: Border.all(color: StationColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Daily reconciliation result', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    _buildRow('Handed over to owner', CurrencyFormatter.formatPaise(report.cashGivenToOwnerPaise), isBold: true),
                    const SizedBox(height: 8),
                    _buildRow('Other cash debits', CurrencyFormatter.formatPaise(report.otherCashDebitsPaise), subnote: 'Category to confirm'),
                    const SizedBox(height: 8),
                    _buildRow('Food expenses', CurrencyFormatter.formatPaise(report.foodExpensesPaise)),
                    const Divider(height: 20),
                    _buildRow(
                      'Cash variance',
                      '₹0 (Exact Match)',
                      isBold: true,
                      color: StationColors.successGreen,
                    ),
                  ],
                ),
              );

              if (!isWide) {
                return Column(
                  children: [
                    cashSettlement,
                    const SizedBox(height: 16),
                    reconciliationPane,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: cashSettlement),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: reconciliationPane),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
        border: Border.all(color: StationColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: StationColors.textMedium)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? color, String? subnote}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? StationColors.textDark)),
          ],
        ),
        if (subnote != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subnote, style: TextStyle(fontSize: 11, color: Colors.orange[900], fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}
