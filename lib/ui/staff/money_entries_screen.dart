import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../core/formatting/date_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../models/transaction_entry.dart';
import '../../services/station_state_provider.dart';

class MoneyEntriesScreen extends StatefulWidget {
  const MoneyEntriesScreen({super.key});

  @override
  State<MoneyEntriesScreen> createState() => _MoneyEntriesScreenState();
}

class _MoneyEntriesScreenState extends State<MoneyEntriesScreen> {
  EntryDirection _direction = EntryDirection.received;
  EntryCategory _selectedCategory = EntryCategory.phonePe;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  late final TextEditingController _timeController;
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerSubtitleController = TextEditingController();
  String? _selectedCreditCustomerId;

  @override
  void initState() {
    super.initState();
    _timeController = TextEditingController(text: DateFormatter.formatDisplayTime(DateTime.now()));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    _timeController.dispose();
    _refController.dispose();
    _customerNameController.dispose();
    _customerSubtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            AppStrings.get('moneyEntries', lang),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: StationColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${state.activeShift.businessDate} • ${state.activeShift.shiftName} shift',
            style: const TextStyle(fontSize: 14, color: StationColors.textMedium),
          ),
          const SizedBox(height: 16),

          // Direction Segmented Control: [ Received ] | [ Paid out ]
          Container(
            height: 46,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() {
                      _direction = EntryDirection.received;
                      if (_selectedCategory == EntryCategory.expense || _selectedCategory == EntryCategory.toOwner) {
                        _selectedCategory = EntryCategory.phonePe;
                      }
                    }),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _direction == EntryDirection.received ? StationColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        AppStrings.get('received', lang),
                        style: TextStyle(
                          color: _direction == EntryDirection.received ? Colors.white : StationColors.textMedium,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() {
                      _direction = EntryDirection.paidOut;
                      _selectedCategory = EntryCategory.expense;
                    }),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _direction == EntryDirection.paidOut ? StationColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        AppStrings.get('paidOut', lang),
                        style: TextStyle(
                          color: _direction == EntryDirection.paidOut ? Colors.white : StationColors.textMedium,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Select Category Pills
          Text(
            AppStrings.get('selectCategory', lang),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: StationColors.textMedium),
          ),
          const SizedBox(height: 10),

          // Category Grid / Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _direction == EntryDirection.received
                ? [
                    _buildCategoryPill(EntryCategory.cash, Icons.money, 'Cash', null),
                    _buildCategoryPill(EntryCategory.phonePe, Icons.payment, 'PhonePe', StationColors.phonePePurple),
                    _buildCategoryPill(EntryCategory.card, Icons.credit_card, 'Card', StationColors.cardBlue),
                    _buildCategoryPill(EntryCategory.credit, Icons.bookmark_outline, 'Credit', StationColors.creditTeal),
                  ]
                : [
                    _buildCategoryPill(EntryCategory.expense, Icons.receipt_long, 'Expense', Colors.orange[800]),
                    _buildCategoryPill(EntryCategory.salary, Icons.people_outline, 'Salary', Colors.indigo),
                    _buildCategoryPill(EntryCategory.toOwner, Icons.person_pin_outlined, 'To owner', StationColors.accentOrange),
                  ],
          ),
          const SizedBox(height: 20),

          // Amount Input Card (Large Forecourt Typography)
          Text(
            AppStrings.get('amount', lang),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: StationColors.textMedium),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: StationColors.divider, width: 1.5),
            ),
            child: Row(
              children: [
                const Text(
                  '₹',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: StationColors.textDark),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: StationColors.textDark),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      hintText: '0',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Conditional PhonePe Number & Time Fields
          if (_selectedCategory == EntryCategory.phonePe) ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.get('phonePeNumber', lang),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: StationColors.textMedium),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                        decoration: InputDecoration(
                          hintText: '10 digits mobile',
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: StationColors.divider),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.get('time', lang),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: StationColors.textMedium),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _timeController,
                        maxLength: 15,
                        decoration: InputDecoration(
                          hintText: '12:15 pm',
                          counterText: '',
                          suffixIcon: const Icon(Icons.access_time, size: 18),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: StationColors.divider),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Conditional Credit Customer Selection & Input (Compulsory when Credit is selected)
          if (_selectedCategory == EntryCategory.credit) ...[
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: StationColors.creditTeal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: StationColors.creditTeal.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.person_pin, color: StationColors.creditTeal, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Credit Customer Details *',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: StationColors.textDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Customer Dropdown if existing customers exist
                  if (state.creditCustomers.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedCreditCustomerId ?? (state.creditCustomers.isNotEmpty ? state.creditCustomers.first.id : '__new__'),
                      decoration: InputDecoration(
                        labelText: 'Select Customer',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: [
                        ...state.creditCustomers.map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.name} (${c.formattedPending} due)'),
                            )),
                        const DropdownMenuItem(
                          value: '__new__',
                          child: Text('+ Add New Customer', style: TextStyle(color: StationColors.primary, fontWeight: FontWeight.bold)),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedCreditCustomerId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // If '__new__' selected or no customers registered yet
                  if (_selectedCreditCustomerId == '__new__' || state.creditCustomers.isEmpty) ...[
                    TextField(
                      controller: _customerNameController,
                      maxLength: 30,
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      decoration: InputDecoration(
                        labelText: 'New Customer Name *',
                        hintText: 'e.g. Ramesh Reddy (max 30 chars)',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customerSubtitleController,
                      maxLength: 30,
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      decoration: InputDecoration(
                        labelText: 'Vehicle / Description (optional)',
                        hintText: 'e.g. Tractor AP16 XX1234 (max 30 chars)',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Reference (optional) Field (Max 30 characters)
          Text(
            AppStrings.get('referenceOptional', lang),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: StationColors.textMedium),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _refController,
            maxLength: 30,
            decoration: InputDecoration(
              hintText: 'e.g. customer note (max 30 chars)',
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: StationColors.divider),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Big Save Button (60px high)
          SizedBox(
            width: double.infinity,
            height: StationDimensions.primaryButtonHeight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(
                AppStrings.get('saveEntry', lang),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: StationColors.primary,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(StationDimensions.buttonRadius),
                ),
              ),
              onPressed: () {
                int paise = CurrencyFormatter.parseToPaise(_amountController.text);
                if (paise <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount.')),
                  );
                  return;
                }

                if (_selectedCategory == EntryCategory.credit) {
                  String customerName = '';
                  String subtitle = '';

                  final isSelectingExisting = state.creditCustomers.isNotEmpty &&
                      _selectedCreditCustomerId != '__new__' &&
                      _selectedCreditCustomerId != null;

                  if (isSelectingExisting) {
                    final existing = state.creditCustomers.firstWhere(
                      (c) => c.id == _selectedCreditCustomerId,
                      orElse: () => state.creditCustomers.first,
                    );
                    customerName = existing.name;
                    subtitle = existing.subtitle;
                  } else {
                    customerName = _customerNameController.text.trim();
                    subtitle = _customerSubtitleController.text.trim();
                  }

                  if (customerName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Customer name is compulsory for Credit entries.'),
                        backgroundColor: StationColors.errorRed,
                      ),
                    );
                    return;
                  }

                  state.recordCreditSale(
                    customerName: customerName,
                    subtitle: subtitle,
                    amountPaise: paise,
                    reference: _refController.text.trim().isEmpty ? null : _refController.text.trim(),
                    staffName: state.currentUser.name,
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Credit recorded for $customerName: ${CurrencyFormatter.formatPaise(paise)}'),
                      backgroundColor: StationColors.successGreen,
                    ),
                  );
                } else {
                  final entry = TransactionEntry(
                    id: 'entry_${DateTime.now().millisecondsSinceEpoch}',
                    shiftId: state.activeShift.id,
                    category: _selectedCategory,
                    direction: _direction,
                    amountPaise: paise,
                    phonePeNumber: _selectedCategory == EntryCategory.phonePe ? _phoneController.text : null,
                    timeString: _timeController.text,
                    reference: _refController.text.trim().isEmpty ? null : _refController.text.trim(),
                    createdAt: DateTime.now(),
                    createdBy: state.currentUser.name,
                  );

                  state.addTransactionEntry(entry);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Entry saved: ${CurrencyFormatter.formatPaise(paise)} (${_selectedCategory.displayName})'),
                      backgroundColor: StationColors.successGreen,
                    ),
                  );
                }

                _amountController.clear();
                _phoneController.clear();
                _refController.clear();
                _customerNameController.clear();
                _customerSubtitleController.clear();
                setState(() {
                  _selectedCreditCustomerId = null;
                });
              },
            ),
          ),
          const SizedBox(height: 28),

          // Recent Entries in Shift (Strict user data isolation)
          const Text(
            'Recorded in this shift',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: StationColors.textDark),
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final entries = state.userEntries;
              if (entries.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: StationColors.divider),
                  ),
                  child: const Center(
                    child: Text(
                      'No money entries recorded yet for your shift.',
                      style: TextStyle(color: StationColors.textLight, fontSize: 13),
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.take(10).length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final item = entries[idx];
                  bool isReceived = item.direction == EntryDirection.received;

                  String? subtitle;
                  if (item.category == EntryCategory.phonePe && item.phonePeNumber != null && item.phonePeNumber!.isNotEmpty) {
                    subtitle = 'Mobile: ${item.phonePeNumber!}${item.reference != null && item.reference!.isNotEmpty ? ' • ${item.reference}' : ''}';
                  } else if (item.reference != null && item.reference!.isNotEmpty) {
                    subtitle = item.reference!;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: StationColors.divider),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: isReceived ? StationColors.successBg : StationColors.errorBg,
                          child: Icon(
                            isReceived ? Icons.arrow_downward : Icons.arrow_upward,
                            size: 16,
                            color: isReceived ? StationColors.successGreen : StationColors.errorRed,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.category.displayName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              if (subtitle != null && subtitle.isNotEmpty)
                                Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: StationColors.textLight),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatPaise(item.amountPaise),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: isReceived ? StationColors.textDark : StationColors.accentOrange,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(EntryCategory cat, IconData icon, String label, Color? brandColor) {
    bool isSelected = _selectedCategory == cat;
    Color activeColor = brandColor ?? StationColors.primary;

    return InkWell(
      onTap: () => setState(() => _selectedCategory = cat),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : StationColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? activeColor : StationColors.textMedium),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : StationColors.textDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
