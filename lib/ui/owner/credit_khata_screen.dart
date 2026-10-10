import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../models/credit_customer.dart';
import '../../services/station_state_provider.dart';
import '../common/pagination_control.dart';

class CreditKhataScreen extends StatefulWidget {
  const CreditKhataScreen({super.key});

  @override
  State<CreditKhataScreen> createState() => _CreditKhataScreenState();
}

class _CreditKhataScreenState extends State<CreditKhataScreen> {
  int _selectedCustomerIdx = 0;
  int _currentPage = 1;
  static const int _pageSize = 10;
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

    int totalOutstanding = customers.fold(0, (sum, c) => sum + c.pendingAmountPaise);

    final totalItems = customers.length;
    final int startIndex = (_currentPage - 1) * _pageSize;
    final int endIndex = (startIndex + _pageSize).clamp(0, totalItems);
    final displayedCustomers = (startIndex < totalItems)
        ? customers.sublist(startIndex, endIndex)
        : <CreditCustomer>[];

    final customer = displayedCustomers.isNotEmpty
        ? displayedCustomers[_selectedCustomerIdx.clamp(0, displayedCustomers.length - 1)]
        : (customers.isNotEmpty ? customers.first : null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Total Outstanding
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.get('customersYetToPay', lang),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: StationColors.textDark),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatPaise(totalOutstanding),
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: StationColors.accentOrange),
                  ),
                  const Text('Outstanding balance', style: TextStyle(fontSize: 12, color: StationColors.textLight)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Two-column Layout: Customers List & Detail/Payment
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 750;

              Widget customersList = Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                      border: Border.all(color: StationColors.divider),
                    ),
                    child: displayedCustomers.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('No credit customers registered.')),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: displayedCustomers.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: StationColors.divider),
                            itemBuilder: (context, i) {
                              final c = displayedCustomers[i];
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
                  ),
                  const SizedBox(height: 12),
                  PaginationControl(
                    currentPage: _currentPage,
                    totalItems: totalItems,
                    pageSize: _pageSize,
                    onPageChanged: (newPage) {
                      setState(() {
                        _currentPage = newPage;
                        _selectedCustomerIdx = 0;
                      });
                    },
                  ),
                ],
              );

              Widget detailCard = customer == null
                  ? const SizedBox()
                  : Container(
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: StationColors.textDark)),
                                  Text(customer.subtitle, style: const TextStyle(fontSize: 13, color: StationColors.textMedium)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: StationColors.accentOrangeLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  customer.formattedPending,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: StationColors.accentOrange),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 28),

                          // Customer Activity Timeline
                          const Text('Recent Khata payments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 12),
                          if (customer.payments.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: Text('No previous payments recorded.', style: TextStyle(fontSize: 13, color: StationColors.textLight)),
                            )
                          else
                            ...customer.payments.map((p) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${p.date.day}/${p.date.month} • Paid via ${p.mode}${p.note != null ? ' (${p.note})' : ''}',
                                      style: const TextStyle(fontSize: 13, color: StationColors.textMedium),
                                    ),
                                    Text(
                                      p.formattedAmount,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: StationColors.successGreen),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const Divider(height: 28),

                          // Record Khata Payment Section
                          const Text('Record Khata payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _paymentAmountController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Payment amount',
                                    prefixText: '₹ ',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: _paymentMode,
                                  decoration: InputDecoration(
                                    labelText: 'Mode',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                                    DropdownMenuItem(value: 'PhonePe', child: Text('PhonePe')),
                                    DropdownMenuItem(value: 'Bank', child: Text('Bank Transfer')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _paymentMode = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                              label: const Text('Record payment received', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: StationColors.successGreen,
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
