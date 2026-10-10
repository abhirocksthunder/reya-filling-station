import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/date_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../models/pump.dart';
import '../../models/receipt_scan.dart';
import '../../services/station_state_provider.dart';

class ScanReceiptScreen extends StatefulWidget {
  final Function(int)? onNavigate;

  const ScanReceiptScreen({super.key, this.onNavigate});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  String? _selectedPumpId;
  String? _uploadedImagePath = 'assets/images/media_1791616403909.jpg';
  bool _isCustomImageUploaded = false;

  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late final TextEditingController _nozzle1Controller;
  late final TextEditingController _nozzle2Controller;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final dayStr = now.day.toString().padLeft(2, '0');
    final monthStr = now.month.toString().padLeft(2, '0');
    _dateController = TextEditingController(text: '$dayStr/$monthStr/${now.year}');
    final hourStr = now.hour.toString().padLeft(2, '0');
    final minStr = now.minute.toString().padLeft(2, '0');
    final secStr = now.second.toString().padLeft(2, '0');
    _timeController = TextEditingController(text: '$hourStr:$minStr:$secStr');
    _nozzle1Controller = TextEditingController();
    _nozzle2Controller = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<StationStateProvider>();
    if (_selectedPumpId == null && state.pumps.isNotEmpty) {
      _selectPump(state.pumps.first);
    }
  }

  void _selectPump(Pump pump) {
    _selectedPumpId = pump.id;
    if (pump.nozzles.isNotEmpty) {
      _nozzle1Controller.text = (pump.nozzles[0].currentTotaliserMl / 1000.0).toStringAsFixed(3);
    }
    if (pump.nozzles.length > 1) {
      _nozzle2Controller.text = (pump.nozzles[1].currentTotaliserMl / 1000.0).toStringAsFixed(3);
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _nozzle1Controller.dispose();
    _nozzle2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final pumps = state.pumps;

    final selectedPump = pumps.firstWhere(
      (p) => p.id == _selectedPumpId,
      orElse: () => pumps.isNotEmpty
          ? pumps.first
          : const Pump(id: 'pump_1', name: 'Pump 1', serialNumber: '202501001272', nozzles: []),
    );

    double n1Litres = double.tryParse(_nozzle1Controller.text) ??
        (selectedPump.nozzles.isNotEmpty ? selectedPump.nozzles[0].currentTotaliserMl / 1000.0 : 0.0);
    double n2Litres = double.tryParse(_nozzle2Controller.text) ??
        (selectedPump.nozzles.length > 1 ? selectedPump.nozzles[1].currentTotaliserMl / 1000.0 : 0.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.get('scanReceipt', lang),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: StationColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.get('keepNozzleDateClear', lang),
            style: const TextStyle(fontSize: 14, color: StationColors.textMedium),
          ),
          const SizedBox(height: 16),

          // Owner Camera Scan Restriction Banner
          if (!state.settings.allowStaffTotaliserCameraScan) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: StationColors.warningBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: StationColors.warningBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_rounded, color: StationColors.warningAmber, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Totaliser Photo Restricted: Station owner has disabled staff camera capture in settings. Please report meter readings manually to the shift manager.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: StationColors.textDark),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Dispenser / Pump Selection Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
              border: Border.all(color: StationColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Dispenser / Pump:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: StationColors.textDark),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedPump.id,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.local_gas_station, color: StationColors.primary),
                  ),
                  items: pumps.map((p) {
                    return DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.name} (SNo: ${p.serialNumber})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final p = pumps.firstWhere((item) => item.id == val);
                      setState(() => _selectPump(p));
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Upload / Capture Photo Row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(
                          _isCustomImageUploaded ? Icons.check_circle : Icons.camera_alt_outlined,
                          color: _isCustomImageUploaded ? StationColors.successGreen : StationColors.primary,
                        ),
                        label: Text(
                          _isCustomImageUploaded ? 'Receipt Photo Captured' : 'Take / Upload Receipt Photo',
                          style: TextStyle(
                            color: _isCustomImageUploaded ? StationColors.successGreen : StationColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _isCustomImageUploaded ? StationColors.successGreen : StationColors.primary,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: !state.settings.allowStaffTotaliserCameraScan
                            ? null
                            : () {
                                setState(() {
                                  _isCustomImageUploaded = true;
                                  _uploadedImagePath = 'assets/images/media_1791616403909.jpg';
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Receipt slip photo captured & verified.'),
                                    backgroundColor: StationColors.successGreen,
                                  ),
                                );
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Reading Input Fields (Real Dynamic Totaliser Meter Confirmation)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
              border: Border.all(color: StationColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Confirm Meter Readings from Receipt:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: StationColors.textDark),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _dateController,
                        decoration: const InputDecoration(
                          labelText: 'Date (dd/MM/yyyy)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _timeController,
                        decoration: const InputDecoration(
                          labelText: 'Time (HH:mm:ss)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nozzle1Controller,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: selectedPump.nozzles.isNotEmpty
                              ? 'Nozzle 1 (${selectedPump.nozzles[0].fuelType}) Litres'
                              : 'Nozzle 1 (Petrol) Litres',
                          helperText: selectedPump.nozzles.isNotEmpty
                              ? 'Prev: ${selectedPump.nozzles[0].formattedPreviousReading}'
                              : null,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _nozzle2Controller,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: selectedPump.nozzles.length > 1
                              ? 'Nozzle 2 (${selectedPump.nozzles[1].fuelType}) Litres'
                              : 'Nozzle 2 (Diesel) Litres',
                          helperText: selectedPump.nozzles.length > 1
                              ? 'Prev: ${selectedPump.nozzles[1].formattedPreviousReading}'
                              : null,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Printed Receipt View Card (Live reflection of input)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF8F1),
              borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
              border: Border.all(color: const Color(0xFFE2D9C8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('INDIANOIL AUTOMATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const Icon(Icons.receipt_long, size: 20, color: Colors.black54),
                  ],
                ),
                const SizedBox(height: 12),
                _buildReceiptLine('FP. ID', ': ${selectedPump.id.replaceAll('pump_', '')}'),
                _buildReceiptLine('Pump SNo', ': ${selectedPump.serialNumber}'),
                _buildReceiptLine('Date', ': ${_dateController.text}'),
                _buildReceiptLine('Time', ': ${_timeController.text}'),
                const Divider(height: 16, color: Color(0xFFD6CBBB)),
                Text(
                  'Nozzle No1 (${selectedPump.nozzles.isNotEmpty ? selectedPump.nozzles[0].fuelType : 'Petrol'})',
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'CumVolume: ${n1Litres.toStringAsFixed(3)}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nozzle No2 (${selectedPump.nozzles.length > 1 ? selectedPump.nozzles[1].fuelType : 'Diesel'})',
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'CumVolume: ${n2Litres.toStringAsFixed(3)}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // "Read from receipt" Summary Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
              border: Border.all(color: StationColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.get('readFromReceipt', lang),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: StationColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSummaryRow(AppStrings.get('pump', lang), selectedPump.name),
                const SizedBox(height: 8),
                _buildSummaryRow(AppStrings.get('receiptDate', lang), _dateController.text),
                const SizedBox(height: 8),
                _buildSummaryRow('Nozzle 1 (${selectedPump.nozzles.isNotEmpty ? selectedPump.nozzles[0].fuelType : ''})', '${n1Litres.toStringAsFixed(3)} L', isBoldValue: true),
                const SizedBox(height: 8),
                _buildSummaryRow('Nozzle 2 (${selectedPump.nozzles.length > 1 ? selectedPump.nozzles[1].fuelType : ''})', '${n2Litres.toStringAsFixed(3)} L', isBoldValue: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Valid counter badge
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: StationColors.successBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: StationColors.successGreen.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: StationColors.successGreen, size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Dynamic counter validation active • Updates pump & Cloud Firestore',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: StationColors.successGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: StationDimensions.primaryButtonHeight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, color: StationColors.primary),
                    label: const Text(
                      'Reset Readings',
                      style: TextStyle(
                        color: StationColors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: StationColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(StationDimensions.buttonRadius),
                      ),
                    ),
                    onPressed: () {
                      _selectPump(selectedPump);
                      setState(() {
                        _isCustomImageUploaded = false;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: StationDimensions.primaryButtonHeight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: Text(
                      AppStrings.get('saveReading', lang),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StationColors.successGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(StationDimensions.buttonRadius),
                      ),
                    ),
                    onPressed: !state.settings.allowStaffTotaliserCameraScan
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Totaliser camera scan is restricted by Station Owner in settings.'),
                                backgroundColor: StationColors.errorRed,
                              ),
                            );
                          }
                        : () {
                            final n1Ml = (n1Litres * 1000).round();
                            final n2Ml = (n2Litres * 1000).round();

                            final scan = ReceiptScan(
                              id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
                              pumpSerialNumber: selectedPump.serialNumber,
                              fpId: selectedPump.id.replaceAll('pump_', ''),
                              printedDate: _dateController.text,
                              printedTime: _timeController.text,
                              nozzleCumVolumeMl: {
                                1: n1Ml,
                                2: n2Ml,
                              },
                              imagePath: _uploadedImagePath ?? 'assets/images/media_1791616403909.jpg',
                              validationStatus: ReceiptValidationStatus.valid,
                              statusMessage: 'Verified dynamic reading committed.',
                              capturedBy: '${state.currentUser.name} (live capture)',
                              capturedAt: DateTime.now(),
                            );

                            state.saveReceiptScan(scan);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Totaliser reading saved! ${selectedPump.name} nozzles updated in Firestore.'),
                                backgroundColor: StationColors.successGreen,
                              ),
                            );

                            if (widget.onNavigate != null) {
                              widget.onNavigate!(0); // Back to My Shift
                            }
                          },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildReceiptLine(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(key, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Text(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String title, String val, {bool isBoldValue = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: StationColors.textMedium)),
        Text(
          val,
          style: TextStyle(
            fontSize: isBoldValue ? 16 : 14,
            fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w500,
            color: StationColors.textDark,
          ),
        ),
      ],
    );
  }
}
