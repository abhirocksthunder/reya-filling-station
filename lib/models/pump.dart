import '../core/formatting/currency_formatter.dart';
import '../core/formatting/volume_formatter.dart';

class Nozzle {
  final String id;
  final String pumpId;
  final int nozzleNumber;
  final String fuelType; // "Petrol" or "Diesel"
  final int ratePaisePerLitre; // e.g. 11752 paise = ₹117.52/L
  final int currentTotaliserMl; // e.g. 169923720 mL = 169,923.720 L
  final int previousAcceptedReadingMl; // e.g. 168676720 mL = 168,676.720 L
  final DateTime? previousReadingTimestamp;
  final bool active;

  const Nozzle({
    required this.id,
    required this.pumpId,
    required this.nozzleNumber,
    required this.fuelType,
    required this.ratePaisePerLitre,
    required this.currentTotaliserMl,
    required this.previousAcceptedReadingMl,
    this.previousReadingTimestamp,
    this.active = true,
  });

  String get displayName => 'Nozzle $nozzleNumber';
  String get formattedRate => CurrencyFormatter.formatRate(ratePaisePerLitre);
  String get formattedReading => VolumeFormatter.formatMl(currentTotaliserMl);
  String get formattedPreviousReading => VolumeFormatter.formatMl(previousAcceptedReadingMl);

  Nozzle copyWith({
    String? id,
    String? pumpId,
    int? nozzleNumber,
    String? fuelType,
    int? ratePaisePerLitre,
    int? currentTotaliserMl,
    int? previousAcceptedReadingMl,
    DateTime? previousReadingTimestamp,
    bool? active,
  }) {
    return Nozzle(
      id: id ?? this.id,
      pumpId: pumpId ?? this.pumpId,
      nozzleNumber: nozzleNumber ?? this.nozzleNumber,
      fuelType: fuelType ?? this.fuelType,
      ratePaisePerLitre: ratePaisePerLitre ?? this.ratePaisePerLitre,
      currentTotaliserMl: currentTotaliserMl ?? this.currentTotaliserMl,
      previousAcceptedReadingMl: previousAcceptedReadingMl ?? this.previousAcceptedReadingMl,
      previousReadingTimestamp: previousReadingTimestamp ?? this.previousReadingTimestamp,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pumpId': pumpId,
      'nozzleNumber': nozzleNumber,
      'fuelType': fuelType,
      'ratePaisePerLitre': ratePaisePerLitre,
      'currentTotaliserMl': currentTotaliserMl,
      'previousAcceptedReadingMl': previousAcceptedReadingMl,
      'previousReadingTimestamp': previousReadingTimestamp?.toIso8601String(),
      'active': active,
    };
  }

  factory Nozzle.fromMap(Map<String, dynamic> map) {
    return Nozzle(
      id: map['id'] ?? '',
      pumpId: map['pumpId'] ?? '',
      nozzleNumber: map['nozzleNumber'] ?? 1,
      fuelType: map['fuelType'] ?? 'Petrol',
      ratePaisePerLitre: map['ratePaisePerLitre'] ?? 0,
      currentTotaliserMl: map['currentTotaliserMl'] ?? 0,
      previousAcceptedReadingMl: map['previousAcceptedReadingMl'] ?? 0,
      previousReadingTimestamp: map['previousReadingTimestamp'] != null
          ? DateTime.tryParse(map['previousReadingTimestamp'])
          : null,
      active: map['active'] ?? true,
    );
  }
}

class Pump {
  final String id;
  final String name; // e.g. "Pump 1"
  final String serialNumber; // e.g. "202501001272"
  final bool active;
  final List<Nozzle> nozzles;
  final String templateVersion; // "v1"
  final String? referenceReceiptAsset;

  const Pump({
    required this.id,
    required this.name,
    required this.serialNumber,
    this.active = true,
    required this.nozzles,
    this.templateVersion = 'v1',
    this.referenceReceiptAsset,
  });

  Pump copyWith({
    String? id,
    String? name,
    String? serialNumber,
    bool? active,
    List<Nozzle>? nozzles,
    String? templateVersion,
    String? referenceReceiptAsset,
  }) {
    return Pump(
      id: id ?? this.id,
      name: name ?? this.name,
      serialNumber: serialNumber ?? this.serialNumber,
      active: active ?? this.active,
      nozzles: nozzles ?? this.nozzles,
      templateVersion: templateVersion ?? this.templateVersion,
      referenceReceiptAsset: referenceReceiptAsset ?? this.referenceReceiptAsset,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'serialNumber': serialNumber,
      'active': active,
      'nozzles': nozzles.map((n) => n.toMap()).toList(),
      'templateVersion': templateVersion,
      'referenceReceiptAsset': referenceReceiptAsset,
    };
  }

  factory Pump.fromMap(Map<String, dynamic> map) {
    return Pump(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      serialNumber: map['serialNumber'] ?? '',
      active: map['active'] ?? true,
      nozzles: (map['nozzles'] as List? ?? []).map((n) => Nozzle.fromMap(n)).toList(),
      templateVersion: map['templateVersion'] ?? 'v1',
      referenceReceiptAsset: map['referenceReceiptAsset'],
    );
  }
}
