import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../services/station_state_provider.dart';

class DailyReportScreen extends StatelessWidget {
  const DailyReportScreen({super.key});

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
                        const SnackBar(content: Text('Generating Daily Station Report PDF / Excel export.')),
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
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date & Shift Selector
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
                    IconButton(icon: const Icon(Icons.chevron_left, size: 18), onPressed: () {}),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('9 Oct 2026', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    IconButton(icon: const Icon(Icons.chevron_right, size: 18), onPressed: () {}),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: StationColors.divider),
                ),
                child: const Row(
                  children: [
                    Text('Evening • Sample', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 18),
                  ],
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
                    columns: const [
                      DataColumn(label: Text('Fuel', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Opening (L)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Closing (L)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Gross (L)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Test (L)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Sale (L)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Rate (₹/L)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Calculated value (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: report.nozzleResults.map((n) {
                      return DataRow(
                        cells: [
                          DataCell(Text(n.fuelType, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text((n.openingReadingMl / 1000.0).toStringAsFixed(3))),
                          DataCell(Text((n.closingReadingMl / 1000.0).toStringAsFixed(3))),
                          DataCell(Text((n.grossVolumeMl / 1000.0).toStringAsFixed(3))),
                          DataCell(Text((n.testVolumeMl / 1000.0).toStringAsFixed(3))),
                          DataCell(Text((n.billableVolumeMl / 1000.0).toStringAsFixed(3))),
                          DataCell(Text((n.ratePaisePerLitre / 100.0).toStringAsFixed(2))),
                          DataCell(Text(CurrencyFormatter.formatPaise(n.fuelSalesPaise), style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Calculated fuel value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      CurrencyFormatter.formatPaise(report.totalCalculatedFuelSalesPaise, forceDecimals: true),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: StationColors.textDark),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: StationColors.warningBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: StationColors.warningBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 20, color: StationColors.warningAmber),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Paper total ₹98,146 • Rounding difference ₹0.88 — These figures are from handwritten records and need confirmation.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: StationColors.textDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Two-column Bottom: Cash Reconciliation & Payment Mix
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 750;

              Widget cashReconCard = Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                  border: Border.all(color: StationColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cash reconciliation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 14),
                    _buildRow('Cash sales', CurrencyFormatter.formatPaise(report.cashSalesPaise), isBold: true),
                    const SizedBox(height: 10),
                    _buildRow('Other cash debit', CurrencyFormatter.formatPaise(report.otherCashDebitsPaise), subnote: "Confirm category for 'Other cash debit'"),
                    const SizedBox(height: 10),
                    _buildRow('Food expense', CurrencyFormatter.formatPaise(report.foodExpensesPaise)),
                    const SizedBox(height: 10),
                    _buildRow('Given owner', CurrencyFormatter.formatPaise(report.cashGivenToOwnerPaise), isBold: true, color: StationColors.accentOrange),
                    const Divider(height: 20),
                    _buildRow('Cash remaining', CurrencyFormatter.formatPaise(report.cashVariancePaise), isBold: true, color: StationColors.successGreen),
                  ],
                ),
              );

              Widget paymentMixCard = Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                  border: Border.all(color: StationColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment mix (illustrative)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 14),
                    _buildRow('PhonePe', CurrencyFormatter.formatPaise(report.phonePeSalesPaise)),
                    const SizedBox(height: 10),
                    _buildRow('Card', CurrencyFormatter.formatPaise(report.cardSalesPaise)),
                    const SizedBox(height: 10),
                    _buildRow('Credit', CurrencyFormatter.formatPaise(report.creditSalesPaise)),
                  ],
                ),
              );

              if (!isWide) {
                return Column(
                  children: [
                    cashReconCard,
                    const SizedBox(height: 20),
                    paymentMixCard,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: cashReconCard),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: paymentMixCard),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Who Updated This Audit Trail
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Who updated this', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton.icon(
                      icon: const Icon(Icons.description_outlined, size: 16),
                      label: const Text('View source notebook', style: TextStyle(fontSize: 12)),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildAuditPoint('Srikant', 'Sample shift entry\n9 Oct 2026, 10:00 pm'),
                    Expanded(child: Container(height: 2, color: StationColors.primary)),
                    _buildAuditPoint('Owner handover', '₹13,074\n9 Oct 2026'),
                    Expanded(child: Container(height: 2, color: StationColors.primary)),
                    _buildAuditPoint('Receipt sample', 'Pump 1\n9 Oct 2026, 9:50 pm'),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.orange),
                      SizedBox(width: 10),
                      Text('Illustrative classification — confirm N.C and Bus bill before accounting approval.', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StationColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: StationColors.textMedium, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
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

  Widget _buildAuditPoint(String title, String subtitle) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(color: StationColors.primary, shape: BoxShape.circle),
        ),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 2),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: StationColors.textLight)),
      ],
    );
  }
}
