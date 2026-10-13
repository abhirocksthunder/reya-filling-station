import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/formatting/currency_formatter.dart';
import '../../../models/cash_handover_record.dart';
import '../../../models/user_profile.dart';
import '../../common/pagination_control.dart';
import '../../../services/station_state_provider.dart';

class CashHandoverWorkflowCard extends StatefulWidget {
  final bool showQuickInitiateForm;

  const CashHandoverWorkflowCard({
    super.key,
    this.showQuickInitiateForm = false,
  });

  @override
  State<CashHandoverWorkflowCard> createState() =>
      _CashHandoverWorkflowCardState();
}

class _CashHandoverWorkflowCardState extends State<CashHandoverWorkflowCard> {
  String? _selectedReceiverName;
  String? _selectedForwardOwnerName;
  bool _showInitiateForm = false;
  int _incomingPage = 1, _forwardPage = 1, _historyPage = 1;
  int _safePage(int page, int total) =>
      page.clamp(1, total == 0 ? 1 : (total / 10).ceil());
  List<T> _pageItems<T>(List<T> items, int page) =>
      items.skip((_safePage(page, items.length) - 1) * 10).take(10).toList();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _showInitiateForm = widget.showQuickInitiateForm;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final currentUser = state.currentUser;
    final eligibleNames = state.getEligibleHandoverReceiverNames(currentUser);
    final incomingPending = state.incomingPendingHandoversForCurrentUser;
    final unforwardedManagerItems =
        state.managerUnforwardedHandoversForCurrentUser;
    final allHandovers = state.cashHandovers;

    final String? activeReceiver = eligibleNames.isEmpty
        ? null
        : (eligibleNames.contains(_selectedReceiverName)
              ? _selectedReceiverName
              : eligibleNames.first);

    final String? activeForwardOwner = eligibleNames.isEmpty
        ? null
        : (eligibleNames.contains(_selectedForwardOwnerName)
              ? _selectedForwardOwnerName
              : eligibleNames.first);

    String hierarchyRuleText;
    if (currentUser.role == UserRole.shiftStaff) {
      hierarchyRuleText = 'Shift Staff → Manager / Admin / Owner';
    } else if (currentUser.role == UserRole.manager) {
      hierarchyRuleText =
          'Manager → Owner / Admin Only (Cannot handover to Shift Staff)';
    } else {
      hierarchyRuleText =
          'Owner / Admin → Verify & Settle Station Cash Handovers';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: StationColors.primary.withOpacity(0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: StationColors.accentOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: StationColors.accentOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cash Handover Workflow',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: StationColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hierarchyRuleText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: StationColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (eligibleNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showInitiateForm = !_showInitiateForm;
                  });
                },
                icon: Icon(
                  _showInitiateForm ? Icons.expand_less : Icons.send_rounded,
                  size: 16,
                  color: StationColors.primary,
                ),
                label: Text(
                  _showInitiateForm
                      ? 'Hide Handover Form'
                      : '+ New Cash Handover',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: StationColors.primary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: StationColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Visual 3-Tier Hierarchy Pipeline Strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: StationColors.scaffoldBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: StationColors.divider),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildStepChip(
                  '1. Shift Staff',
                  currentUser.role == UserRole.shiftStaff,
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: StationColors.textLight,
                ),
                _buildStepChip(
                  '2. Manager',
                  currentUser.role == UserRole.manager,
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: StationColors.textLight,
                ),
                _buildStepChip(
                  '3. Owner / Admin',
                  currentUser.hasOwnerPrivileges,
                ),
              ],
            ),
          ),

          // Quick Initiate Handover Form
          if (_showInitiateForm && activeReceiver != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: StationColors.primary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: StationColors.primary.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Initiate Cash Handover',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: StationColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Handover to',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: StationColors.textMedium,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: StationColors.divider),
                    ),
                    child: DropdownButton<String>(
                      value: activeReceiver,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: eligibleNames
                          .map(
                            (name) => DropdownMenuItem(
                              value: name,
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedReceiverName = val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    maxLength: 15,
                    inputFormatters: [
                      IndianCurrencyInputFormatter(),
                      LengthLimitingTextInputFormatter(15),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Handover Amount (₹) *',
                      hintText: 'e.g. 25,000.00',
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noteController,
                    maxLength: 30,
                    inputFormatters: [LengthLimitingTextInputFormatter(30)],
                    decoration: InputDecoration(
                      labelText: 'Note (Optional, max 30 chars)',
                      hintText: 'e.g. Morning shift cash',
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StationColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: Text(
                        'Send Handover to $activeReceiver',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: () {
                        final paise = CurrencyFormatter.parseToPaise(
                          _amountController.text,
                        );
                        if (paise <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter a valid handover amount.',
                              ),
                            ),
                          );
                          return;
                        }
                        final created = state.initiateCashHandover(
                          receiverName: activeReceiver,
                          amountPaise: paise,
                          note: _noteController.text.trim(),
                        );
                        if (created != null) {
                          _amountController.clear();
                          _noteController.clear();
                          setState(() => _showInitiateForm = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Cash handover of ${created.formattedAmount} sent to ${created.toUserName}!',
                              ),
                              backgroundColor: StationColors.successGreen,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 1. Incoming Pending Handovers Awaiting Current User's Acceptance
          if (incomingPending.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Awaiting Your Confirmation (${incomingPending.length})',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: StationColors.warningAmber,
              ),
            ),
            const SizedBox(height: 8),
            ..._pageItems(incomingPending, _incomingPage).map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: StationColors.warningBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: StationColors.warningBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          '${item.fromUserName} → ${item.toUserName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: StationColors.textDark,
                          ),
                        ),
                        Text(
                          item.formattedAmount,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: StationColors.accentOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.shiftName} Shift • ${item.businessDate} • ${item.timeString}${item.note != null && item.note!.isNotEmpty ? " • ${item.note}" : ""}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: StationColors.textMedium,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: StationColors.successGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(
                              Icons.verified_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            label: const Text(
                              'Accept Cash',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            onPressed: () {
                              state.acceptCashHandover(item.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Accepted ${item.formattedAmount} from ${item.fromUserName}.',
                                  ),
                                  backgroundColor: StationColors.successGreen,
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: StationColors.errorRed,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(
                              Icons.close,
                              color: StationColors.errorRed,
                              size: 16,
                            ),
                            label: const Text(
                              'Reject',
                              style: TextStyle(
                                color: StationColors.errorRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            onPressed: () {
                              state.rejectCashHandover(item.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Returned handover of ${item.formattedAmount} to ${item.fromUserName}.',
                                  ),
                                  backgroundColor: StationColors.errorRed,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],

          if (incomingPending.length > 10)
            PaginationControl(
              currentPage: _safePage(_incomingPage, incomingPending.length),
              totalItems: incomingPending.length,
              onPageChanged: (page) => setState(() => _incomingPage = page),
            ),
          // 2. Manager Collected Cash from Staff -> Forward to Owner/Admin
          if (unforwardedManagerItems.isNotEmpty &&
              activeForwardOwner != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: StationColors.successBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: StationColors.successGreen.withOpacity(0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cash Collected from Staff: ${CurrencyFormatter.formatPaise(state.managerAcceptedCashFromStaffPaise)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: StationColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select Owner / Admin to forward collected shift cash:',
                    style: TextStyle(
                      fontSize: 11,
                      color: StationColors.textMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: StationColors.divider),
                    ),
                    child: DropdownButton<String>(
                      value: activeForwardOwner,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: eligibleNames
                          .map(
                            (name) => DropdownMenuItem(
                              value: name,
                              child: Text(name),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedForwardOwnerName = val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._pageItems(unforwardedManagerItems, _forwardPage).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: StationColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(
                            Icons.forward_to_inbox_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          label: Text(
                            'Handover ${item.formattedAmount} (from ${item.fromUserName}) to $activeForwardOwner',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () {
                            final forwarded = state.forwardHandoverToOwner(
                              item.id,
                              ownerReceiverName: activeForwardOwner,
                            );
                            if (forwarded != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Forwarded ${forwarded.formattedAmount} to ${forwarded.toUserName}!',
                                  ),
                                  backgroundColor: StationColors.successGreen,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (unforwardedManagerItems.length > 10)
            PaginationControl(
              currentPage: _safePage(
                _forwardPage,
                unforwardedManagerItems.length,
              ),
              totalItems: unforwardedManagerItems.length,
              onPageChanged: (page) => setState(() => _forwardPage = page),
            ),
          // 3. Recent Cash Handover Workflow Trail
          if (allHandovers.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Recent Handover Activity',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: StationColors.textMedium,
              ),
            ),
            const SizedBox(height: 8),
            ..._pageItems(allHandovers, _historyPage).map((h) {
              final Color badgeColor =
                  h.status == CashHandoverStatus.accepted ||
                      h.status == CashHandoverStatus.forwarded
                  ? StationColors.successGreen
                  : h.status == CashHandoverStatus.rejected
                  ? StationColors.errorRed
                  : StationColors.warningAmber;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: StationColors.scaffoldBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: StationColors.divider),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${h.fromUserName} → ${h.toUserName}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: StationColors.textDark,
                          ),
                        ),
                        Text(
                          '${h.timeString} • ${h.shiftName} Shift',
                          style: const TextStyle(
                            fontSize: 11,
                            color: StationColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          h.formattedAmount,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: StationColors.textDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            h.status.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
          if (allHandovers.length > 10)
            PaginationControl(
              currentPage: _safePage(_historyPage, allHandovers.length),
              totalItems: allHandovers.length,
              onPageChanged: (page) => setState(() => _historyPage = page),
            ),
        ],
      ),
    );
  }

  Widget _buildStepChip(String label, bool isCurrentRole) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrentRole ? StationColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: isCurrentRole ? StationColors.primary : StationColors.divider,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isCurrentRole ? Colors.white : StationColors.textDark,
        ),
      ),
    );
  }
}
