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
  });
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
  }) {
    // Monotonic continuity check: closing reading must be >= opening reading
    if (closingReadingMl < openingReadingMl) {
      throw ArgumentError(
        'Closing reading ($closingReadingMl mL) is less than opening reading ($openingReadingMl mL). Counter rollover requires explicit epoch authorization.',
      );
    }

    int grossVolumeMl = closingReadingMl - openingReadingMl;
    
    // Test volume deduction cannot exceed gross dispensed volume
    if (testVolumeMl > grossVolumeMl) {
      throw ArgumentError(
        'Approved test volume ($testVolumeMl mL) exceeds gross volume ($grossVolumeMl mL).',
      );
    }

    int billableVolumeMl = grossVolumeMl - testVolumeMl;
    int fuelSalesPaise = calculateFuelSalesPaise(
      billableVolumeMl: billableVolumeMl,
      ratePaisePerLitre: ratePaisePerLitre,
    );

    return NozzleCalculationResult(
      nozzleNumber: nozzleNumber,
      fuelType: fuelType,
      openingReadingMl: openingReadingMl,
      closingReadingMl: closingReadingMl,
      grossVolumeMl: grossVolumeMl,
      testVolumeMl: testVolumeMl,
      billableVolumeMl: billableVolumeMl,
      ratePaisePerLitre: ratePaisePerLitre,
      fuelSalesPaise: fuelSalesPaise,
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
