import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../core/formatting/date_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../models/shift.dart';
import '../../services/station_state_provider.dart';
import '../staff/widgets/cash_handover_workflow_card.dart';
import 'widgets/owner_ai_analytics_panel.dart';
import '../common/pagination_control.dart';
import 'daily_report_screen.dart';

enum _OverviewSection { summary, operations, insights, team, reports }

class StationOverviewScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const StationOverviewScreen({super.key, required this.onNavigate});

  @override
  State<StationOverviewScreen> createState() => _StationOverviewScreenState();
}

class _StationOverviewScreenState extends State<StationOverviewScreen> {
  _OverviewSection _section = _OverviewSection.summary;
  final _sectionKeys = {
    for (final section in _OverviewSection.values) section: GlobalKey(),
  };
  int _approvalPage = 1,
      _reviewPage = 1,
      _pumpPage = 1,
      _shiftPage = 1,
      _teamPage = 1;
  Function(int) get onNavigate => widget.onNavigate;

  int _boundedPage(int page, int total) =>
      page.clamp(1, total == 0 ? 1 : (total / 10).ceil());
  List<T> _pageItems<T>(List<T> items, int page) =>
      items.skip((_boundedPage(page, items.length) - 1) * 10).take(10).toList();

  void _selectSection(_OverviewSection section) {
    setState(() {
      _section = section;
      _approvalPage = _reviewPage = _pumpPage = _shiftPage = _teamPage = 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tabContext = _sectionKeys[section]?.currentContext;
      if (mounted && tabContext != null) {
        Scrollable.ensureVisible(
          tabContext,
          alignment: 0.5,
          duration: MediaQuery.of(tabContext).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 200),
        );
      }
    });
  }

  Future<void> _openMap(double lat, double lon) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lon',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final isOwner = state.currentUser.hasOwnerPrivileges;
    final pendingUsers = state.pendingApprovalUsers;
    final sections = <_OverviewSection>[
      _OverviewSection.summary,
      _OverviewSection.operations,
      if (isOwner) _OverviewSection.insights,
      if (state.canAccessScreen('people_management')) _OverviewSection.team,
      if (state.canAccessScreen('daily_report')) _OverviewSection.reports,
    ];
    final section = sections.contains(_section)
        ? _section
        : _OverviewSection.summary;

    // Authoritative Day Calculation for Today (immediate live updates on scan / approval)
    final dayCalc = state.getDayCalculation(DateTime.now());

    // 1. Dynamic Pending Review Shifts Count (scoped to Today)
    final activeVisibleShifts = state.getVisibleShiftsForDate(DateTime.now());
    final reviewShifts = activeVisibleShifts
        .where((s) => s.status == ShiftStatus.needsReview)
        .toList();

    // 2. Dynamic Owner Cash Received Calculation (scoped to Today: Paid to Owner entries or Shift Handover)
    int ownerCashPaise = dayCalc.cashGivenToOwnerPaise;
    if (ownerCashPaise == 0) {
      for (var s in activeVisibleShifts) {
        ownerCashPaise += state.getShiftHandoverToOwnerPaise(
          s,
          date: DateTime.now(),
        );
      }
    }

    // 3. Dynamic Credit Outstanding Balance Calculation (authoritative CreditCustomer balances)
    int totalCreditPaise = 0;
    for (var c in state.creditCustomers) {
      totalCreditPaise += c.pendingAmountPaise;
    }

    return LayoutBuilder(
      builder: (context, screenConstraints) {
        final bool isMobile = screenConstraints.maxWidth < 600;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 14 : 20,
                16,
                isMobile ? 14 : 20,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Responsive Header
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.get('stationOverview', lang),
                            style: TextStyle(
                              fontSize: isMobile ? 22 : 24,
                              fontWeight: FontWeight.w800,
                              color: StationColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormatter.formatDisplayDate(DateTime.now()),
                            style: const TextStyle(
                              fontSize: 13,
                              color: StationColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                      if (sections.contains(_OverviewSection.reports))
                        OutlinedButton.icon(
                          icon: const Icon(Icons.analytics_outlined, size: 16),
                          label: const Text(
                            'Full Daily Report',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: StationColors.primary,
                            side: const BorderSide(
                              color: StationColors.primary,
                            ),
                            minimumSize: const Size(44, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () =>
                              onNavigate(8), // Navigate to Daily Report tab
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    height: 52,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: sections
                            .map(
                              (item) => Padding(
                                key: _sectionKeys[item],
                                padding: const EdgeInsets.only(right: 8),
                                child: OutlinedButton.icon(
                                  key: ValueKey(
                                    'overview-section-${item.name}',
                                  ),
                                  onPressed: () => _selectSection(item),
                                  icon: Icon(_sectionIcon(item), size: 18),
                                  label: Text(_sectionLabel(item, lang)),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(44, 44),
                                    foregroundColor: item == section
                                        ? Colors.white
                                        : StationColors.primary,
                                    backgroundColor: item == section
                                        ? StationColors.primary
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Expanded(
              child: section == _OverviewSection.reports
                  ? const DailyReportScreen()
                  : SingleChildScrollView(
                      key: ValueKey('overview-content-${section.name}'),
                      padding: EdgeInsets.all(isMobile ? 14 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (section == _OverviewSection.summary) ...[
                            // 4 Responsive Stat Cards: Fuel Sales, Fuel Litres Dispensed, Owner Cash, Credit Balance
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth > 850;
                                final double cardSpacing = 12;

                                final card1 = _buildStatCard(
                                  title: 'Fuel Sales (To Receive)',
                                  amount: CurrencyFormatter.formatPaise(
                                    dayCalc.totalFuelSalesPaise,
                                  ),
                                  subtitle:
                                      '${dayCalc.totalNetLitres.toStringAsFixed(1)} L net (MS: ${dayCalc.totalMsLitres.toStringAsFixed(1)}L, HSD: ${dayCalc.totalHsdLitres.toStringAsFixed(1)}L)',
                                  icon: Icons.local_gas_station_rounded,
                                  iconColor: StationColors.accentOrange,
                                  onTap: () => onNavigate(8), // Daily report
                                );

                                final card2 = _buildStatCard(
                                  title: 'Total Fuel Dispensed',
                                  amount:
                                      '${dayCalc.totalNetLitres.toStringAsFixed(1)} L',
                                  subtitle:
                                      'Gross: ${dayCalc.totalGrossLitres.toStringAsFixed(1)} L (-${dayCalc.totalTestLitres.toStringAsFixed(1)}L daily test)',
                                  icon: Icons.water_drop_outlined,
                                  iconColor: StationColors.primary,
                                  onTap: () => onNavigate(8), // Daily report
                                );

                                final card3 = _buildStatCard(
                                  title: AppStrings.get(
                                    'ownerCashReceived',
                                    lang,
                                  ),
                                  amount: CurrencyFormatter.formatPaise(
                                    ownerCashPaise,
                                  ),
                                  subtitle: ownerCashPaise > 0
                                      ? 'Today handover recorded'
                                      : 'Awaiting cash handover',
                                  icon: Icons.account_balance_wallet_outlined,
                                  iconColor: StationColors.successGreen,
                                  onTap: () => onNavigate(3), // Money ledger
                                );

                                final card4 = _buildStatCard(
                                  title: AppStrings.get('creditBalance', lang),
                                  amount: CurrencyFormatter.formatPaise(
                                    totalCreditPaise,
                                  ),
                                  subtitle: totalCreditPaise > 0
                                      ? 'Outstanding Khata'
                                      : 'Zero credit balance',
                                  icon: Icons.credit_score_outlined,
                                  iconColor: StationColors.creditTeal,
                                  onTap: () => onNavigate(4), // Credit tab
                                );

                                if (isWide) {
                                  return Row(
                                    children: [
                                      Expanded(child: card1),
                                      SizedBox(width: cardSpacing),
                                      Expanded(child: card2),
                                      SizedBox(width: cardSpacing),
                                      Expanded(child: card3),
                                      SizedBox(width: cardSpacing),
                                      Expanded(child: card4),
                                    ],
                                  );
                                }

                                // Mobile 2x2 grid
                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: card1),
                                        SizedBox(width: cardSpacing),
                                        Expanded(child: card2),
                                      ],
                                    ),
                                    SizedBox(height: cardSpacing),
                                    Row(
                                      children: [
                                        Expanded(child: card3),
                                        SizedBox(width: cardSpacing),
                                        Expanded(child: card4),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 24),

                            if (reviewShifts.isNotEmpty)
                              _summaryAction(
                                'Shift reviews',
                                '${reviewShifts.length} shifts need review',
                                Icons.fact_check_outlined,
                                () =>
                                    _selectSection(_OverviewSection.operations),
                              ),
                            if (pendingUsers.isNotEmpty &&
                                sections.contains(_OverviewSection.team))
                              _summaryAction(
                                'User approvals',
                                '${pendingUsers.length} people await approval',
                                Icons.person_add_outlined,
                                () => _selectSection(_OverviewSection.team),
                              ),
                            _summaryAction(
                              'Operations',
                              'Meter readings, shifts, receipts and cash handovers',
                              Icons.local_gas_station_outlined,
                              () => _selectSection(_OverviewSection.operations),
                            ),
                            if (sections.contains(_OverviewSection.insights))
                              _summaryAction(
                                'AI Insights',
                                'Sales trends, payment mix and growth suggestions',
                                Icons.auto_awesome_outlined,
                                () => _selectSection(_OverviewSection.insights),
                              ),
                            if (sections.contains(_OverviewSection.team))
                              _summaryAction(
                                'Team',
                                'Users, app versions and shift location status',
                                Icons.people_outline,
                                () => _selectSection(_OverviewSection.team),
                              ),
                            if (sections.contains(_OverviewSection.reports))
                              _summaryAction(
                                'Reports',
                                'Daily fuel and cash reconciliation',
                                Icons.assessment_outlined,
                                () => _selectSection(_OverviewSection.reports),
                              ),
                          ],
                          if (section == _OverviewSection.operations) ...[
                            // Dynamic Status Banner: Pending Shift Approval Requests vs All Reconciled
                            if (reviewShifts.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: StationColors.warningBg,
                                  borderRadius: BorderRadius.circular(
                                    StationDimensions.cardRadius,
                                  ),
                                  border: Border.all(
                                    color: StationColors.warningBorder,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.notification_important_rounded,
                                          color: StationColors.warningAmber,
                                          size: 26,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Shift Approval Request (${reviewShifts.length} Pending)',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                  color: StationColors
                                                      .warningAmber,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                'Tap a shift request below to review reconciliation details and approve cash handover.',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      StationColors.textMedium,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!isMobile)
                                          ElevatedButton.icon(
                                            icon: const Icon(
                                              Icons.arrow_forward,
                                              size: 15,
                                              color: Colors.white,
                                            ),
                                            label: Text(
                                              AppStrings.get(
                                                'reviewShifts',
                                                lang,
                                              ),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  StationColors.accentOrange,
                                              elevation: 0,
                                              minimumSize: const Size(44, 44),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 10,
                                                  ),
                                            ),
                                            onPressed: () {
                                              state.selectShiftForReview(
                                                reviewShifts.first.id,
                                              );
                                              onNavigate(2);
                                            },
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ..._pageItems(
                                      reviewShifts,
                                      _reviewPage,
                                    ).map((s) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: InkWell(
                                          onTap: () {
                                            state.selectShiftForReview(s.id);
                                            onNavigate(
                                              2,
                                            ); // Navigate to ShiftReviewScreen with shift selected
                                          },
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color:
                                                    StationColors.warningBorder,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: StationColors
                                                        .accentOrangeLight,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons
                                                        .assignment_turned_in_outlined,
                                                    color: StationColors
                                                        .accentOrange,
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        '${s.shiftName} Shift • ${s.staffName} (${s.pumpName})',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                          color: StationColors
                                                              .textDark,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Handover: ${s.formattedHandover} to ${s.handoverReceiver}${s.handoverTime != null ? " • ${DateFormatter.formatTimeIST(s.handoverTime!)}" : ""}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: StationColors
                                                              .accentOrange,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        StationColors.primary,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      if (!isMobile)
                                                        Text(
                                                          'Approve / Review',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      SizedBox(width: 4),
                                                      Icon(
                                                        Icons.chevron_right,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: StationColors.successBg,
                                  borderRadius: BorderRadius.circular(
                                    StationDimensions.cardRadius,
                                  ),
                                  border: Border.all(
                                    color: StationColors.successGreen
                                        .withOpacity(0.3),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: StationColors.successGreen,
                                      size: 24,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'All shifts reconciled & operational',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: StationColors.successGreen,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Meter totalisers and cash handovers tracked live in real time.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: StationColors.textMedium,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (reviewShifts.length > 10) ...[
                              const SizedBox(height: 12),
                              PaginationControl(
                                currentPage: _boundedPage(
                                  _reviewPage,
                                  reviewShifts.length,
                                ),
                                totalItems: reviewShifts.length,
                                onPageChanged: (page) =>
                                    setState(() => _reviewPage = page),
                              ),
                            ],
                            if (state
                                    .incomingPendingHandoversForCurrentUser
                                    .isNotEmpty ||
                                state.cashHandovers.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const CashHandoverWorkflowCard(),
                            ],
                            const SizedBox(height: 18),

                            // =========================================================================
                            // LIVE DISPENSER METER READINGS & FUEL SALES BREAKDOWN (ALL PUMPS & NOZZLES)
                            // =========================================================================
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Today's Dispenser Meter Readings & Fuel Sales",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: StationColors.textDark,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Multi-pump live sales (Closing - Opening - 5L Test × Fuel Rate)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: StationColors.textMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => onNavigate(1), // Receipts inbox
                                  borderRadius: BorderRadius.circular(6),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.camera_alt_outlined,
                                          size: 16,
                                          color: StationColors.primary,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Receipts',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: StationColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // For each pump, render an individual dispenser card with all nozzles
                            if (dayCalc.pumpResults.isEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    StationDimensions.cardRadius,
                                  ),
                                  border: Border.all(
                                    color: StationColors.divider,
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    'No pumps configured yet. Add pumps in Pump Setup.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ),
                            ] else ...[
                              ..._pageItems(dayCalc.pumpResults, _pumpPage).map(
                                (pResult) => _buildPumpCard(context, pResult),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Grand Total Station Summary Banner
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0F2B48),
                                    Color(0xFF1E3A8A),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(
                                  StationDimensions.cardRadius,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth > 850;
                                  final content = [
                                    _buildSummaryPill(
                                      'Petrol (MS)',
                                      '${dayCalc.totalMsLitres.toStringAsFixed(2)} L',
                                      Colors.amberAccent,
                                    ),
                                    _buildSummaryPill(
                                      'Diesel (HSD)',
                                      '${dayCalc.totalHsdLitres.toStringAsFixed(2)} L',
                                      Colors.lightBlueAccent,
                                    ),
                                    _buildSummaryPill(
                                      'Total Net Sold',
                                      '${dayCalc.totalNetLitres.toStringAsFixed(2)} L',
                                      Colors.white,
                                    ),
                                    _buildSummaryPill(
                                      'Amount to Receive',
                                      CurrencyFormatter.formatPaise(
                                        dayCalc.totalFuelSalesPaise,
                                      ),
                                      const Color(0xFF4ADE80),
                                      isLarge: true,
                                    ),
                                  ];

                                  if (isWide) {
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: content
                                          .map((c) => Expanded(child: c))
                                          .toList(),
                                    );
                                  }

                                  return Wrap(
                                    spacing: 16,
                                    runSpacing: 12,
                                    alignment: WrapAlignment.spaceBetween,
                                    children: content,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 28),

                            if (dayCalc.pumpResults.length > 10) ...[
                              const SizedBox(height: 12),
                              PaginationControl(
                                currentPage: _boundedPage(
                                  _pumpPage,
                                  dayCalc.pumpResults.length,
                                ),
                                totalItems: dayCalc.pumpResults.length,
                                onPageChanged: (page) =>
                                    setState(() => _pumpPage = page),
                              ),
                            ],
                            // Today's Shifts (Mobile cards or Desktop table — only logged-in / active / submitted shifts)
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Text(
                                  AppStrings.get('todaysShifts', lang),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: StationColors.textDark,
                                  ),
                                ),
                                if (activeVisibleShifts.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: () => onNavigate(2),
                                    icon: const Icon(
                                      Icons.assignment_outlined,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Review All Shifts →',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (activeVisibleShifts.isEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    StationDimensions.cardRadius,
                                  ),
                                  border: Border.all(
                                    color: StationColors.divider,
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.schedule_outlined,
                                      color: StationColors.textLight,
                                      size: 22,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'No active shifts in progress yet — shift details appear automatically when an assigned staff member logs in.',
                                        style: TextStyle(
                                          color: StationColors.textMedium,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (isMobile) ...[
                              ..._pageItems(
                                activeVisibleShifts,
                                _shiftPage,
                              ).map((s) {
                                Color statusColor =
                                    s.status == ShiftStatus.approved
                                    ? StationColors.successGreen
                                    : s.status == ShiftStatus.inProgress
                                    ? StationColors.primary
                                    : s.status == ShiftStatus.needsReview
                                    ? StationColors.warningAmber
                                    : StationColors.textLight;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: InkWell(
                                    onTap: () {
                                      state.selectShiftForReview(s.id);
                                      onNavigate(2);
                                    },
                                    borderRadius: BorderRadius.circular(
                                      StationDimensions.cardRadius,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          StationDimensions.cardRadius,
                                        ),
                                        border: Border.all(
                                          color:
                                              s.status ==
                                                  ShiftStatus.needsReview
                                              ? StationColors.warningBorder
                                              : StationColors.divider,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              s.status == ShiftStatus.approved
                                                  ? Icons.verified_rounded
                                                  : s.status ==
                                                        ShiftStatus.needsReview
                                                  ? Icons
                                                        .pending_actions_rounded
                                                  : Icons.schedule,
                                              color: statusColor,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${s.shiftName} (${s.pumpName})',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Builder(
                                                  builder: (_) {
                                                    final handoverPaise = state
                                                        .getShiftHandoverToOwnerPaise(
                                                          s,
                                                          date: DateTime.now(),
                                                        );
                                                    return Text(
                                                      '${s.staffName} · ${s.timeRange}${handoverPaise > 0 ? " · Handover: ${CurrencyFormatter.formatPaise(handoverPaise)}" : ""}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: StationColors
                                                            .textMedium,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(
                                                0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: statusColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  s.status.displayName,
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.chevron_right,
                                            size: 18,
                                            color: StationColors.textLight,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ] else ...[
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    StationDimensions.cardRadius,
                                  ),
                                  border: Border.all(
                                    color: StationColors.divider,
                                  ),
                                ),
                                child: Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(1.2),
                                    1: FlexColumnWidth(1.5),
                                    2: FlexColumnWidth(2),
                                    3: FlexColumnWidth(1.8),
                                  },
                                  children: [
                                    _buildTableHeader([
                                      'Shift',
                                      'Staff',
                                      'Time / Handover',
                                      'Status (Tap to Review)',
                                    ]),
                                    ..._pageItems(
                                      activeVisibleShifts,
                                      _shiftPage,
                                    ).map((s) {
                                      Color statusColor =
                                          s.status == ShiftStatus.approved
                                          ? StationColors.successGreen
                                          : s.status == ShiftStatus.inProgress
                                          ? StationColors.primary
                                          : s.status == ShiftStatus.needsReview
                                          ? StationColors.warningAmber
                                          : StationColors.textLight;
                                      return _buildShiftRow(
                                        '${s.shiftName} (${s.pumpName})',
                                        s.staffName,
                                        s.cashHandoverPaise > 0
                                            ? '${s.timeRange} • Handover: ${s.formattedHandover}'
                                            : s.timeRange,
                                        s.status.displayName,
                                        statusColor,
                                        onTap: () {
                                          state.selectShiftForReview(s.id);
                                          onNavigate(2);
                                        },
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),

                            if (activeVisibleShifts.length > 10) ...[
                              const SizedBox(height: 12),
                              PaginationControl(
                                currentPage: _boundedPage(
                                  _shiftPage,
                                  activeVisibleShifts.length,
                                ),
                                totalItems: activeVisibleShifts.length,
                                onPageChanged: (page) =>
                                    setState(() => _shiftPage = page),
                              ),
                            ],
                            // Latest Receipt Strip
                            Text(
                              AppStrings.get('latestReceipt', lang),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: StationColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () => onNavigate(1), // Receipts tab
                              borderRadius: BorderRadius.circular(
                                StationDimensions.cardRadius,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    StationDimensions.cardRadius,
                                  ),
                                  border: Border.all(
                                    color: StationColors.divider,
                                  ),
                                ),
                                child: isMobile
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.receipt_long,
                                                color: StationColors.primary,
                                                size: 22,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  state.receipts.isNotEmpty
                                                      ? 'Latest Slip'
                                                      : 'No Slips Yet',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color:
                                                        StationColors.textDark,
                                                  ),
                                                ),
                                              ),
                                              const Icon(
                                                Icons.chevron_right,
                                                color: StationColors.textMedium,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            state.receipts.isNotEmpty
                                                ? 'Pump ${state.receipts.first.fpId} • ${state.receipts.first.printedDate} ${state.receipts.first.printedTime} • ${state.receipts.first.capturedBy}'
                                                : 'No receipts uploaded yet today • Tap to review',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: StationColors.textMedium,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          const Icon(
                                            Icons.receipt_long,
                                            color: StationColors.textMedium,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              state.receipts.isNotEmpty
                                                  ? 'Pump ${state.receipts.first.fpId} • ${state.receipts.first.printedDate} ${state.receipts.first.printedTime} • Captured by ${state.receipts.first.capturedBy}'
                                                  : 'No receipts uploaded yet today • Awaiting forecourt staff entries',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: StationColors.textDark,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                onNavigate(1), // Receipts tab
                                            child: const Text(
                                              'View receipts →',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (section == _OverviewSection.insights &&
                              isOwner) ...[
                            // =========================================================================
                            // OWNER-ONLY MINIMALISTIC AI SALES ANALYTICS, WEEKLY/MONTHLY GRAPHS, PIE CHARTS & TIPS
                            // =========================================================================
                            if (isOwner) ...[
                              OwnerAiAnalyticsPanel(
                                state: state,
                                onNavigate: onNavigate,
                              ),
                              const SizedBox(height: 24),
                            ],
                          ],
                          if (section == _OverviewSection.team &&
                              sections.contains(_OverviewSection.team)) ...[
                            // Pending User Approvals Banner (Manager-added/edited users awaiting Owner approval)
                            if (pendingUsers.isNotEmpty) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(
                                    StationDimensions.cardRadius,
                                  ),
                                  border: Border.all(
                                    color: Colors.orange.shade400,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.how_to_reg_rounded,
                                          color: Colors.orange.shade900,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'User Approval Request (${pendingUsers.length} Pending)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: Colors.orange.shade900,
                                            ),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () =>
                                              onNavigate(5), // People & Roles
                                          icon: const Icon(
                                            Icons.people_outline,
                                            size: 15,
                                          ),
                                          label: const Text(
                                            'Open People & Roles →',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ..._pageItems(
                                      pendingUsers,
                                      _approvalPage,
                                    ).map(
                                      (pu) => Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.orange.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${pu.name} (${pu.role.displayName}) • Requested by ${pu.requestedBy ?? "Manager"}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            if (isOwner) ...[
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: StationColors
                                                      .successGreen,
                                                  minimumSize: const Size(
                                                    76,
                                                    44,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                      ),
                                                ),
                                                onPressed: () {
                                                  state.approveUserRequest(
                                                    pu.id,
                                                  );
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Approved user "${pu.name}"!',
                                                      ),
                                                      backgroundColor:
                                                          StationColors
                                                              .successGreen,
                                                    ),
                                                  );
                                                },
                                                child: const Text(
                                                  'Approve',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(
                                                    color:
                                                        StationColors.errorRed,
                                                  ),
                                                  minimumSize: const Size(
                                                    68,
                                                    44,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                      ),
                                                ),
                                                onPressed: () => state
                                                    .rejectUserRequest(pu.id),
                                                child: const Text(
                                                  'Reject',
                                                  style: TextStyle(
                                                    color:
                                                        StationColors.errorRed,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            if (pendingUsers.length > 10) ...[
                              const SizedBox(height: 12),
                              PaginationControl(
                                currentPage: _boundedPage(
                                  _approvalPage,
                                  pendingUsers.length,
                                ),
                                totalItems: pendingUsers.length,
                                onPageChanged: (page) =>
                                    setState(() => _approvalPage = page),
                              ),
                            ],
                            // Team App Versions & Live Location Tracker (Updated Every 1 Minute)
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                const Text.rich(
                                  TextSpan(
                                    children: [
                                      WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: Padding(
                                          padding: EdgeInsets.only(right: 6),
                                          child: Icon(
                                            Icons.my_location_rounded,
                                            size: 18,
                                            color: StationColors.primary,
                                          ),
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            'Team App Versions & Live Location (1m Sync)',
                                      ),
                                    ],
                                  ),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: StationColors.textDark,
                                  ),
                                ),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (state
                                        .settings
                                        .enableLiveLocationTracking)
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          state.refreshCurrentUserLocation(
                                            allowOutsideShift: true,
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Live GPS location synchronized for current device!',
                                              ),
                                              backgroundColor:
                                                  StationColors.successGreen,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.gps_fixed_rounded,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          'Sync GPS Now',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(44, 36),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                        ),
                                      ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          onNavigate(5), // People & Roles
                                      icon: const Icon(
                                        Icons.people_outline,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Manage People →',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  StationDimensions.cardRadius,
                                ),
                                border: Border.all(
                                  color: StationColors.divider,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!state
                                      .settings
                                      .enableLiveLocationTracking)
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.amber.shade200,
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.location_off_outlined,
                                            size: 16,
                                            color: Colors.deepOrange,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Live location tracking feature flag is currently disabled in Station Settings.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.deepOrange,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 10,
                                    children: _pageItems(state.allUsers, _teamPage).map((
                                      u,
                                    ) {
                                      final isOnline = state.isUserOnline(u.id);
                                      final isSelf = state.isSelfUser(u);
                                      final verLabel = u.appVersion.isNotEmpty
                                          ? u.appVersion
                                          : 'Not logged in yet';
                                      final hasLoc =
                                          state
                                              .settings
                                              .enableLiveLocationTracking &&
                                          u.lastLatitude != null &&
                                          u.lastLongitude != null;
                                      final atStation = u.isAtStation ?? true;
                                      final shiftActive = state
                                          .isUserShiftInProgress(u);
                                      final locName = hasLoc
                                          ? state.resolveUserLocationName(u)
                                          : '';

                                      return Container(
                                        width: isMobile ? double.infinity : 290,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: u.isPendingApproval
                                                ? Colors.orange.shade300
                                                : (isSelf
                                                      ? StationColors.primary
                                                            .withOpacity(0.55)
                                                      : StationColors.divider),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: StationColors
                                                  .primary
                                                  .withOpacity(0.12),
                                              child: Text(
                                                u.name.isNotEmpty
                                                    ? u.name[0]
                                                    : 'U',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: StationColors.primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          isSelf
                                                              ? '${u.name} (Self)'
                                                              : u.name,
                                                          style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13,
                                                            color: StationColors
                                                                .textDark,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      if (isSelf) ...[
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 1,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: StationColors
                                                                .primary,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          child: const Text(
                                                            'Self',
                                                            style: TextStyle(
                                                              fontSize: 9,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                      const SizedBox(width: 6),
                                                      if (isOnline)
                                                        Container(
                                                          width: 7,
                                                          height: 7,
                                                          decoration:
                                                              const BoxDecoration(
                                                                color: StationColors
                                                                    .successGreen,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${u.role.displayName}${u.assignedShift != null ? " • ${u.assignedShift} (${shiftActive ? "Shift Active" : "Shift Closed"})" : ""}${u.isPendingApproval ? " • Pending Approval" : ""}',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: StationColors
                                                          .textMedium,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 5),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 4,
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              u
                                                                  .appVersion
                                                                  .isNotEmpty
                                                              ? StationColors
                                                                    .primary
                                                                    .withOpacity(
                                                                      0.1,
                                                                    )
                                                              : Colors.orange
                                                                    .withOpacity(
                                                                      0.12,
                                                                    ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          'App: $verLabel',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                u
                                                                    .appVersion
                                                                    .isNotEmpty
                                                                ? StationColors
                                                                      .primary
                                                                : StationColors
                                                                      .accentOrange,
                                                          ),
                                                        ),
                                                      ),
                                                      if (hasLoc)
                                                        InkWell(
                                                          onTap: () => _openMap(
                                                            u.lastLatitude!,
                                                            u.lastLongitude!,
                                                          ),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 2,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: atStation
                                                                  ? Colors.teal
                                                                        .withOpacity(
                                                                          0.12,
                                                                        )
                                                                  : Colors
                                                                        .deepOrange
                                                                        .withOpacity(
                                                                          0.12,
                                                                        ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    4,
                                                                  ),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .location_on_rounded,
                                                                  size: 11,
                                                                  color:
                                                                      atStation
                                                                      ? Colors
                                                                            .teal[800]
                                                                      : Colors
                                                                            .deepOrange[800],
                                                                ),
                                                                const SizedBox(
                                                                  width: 2,
                                                                ),
                                                                Text(
                                                                  '${atStation ? "At Station" : "Outside"} (${(u.lastDistanceMeters ?? 0).toStringAsFixed(1)}m)',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color:
                                                                        atStation
                                                                        ? Colors
                                                                              .teal[900]
                                                                        : Colors
                                                                              .deepOrange[900],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  if (hasLoc) ...[
                                                    const SizedBox(height: 4),
                                                    InkWell(
                                                      onTap: () => _openMap(
                                                        u.lastLatitude!,
                                                        u.lastLongitude!,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 2,
                                                            ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .map_outlined,
                                                              size: 12,
                                                              color:
                                                                  StationColors
                                                                      .primary,
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Flexible(
                                                              child: Text(
                                                                '$locName (${u.lastLatitude!.toStringAsFixed(4)}°N, ${u.lastLongitude!.toStringAsFixed(4)}°E)${u.locationUpdatedAt != null ? " • ${DateFormatter.formatTimeIST(u.locationUpdatedAt!)}" : ""} • Open Map ↗',
                                                                style: const TextStyle(
                                                                  fontSize:
                                                                      10.5,
                                                                  color: StationColors
                                                                      .primary,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  decoration:
                                                                      TextDecoration
                                                                          .underline,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (state.allUsers.length > 10) ...[
                              const SizedBox(height: 12),
                              PaginationControl(
                                currentPage: _boundedPage(
                                  _teamPage,
                                  state.allUsers.length,
                                ),
                                totalItems: state.allUsers.length,
                                onPageChanged: (page) =>
                                    setState(() => _teamPage = page),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  String _sectionLabel(_OverviewSection section, String lang) {
    final english = ['Summary', 'Operations', 'AI Insights', 'Team', 'Reports'];
    final telugu = [
      'సారాంశం',
      'కార్యకలాపాలు',
      'AI సూచనలు',
      'సిబ్బంది',
      'నివేదికలు',
    ];
    return (lang == 'te' ? telugu : english)[section.index];
  }

  IconData _sectionIcon(_OverviewSection section) => const [
    Icons.dashboard_outlined,
    Icons.local_gas_station_outlined,
    Icons.auto_awesome_outlined,
    Icons.people_outline,
    Icons.assessment_outlined,
  ][section.index];

  Widget _summaryAction(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          minVerticalPadding: 12,
          leading: Icon(icon, color: StationColors.primary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildPumpCard(
    BuildContext context,
    PumpDayCalculationResult pResult,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
        border: Border.all(color: StationColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pump Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(StationDimensions.cardRadius),
              ),
              border: Border(bottom: BorderSide(color: StationColors.divider)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: StationColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.local_gas_station,
                          size: 18,
                          color: StationColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pResult.pump.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: StationColors.textDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'S/N: ${pResult.pump.serialNumber} • Attendant: ${pResult.staffName}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: StationColors.textMedium,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: StationColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: StationColors.primary.withOpacity(0.25),
                    ),
                  ),
                  child: Text(
                    'Fuel Total: ${CurrencyFormatter.formatPaise(pResult.totalFuelSalesPaise)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: StationColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Nozzle Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(
                const Color(0xFFFBFBFB),
              ),
              dataRowMinHeight: 44,
              horizontalMargin: 14,
              columnSpacing: 18,
              columns: const [
                DataColumn(
                  label: Text(
                    'Nozzle',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Product',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Opening (L)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Closing (L)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Gross (L)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Test (-5 L)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Net Sold (L)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Rate',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Amount to Receive',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
              rows: pResult.nozzleResults.map((n) {
                final isPetrol =
                    n.fuelType.toLowerCase().contains('petrol') ||
                    n.fuelType.toLowerCase().contains('ms');
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        'N${n.nozzleNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isPetrol
                              ? Colors.orange.withOpacity(0.12)
                              : Colors.blue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          n.fuelType,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isPetrol
                                ? StationColors.accentOrange
                                : Colors.blue[800],
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        (n.openingReadingMl / 1000).toStringAsFixed(2),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    DataCell(
                      Text(
                        (n.closingReadingMl / 1000).toStringAsFixed(2),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    DataCell(
                      Text(
                        (n.grossVolumeMl / 1000).toStringAsFixed(2),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    DataCell(
                      Text(
                        '-${(n.testVolumeMl / 1000).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: StationColors.errorRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        (n.billableVolumeMl / 1000).toStringAsFixed(2),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: StationColors.textDark,
                        ),
                      ),
                    ),
                    DataCell(
                      n.hasPriceChange
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.bolt,
                                      size: 12,
                                      color: Colors.orange,
                                    ),
                                    Text(
                                      '${CurrencyFormatter.formatPaise(n.segments.first.ratePaisePerLitre)} → ${CurrencyFormatter.formatPaise(n.segments.last.ratePaisePerLitre)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${n.segments.length} price tiers',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: StationColors.textLight,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              CurrencyFormatter.formatPaise(
                                n.ratePaisePerLitre,
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                    ),
                    DataCell(
                      Text(
                        CurrencyFormatter.formatPaise(n.fuelSalesPaise),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: StationColors.primary,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),

          if (pResult.nozzleResults.any((n) => n.hasPriceChange)) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              padding: const EdgeInsets.all(10),
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
                      Icon(Icons.bolt, size: 15, color: Colors.orange),
                      SizedBox(width: 6),
                      Text(
                        'Mid-Day Fuel Price Change Applied:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...pResult.nozzleResults.where((n) => n.hasPriceChange).map((
                    n,
                  ) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• Nozzle ${n.nozzleNumber} (${n.fuelType}):',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: StationColors.textDark,
                          ),
                        ),
                        ...n.segments.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final seg = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(left: 10, top: 2),
                            child: Text(
                              'Segment $idx: ${seg.billableLitres.toStringAsFixed(2)} L net @ ₹${seg.rateRupees.toStringAsFixed(2)}/L = ${CurrencyFormatter.formatPaise(seg.amountPaise)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: StationColors.textMedium,
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],

          // Pump Footer Subtotal Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(StationDimensions.cardRadius),
              ),
              border: Border(top: BorderSide(color: StationColors.divider)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${pResult.pump.name} Subtotal: ${pResult.totalNetLitres.toStringAsFixed(2)} L (MS: ${pResult.msLitres.toStringAsFixed(2)}L, HSD: ${pResult.hsdLitres.toStringAsFixed(2)}L)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: StationColors.textMedium,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  CurrencyFormatter.formatPaise(pResult.totalFuelSalesPaise),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: StationColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPill(
    String title,
    String value,
    Color valueColor, {
    bool isLarge = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isLarge ? 12 : 11,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 18 : 15,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
          border: Border.all(color: StationColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 19),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: StationColors.textMedium,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: StationColors.textDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.3,
                color: StationColors.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableHeader(List<String> headers) {
    return TableRow(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F9F9),
        border: Border(bottom: BorderSide(color: StationColors.divider)),
      ),
      children: headers
          .map(
            (h) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                h,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: StationColors.textMedium,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  TableRow _buildShiftRow(
    String shift,
    String staff,
    String time,
    String status,
    Color statusColor, {
    VoidCallback? onTap,
  }) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: StationColors.divider)),
      ),
      children: [
        TableRowInkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Text(
              shift,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
        TableRowInkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Text(staff, style: const TextStyle(fontSize: 14)),
          ),
        ),
        TableRowInkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 13,
                color: StationColors.textMedium,
              ),
            ),
          ),
        ),
        TableRowInkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: StationColors.textLight,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
