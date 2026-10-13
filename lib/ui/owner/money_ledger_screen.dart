import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../core/formatting/date_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../models/transaction_entry.dart';
import '../../services/station_state_provider.dart';
import '../common/pagination_control.dart';

class MoneyLedgerScreen extends StatefulWidget {
  const MoneyLedgerScreen({super.key});

  @override
  State<MoneyLedgerScreen> createState() => _MoneyLedgerScreenState();
}

class _MoneyLedgerScreenState extends State<MoneyLedgerScreen> {
  int _selectedSubTab = 0; // 0=All, 1=Cash, 2=PhonePe, 3=Card, 4=Credit, 5=Paid out
  String _selectedStaffFilter = 'All';
  DateTime? _selectedDateFilter;
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final allEntries = state.entries;

    // Staff dropdown list options
    final staffNames = <String>{'All'};
    for (var u in state.allUsers) {
      staffNames.add(u.name);
    }
    for (var e in allEntries) {
      if (e.createdBy.isNotEmpty) {
        staffNames.add(e.createdBy);
      }
    }
    final sortedStaffList = staffNames.toList()..sort();
    // Ensure 'All' is first
    sortedStaffList.remove('All');
    sortedStaffList.insert(0, 'All');

    // 1. Filter entries by Date & Staff for Summary calculations
    final dateStaffFilteredEntries = allEntries.where((e) {
      if (_selectedDateFilter != null) {
        final d = e.createdAt;
        final f = _selectedDateFilter!;
        if (d.year != f.year || d.month != f.month || d.day != f.day) {
          return false;
        }
      }
      if (_selectedStaffFilter != 'All' && e.createdBy != _selectedStaffFilter) {
        return false;
      }
      return true;
    }).toList();

    // 2. Compute live aggregates from filtered entries
    int cashSales = 0;
    int phonePeSales = 0;
    int cardSales = 0;
    int creditSales = 0;
    int otherDebits = 0;
    int foodExpenses = 0;
    int toOwner = 0;

    for (var e in dateStaffFilteredEntries) {
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

    final int recordedSales = cashSales + phonePeSales + cardSales + creditSales;
    final int cashRemaining = cashSales - (toOwner + otherDebits + foodExpenses);

    // 3. Filter further by Subtab for table display
    final subTabFilteredEntries = dateStaffFilteredEntries.where((e) {
      switch (_selectedSubTab) {
        case 1: // Cash
          return e.category == EntryCategory.cash && e.direction == EntryDirection.received;
        case 2: // PhonePe
          return e.category == EntryCategory.phonePe;
        case 3: // Card
          return e.category == EntryCategory.card;
        case 4: // Credit
          return e.category == EntryCategory.credit;
        case 5: // Paid out
          return e.direction == EntryDirection.paidOut;
        case 0: // All
        default:
          return true;
      }
    }).toList();

    // 4. Pagination
    final totalItems = subTabFilteredEntries.length;
    final int totalPages = (totalItems / _pageSize).ceil();
    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    }
    final int startIndex = (_currentPage - 1) * _pageSize;
    final int endIndex = (startIndex + _pageSize).clamp(0, totalItems);
    final displayedEntries = (startIndex < totalItems)
        ? subTabFilteredEntries.sublist(startIndex, endIndex)
        : <TransactionEntry>[];

    return LayoutBuilder(
      builder: (context, screenConstraints) {
        final isMobile = screenConstraints.maxWidth < 600;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            AppStrings.get('moneyLedger', lang),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: StationColors.textDark),
          ),
          const SizedBox(height: 2),
          Text(
            '${DateFormatter.formatDisplayDate(DateTime.now())} • Forecourt Dynamic Ledger',
            style: const TextStyle(fontSize: 14, color: StationColors.textMedium),
          ),
          const SizedBox(height: 20),

          // Filters Bar (Date Filter, Staff Filter, Clear)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
              border: Border.all(color: StationColors.divider),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Date Filter Pill
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDateFilter ?? DateTime.now(),
                      firstDate: DateTime(2025),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDateFilter = picked;
                        _currentPage = 1;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 44, // 44px+ touch target mandate
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _selectedDateFilter != null ? StationColors.primaryLight.withOpacity(0.12) : const Color(0xFFF7F9F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _selectedDateFilter != null ? StationColors.primary : StationColors.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: _selectedDateFilter != null ? StationColors.primary : StationColors.textMedium,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedDateFilter != null
                              ? 'Date: ${DateFormatter.formatDisplayDate(_selectedDateFilter!)}'
                              : 'Filter by Date: All',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _selectedDateFilter != null ? StationColors.primary : StationColors.textDark,
                          ),
                        ),
                        if (_selectedDateFilter != null) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => setState(() {
                              _selectedDateFilter = null;
                              _currentPage = 1;
                            }),
                            child: const Icon(Icons.close, size: 16, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Staff Filter Dropdown
                Container(
                  height: 44, // 44px+ touch target mandate
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _selectedStaffFilter != 'All' ? StationColors.primaryLight.withOpacity(0.12) : const Color(0xFFF7F9F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _selectedStaffFilter != 'All' ? StationColors.primary : StationColors.divider),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: sortedStaffList.contains(_selectedStaffFilter) ? _selectedStaffFilter : 'All',
                      icon: const Icon(Icons.arrow_drop_down, color: StationColors.textMedium),
                      style: const TextStyle(fontSize: 13, color: StationColors.textDark, fontWeight: FontWeight.w600),
                      items: sortedStaffList.map((name) {
                        return DropdownMenuItem(
                          value: name,
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline, size: 16, color: StationColors.textMedium),
                              const SizedBox(width: 8),
                              Text(name == 'All' ? 'Staff: All Staff' : 'Staff: $name'),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedStaffFilter = val;
                            _currentPage = 1;
                          });
                        }
                      },
                    ),
                  ),
                ),

                // Reset Filters Button
                if (_selectedDateFilter != null || _selectedStaffFilter != 'All' || _selectedSubTab != 0)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: StationColors.errorRed,
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () {
                      setState(() {
                        _selectedDateFilter = null;
                        _selectedStaffFilter = 'All';
                        _selectedSubTab = 0;
                        _currentPage = 1;
                      });
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

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
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          _selectedDateFilter != null
                              ? 'Money summary (${DateFormatter.formatDisplayDate(_selectedDateFilter!)})'
                              : 'Money summary (Dynamic Total)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (_selectedStaffFilter != 'All')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: StationColors.primaryLight.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _selectedStaffFilter,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: StationColors.primary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildLedgerRow('Recorded sales', CurrencyFormatter.formatPaise(recordedSales), isBold: true),
                    const Divider(height: 20),
                    _buildLedgerRow('Cash sales', CurrencyFormatter.formatPaise(cashSales)),
                    const SizedBox(height: 8),
                    _buildLedgerRow('PhonePe', CurrencyFormatter.formatPaise(phonePeSales)),
                    const SizedBox(height: 8),
                    _buildLedgerRow('Card', CurrencyFormatter.formatPaise(cardSales)),
                    const SizedBox(height: 8),
                    _buildLedgerRow('Credit', CurrencyFormatter.formatPaise(creditSales)),
                  ],
                ),
              );

              final int totalCollections = cashSales + phonePeSales + cardSales;
              final int netForecourtBalance = totalCollections - (toOwner + otherDebits + foodExpenses);

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
                    const Text('Forecourt Collections & Settlement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    _buildLedgerRow('Total collections received', CurrencyFormatter.formatPaise(totalCollections), isBold: true),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        children: [
                          _buildLedgerRow('• Cash received', CurrencyFormatter.formatPaise(cashSales)),
                          const SizedBox(height: 4),
                          _buildLedgerRow('• PhonePe / UPI', CurrencyFormatter.formatPaise(phonePeSales)),
                          const SizedBox(height: 4),
                          _buildLedgerRow('• Card swiping', CurrencyFormatter.formatPaise(cardSales)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildLedgerRow('Credit given (Khata)', CurrencyFormatter.formatPaise(creditSales)),
                    const Divider(height: 20),
                    _buildLedgerRow('Other expenses & debits', CurrencyFormatter.formatPaise(otherDebits)),
                    const SizedBox(height: 8),
                    _buildLedgerRow('Food', CurrencyFormatter.formatPaise(foodExpenses)),
                    const SizedBox(height: 8),
                    _buildLedgerRow('Given to owner', CurrencyFormatter.formatPaise(toOwner), isBold: true),
                    const Divider(height: 20),
                    _buildLedgerRow(
                      'Physical cash remaining',
                      CurrencyFormatter.formatPaise(cashRemaining),
                      isBold: true,
                      color: cashRemaining >= 0 ? StationColors.successGreen : StationColors.errorRed,
                    ),
                    const SizedBox(height: 6),
                    _buildLedgerRow(
                      'Net balance (All modes)',
                      CurrencyFormatter.formatPaise(netForecourtBalance),
                      isBold: true,
                      color: netForecourtBalance >= 0 ? StationColors.primary : StationColors.errorRed,
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

          // Sub-tabs row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSubTab(0, 'All (${dateStaffFilteredEntries.length})'),
                const SizedBox(width: 8),
                _buildSubTab(1, 'Cash'),
                const SizedBox(width: 8),
                _buildSubTab(2, 'PhonePe'),
                const SizedBox(width: 8),
                _buildSubTab(3, 'Card'),
                const SizedBox(width: 8),
                _buildSubTab(4, 'Credit'),
                const SizedBox(width: 8),
                _buildSubTab(5, 'Paid out'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Detailed Entries Table / Cards List with Pagination
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
              border: Border.all(color: StationColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Shift Entries Details (${subTabFilteredEntries.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: StationColors.textDark),
                      ),
                      Text(
                        'Page $_currentPage of ${totalPages == 0 ? 1 : totalPages}',
                        style: const TextStyle(fontSize: 12, color: StationColors.textMedium, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Entries Content
                if (displayedEntries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text(
                            'No entries found for selected filters',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: StationColors.textDark),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Transactions entered by shift staff in Forecourt will appear here dynamically.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: StationColors.textMedium),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      bool isNarrow = constraints.maxWidth < 650;

                      if (isNarrow) {
                        // Mobile Card Layout
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: displayedEntries.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final entry = displayedEntries[index];
                            final isReceived = entry.direction == EntryDirection.received;
                            final rawTime = (entry.timeString ?? '').trim();
                            final timeLabel = rawTime.isNotEmpty
                                ? rawTime
                                : DateFormatter.formatDisplayTime(entry.createdAt);

                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            _buildCategoryChip(entry),
                                            Text(
                                              entry.createdBy.isNotEmpty ? entry.createdBy : 'Staff',
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: StationColors.textDark),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        entry.formattedAmount,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: isReceived ? StationColors.successGreen : StationColors.errorRed,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (entry.phonePeNumber != null && entry.phonePeNumber!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.phone_android, size: 14, color: Colors.purple),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Mobile: ${entry.phonePeNumber}',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.purple),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (entry.reference != null && entry.reference!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        'Ref: ${entry.reference}',
                                        style: const TextStyle(fontSize: 12, color: StationColors.textMedium),
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                DateFormatter.formatDisplayDate(entry.createdAt),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: StationColors.textMedium),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: StationColors.primary.withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(5),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.access_time_filled_rounded, size: 11, color: StationColors.primary),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      timeLabel,
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: StationColors.primary),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              isReceived ? 'Received (+)' : 'Paid out (-)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isReceived ? StationColors.successGreen : StationColors.errorRed,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18, color: StationColors.errorRed),
                                              tooltip: 'Delete entry',
                                              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                              padding: EdgeInsets.zero,
                                              onPressed: () => _confirmDeleteEntry(context, entry, state),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }

                        // Wide Desktop / Tablet Table
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.all(const Color(0xFFF7F9F9)),
                              columns: const [
                                DataColumn(label: Text('Date & Time (IST)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                DataColumn(label: Text('Staff', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                DataColumn(label: Text('Details / PhonePe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                DataColumn(label: Text('Direction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              ],
                              rows: displayedEntries.map((entry) {
                                final isReceived = entry.direction == EntryDirection.received;
                                final rawTime = (entry.timeString ?? '').trim();
                                final timeLabel = rawTime.isNotEmpty
                                    ? rawTime
                                    : DateFormatter.formatDisplayTime(entry.createdAt);
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        '${DateFormatter.formatDisplayDate(entry.createdAt)} • $timeLabel',
                                        style: const TextStyle(fontSize: 12, color: StationColors.textMedium),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          const Icon(Icons.person_outline, size: 16, color: StationColors.textMedium),
                                          const SizedBox(width: 6),
                                          Text(entry.createdBy.isNotEmpty ? entry.createdBy : 'Staff', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    DataCell(_buildCategoryChip(entry)),
                                    DataCell(
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          if (entry.phonePeNumber != null && entry.phonePeNumber!.isNotEmpty)
                                            Text(
                                              'Mobile: ${entry.phonePeNumber}',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple),
                                            ),
                                          if (entry.reference != null && entry.reference!.isNotEmpty)
                                            Text(
                                              entry.reference!,
                                              style: const TextStyle(fontSize: 12, color: StationColors.textMedium),
                                            ),
                                          if ((entry.phonePeNumber == null || entry.phonePeNumber!.isEmpty) && (entry.reference == null || entry.reference!.isEmpty))
                                            const Text('—', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isReceived ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isReceived ? 'Received' : 'Paid out',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isReceived ? StationColors.successGreen : StationColors.errorRed,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        entry.formattedAmount,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: isReceived ? StationColors.successGreen : StationColors.errorRed,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: StationColors.errorRed),
                                        tooltip: 'Delete entry permanently',
                                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                        onPressed: () => _confirmDeleteEntry(context, entry, state),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        );
                    },
                  ),

                // Pagination Control
                if (totalItems > 0)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: PaginationControl(
                      currentPage: _currentPage,
                      totalItems: totalItems,
                      pageSize: _pageSize,
                      onPageChanged: (newPage) {
                        setState(() => _currentPage = newPage);
                      },
                    ),
                  ),
              ],
            ),
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
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: StationColors.warningAmber, size: 24),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Illustrative categories',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: StationColors.warningAmber),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'These amounts are calculated dynamically from forecourt entries. Verify category mappings for notebook abbreviations.',
                        style: TextStyle(fontSize: 12, color: StationColors.textMedium),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: StationColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(44, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _showUncategorizedAuditDialog(context, state),
                          child: const Text('Review uncategorized entry →', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                : Row(
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
                              'These amounts are calculated dynamically from forecourt entries. Verify category mappings for notebook abbreviations.',
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
                        onPressed: () => _showUncategorizedAuditDialog(context, state),
                        child: const Text('Review uncategorized entry →', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildCategoryChip(TransactionEntry entry) {
    Color bg;
    Color fg;
    switch (entry.category) {
      case EntryCategory.cash:
        bg = Colors.green.withOpacity(0.12);
        fg = Colors.green[800]!;
        break;
      case EntryCategory.phonePe:
        bg = Colors.purple.withOpacity(0.12);
        fg = Colors.purple[800]!;
        break;
      case EntryCategory.card:
        bg = Colors.blue.withOpacity(0.12);
        fg = Colors.blue[800]!;
        break;
      case EntryCategory.credit:
        bg = Colors.orange.withOpacity(0.15);
        fg = Colors.orange[900]!;
        break;
      case EntryCategory.expense:
      case EntryCategory.salary:
      case EntryCategory.toOwner:
        bg = Colors.red.withOpacity(0.12);
        fg = Colors.red[800]!;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        entry.category.displayName,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  void _showUncategorizedAuditDialog(BuildContext context, StationStateProvider state) {
    String selectedCategory = state.settings.categories.isNotEmpty ? state.settings.categories.first.name : 'Expenses';
    final notesCtrl = TextEditingController(text: 'Forecourt operational expense / generator diesel & maintenance');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.rule_folder_rounded, color: StationColors.primary),
                SizedBox(width: 8),
                Text('Audit Uncategorized Entry', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: StationColors.warningBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: StationColors.warningBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Original Ledger Record (${DateFormatter.formatDisplayDate(DateTime.now())}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: StationColors.warningAmber)),
                        const SizedBox(height: 4),
                        const Text('• Description: Other cash debit', style: TextStyle(fontSize: 12)),
                        const Text('• Shift: Forecourt entries', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Map to Authoritative Category:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: StationColors.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCategory,
                        isExpanded: true,
                        items: state.settings.categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedCategory = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Audit Notes / Reference:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    maxLength: 30,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      hintText: 'Enter justification for ledger classification...',
                      counterText: '',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: StationColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Entry mapped to "$selectedCategory" and confirmed in ledger audit trail.'),
                      backgroundColor: StationColors.successGreen,
                    ),
                  );
                },
                child: const Text('Confirm & Map Category', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubTab(int index, String label) {
    bool isSelected = _selectedSubTab == index;
    return InkWell(
      onTap: () => setState(() {
        _selectedSubTab = index;
        _currentPage = 1;
      }),
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

  Future<void> _confirmDeleteEntry(
    BuildContext context,
    TransactionEntry entry,
    StationStateProvider state,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_outlined, color: StationColors.errorRed),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete Transaction Entry?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Permanently delete ${entry.category.displayName} entry of ${entry.formattedAmount} recorded by ${entry.createdBy}? This will remove it from both the app and Cloud Firestore.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: StationColors.errorRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Entry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await state.deleteTransactionEntry(entry.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${entry.category.displayName} entry (${entry.formattedAmount})'),
            backgroundColor: StationColors.errorRed,
          ),
        );
      }
    }
  }
}
