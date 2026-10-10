import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../services/station_state_provider.dart';

class MoneyLedgerScreen extends StatefulWidget {
  const MoneyLedgerScreen({super.key});

  @override
  State<MoneyLedgerScreen> createState() => _MoneyLedgerScreenState();
}

class _MoneyLedgerScreenState extends State<MoneyLedgerScreen> {
  int _selectedSubTab = 0; // 0=Cash, 1=PhonePe, 2=Card, 3=Credit, 4=Paid out

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
          // Header
          Text(
            AppStrings.get('moneyLedger', lang),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: StationColors.textDark),
          ),
          const SizedBox(height: 2),
          const Text('9 Oct 2026 • Illustrated from notebook', style: TextStyle(fontSize: 14, color: StationColors.textMedium)),
          const SizedBox(height: 20),

          // Sub-tabs row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSubTab(0, 'Cash'),
                const SizedBox(width: 8),
                _buildSubTab(1, 'PhonePe'),
                const SizedBox(width: 8),
                _buildSubTab(2, 'Card'),
                const SizedBox(width: 8),
                _buildSubTab(3, 'Credit'),
                const SizedBox(width: 8),
                _buildSubTab(4, 'Paid out'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Two-column Summary & Cash Details
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 700;

              Widget summaryCard = Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                  border: Border.all(color: StationColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Money summary (9 Oct 2026)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    _buildLedgerRow('Recorded sales', '₹98,146', isBold: true),
                    const Divider(height: 20),
                    _buildLedgerRow('Cash sales', CurrencyFormatter.formatPaise(report.cashSalesPaise)),
                    const SizedBox(height: 8),
                    _buildLedgerRow('PhonePe', CurrencyFormatter.formatPaise(report.phonePeSalesPaise)),
                    const SizedBox(height: 8),
                    _buildLedgerRow('Card', CurrencyFormatter.formatPaise(report.cardSalesPaise)),
                    const SizedBox(height: 8),
                    _buildLedgerRow('Credit', CurrencyFormatter.formatPaise(report.creditSalesPaise)),
                  ],
                ),
              );

              Widget cashDetailsCard = Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                  border: Border.all(color: StationColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cash details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    _buildLedgerRow('Cash sales (from entries)', CurrencyFormatter.formatPaise(report.cashSalesPaise), isBold: true),
                    const SizedBox(height: 12),
                    _buildLedgerRow(
                      'Other cash debit',
                      CurrencyFormatter.formatPaise(report.otherCashDebitsPaise),
                      badge: 'Category to confirm',
                    ),
                    const SizedBox(height: 12),
                    _buildLedgerRow('Food', CurrencyFormatter.formatPaise(report.foodExpensesPaise)),
                    const SizedBox(height: 12),
                    _buildLedgerRow('Given to owner', CurrencyFormatter.formatPaise(report.cashGivenToOwnerPaise), isBold: true),
                    const Divider(height: 20),
                    _buildLedgerRow(
                      'Cash remaining',
                      CurrencyFormatter.formatPaise(report.cashVariancePaise),
                      isBold: true,
                      color: StationColors.successGreen,
                    ),
                  ],
                ),
              );

              if (!isWide) {
                return Column(
                  children: [
                    summaryCard,
                    const SizedBox(height: 16),
                    cashDetailsCard,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: summaryCard),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: cashDetailsCard),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Illustrative Warning Callout
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Illustrative categories — verify notebook abbreviations',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: StationColors.warningAmber),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'These amounts are from the handwritten notebook. Category names and meanings are illustrative.',
                        style: TextStyle(fontSize: 12, color: StationColors.textMedium),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StationColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening category mapping audit dialog.')),
                    );
                  },
                  child: const Text('Review uncategorized entry →', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTab(int index, String label) {
    bool isSelected = _selectedSubTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedSubTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? StationColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? StationColors.primary : StationColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : StationColors.textDark,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildLedgerRow(String label, String value, {bool isBold = false, String? badge, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
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
                child: Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange[900])),
              ),
            ],
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? StationColors.textDark,
          ),
        ),
      ],
    );
  }
}
