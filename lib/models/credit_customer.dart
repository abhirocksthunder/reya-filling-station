import '../core/formatting/currency_formatter.dart';

class CreditPayment {
  final String id;
  final DateTime date;
  final int amountPaise;
  final String mode; // "Cash" or "PhonePe"
  final String? note;

  const CreditPayment({
    required this.id,
    required this.date,
    required this.amountPaise,
    required this.mode,
    this.note,
  });

  String get formattedAmount => CurrencyFormatter.formatPaise(amountPaise);
}

class CreditCustomer {
  final String id;
  final String name; // e.g. "Sri Sai Travels"
  final String subtitle; // e.g. "Bus AP16 XX1234" or "School Transport"
  final int pendingAmountPaise; // e.g. 1800000 = ₹18,000
  final DateTime lastCreditDate;
  final List<CreditPayment> payments;

  const CreditCustomer({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.pendingAmountPaise,
    required this.lastCreditDate,
    this.payments = const [],
  });

  String get formattedPending => CurrencyFormatter.formatPaise(pendingAmountPaise);

  CreditCustomer copyWith({
    String? id,
    String? name,
    String? subtitle,
    int? pendingAmountPaise,
    DateTime? lastCreditDate,
    List<CreditPayment>? payments,
  }) {
    return CreditCustomer(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      pendingAmountPaise: pendingAmountPaise ?? this.pendingAmountPaise,
      lastCreditDate: lastCreditDate ?? this.lastCreditDate,
      payments: payments ?? this.payments,
    );
  }
}
