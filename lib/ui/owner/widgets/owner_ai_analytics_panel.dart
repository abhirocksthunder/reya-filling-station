import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/formatting/currency_formatter.dart';
import '../../../core/formatting/date_formatter.dart';
import '../../../services/station_state_provider.dart';

enum OwnerAnalyticsPeriod {
  today,
  weekly,
  monthly;

  String get label {
    switch (this) {
      case OwnerAnalyticsPeriod.today:
        return 'Today';
      case OwnerAnalyticsPeriod.weekly:
        return 'Weekly (7D)';
      case OwnerAnalyticsPeriod.monthly:
        return 'Monthly (30D)';
    }
  }
}

class PeriodTrendPoint {
  final String label;
  final String fullDateLabel;
  final int totalSalesPaise;
  final int petrolSalesPaise;
  final int dieselSalesPaise;
  final double petrolLitres;
  final double dieselLitres;

  const PeriodTrendPoint({
    required this.label,
    required this.fullDateLabel,
    required this.totalSalesPaise,
    required this.petrolSalesPaise,
    required this.dieselSalesPaise,
    required this.petrolLitres,
    required this.dieselLitres,
  });

  double get totalLitres => petrolLitres + dieselLitres;
}

class PeriodAnalyticsBundle {
  final OwnerAnalyticsPeriod period;
  final int totalFuelSalesPaise;
  final int petrolFuelSalesPaise;
  final int dieselFuelSalesPaise;
  final double totalNetLitres;
  final double totalMsLitres;
  final double totalHsdLitres;
  final int cashSalesPaise;
  final int phonePeSalesPaise;
  final int cardSalesPaise;
  final int creditSalesPaise;
  final int ownerHandoverPaise;
  final int expensesPaise;
  final double growthPercent;
  final bool hasData;
  final bool hasComparison;
  final List<PeriodTrendPoint> trendPoints;

  const PeriodAnalyticsBundle({
    required this.period,
    required this.totalFuelSalesPaise,
    required this.petrolFuelSalesPaise,
    required this.dieselFuelSalesPaise,
    required this.totalNetLitres,
    required this.totalMsLitres,
    required this.totalHsdLitres,
    required this.cashSalesPaise,
    required this.phonePeSalesPaise,
    required this.cardSalesPaise,
    required this.creditSalesPaise,
    required this.ownerHandoverPaise,
    required this.expensesPaise,
    required this.growthPercent,
    required this.hasData,
    required this.hasComparison,
    required this.trendPoints,
  });

  int get totalRecordedCollectionsPaise =>
      cashSalesPaise + phonePeSalesPaise + cardSalesPaise + creditSalesPaise;
}

class AiSalesGrowthTip {
  final String id;
  final String categoryTag;
  final String title;
  final String subtitle;
  final String impactBadge;
  final String dataEvidence;
  final List<String> actionSteps;
  final Color accentColor;
  final IconData heroIcon;
  final String
  visualSceneType; // 'fleet_diesel', 'morning_rush', 'upi_fastlane', 'khata_cycle'

  const AiSalesGrowthTip({
    required this.id,
    required this.categoryTag,
    required this.title,
    required this.subtitle,
    required this.impactBadge,
    required this.dataEvidence,
    required this.actionSteps,
    required this.accentColor,
    required this.heroIcon,
    required this.visualSceneType,
  });
}

class OwnerAiAnalyticsPanel extends StatefulWidget {
  final StationStateProvider state;
  final Function(int)? onNavigate;

  const OwnerAiAnalyticsPanel({
    super.key,
    required this.state,
    this.onNavigate,
  });

  @override
  State<OwnerAiAnalyticsPanel> createState() => _OwnerAiAnalyticsPanelState();
}

class _OwnerAiAnalyticsPanelState extends State<OwnerAiAnalyticsPanel>
    with SingleTickerProviderStateMixin {
  OwnerAnalyticsPeriod _selectedPeriod = OwnerAnalyticsPeriod.weekly;
  int _selectedBarIndex = -1;
  int _selectedTipCategoryIndex = 0;
  late final AnimationController _pulseController;

  static const List<String> _tipCategories = [
    'All AI Tips',
    'Diesel & Fleet',
    'Peak Hours',
    'UPI & Express',
    'Khata & Cashflow',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  PeriodAnalyticsBundle _computeAnalytics(OwnerAnalyticsPeriod period) {
    final now = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    final today = DateTime.utc(now.year, now.month, now.day);
    final days = period == OwnerAnalyticsPeriod.today
        ? 1
        : period == OwnerAnalyticsPeriod.weekly
        ? 7
        : 30;
    final points = <PeriodTrendPoint>[];
    int fuel = 0,
        cash = 0,
        upi = 0,
        card = 0,
        credit = 0,
        owner = 0,
        expenses = 0;
    double ms = 0, hsd = 0;
    int petrolRevenue = 0, dieselRevenue = 0;
    int previousFuel = 0;
    bool previousHasData = false;
    bool hasData = false;
    for (int offset = days - 1; offset >= 0; offset--) {
      final date = DateTime.utc(today.year, today.month, today.day - offset);
      final calc = widget.state.getDayCalculation(date);
      hasData = hasData || calc.hasData;
      fuel += calc.totalFuelSalesPaise;
      cash += calc.cashSalesPaise;
      upi += calc.phonePeSalesPaise;
      card += calc.cardSalesPaise;
      credit += calc.creditSalesPaise;
      owner += calc.cashGivenToOwnerPaise;
      expenses += calc.foodExpensesPaise + calc.otherExpensesPaise;
      ms += calc.totalMsLitres;
      hsd += calc.totalHsdLitres;
      int petrol = 0, diesel = 0;
      for (final nozzle in calc.allNozzleResults) {
        final type = nozzle.fuelType.toLowerCase();
        if (type.contains('petrol') || type.contains('ms')) {
          petrol += nozzle.fuelSalesPaise;
        } else {
          diesel += nozzle.fuelSalesPaise;
        }
      }
      petrolRevenue += petrol;
      dieselRevenue += diesel;
      final point = PeriodTrendPoint(
        label: offset == 0 ? 'Today' : '${date.day}/${date.month}',
        fullDateLabel: DateFormatter.formatDisplayDate(date),
        totalSalesPaise: calc.totalFuelSalesPaise,
        petrolSalesPaise: petrol,
        dieselSalesPaise: diesel,
        petrolLitres: calc.totalMsLitres,
        dieselLitres: calc.totalHsdLitres,
      );
      // Thirty actual daily records aggregate into five six-day chart buckets.
      if (days == 30 && points.isNotEmpty && (days - 1 - offset) % 6 != 0) {
        final old = points.removeLast();
        points.add(
          PeriodTrendPoint(
            label: old.label,
            fullDateLabel:
                '${old.fullDateLabel.split(' – ').first} – ${point.fullDateLabel}',
            totalSalesPaise: old.totalSalesPaise + point.totalSalesPaise,
            petrolSalesPaise: old.petrolSalesPaise + point.petrolSalesPaise,
            dieselSalesPaise: old.dieselSalesPaise + point.dieselSalesPaise,
            petrolLitres: old.petrolLitres + point.petrolLitres,
            dieselLitres: old.dieselLitres + point.dieselLitres,
          ),
        );
      } else {
        points.add(point);
      }
      final prior = widget.state.getDayCalculation(
        DateTime(date.year, date.month, date.day - days),
      );
      previousFuel += prior.totalFuelSalesPaise;
      previousHasData = previousHasData || prior.hasData;
    }
    return PeriodAnalyticsBundle(
      period: period,
      totalFuelSalesPaise: fuel,
      petrolFuelSalesPaise: petrolRevenue,
      dieselFuelSalesPaise: dieselRevenue,
      totalNetLitres: ms + hsd,
      totalMsLitres: ms,
      totalHsdLitres: hsd,
      cashSalesPaise: cash,
      phonePeSalesPaise: upi,
      cardSalesPaise: card,
      creditSalesPaise: credit,
      ownerHandoverPaise: owner,
      expensesPaise: expenses,
      growthPercent: previousHasData && previousFuel > 0
          ? (fuel - previousFuel) / previousFuel * 100
          : 0,
      hasComparison: previousHasData && previousFuel > 0,
      hasData:
          hasData ||
          widget.state.creditCustomers.any((c) => c.pendingAmountPaise > 0),
      trendPoints: points,
    );
  }

  List<AiSalesGrowthTip> _buildAiTips(PeriodAnalyticsBundle bundle) {
    final tips = <AiSalesGrowthTip>[];
    if (!bundle.hasData) return tips;
    if (bundle.totalHsdLitres > 0) {
      tips.add(
        AiSalesGrowthTip(
          id: 'diesel',
          categoryTag: 'Diesel & Fleet',
          title: 'Review diesel demand for this period',
          subtitle:
              'Diesel accounts for ${(bundle.totalHsdLitres / bundle.totalNetLitres * 100).toStringAsFixed(1)}% of recorded volume.',
          impactBadge: 'Recorded fuel mix',
          dataEvidence:
              '${bundle.totalHsdLitres.toStringAsFixed(1)} L diesel and ${bundle.totalMsLitres.toStringAsFixed(1)} L petrol from current meter records.',
          actionSteps: const [
            'Review actual diesel demand before changing staffing.',
            'Check dispenser availability against recorded volume.',
          ],
          accentColor: const Color(0xFF0284C7),
          heroIcon: Icons.local_shipping_rounded,
          visualSceneType: 'fleet_diesel',
        ),
      );
    }
    if (bundle.totalRecordedCollectionsPaise > 0) {
      tips.add(
        AiSalesGrowthTip(
          id: 'payments',
          categoryTag: 'UPI & Express',
          title: 'Review recorded payment collections',
          subtitle:
              'UPI represents ${(bundle.phonePeSalesPaise / bundle.totalRecordedCollectionsPaise * 100).toStringAsFixed(1)}% of collections in this period.',
          impactBadge: 'Recorded payment mix',
          dataEvidence:
              'UPI ${CurrencyFormatter.formatPaise(bundle.phonePeSalesPaise)}; cash ${CurrencyFormatter.formatPaise(bundle.cashSalesPaise)}.',
          actionSteps: const [
            'Reconcile digital payments against the ledger.',
            'Review cash handovers before changing cash collection routines.',
          ],
          accentColor: StationColors.phonePePurple,
          heroIcon: Icons.qr_code_scanner_rounded,
          visualSceneType: 'upi_fastlane',
        ),
      );
    }
    final accounts = widget.state.creditCustomers
        .where((c) => c.pendingAmountPaise > 0)
        .toList();
    final outstanding = accounts.fold<int>(
      0,
      (sum, c) => sum + c.pendingAmountPaise,
    );
    if (outstanding > 0) {
      tips.add(
        AiSalesGrowthTip(
          id: 'credit',
          categoryTag: 'Khata & Cashflow',
          title: 'Review outstanding credit balances',
          subtitle: '${accounts.length} current accounts have unpaid credit.',
          impactBadge: 'Current outstanding balance',
          dataEvidence:
              '${CurrencyFormatter.formatPaise(outstanding)} outstanding in current Credit Khata records.',
          actionSteps: const [
            'Open Credit Khata and review unpaid balances.',
            'Agree settlement dates with the recorded account holders.',
          ],
          accentColor: StationColors.creditTeal,
          heroIcon: Icons.verified_user_rounded,
          visualSceneType: 'khata_cycle',
        ),
      );
    }
    if (_selectedTipCategoryIndex == 0) return tips;
    return tips
        .where(
          (t) => t.categoryTag == _tipCategories[_selectedTipCategoryIndex],
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _computeAnalytics(_selectedPeriod);
    if (!bundle.hasData) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final period in OwnerAnalyticsPeriod.values)
                  ChoiceChip(
                    label: Text(period.label),
                    selected: _selectedPeriod == period,
                    onSelected: (_) => setState(() => _selectedPeriod = period),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Nothing to analyse',
              key: ValueKey('analytics-empty'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }
    final tips = _buildAiTips(bundle);
    final int clampedBarIdx =
        (_selectedBarIndex >= 0 &&
            _selectedBarIndex < bundle.trendPoints.length)
        ? _selectedBarIndex
        : bundle.trendPoints.length - 1;
    final selectedPoint = bundle.trendPoints[clampedBarIdx];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 680;
        final bool isWide = constraints.maxWidth >= 920;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 14 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
            border: Border.all(
              color: StationColors.primary.withValues(alpha: 0.18),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: StationColors.primary.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Minimalistic AI Header + Period Segmented Switcher (Today | Weekly 7D | Monthly 30D)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobile
                          ? (constraints.maxWidth - 28).clamp(200.0, 680.0)
                          : (constraints.maxWidth - 290).clamp(260.0, 900.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            final double scale =
                                0.94 + (_pulseController.value * 0.10);
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0C4A4D),
                                      Color(0xFF0284C7),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF0284C7,
                                      ).withValues(alpha: 0.28),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Colors.amberAccent,
                                  size: 22,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text(
                                    'AI Sales Intelligence & Weekly/Monthly Analytics',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: StationColors.textDark,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(
                                        color: const Color(0xFF7DD3FC),
                                      ),
                                    ),
                                    child: const Text(
                                      'OWNER AI',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0369A1),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Interactive sales graphs, payment & fuel pie charts, and AI tips to grow station revenue',
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

                  // Period Switcher Pills
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: StationColors.scaffoldBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: StationColors.divider),
                    ),
                    child: Wrap(
                      spacing: 4,
                      children: OwnerAnalyticsPeriod.values.map((p) {
                        final bool selected = _selectedPeriod == p;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedPeriod = p;
                              _selectedBarIndex = -1;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? StationColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              p.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: selected
                                    ? Colors.white
                                    : StationColors.textDark,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Concise AI Natural-Language Executive Summary Strip
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF0F9FF),
                      StationColors.primary.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: (constraints.maxWidth - 56).clamp(
                          180.0,
                          900.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.tips_and_updates_rounded,
                            color: Color(0xFF0284C7),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${_selectedPeriod.label} Summary: ${CurrencyFormatter.formatPaise(bundle.totalFuelSalesPaise)} total sales (${bundle.totalNetLitres.toStringAsFixed(1)} L dispensed) • Diesel is ${(bundle.totalHsdLitres / (bundle.totalNetLitres == 0 ? 1 : bundle.totalNetLitres) * 100).toStringAsFixed(0)}% of volume.',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: StationColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: StationColors.successBg,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.trending_up_rounded,
                            size: 15,
                            color: StationColors.successGreen,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              bundle.hasComparison
                                  ? '${bundle.growthPercent >= 0 ? '+' : ''}${bundle.growthPercent.toStringAsFixed(1)}% vs prior ${_selectedPeriod == OwnerAnalyticsPeriod.today
                                        ? "day"
                                        : _selectedPeriod == OwnerAnalyticsPeriod.weekly
                                        ? "week"
                                        : "month"}'
                                  : 'No prior-period sales to compare',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: StationColors.successGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 3. Weekly / Monthly / Daily Graphs + Pie Charts Grid
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildInteractiveBarAndLineGraphCard(
                        bundle,
                        selectedPoint,
                        clampedBarIdx,
                        isMobile,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: _buildDualPieChartsCard(bundle, isMobile),
                    ),
                  ],
                )
              else ...[
                _buildInteractiveBarAndLineGraphCard(
                  bundle,
                  selectedPoint,
                  clampedBarIdx,
                  isMobile,
                ),
                const SizedBox(height: 16),
                _buildDualPieChartsCard(bundle, isMobile),
              ],

              const SizedBox(height: 22),
              const Divider(height: 1),
              const SizedBox(height: 18),

              // 4. AI Tips to Increase Sales (with Visual Illustrations, Animations & Actionable Playbooks)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.rocket_launch_rounded,
                        color: StationColors.accentOrange,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'AI Tips to Increase Station Sales',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: StationColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_tipCategories.length, (idx) {
                        final bool active = _selectedTipCategoryIndex == idx;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              _tipCategories[idx],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: active
                                    ? Colors.white
                                    : StationColors.textDark,
                              ),
                            ),
                            selected: active,
                            selectedColor: StationColors.primary,
                            backgroundColor: StationColors.scaffoldBg,
                            onSelected: (_) =>
                                setState(() => _selectedTipCategoryIndex = idx),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Responsive Grid / Carousel of Visual AI Growth Cards
              LayoutBuilder(
                builder: (context, tipConstraints) {
                  final bool twoColumns = tipConstraints.maxWidth >= 740;
                  if (twoColumns) {
                    final List<Widget> rows = [];
                    for (int i = 0; i < tips.length; i += 2) {
                      rows.add(
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildVisualAiTipCard(context, tips[i]),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: (i + 1 < tips.length)
                                    ? _buildVisualAiTipCard(
                                        context,
                                        tips[i + 1],
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Column(children: rows);
                  }

                  return Column(
                    children: tips
                        .map(
                          (tip) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildVisualAiTipCard(context, tip),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInteractiveBarAndLineGraphCard(
    PeriodAnalyticsBundle bundle,
    PeriodTrendPoint selectedPoint,
    int selectedIdx,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedPeriod == OwnerAnalyticsPeriod.today
                        ? 'Today Sales & Shift Trend Graph'
                        : _selectedPeriod == OwnerAnalyticsPeriod.weekly
                        ? 'Weekly Sales Trend Graph (Last 7 Days)'
                        : 'Monthly Sales Trend Graph (Last 30 Days)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: StationColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap any bar below to inspect Petrol (MS) vs Diesel (HSD) revenue',
                    style: TextStyle(
                      fontSize: 11,
                      color: StationColors.textMedium,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 10,
                children: [
                  _buildLegendDot('Diesel (HSD)', const Color(0xFF0284C7)),
                  _buildLegendDot('Petrol (MS)', StationColors.accentOrange),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Selected Bar Callout Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: StationColors.divider),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 4,
              children: [
                Text(
                  selectedPoint.fullDateLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: StationColors.primary,
                  ),
                ),
                Text(
                  'Total: ${CurrencyFormatter.formatPaise(selectedPoint.totalSalesPaise)} (${selectedPoint.totalLitres.toStringAsFixed(0)} L)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: StationColors.textDark,
                  ),
                ),
                Text(
                  'MS: ${selectedPoint.petrolLitres.toStringAsFixed(0)}L • HSD: ${selectedPoint.dieselLitres.toStringAsFixed(0)}L',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: StationColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Animated Custom Bar + Bezier Trend Line Canvas
          TweenAnimationBuilder<double>(
            key: ValueKey(_selectedPeriod),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) {
              return SizedBox(
                height: 195,
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, box) {
                    return GestureDetector(
                      onTapDown: (details) {
                        final count = bundle.trendPoints.length;
                        if (count == 0 || box.maxWidth <= 0) return;
                        final slotWidth = box.maxWidth / count;
                        final tappedIdx = (details.localPosition.dx / slotWidth)
                            .floor()
                            .clamp(0, count - 1);
                        setState(() {
                          _selectedBarIndex = tappedIdx;
                        });
                      },
                      child: CustomPaint(
                        painter: _SalesTrendGraphPainter(
                          points: bundle.trendPoints,
                          selectedIndex: selectedIdx,
                          animationProgress: progress,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDualPieChartsCard(PeriodAnalyticsBundle bundle, bool isMobile) {
    final totalPay = math.max(1, bundle.totalRecordedCollectionsPaise);
    final paymentSlices = [
      _PieSliceData(
        label: 'PhonePe / UPI',
        amountPaise: bundle.phonePeSalesPaise,
        percentage: (bundle.phonePeSalesPaise / totalPay) * 100,
        color: StationColors.phonePePurple,
      ),
      _PieSliceData(
        label: 'Cash',
        amountPaise: bundle.cashSalesPaise,
        percentage: (bundle.cashSalesPaise / totalPay) * 100,
        color: StationColors.successGreen,
      ),
      _PieSliceData(
        label: 'Card (POS)',
        amountPaise: bundle.cardSalesPaise,
        percentage: (bundle.cardSalesPaise / totalPay) * 100,
        color: StationColors.cardBlue,
      ),
      _PieSliceData(
        label: 'Credit Khata',
        amountPaise: bundle.creditSalesPaise,
        percentage: (bundle.creditSalesPaise / totalPay) * 100,
        color: StationColors.accentOrange,
      ),
    ];

    final int msSalesPaise = bundle.petrolFuelSalesPaise;
    final int hsdSalesPaise = bundle.dieselFuelSalesPaise;
    final int totalFuelMix = math.max(1, msSalesPaise + hsdSalesPaise);
    final fuelSlices = [
      _PieSliceData(
        label: 'Diesel (${bundle.totalHsdLitres.toStringAsFixed(0)} L)',
        amountPaise: hsdSalesPaise,
        percentage: (hsdSalesPaise / totalFuelMix) * 100,
        color: const Color(0xFF0284C7),
      ),
      _PieSliceData(
        label: 'Petrol (${bundle.totalMsLitres.toStringAsFixed(0)} L)',
        amountPaise: msSalesPaise,
        percentage: (msSalesPaise / totalFuelMix) * 100,
        color: StationColors.accentOrange,
      ),
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StationColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedPeriod.label} Pie Charts: Payment Modes & Fuel Share',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: StationColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Distribution of collections by payment channel and fuel grade',
            style: TextStyle(fontSize: 11, color: StationColors.textMedium),
          ),
          const SizedBox(height: 14),

          // Pie Chart 1: Payment Modes Breakdown
          _buildSingleDonutSection(
            title: 'Payment Collections Pie Chart',
            centerTop: 'Digital',
            centerBottom:
                '${(((bundle.phonePeSalesPaise + bundle.cardSalesPaise) / totalPay) * 100).toStringAsFixed(0)}%',
            slices: paymentSlices,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),

          // Pie Chart 2: Fuel Grade Mix (Diesel vs Petrol)
          _buildSingleDonutSection(
            title: 'Fuel Grade Revenue Pie Chart',
            centerTop: 'Total Vol',
            centerBottom: '${bundle.totalNetLitres.toStringAsFixed(0)}L',
            slices: fuelSlices,
          ),
        ],
      ),
    );
  }

  Widget _buildSingleDonutSection({
    required String title,
    required String centerTop,
    required String centerBottom,
    required List<_PieSliceData> slices,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: StationColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey('$title-${_selectedPeriod.name}'),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutBack,
                builder: (context, anim, _) {
                  return SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(96, 96),
                          painter: _DonutChartPainter(
                            slices: slices,
                            animationProgress: anim.clamp(0.0, 1.0),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              centerTop,
                              style: const TextStyle(
                                fontSize: 9,
                                color: StationColors.textMedium,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              centerBottom,
                              style: const TextStyle(
                                fontSize: 12,
                                color: StationColors.textDark,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              SizedBox(
                width: constraints.maxWidth < 420
                    ? constraints.maxWidth
                    : constraints.maxWidth - 110,
                child: Column(
                  children: slices.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: s.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '${s.label} (${s.percentage.toStringAsFixed(0)}%)',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: StationColors.textDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            CurrencyFormatter.formatPaise(s.amountPaise),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: StationColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVisualAiTipCard(BuildContext context, AiSalesGrowthTip tip) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tip.accentColor.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: tip.accentColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Animated Visual Photo / Forecourt Scene Banner
          Stack(
            children: [
              // Background reference receipt/station photo with rich gradient overlay
              Positioned.fill(
                child: Image.asset(
                  'assets/images/media_1791634198035.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        tip.accentColor.withValues(alpha: 0.92),
                        const Color(0xFF0F172A).withValues(alpha: 0.88),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              // Animated Forecourt Graphic Overlay
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _ForecourtTipIllustrationPainter(
                        sceneType: tip.visualSceneType,
                        pulseValue: _pulseController.value,
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(tip.heroIcon, color: Colors.white, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                tip.categoryTag,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF08A),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            tip.impactBadge,
                            style: const TextStyle(
                              color: Color(0xFF713F12),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tip.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Card Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: StationColors.textDark,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: StationColors.scaffoldBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 14,
                        color: tip.accentColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          tip.dataEvidence,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: StationColors.textMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton.icon(
                    icon: Icon(
                      Icons.play_circle_outline_rounded,
                      size: 16,
                      color: tip.accentColor,
                    ),
                    label: Text(
                      'View 3-Step Sales Action Plan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: tip.accentColor,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: tip.accentColor.withValues(alpha: 0.45),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _showActionPlanDialog(context, tip),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showActionPlanDialog(BuildContext context, AiSalesGrowthTip tip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(tip.heroIcon, color: tip.accentColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tip.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: tip.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Estimated Impact: ${tip.impactBadge}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: tip.accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tip.dataEvidence,
                style: const TextStyle(
                  fontSize: 12,
                  color: StationColors.textMedium,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Recommended Owner Action Steps:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: StationColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(tip.actionSteps.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: tip.accentColor,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tip.actionSteps[i],
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: StationColors.textDark,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: StationColors.textDark,
          ),
        ),
      ],
    );
  }
}

class _PieSliceData {
  final String label;
  final int amountPaise;
  final double percentage;
  final Color color;

  const _PieSliceData({
    required this.label,
    required this.amountPaise,
    required this.percentage,
    required this.color,
  });
}

class _SalesTrendGraphPainter extends CustomPainter {
  final List<PeriodTrendPoint> points;
  final int selectedIndex;
  final double animationProgress;

  _SalesTrendGraphPainter({
    required this.points,
    required this.selectedIndex,
    required this.animationProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const double bottomLabelHeight = 26.0;
    const double topPadding = 16.0;
    final double chartHeight = size.height - bottomLabelHeight - topPadding;
    final int maxPaise = points.fold<int>(
      1,
      (m, p) => math.max(m, p.totalSalesPaise),
    );

    // Horizontal grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = topPadding + (chartHeight * (i / 3));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final int count = points.length;
    final double slotWidth = size.width / count;
    final double barWidth = math.min(28.0, slotWidth * 0.52);

    final List<Offset> trendLinePoints = [];

    for (int i = 0; i < count; i++) {
      final p = points[i];
      final double centerX = (i + 0.5) * slotWidth;
      final double totalRatio =
          (p.totalSalesPaise / maxPaise).clamp(0.0, 1.0) * animationProgress;
      final double dieselRatio =
          (p.dieselSalesPaise / maxPaise).clamp(0.0, 1.0) * animationProgress;

      final double totalBarHeight = chartHeight * totalRatio;
      final double dieselBarHeight = chartHeight * dieselRatio;
      final double barTop = topPadding + chartHeight - totalBarHeight;
      final double barBottom = topPadding + chartHeight;

      trendLinePoints.add(Offset(centerX, barTop));

      // Highlight selected bar column background
      if (i == selectedIndex) {
        final highlightPaint = Paint()
          ..color = StationColors.primary.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              centerX - slotWidth * 0.42,
              topPadding - 6,
              slotWidth * 0.84,
              chartHeight + 10,
            ),
            const Radius.circular(8),
          ),
          highlightPaint,
        );
      }

      // Draw full bar (Petrol Orange on top + Diesel Blue on bottom)
      final fullRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(centerX - barWidth / 2, barTop, barWidth, totalBarHeight),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );
      canvas.drawRRect(fullRect, Paint()..color = StationColors.accentOrange);

      final dieselTop = barBottom - dieselBarHeight;
      final dieselRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          centerX - barWidth / 2,
          dieselTop,
          barWidth,
          dieselBarHeight,
        ),
        topLeft: Radius.circular(
          dieselBarHeight >= totalBarHeight * 0.95 ? 6 : 2,
        ),
        topRight: Radius.circular(
          dieselBarHeight >= totalBarHeight * 0.95 ? 6 : 2,
        ),
      );
      canvas.drawRRect(dieselRect, Paint()..color = const Color(0xFF0284C7));

      // X-axis label
      final tp = TextPainter(
        text: TextSpan(
          text: p.label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: i == selectedIndex ? FontWeight.w900 : FontWeight.w600,
            color: i == selectedIndex
                ? StationColors.primary
                : StationColors.textMedium,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: slotWidth);
      tp.paint(
        canvas,
        Offset(centerX - tp.width / 2, size.height - bottomLabelHeight + 7),
      );
    }

    // Draw smooth trend line connecting bar peaks
    if (trendLinePoints.length >= 2) {
      final linePath = Path()
        ..moveTo(trendLinePoints.first.dx, trendLinePoints.first.dy);
      for (int i = 0; i < trendLinePoints.length - 1; i++) {
        final p0 = trendLinePoints[i];
        final p1 = trendLinePoints[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      }
      final linePaint = Paint()
        ..color = StationColors.primaryDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      canvas.drawPath(linePath, linePaint);

      for (int i = 0; i < trendLinePoints.length; i++) {
        final pt = trendLinePoints[i];
        canvas.drawCircle(pt, 4.0, Paint()..color = Colors.white);
        canvas.drawCircle(
          pt,
          i == selectedIndex ? 4.5 : 3.0,
          Paint()
            ..color = i == selectedIndex
                ? StationColors.accentOrange
                : StationColors.primaryDark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SalesTrendGraphPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.animationProgress != animationProgress;
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<_PieSliceData> slices;
  final double animationProgress;

  _DonutChartPainter({required this.slices, required this.animationProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2;
    final double totalSweep = 2 * math.pi * animationProgress;

    for (final slice in slices) {
      final sweepAngle = (slice.percentage / 100.0) * totalSweep;
      if (sweepAngle <= 0) continue;

      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        rect,
        startAngle,
        math.max(0.01, sweepAngle - 0.04),
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.animationProgress != animationProgress;
  }
}

class _ForecourtTipIllustrationPainter extends CustomPainter {
  final String sceneType;
  final double pulseValue;

  _ForecourtTipIllustrationPainter({
    required this.sceneType,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw animated decorative rings & rising sparkline bars on the right side of the banner
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08 + pulseValue * 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rightCenter = Offset(size.width - 42, size.height * 0.52);
    canvas.drawCircle(rightCenter, 22 + pulseValue * 6, ringPaint);
    canvas.drawCircle(rightCenter, 36 + pulseValue * 10, ringPaint);

    // Mini rising sales bars illustration on the right
    final barPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final heights = [16.0, 24.0, 32.0, 44.0 + pulseValue * 6];
    for (int i = 0; i < heights.length; i++) {
      final h = heights[i];
      final x = size.width - 78 + (i * 14.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h - 10, 9, h),
          const Radius.circular(3),
        ),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ForecourtTipIllustrationPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.sceneType != sceneType;
  }
}
