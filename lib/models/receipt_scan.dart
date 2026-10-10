import '../core/formatting/volume_formatter.dart';

enum ReceiptValidationStatus {
  valid,
  previousDayReceipt,
  stale,
  wrongPump,
  lowerCounter,
  duplicate;

  String get badgeText {
    switch (this) {
      case ReceiptValidationStatus.valid:
        return 'Verified reading';
      case ReceiptValidationStatus.previousDayReceipt:
        return 'Previous-day receipt';
      case ReceiptValidationStatus.stale:
        return 'Stale receipt';
      case ReceiptValidationStatus.wrongPump:
        return 'Pump mismatch';
      case ReceiptValidationStatus.lowerCounter:
        return 'Meter rollover/reduction';
      case ReceiptValidationStatus.duplicate:
        return 'Duplicate receipt';
    }
  }
}

class ReceiptScan {
  final String id;
  final String pumpSerialNumber; // e.g. "202501001272"
  final String fpId; // "1"
  final String printedDate; // "09/10/2026"
  final String printedTime; // "21:50:29"
  final Map<int, int> nozzleCumVolumeMl; // Nozzle 1 -> 169923720, Nozzle 2 -> 274487190
  final String imagePath;
  final String imageHash;
  final ReceiptValidationStatus validationStatus;
  final String statusMessage;
  final String capturedBy;
  final DateTime capturedAt;
  final bool locationVerified;
  final double distanceMeters;
  final String reviewStatus; // 'approved', 'pending', 'rejected'

  const ReceiptScan({
    required this.id,
    required this.pumpSerialNumber,
    this.fpId = '1',
    required this.printedDate,
    required this.printedTime,
    required this.nozzleCumVolumeMl,
    required this.imagePath,
    this.imageHash = '',
    required this.validationStatus,
    required this.statusMessage,
    required this.capturedBy,
    required this.capturedAt,
    this.locationVerified = true,
    this.distanceMeters = 24.0,
    this.reviewStatus = 'pending',
  });

  String formattedVolume(int nozzleNum) {
    int ml = nozzleCumVolumeMl[nozzleNum] ?? 0;
    return VolumeFormatter.formatMl(ml);
  }

  ReceiptScan copyWith({
    String? id,
    String? pumpSerialNumber,
    String? fpId,
    String? printedDate,
    String? printedTime,
    Map<int, int>? nozzleCumVolumeMl,
    String? imagePath,
    String? imageHash,
    ReceiptValidationStatus? validationStatus,
    String? statusMessage,
    String? capturedBy,
    DateTime? capturedAt,
    bool? locationVerified,
    double? distanceMeters,
    String? reviewStatus,
  }) {
    return ReceiptScan(
      id: id ?? this.id,
      pumpSerialNumber: pumpSerialNumber ?? this.pumpSerialNumber,
      fpId: fpId ?? this.fpId,
      printedDate: printedDate ?? this.printedDate,
      printedTime: printedTime ?? this.printedTime,
      nozzleCumVolumeMl: nozzleCumVolumeMl ?? this.nozzleCumVolumeMl,
      imagePath: imagePath ?? this.imagePath,
      imageHash: imageHash ?? this.imageHash,
      validationStatus: validationStatus ?? this.validationStatus,
      statusMessage: statusMessage ?? this.statusMessage,
      capturedBy: capturedBy ?? this.capturedBy,
      capturedAt: capturedAt ?? this.capturedAt,
      locationVerified: locationVerified ?? this.locationVerified,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      reviewStatus: reviewStatus ?? this.reviewStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pumpSerialNumber': pumpSerialNumber,
      'fpId': fpId,
      'printedDate': printedDate,
      'printedTime': printedTime,
      'nozzleCumVolumeMl': nozzleCumVolumeMl.map((k, v) => MapEntry(k.toString(), v)),
      'imagePath': imagePath,
      'imageHash': imageHash,
      'validationStatus': validationStatus.name,
      'statusMessage': statusMessage,
      'capturedBy': capturedBy,
      'capturedAt': capturedAt.toIso8601String(),
      'locationVerified': locationVerified,
      'distanceMeters': distanceMeters,
      'reviewStatus': reviewStatus,
    };
  }

  factory ReceiptScan.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> rawMap = map['nozzleCumVolumeMl'] ?? {};
    Map<int, int> parsedMap = {};
    rawMap.forEach((k, v) {
      parsedMap[int.tryParse(k) ?? 1] = (v as num).toInt();
    });

    final capturedBy = map['capturedBy'] ?? '';
    final isOwner = capturedBy.toString().toLowerCase().contains('owner');

    return ReceiptScan(
      id: map['id'] ?? '',
      pumpSerialNumber: map['pumpSerialNumber'] ?? '',
      fpId: map['fpId'] ?? '1',
      printedDate: map['printedDate'] ?? '',
      printedTime: map['printedTime'] ?? '',
      nozzleCumVolumeMl: parsedMap,
      imagePath: map['imagePath'] ?? '',
      imageHash: map['imageHash'] ?? '',
      validationStatus: ReceiptValidationStatus.values.firstWhere(
        (v) => v.name == map['validationStatus'],
        orElse: () => ReceiptValidationStatus.valid,
      ),
      statusMessage: map['statusMessage'] ?? '',
      capturedBy: capturedBy,
      capturedAt: DateTime.tryParse(map['capturedAt'] ?? '') ?? DateTime.now(),
      locationVerified: map['locationVerified'] ?? true,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 24.0,
      reviewStatus: map['reviewStatus'] ?? (isOwner ? 'approved' : 'pending'),
    );
  }
}
