import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../services/station_state_provider.dart';
import '../../models/transaction_entry.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedShift = 'All Shifts';

  final List<String> _shiftOptions = const [
    'All Shifts',
    'Morning',
    'Evening',
    'Night',
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

    // Authoritative Day Calculation strictly for _selectedDate (isolated from other dates)
    final dayCalc = state.getDayCalculation(_selectedDate);

    // Filter transaction entries strictly for _selectedDate (NO fallback to other dates!)
    final dateFiltered = state.entries.where((e) {
      final d = e.createdAt;
      return d.year == _selectedDate.year && d.month == _selectedDate.month && d.day == _selectedDate.day;
    }).toList();

    int cashSales = 0;
    int phonePeSales = 0;
    int cardSales = 0;
    int creditSales = 0;
    int toOwner = 0;
    int otherDebits = 0;
    int foodExpenses = 0;

    for (var e in dateFiltered) {
      if (e.direction == EntryDirection.received) {
        switch (e.category) {
          case EntryCategory.cash:
            cashSales += e.amountPaise;
            break;
          case EntryCategory.phonePe:
            phonePeSales += e.amountPaise;
            break;
          case EntryCategory.card:
            cardSales += e.amountPaise;
            break;
          case EntryCategory.credit:
            creditSales += e.amountPaise;
            break;
          default:
            cashSales += e.amountPaise;
        }
      } else {
        switch (e.category) {
          case EntryCategory.toOwner:
            toOwner += e.amountPaise;
            break;
          case EntryCategory.expense:
            final ref = (e.reference ?? '').toLowerCase();
            if (ref.contains('food') || ref.contains('curries') || ref.contains('tea')) {
              foodExpenses += e.amountPaise;
            } else {
              otherDebits += e.amountPaise;
            }
            break;
          default:
            otherDebits += e.amountPaise;
        }
      }
    }

    final int dynamicRecordedSales = cashSales + phonePeSales + cardSales + creditSales;
    final int dynamicPhonePeCard = phonePeSales + cardSales;

    // Fuel Sales & Reconciliation
    final int fuelSalesPaise = dayCalc.totalFuelSalesPaise;
    final int netCashCollected = fuelSalesPaise - phonePeSales - cardSales - creditSales;
    final int totalCashAccounted = toOwner + otherDebits + foodExpenses;
    final int cashVariance = netCashCollected - totalCashAccounted;

    return LayoutBuilder(
      builder: (context, screenConstraints) {
        final isMobile = screenConstraints.maxWidth < 600;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Responsive Header with Date, Shift, and Actions
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    AppStrings.get('dailyStationReport', lang),
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.w800,
                      color: StationColors.textDark,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_download_outlined, size: 16),
                        label: const Text('Export report'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: StationColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(44, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Generating Daily Station Report PDF for ${_formatDate(_selectedDate)} (${_selectedShift}).')),
                          );
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: const Text('Print'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: StationColors.textDark,
                          minimumSize: const Size(44, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              const SizedBox(height: 14),

              // Date & Shift Selector (Interactive Calendar & Dropdown)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
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
                              mainAxisSize: MainAxisSize.min,
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
                        value: _shiftOptions.contains(_selectedShift) ? _selectedShift : _shiftOptions.first,
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
              const SizedBox(height: 18),

          // Empty state warning banner if no data on selected date
          if (!dayCalc.hasData) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: StationColors.textMedium, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No fuel totaliser scans or transaction entries recorded for ${_formatDate(_selectedDate)}. Showing zero values for this date.',
                      style: const TextStyle(fontSize: 13, color: StationColors.textMedium, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // 4 Summary Metrics Cards (Isolated for _selectedDate)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final double cardSpacing = 12;

              final c1 = _buildMetricCard('Recorded sales', CurrencyFormatter.formatPaise(dynamicRecordedSales), StationColors.textDark);
              final c2 = _buildMetricCard('PhonePe + card', CurrencyFormatter.formatPaise(dynamicPhonePeCard), StationColors.primary);
              final c3 = _buildMetricCard('Credit sales', CurrencyFormatter.formatPaise(creditSales), StationColors.creditTeal);
              final c4 = _buildMetricCard('Cash to owner', CurrencyFormatter.formatPaise(toOwner), StationColors.accentOrange);

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: c1),
                    SizedBox(width: cardSpacing),
                    Expanded(child: c2),
                    SizedBox(width: cardSpacing),
                    Expanded(child: c3),
                    SizedBox(width: cardSpacing),
                    Expanded(child: c4),
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: c1),
                      SizedBox(width: cardSpacing),
                      Expanded(child: c2),
                    ],
                  ),
                  SizedBox(height: cardSpacing),
                  Row(
                    children: [
                      Expanded(child: c3),
                      SizedBox(width: cardSpacing),
                      Expanded(child: c4),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Fuel Calculation Table (All Pumps & Nozzles strictly for _selectedDate)
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
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Fuel calculation (Dispenser Meters)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    Text(
                      'First recording of day → Ending recording of day (-5 L Test)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF7F9F9)),
                    dataRowMinHeight: 46,
                    horizontalMargin: 16,
                    columns: const [
                      DataColumn(label: Text('Pump & Nozzle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text('Opening (L)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text('Closing (L)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text('Gross (L)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text('Test (-5 L)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text('Net Sold (L)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text('Amount to Receive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    ],
                    rows: [
                      ...dayCalc.allNozzleResults.map((n) {
                        final isPetrol = n.fuelType.toLowerCase().contains('petrol') || n.fuelType.toLowerCase().contains('ms');
                        return DataRow(
                          cells: [
                            DataCell(Text('${n.pumpName} - N${n.nozzleNumber}', style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isPetrol ? Colors.orange.withOpacity(0.12) : Colors.blue.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  n.fuelType,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isPetrol ? StationColors.accentOrange : Colors.blue[800],
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
                                style: const TextStyle(color: StationColors.errorRed, fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataCell(Text((n.billableVolumeMl / 1000).toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(
                              n.hasPriceChange
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.bolt, size: 12, color: Colors.orange),
                                            Text(
                                              '${CurrencyFormatter.formatPaise(n.segments.first.ratePaisePerLitre)} → ${CurrencyFormatter.formatPaise(n.segments.last.ratePaisePerLitre)}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${n.segments.length} price tiers',
                                          style: const TextStyle(fontSize: 10, color: StationColors.textLight),
                                        ),
                                      ],
                                    )
                                  : Text(CurrencyFormatter.formatPaise(n.ratePaisePerLitre)),
                            ),
                            DataCell(Text(CurrencyFormatter.formatPaise(n.fuelSalesPaise), style: const TextStyle(fontWeight: FontWeight.bold, color: StationColors.primary))),
                          ],
                        );
                      }),
                      // Grand Total Summary Row
                      DataRow(
                        color: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
                        cells: [
                          const DataCell(Text('Station Total', style: TextStyle(fontWeight: FontWeight.w900, color: StationColors.textDark))),
                          const DataCell(Text('MS + HSD', style: TextStyle(fontWeight: FontWeight.bold))),
                          const DataCell(Text('-')),
                          const DataCell(Text('-')),
                          DataCell(Text(dayCalc.totalGrossLitres.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text('-${dayCalc.totalTestLitres.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: StationColors.errorRed))),
                          DataCell(Text(dayCalc.totalNetLitres.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w900, color: StationColors.textDark))),
                          const DataCell(Text('-')),
                          DataCell(Text(CurrencyFormatter.formatPaise(dayCalc.totalFuelSalesPaise), style: const TextStyle(fontWeight: FontWeight.w900, color: StationColors.primary, fontSize: 14))),
                        ],
                      ),
                    ],
                  ),
                ),
                if (dayCalc.allNozzleResults.any((n) => n.hasPriceChange)) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt, size: 16, color: Colors.orange),
                            SizedBox(width: 6),
                            Text(
                              'Mid-Day Tariff Price Changes Applied:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...dayCalc.allNozzleResults.where((n) => n.hasPriceChange).map((n) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• ${n.pumpName} - Nozzle ${n.nozzleNumber} (${n.fuelType}):',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: StationColors.textDark),
                                ),
                                ...n.segments.asMap().entries.map((entry) {
                                  final idx = entry.key + 1;
                                  final seg = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 12, top: 2),
                                    child: Text(
                                      'Tier $idx: ${seg.billableLitres.toStringAsFixed(2)} L net @ ₹${seg.rateRupees.toStringAsFixed(2)}/L = ${CurrencyFormatter.formatPaise(seg.amountPaise)}',
                                      style: const TextStyle(fontSize: 12, color: StationColors.textMedium),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
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
                    _buildRow('Total fuel sales (Meter)', CurrencyFormatter.formatPaise(fuelSalesPaise), isBold: true),
                    const Divider(height: 20),
                    _buildRow('PhonePe & UPI', '-${CurrencyFormatter.formatPaise(phonePeSales)}'),
                    const SizedBox(height: 8),
                    _buildRow('Card swipe', '-${CurrencyFormatter.formatPaise(cardSales)}'),
                    const SizedBox(height: 8),
                    _buildRow('Credit sales (Khata)', '-${CurrencyFormatter.formatPaise(creditSales)}'),
                    const Divider(height: 20),
                    _buildRow(
                      'Net cash to collect',
                      CurrencyFormatter.formatPaise(netCashCollected > 0 ? netCashCollected : 0),
                      isBold: true,
                      color: StationColors.primary,
                    ),
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
                    _buildRow('Handed over to owner', CurrencyFormatter.formatPaise(toOwner), isBold: true),
                    const SizedBox(height: 8),
                    _buildRow('Other cash debits', CurrencyFormatter.formatPaise(otherDebits)),
                    const SizedBox(height: 8),
                    _buildRow('Food expenses', CurrencyFormatter.formatPaise(foodExpenses)),
                    const Divider(height: 20),
                    _buildRow(
                      'Cash variance',
                      cashVariance == 0
                          ? '₹0 (Exact Match)'
                          : cashVariance > 0
                              ? '+${CurrencyFormatter.formatPaise(cashVariance)} (Surplus)'
                              : '${CurrencyFormatter.formatPaise(cashVariance)} (Shortage)',
                      isBold: true,
                      color: cashVariance == 0 ? StationColors.successGreen : StationColors.errorRed,
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
          const SizedBox(height: 24),
        ],
      ),
    );
      },
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
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
            const SizedBox(width: 12),
            Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? StationColors.textDark))),
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
