import '../core/formatting/currency_formatter.dart';

enum ShiftStatus {
  inProgress,
  needsReview,
  approved,
  scheduled;

  String get displayName {
    switch (this) {
      case ShiftStatus.inProgress:
        return 'In progress';
      case ShiftStatus.needsReview:
        return 'Needs review';
      case ShiftStatus.approved:
        return 'Approved';
      case ShiftStatus.scheduled:
        return 'Scheduled';
    }
  }
}

class Shift {
  final String id;
  final String shiftName; // "Morning", "Evening", "Night"
  final String businessDate; // "10 Oct 2026" or "9 Oct 2026"
  final String staffId;
  final String staffName;
  final String pumpName; // "Pump 1"
  final ShiftStatus status;
  final String timeRange; // "2:00 PM - 10:00 PM"
  final Map<int, int> openingReadingsMl;
  final Map<int, int> closingReadingsMl;
  final Map<int, int> testVolumesMl; // Approved 5L tests
  final int cashHandoverPaise; // e.g. 1307400 = ₹13,074
  final String handoverReceiver; // "Owner"
  final DateTime? handoverTime;
  final String? note;

  const Shift({
    required this.id,
    required this.shiftName,
    required this.businessDate,
    required this.staffId,
    required this.staffName,
    required this.pumpName,
    required this.status,
    required this.timeRange,
    required this.openingReadingsMl,
    required this.closingReadingsMl,
    required this.testVolumesMl,
    this.cashHandoverPaise = 0,
    this.handoverReceiver = 'Owner',
    this.handoverTime,
    this.note,
  });

  String get formattedHandover => CurrencyFormatter.formatPaise(cashHandoverPaise);

  Shift copyWith({
    String? id,
    String? shiftName,
    String? businessDate,
    String? staffId,
    String? staffName,
    String? pumpName,
    ShiftStatus? status,
    String? timeRange,
    Map<int, int>? openingReadingsMl,
    Map<int, int>? closingReadingsMl,
    Map<int, int>? testVolumesMl,
    int? cashHandoverPaise,
    String? handoverReceiver,
    DateTime? handoverTime,
    String? note,
  }) {
    return Shift(
      id: id ?? this.id,
      shiftName: shiftName ?? this.shiftName,
      businessDate: businessDate ?? this.businessDate,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      pumpName: pumpName ?? this.pumpName,
      status: status ?? this.status,
      timeRange: timeRange ?? this.timeRange,
      openingReadingsMl: openingReadingsMl ?? this.openingReadingsMl,
      closingReadingsMl: closingReadingsMl ?? this.closingReadingsMl,
      testVolumesMl: testVolumesMl ?? this.testVolumesMl,
      cashHandoverPaise: cashHandoverPaise ?? this.cashHandoverPaise,
      handoverReceiver: handoverReceiver ?? this.handoverReceiver,
      handoverTime: handoverTime ?? this.handoverTime,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shiftName': shiftName,
      'businessDate': businessDate,
      'staffId': staffId,
      'staffName': staffName,
      'pumpName': pumpName,
      'status': status.name,
      'timeRange': timeRange,
      'openingReadingsMl': openingReadingsMl.map((k, v) => MapEntry(k.toString(), v)),
      'closingReadingsMl': closingReadingsMl.map((k, v) => MapEntry(k.toString(), v)),
      'testVolumesMl': testVolumesMl.map((k, v) => MapEntry(k.toString(), v)),
      'cashHandoverPaise': cashHandoverPaise,
      'handoverReceiver': handoverReceiver,
      'handoverTime': handoverTime?.toIso8601String(),
      'note': note,
    };
  }

  factory Shift.fromMap(Map<String, dynamic> map) {
    Map<int, int> parseMap(Map? raw) {
      if (raw == null) return {};
      Map<int, int> res = {};
      raw.forEach((k, v) => res[int.tryParse(k.toString()) ?? 1] = (v as num).toInt());
      return res;
    }

    return Shift(
      id: map['id'] ?? '',
      shiftName: map['shiftName'] ?? '',
      businessDate: map['businessDate'] ?? '',
      staffId: map['staffId'] ?? '',
      staffName: map['staffName'] ?? '',
      pumpName: map['pumpName'] ?? '',
      status: ShiftStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => ShiftStatus.inProgress,
      ),
      timeRange: map['timeRange'] ?? '',
      openingReadingsMl: parseMap(map['openingReadingsMl']),
      closingReadingsMl: parseMap(map['closingReadingsMl']),
      testVolumesMl: parseMap(map['testVolumesMl']),
      cashHandoverPaise: map['cashHandoverPaise'] ?? 0,
      handoverReceiver: map['handoverReceiver'] ?? 'Owner',
      handoverTime: map['handoverTime'] != null ? DateTime.tryParse(map['handoverTime']) : null,
      note: map['note'],
    );
  }
}
