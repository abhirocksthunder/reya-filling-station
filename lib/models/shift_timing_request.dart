class ShiftTimingRequest {
  final String id;
  final String staffId;
  final String staffName;
  final String requestedShift; // e.g. "Morning", "Evening", "Night"
  final String timingRange; // e.g. "6:00 AM - 2:00 PM"
  final String reason;
  final String status; // "pending", "approved", "rejected"
  final DateTime requestedAt;

  const ShiftTimingRequest({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.requestedShift,
    this.timingRange = '',
    this.reason = '',
    this.status = 'pending',
    required this.requestedAt,
  });

  ShiftTimingRequest copyWith({
    String? id,
    String? staffId,
    String? staffName,
    String? requestedShift,
    String? timingRange,
    String? reason,
    String? status,
    DateTime? requestedAt,
  }) {
    return ShiftTimingRequest(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      requestedShift: requestedShift ?? this.requestedShift,
      timingRange: timingRange ?? this.timingRange,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'staffId': staffId,
    'staffName': staffName,
    'requestedShift': requestedShift,
    'timingRange': timingRange,
    'reason': reason,
    'status': status,
    'requestedAt': requestedAt.toIso8601String(),
  };

  factory ShiftTimingRequest.fromMap(Map<String, dynamic> map) => ShiftTimingRequest(
    id: map['id'] ?? '',
    staffId: map['staffId'] ?? '',
    staffName: map['staffName'] ?? '',
    requestedShift: map['requestedShift'] ?? '',
    timingRange: map['timingRange'] ?? '',
    reason: map['reason'] ?? '',
    status: map['status'] ?? 'pending',
    requestedAt: map['requestedAt'] != null
        ? DateTime.tryParse(map['requestedAt']) ?? DateTime.now()
        : DateTime.now(),
  );
}
