import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../models/credit_customer.dart';
import '../../services/station_state_provider.dart';

class CreditKhataScreen extends StatefulWidget {
  const CreditKhataScreen({super.key});

  @override
  State<CreditKhataScreen> createState() => _CreditKhataScreenState();
}

class _CreditKhataScreenState extends State<CreditKhataScreen> {
  int _selectedCustomerIdx = 0;
  final TextEditingController _paymentAmountController = TextEditingController(text: '5,000');
  String _paymentMode = 'Cash';

  @override
  void dispose() {
    _paymentAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final customers = state.creditCustomers;
    final customer = customers[_selectedCustomerIdx.clamp(0, customers.length - 1)];

    int totalOutstanding = customers.fold(0, (sum, c) => sum + c.pendingAmountPaise);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Total Outstanding
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.get('customersYetToPay', lang),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: StationColors.textDark),
                  ),
                  const SizedBox(height: 2),
                  const Text('Demo • UI review', style: TextStyle(fontSize: 14, color: StationColors.textMedium)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatPaise(totalOutstanding),
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: StationColors.accentOrange),
                  ),
                  const Text('Illustrative outstanding credit', style: TextStyle(fontSize: 12, color: StationColors.textLight)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Two-column Layout: Customers List & Detail/Payment
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 750;

              Widget customersList = Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                  border: Border.all(color: StationColors.divider),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: customers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: StationColors.divider),
                  itemBuilder: (context, i) {
                    final c = customers[i];
                    bool isSelected = i == _selectedCustomerIdx;

                    return InkWell(
                      onTap: () => setState(() => _selectedCustomerIdx = i),
                      child: Container(
                        color: isSelected ? StationColors.primaryLight.withOpacity(0.08) : Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: StationColors.textDark),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    c.subtitle,
                                    style: const TextStyle(fontSize: 13, color: StationColors.textLight),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              c.formattedPending,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: StationColors.accentOrange),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );

              Widget detailCard = Container(
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
                      customer.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StationColors.textDark),
                    ),
                    Text(customer.subtitle, style: const TextStyle(fontSize: 13, color: StationColors.textMedium)),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Credit given: 9 Oct 2026', style: TextStyle(fontSize: 13, color: StationColors.textLight)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Pending amount', style: TextStyle(fontSize: 11, color: StationColors.textLight)),
                            Text(
                              customer.formattedPending,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: StationColors.accentOrange),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Payment History
                    const Text('Payment history', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: StationColors.divider),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Table(
                        children: const [
                          TableRow(
                            decoration: BoxDecoration(color: Color(0xFFF7F9F9)),
                            children: [
                              Padding(padding: EdgeInsets.all(8), child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                          ),
                          TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(8), child: Text('09 Oct 2026', style: TextStyle(fontSize: 12))),
                              Padding(padding: EdgeInsets.all(8), child: Text('₹0', style: TextStyle(fontSize: 12))),
                              Padding(padding: EdgeInsets.all(8), child: Text('—', style: TextStyle(fontSize: 12))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Credit given', style: TextStyle(fontSize: 12))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Record Payment Section
                    const Text('Record payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    const Text('This reduces credit; it is not a new fuel sale.', style: TextStyle(fontSize: 12, color: StationColors.textLight)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _paymentAmountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixText: '₹ ',
                              labelText: 'Amount',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 4,
                          child: Row(
                            children: [
                              Radio<String>(
                                value: 'Cash',
                                groupValue: _paymentMode,
                                onChanged: (val) => setState(() => _paymentMode = val!),
                              ),
                              const Text('Cash', style: TextStyle(fontSize: 13)),
                              Radio<String>(
                                value: 'PhonePe',
                                groupValue: _paymentMode,
                                onChanged: (val) => setState(() => _paymentMode = val!),
                              ),
                              const Text('PhonePe', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.currency_rupee, size: 18, color: Colors.white),
                        label: const Text('Record payment', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: StationColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          int paise = CurrencyFormatter.parseToPaise(_paymentAmountController.text);
                          if (paise <= 0) return;

                          state.recordCreditPayment(customer.id, paise, _paymentMode);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Payment of ${CurrencyFormatter.formatPaise(paise)} recorded for ${customer.name}.'),
                              backgroundColor: StationColors.successGreen,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );

              if (!isWide) {
                return Column(
                  children: [
                    customersList,
                    const SizedBox(height: 20),
                    detailCard,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: customersList),
                  const SizedBox(width: 20),
                  Expanded(flex: 6, child: detailCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
