class NozzleRateSegment {
  final int fromReadingMl;
  final int toReadingMl;
  final int grossVolumeMl;
  final int testVolumeMl;
  final int billableVolumeMl;
  final int ratePaisePerLitre;
  final int amountPaise;
  final DateTime? startTime;
  final DateTime? endTime;

  const NozzleRateSegment({
    required this.fromReadingMl,
    required this.toReadingMl,
    required this.grossVolumeMl,
    required this.testVolumeMl,
    required this.billableVolumeMl,
    required this.ratePaisePerLitre,
    required this.amountPaise,
    this.startTime,
    this.endTime,
  });

  double get fromReadingLitres => fromReadingMl / 1000.0;
  double get toReadingLitres => toReadingMl / 1000.0;
  double get grossLitres => grossVolumeMl / 1000.0;
  double get testLitres => testVolumeMl / 1000.0;
  double get billableLitres => billableVolumeMl / 1000.0;
  double get rateRupees => ratePaisePerLitre / 100.0;
  double get amountRupees => amountPaise / 100.0;
}

class NozzleCalculationResult {
  final int nozzleNumber;
  final String fuelType;
  final int openingReadingMl;
  final int closingReadingMl;
  final int grossVolumeMl;
  final int testVolumeMl;
  final int billableVolumeMl;
  final int ratePaisePerLitre;
  final int fuelSalesPaise; // Rounded half-up to nearest paise
  final List<NozzleRateSegment> segments;

  final String pumpId;
  final String pumpName;

  const NozzleCalculationResult({
    required this.nozzleNumber,
    required this.fuelType,
    required this.openingReadingMl,
    required this.closingReadingMl,
    required this.grossVolumeMl,
    required this.testVolumeMl,
    required this.billableVolumeMl,
    required this.ratePaisePerLitre,
    required this.fuelSalesPaise,
    this.segments = const [],
    this.pumpId = 'pump_1',
    this.pumpName = 'Pump 1',
  });

  bool get hasPriceChange => segments.length > 1;

  double get openingLitres => openingReadingMl / 1000.0;
  double get closingLitres => closingReadingMl / 1000.0;
  double get grossLitres => grossVolumeMl / 1000.0;
  double get testLitres => testVolumeMl / 1000.0;
  double get billableLitres => billableVolumeMl / 1000.0;
  double get rateRupees => ratePaisePerLitre / 100.0;
  double get fuelSalesRupees => fuelSalesPaise / 100.0;
}

class ShiftReconciliationReport {
  final List<NozzleCalculationResult> nozzleResults;
  final int totalCalculatedFuelSalesPaise;
  
  // Payment Breakdown
  final int cashSalesPaise;
  final int phonePeSalesPaise;
  final int cardSalesPaise;
  final int creditSalesPaise;
  final int totalAccountedPaymentsPaise;
  
  // Variances
  final int salesVariancePaise; // totalAccountedPayments - totalCalculatedFuelSales

  // Cash Handover & Variance
  final int openingCashFloatPaise;
  final int otherCashDebitsPaise; // e.g. Bus Bill ₹17,373
  final int foodExpensesPaise; // e.g. curries/food ₹100
  final int salaryExpensesPaise;
  final int cashGivenToOwnerPaise; // e.g. ₹13,074
  final int countedClosingCashPaise;
  final int expectedClosingCashPaise;
  final int cashVariancePaise; // countedClosingCash - expectedClosingCash

  const ShiftReconciliationReport({
    required this.nozzleResults,
    required this.totalCalculatedFuelSalesPaise,
    required this.cashSalesPaise,
    required this.phonePeSalesPaise,
    required this.cardSalesPaise,
    required this.creditSalesPaise,
    required this.totalAccountedPaymentsPaise,
    required this.salesVariancePaise,
    required this.openingCashFloatPaise,
    required this.otherCashDebitsPaise,
    required this.foodExpensesPaise,
    required this.salaryExpensesPaise,
    required this.cashGivenToOwnerPaise,
    required this.countedClosingCashPaise,
    required this.expectedClosingCashPaise,
    required this.cashVariancePaise,
  });
}

class ReconciliationService {
  /// Rounds half-up to the nearest integer paise:
  /// roundHalfUp((billableVolumeMl * ratePaisePerLitre) / 1000)
  static int calculateFuelSalesPaise({
    required int billableVolumeMl,
    required int ratePaisePerLitre,
  }) {
    if (billableVolumeMl <= 0 || ratePaisePerLitre <= 0) return 0;
    
    // Exact integer arithmetic: numerator = volume * rate
    BigInt numerator = BigInt.from(billableVolumeMl) * BigInt.from(ratePaisePerLitre);
    BigInt thousand = BigInt.from(1000);
    
    // Half-up division: (numerator + 500) ~/ 1000
    BigInt rounded = (numerator + BigInt.from(500)) ~/ thousand;
    return rounded.toInt();
  }

  /// Calculates complete single nozzle reconciliation
  static NozzleCalculationResult calculateNozzle({
    required int nozzleNumber,
    required String fuelType,
    required int openingReadingMl,
    required int closingReadingMl,
    required int testVolumeMl,
    required int ratePaisePerLitre,
    bool clampTestVolume = false,
    String pumpId = 'pump_1',
    String pumpName = 'Pump 1',
  }) {
    if (!clampTestVolume && closingReadingMl < openingReadingMl) {
      throw ArgumentError(
        'Closing reading ($closingReadingMl mL) is less than opening reading ($openingReadingMl mL). Counter rollover requires explicit epoch authorization.',
      );
    }

    int grossVolumeMl = closingReadingMl >= openingReadingMl
        ? (closingReadingMl - openingReadingMl)
        : 0;
    
    int effectiveTestVolume = testVolumeMl;
    if (clampTestVolume) {
      if (effectiveTestVolume > grossVolumeMl) {
        effectiveTestVolume = grossVolumeMl;
      }
    } else {
      // Test volume deduction cannot exceed gross dispensed volume
      if (testVolumeMl > grossVolumeMl) {
        throw ArgumentError(
          'Approved test volume ($testVolumeMl mL) exceeds gross volume ($grossVolumeMl mL).',
        );
      }
    }

    int billableVolumeMl = grossVolumeMl - effectiveTestVolume;
    int fuelSalesPaise = calculateFuelSalesPaise(
      billableVolumeMl: billableVolumeMl,
      ratePaisePerLitre: ratePaisePerLitre,
    );

    final singleSegment = NozzleRateSegment(
      fromReadingMl: openingReadingMl,
      toReadingMl: closingReadingMl,
      grossVolumeMl: grossVolumeMl,
      testVolumeMl: effectiveTestVolume,
      billableVolumeMl: billableVolumeMl,
      ratePaisePerLitre: ratePaisePerLitre,
      amountPaise: fuelSalesPaise,
    );

    return NozzleCalculationResult(
      nozzleNumber: nozzleNumber,
      fuelType: fuelType,
      openingReadingMl: openingReadingMl,
      closingReadingMl: closingReadingMl,
      grossVolumeMl: grossVolumeMl,
      testVolumeMl: effectiveTestVolume,
      billableVolumeMl: billableVolumeMl,
      ratePaisePerLitre: ratePaisePerLitre,
      fuelSalesPaise: fuelSalesPaise,
      segments: [singleSegment],
      pumpId: pumpId,
      pumpName: pumpName,
    );
  }

  /// Calculates multi-rate partitioned nozzle reconciliation.
  /// When fuel prices change mid-day or across scans, each segment calculates volume
  /// and sales at its effective rate, with morning test volume (5 L) applied to the initial segment.
  static NozzleCalculationResult calculateMultiSegmentNozzle({
    required int nozzleNumber,
    required String fuelType,
    required int openingReadingMl,
    required int closingReadingMl,
    required int totalTestVolumeMl,
    required List<({int fromMl, int toMl, int ratePaisePerLitre, DateTime? startTime, DateTime? endTime})> rawSegments,
    String pumpId = 'pump_1',
    String pumpName = 'Pump 1',
  }) {
    if (rawSegments.isEmpty) {
      return calculateNozzle(
        nozzleNumber: nozzleNumber,
        fuelType: fuelType,
        openingReadingMl: openingReadingMl,
        closingReadingMl: closingReadingMl,
        testVolumeMl: totalTestVolumeMl,
        ratePaisePerLitre: 0,
        clampTestVolume: true,
        pumpId: pumpId,
        pumpName: pumpName,
      );
    }

    int remainingTestMl = totalTestVolumeMl;
    int totalGrossMl = 0;
    int totalFuelSalesPaise = 0;
    final List<NozzleRateSegment> computedSegments = [];

    for (var seg in rawSegments) {
      int segGrossMl = seg.toMl >= seg.fromMl ? (seg.toMl - seg.fromMl) : 0;
      totalGrossMl += segGrossMl;

      int segTestMl = 0;
      if (remainingTestMl > 0) {
        segTestMl = remainingTestMl >= segGrossMl ? segGrossMl : remainingTestMl;
        remainingTestMl -= segTestMl;
      }

      int segBillableMl = segGrossMl - segTestMl;
      int segAmountPaise = calculateFuelSalesPaise(
        billableVolumeMl: segBillableMl,
        ratePaisePerLitre: seg.ratePaisePerLitre,
      );
      totalFuelSalesPaise += segAmountPaise;

      computedSegments.add(NozzleRateSegment(
        fromReadingMl: seg.fromMl,
        toReadingMl: seg.toMl,
        grossVolumeMl: segGrossMl,
        testVolumeMl: segTestMl,
        billableVolumeMl: segBillableMl,
        ratePaisePerLitre: seg.ratePaisePerLitre,
        amountPaise: segAmountPaise,
        startTime: seg.startTime,
        endTime: seg.endTime,
      ));
    }

    int effectiveTotalTestMl = totalTestVolumeMl - remainingTestMl;
    int totalBillableMl = totalGrossMl - effectiveTotalTestMl;
    int effectiveRate = computedSegments.last.ratePaisePerLitre;

    return NozzleCalculationResult(
      nozzleNumber: nozzleNumber,
      fuelType: fuelType,
      openingReadingMl: openingReadingMl,
      closingReadingMl: closingReadingMl,
      grossVolumeMl: totalGrossMl,
      testVolumeMl: effectiveTotalTestMl,
      billableVolumeMl: totalBillableMl,
      ratePaisePerLitre: effectiveRate,
      fuelSalesPaise: totalFuelSalesPaise,
      segments: computedSegments,
      pumpId: pumpId,
      pumpName: pumpName,
    );
  }

  /// Reconciles full shift with all nozzles and money entries
  static ShiftReconciliationReport reconcileShift({
    required List<NozzleCalculationResult> nozzleResults,
    required int cashSalesPaise,
    required int phonePeSalesPaise,
    required int cardSalesPaise,
    required int creditSalesPaise,
    int openingCashFloatPaise = 0,
    int otherCashDebitsPaise = 0,
    int foodExpensesPaise = 0,
    int salaryExpensesPaise = 0,
    int cashGivenToOwnerPaise = 0,
    int countedClosingCashPaise = 0,
  }) {
    int totalFuelSalesPaise = nozzleResults.fold(0, (sum, n) => sum + n.fuelSalesPaise);
    
    int totalPaymentsPaise = cashSalesPaise + phonePeSalesPaise + cardSalesPaise + creditSalesPaise;
    int salesVariancePaise = totalPaymentsPaise - totalFuelSalesPaise;

    // Expected closing cash = Opening Float + Cash Sales - Deductions - Handover
    int totalCashOutflows = otherCashDebitsPaise + foodExpensesPaise + salaryExpensesPaise + cashGivenToOwnerPaise;
    int expectedClosingCashPaise = (openingCashFloatPaise + cashSalesPaise) - totalCashOutflows;
    int cashVariancePaise = countedClosingCashPaise - expectedClosingCashPaise;

    return ShiftReconciliationReport(
      nozzleResults: nozzleResults,
      totalCalculatedFuelSalesPaise: totalFuelSalesPaise,
      cashSalesPaise: cashSalesPaise,
      phonePeSalesPaise: phonePeSalesPaise,
      cardSalesPaise: cardSalesPaise,
      creditSalesPaise: creditSalesPaise,
      totalAccountedPaymentsPaise: totalPaymentsPaise,
      salesVariancePaise: salesVariancePaise,
      openingCashFloatPaise: openingCashFloatPaise,
      otherCashDebitsPaise: otherCashDebitsPaise,
      foodExpensesPaise: foodExpensesPaise,
      salaryExpensesPaise: salaryExpensesPaise,
      cashGivenToOwnerPaise: cashGivenToOwnerPaise,
      countedClosingCashPaise: countedClosingCashPaise,
      expectedClosingCashPaise: expectedClosingCashPaise,
      cashVariancePaise: cashVariancePaise,
    );
  }
}
