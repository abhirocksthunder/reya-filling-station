import '../core/formatting/currency_formatter.dart';
import '../core/formatting/date_formatter.dart';

enum CashHandoverStatus {
  pending,
  accepted,
  forwarded,
  rejected;

  String get displayName {
    switch (this) {
      case CashHandoverStatus.pending:
        return 'Pending Acceptance';
      case CashHandoverStatus.accepted:
        return 'Accepted & Verified';
      case CashHandoverStatus.forwarded:
        return 'Forwarded to Owner';
      case CashHandoverStatus.rejected:
        return 'Rejected';
    }
  }
}

class CashHandoverRecord {
  final String id;
  final String shiftId;
  final String shiftName;
  final String businessDate;
  final String fromUserId;
  final String fromUserName;
  final String fromUserRole;
  final String toUserId;
  final String toUserName;
  final String toUserRole;
  final int amountPaise;
  final CashHandoverStatus status;
  final DateTime createdAt;
  final String timeString;
  final DateTime? respondedAt;
  final String? note;
  final String? linkedEntryId;

  const CashHandoverRecord({
    required this.id,
    required this.shiftId,
    required this.shiftName,
    required this.businessDate,
    required this.fromUserId,
    required this.fromUserName,
    required this.fromUserRole,
    required this.toUserId,
    required this.toUserName,
    required this.toUserRole,
    required this.amountPaise,
    this.status = CashHandoverStatus.pending,
    required this.createdAt,
    required this.timeString,
    this.respondedAt,
    this.note,
    this.linkedEntryId,
  });

  String get formattedAmount => CurrencyFormatter.formatPaise(amountPaise);

  CashHandoverRecord copyWith({
    String? id,
    String? shiftId,
    String? shiftName,
    String? businessDate,
    String? fromUserId,
    String? fromUserName,
    String? fromUserRole,
    String? toUserId,
    String? toUserName,
    String? toUserRole,
    int? amountPaise,
    CashHandoverStatus? status,
    DateTime? createdAt,
    String? timeString,
    DateTime? respondedAt,
    String? note,
    String? linkedEntryId,
  }) {
    return CashHandoverRecord(
      id: id ?? this.id,
      shiftId: shiftId ?? this.shiftId,
      shiftName: shiftName ?? this.shiftName,
      businessDate: businessDate ?? this.businessDate,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserName: fromUserName ?? this.fromUserName,
      fromUserRole: fromUserRole ?? this.fromUserRole,
      toUserId: toUserId ?? this.toUserId,
      toUserName: toUserName ?? this.toUserName,
      toUserRole: toUserRole ?? this.toUserRole,
      amountPaise: amountPaise ?? this.amountPaise,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      timeString: timeString ?? this.timeString,
      respondedAt: respondedAt ?? this.respondedAt,
      note: note ?? this.note,
      linkedEntryId: linkedEntryId ?? this.linkedEntryId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shiftId': shiftId,
      'shiftName': shiftName,
      'businessDate': businessDate,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'fromUserRole': fromUserRole,
      'toUserId': toUserId,
      'toUserName': toUserName,
      'toUserRole': toUserRole,
      'amountPaise': amountPaise,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'timeString': timeString,
      'respondedAt': respondedAt?.toIso8601String(),
      'note': note,
      'linkedEntryId': linkedEntryId,
    };
  }

  factory CashHandoverRecord.fromMap(Map<String, dynamic> map) {
    final created = map['createdAt'] != null
        ? (DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
        : DateTime.now();
    return CashHandoverRecord(
      id: (map['id'] ?? '').toString(),
      shiftId: (map['shiftId'] ?? '').toString(),
      shiftName: (map['shiftName'] ?? 'Morning').toString(),
      businessDate: (map['businessDate'] ?? DateFormatter.formatDisplayDate(created)).toString(),
      fromUserId: (map['fromUserId'] ?? '').toString(),
      fromUserName: (map['fromUserName'] ?? '').toString(),
      fromUserRole: (map['fromUserRole'] ?? 'shiftStaff').toString(),
      toUserId: (map['toUserId'] ?? '').toString(),
      toUserName: (map['toUserName'] ?? '').toString(),
      toUserRole: (map['toUserRole'] ?? 'owner').toString(),
      amountPaise: (map['amountPaise'] is int)
          ? map['amountPaise'] as int
          : int.tryParse((map['amountPaise'] ?? '0').toString()) ?? 0,
      status: CashHandoverStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => CashHandoverStatus.pending,
      ),
      createdAt: created,
      timeString: (map['timeString'] ?? DateFormatter.formatDisplayTime(created)).toString(),
      respondedAt: map['respondedAt'] != null
          ? DateTime.tryParse(map['respondedAt'].toString())
          : null,
      note: map['note']?.toString(),
      linkedEntryId: map['linkedEntryId']?.toString(),
    );
  }
}
