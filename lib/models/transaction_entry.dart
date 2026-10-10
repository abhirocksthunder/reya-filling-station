import '../core/formatting/currency_formatter.dart';

enum EntryCategory {
  cash,
  phonePe,
  card,
  credit,
  expense,
  salary,
  toOwner;

  String get displayName {
    switch (this) {
      case EntryCategory.cash:
        return 'Cash';
      case EntryCategory.phonePe:
        return 'PhonePe';
      case EntryCategory.card:
        return 'Card';
      case EntryCategory.credit:
        return 'Credit';
      case EntryCategory.expense:
        return 'Expense';
      case EntryCategory.salary:
        return 'Salary';
      case EntryCategory.toOwner:
        return 'To owner';
    }
  }

  String get shorthandCode {
    switch (this) {
      case EntryCategory.cash:
        return 'Cash';
      case EntryCategory.phonePe:
        return 'ph.p';
      case EntryCategory.card:
        return 'swiping';
      case EntryCategory.credit:
        return 'N.C';
      case EntryCategory.expense:
        return 'food';
      case EntryCategory.salary:
        return 'salary';
      case EntryCategory.toOwner:
        return 'owner';
    }
  }
}

enum EntryDirection {
  received,
  paidOut;

  String get displayName {
    switch (this) {
      case EntryDirection.received:
        return 'Received';
      case EntryDirection.paidOut:
        return 'Paid out';
    }
  }
}

class TransactionEntry {
  final String id;
  final String shiftId;
  final EntryCategory category;
  final EntryDirection direction;
  final int amountPaise;
  final String? phonePeNumber;
  final String? timeString; // e.g. "12:15 pm"
  final String? reference; // e.g. "Sri Sai Travels", "curries"
  final DateTime createdAt;
  final String createdBy;
  final String status; // "active", "needs_review", "approved"

  const TransactionEntry({
    required this.id,
    required this.shiftId,
    required this.category,
    required this.direction,
    required this.amountPaise,
    this.phonePeNumber,
    this.timeString,
    this.reference,
    required this.createdAt,
    required this.createdBy,
    this.status = 'active',
  });

  String get formattedAmount => CurrencyFormatter.formatPaise(amountPaise);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shiftId': shiftId,
      'category': category.name,
      'direction': direction.name,
      'amountPaise': amountPaise,
      'phonePeNumber': phonePeNumber,
      'timeString': timeString,
      'reference': reference,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'status': status,
    };
  }

  factory TransactionEntry.fromMap(Map<String, dynamic> map) {
    return TransactionEntry(
      id: map['id'] ?? '',
      shiftId: map['shiftId'] ?? '',
      category: EntryCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => EntryCategory.cash,
      ),
      direction: EntryDirection.values.firstWhere(
        (d) => d.name == map['direction'],
        orElse: () => EntryDirection.received,
      ),
      amountPaise: map['amountPaise'] ?? 0,
      phonePeNumber: map['phonePeNumber'],
      timeString: map['timeString'],
      reference: map['reference'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      status: map['status'] ?? 'active',
    );
  }
}
