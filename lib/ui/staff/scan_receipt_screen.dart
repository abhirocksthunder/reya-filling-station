import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/date_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../models/pump.dart';
import '../../models/receipt_scan.dart';
import '../../services/station_state_provider.dart';
import '../../services/ocr_service.dart';
import 'package:image_picker/image_picker.dart';

class ScanReceiptScreen extends StatefulWidget {
  final Function(int)? onNavigate;

  const ScanReceiptScreen({super.key, this.onNavigate});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  String? _selectedPumpId;
  String? _uploadedImagePath;
  bool _isCustomImageUploaded = false;
  bool _isProcessingOcr = false;
  bool _isValidatedByOcr = false;
  bool _isStrictVerified = false;
  double _ocrConfidence = 1.0;
  String? _ocrErrorMessage;
  Map<int, String> _matchedSnippets = {};
  String _ocrRawText = '';

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
    if (state.activeScanPumpId != null && state.activeScanPumpId != _selectedPumpId) {
      final targetPump = state.pumps.firstWhere(
        (p) => p.id == state.activeScanPumpId,
        orElse: () => state.pumps.first,
      );
      _selectPump(targetPump);
    } else if (_selectedPumpId == null && state.pumps.isNotEmpty) {
      _selectPump(state.pumps.first);
    }
  }

  void _selectPump(Pump pump) {
    _selectedPumpId = pump.id;
    _isCustomImageUploaded = false;
    _uploadedImagePath = null;
    _isValidatedByOcr = false;
    _isStrictVerified = false;
    _matchedSnippets = {};
    _ocrRawText = '';
    _ocrErrorMessage = null;
    _nozzle1Controller.clear();
    _nozzle2Controller.clear();
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

    final double prevN1 = selectedPump.nozzles.isNotEmpty
        ? (selectedPump.nozzles[0].currentTotaliserMl / 1000.0)
        : 0.0;
    final double prevN2 = selectedPump.nozzles.length > 1
        ? (selectedPump.nozzles[1].currentTotaliserMl / 1000.0)
        : 0.0;

    double n1Litres = double.tryParse(_nozzle1Controller.text) ?? prevN1;
    double n2Litres = double.tryParse(_nozzle2Controller.text) ?? prevN2;

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
                      setState(() {
                        _selectPump(p);
                        _isCustomImageUploaded = false;
                        _uploadedImagePath = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Upload / Capture Photo Row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: _isProcessingOcr
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: StationColors.primary),
                              )
                            : const Icon(
                                Icons.camera_alt_outlined,
                                color: StationColors.primary,
                              ),
                        label: Text(
                          _isProcessingOcr ? 'Extracting with OCR...' : 'Capture Photo',
                          style: const TextStyle(
                            color: StationColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: StationColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: (!state.settings.allowStaffTotaliserCameraScan || _isProcessingOcr)
                            ? null
                            : () => _captureOrUploadReceiptPhoto(context),
                      ),
                    ),
                  ],
                ),
                if (_isCustomImageUploaded && _uploadedImagePath != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: StationColors.successBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: StationColors.successGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: StationColors.successGreen, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Photo attached: ${_uploadedImagePath!.split(RegExp(r"[\\/]")).last}',
                            style: const TextStyle(fontSize: 12, color: StationColors.successGreen, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                        maxLength: 10,
                        inputFormatters: [LengthLimitingTextInputFormatter(10)],
                        decoration: const InputDecoration(
                          labelText: 'Date (dd/MM/yyyy)',
                          counterText: '',
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
                        maxLength: 8,
                        inputFormatters: [LengthLimitingTextInputFormatter(8)],
                        decoration: const InputDecoration(
                          labelText: 'Time (HH:mm:ss)',
                          counterText: '',
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
                        maxLength: 15,
                        inputFormatters: [LengthLimitingTextInputFormatter(15)],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: selectedPump.nozzles.isNotEmpty
                              ? 'Nozzle 1 (${selectedPump.nozzles[0].fuelType}) Litres'
                              : 'Nozzle 1 (Petrol) Litres',
                          helperText: selectedPump.nozzles.isNotEmpty
                              ? 'Prev: ${selectedPump.nozzles[0].formattedPreviousReading}'
                              : null,
                          counterText: '',
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
                        maxLength: 15,
                        inputFormatters: [LengthLimitingTextInputFormatter(15)],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: selectedPump.nozzles.length > 1
                              ? 'Nozzle 2 (${selectedPump.nozzles[1].fuelType}) Litres'
                              : 'Nozzle 2 (Diesel) Litres',
                          helperText: selectedPump.nozzles.length > 1
                              ? 'Prev: ${selectedPump.nozzles[1].formattedPreviousReading}'
                              : null,
                          counterText: '',
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

          // Single Authoritative Captured Receipt Block (Only shown when photo captured or entered)
          if (_isCustomImageUploaded || _isValidatedByOcr) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: StationColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: StationColors.primary.withOpacity(0.2)),
                        ),
                        child: const Text(
                          'Reya filling station receipt capture',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: StationColors.primary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _isValidatedByOcr ? StationColors.successBg : StationColors.warningBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _isValidatedByOcr
                              ? (_isStrictVerified ? '✓ Strict Slip Match (100%)' : '✓ OCR Validated')
                              : '⚠️ Verification Required',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isValidatedByOcr ? StationColors.successGreen : StationColors.warningAmber,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildReceiptLine('Dispenser', ': ${selectedPump.name} (SNo: ${selectedPump.serialNumber})'),
                  _buildReceiptLine('FP. ID', ': ${selectedPump.id.replaceAll('pump_', '')}'),
                  _buildReceiptLine('Date', ': ${_dateController.text}'),
                  _buildReceiptLine('Time', ': ${_timeController.text}'),
                  const Divider(height: 18, color: Color(0xFFD6CBBB)),
                  _buildSummaryRow(
                    'Nozzle 1 (${selectedPump.nozzles.isNotEmpty ? selectedPump.nozzles[0].fuelType : 'Petrol'})',
                    '${n1Litres.toStringAsFixed(3)} L',
                    isBoldValue: true,
                  ),
                  if (selectedPump.nozzles.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        'Baseline: ${selectedPump.nozzles[0].formattedPreviousReading} • Delta: ${n1Litres >= prevN1 ? "+${(n1Litres - prevN1).toStringAsFixed(3)} L" : "${(n1Litres - prevN1).toStringAsFixed(3)} L (LOWER THAN BASELINE)"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: n1Litres < prevN1 ? FontWeight.bold : FontWeight.normal,
                          color: n1Litres < prevN1 ? StationColors.errorRed : StationColors.textLight,
                        ),
                      ),
                    ),
                  ],
                  if (_matchedSnippets.containsKey(1)) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'Matched on Slip: "${_matchedSnippets[1]}"',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: StationColors.textDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    'Nozzle 2 (${selectedPump.nozzles.length > 1 ? selectedPump.nozzles[1].fuelType : 'Diesel'})',
                    '${n2Litres.toStringAsFixed(3)} L',
                    isBoldValue: true,
                  ),
                  if (selectedPump.nozzles.length > 1) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        'Baseline: ${selectedPump.nozzles[1].formattedPreviousReading} • Delta: ${n2Litres >= prevN2 ? "+${(n2Litres - prevN2).toStringAsFixed(3)} L" : "${(n2Litres - prevN2).toStringAsFixed(3)} L (LOWER THAN BASELINE)"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: n2Litres < prevN2 ? FontWeight.bold : FontWeight.normal,
                          color: n2Litres < prevN2 ? StationColors.errorRed : StationColors.textLight,
                        ),
                      ),
                    ),
                  ],
                  if (_matchedSnippets.containsKey(2)) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'Matched on Slip: "${_matchedSnippets[2]}"',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: StationColors.textDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_ocrRawText.isNotEmpty) ...[
                    const Divider(height: 18, color: Color(0xFFD6CBBB)),
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text(
                          'View Full Receipt OCR Text (Audit)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: StationColors.primary),
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: SelectableText(
                              _ocrRawText,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: StationColors.textDark,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

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
                    'Dynamic counter validation active • Updates pump & central records',
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
          Builder(
            builder: (context) {
              final bool canSave = state.settings.allowStaffTotaliserCameraScan &&
                  _isCustomImageUploaded &&
                  _uploadedImagePath != null &&
                  !_isProcessingOcr &&
                  _isValidatedByOcr;

              return Column(
                children: [
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
                              setState(() {
                                _dateController.clear();
                                _timeController.clear();
                                _nozzle1Controller.clear();
                                _nozzle2Controller.clear();
                                _isCustomImageUploaded = false;
                                _uploadedImagePath = null;
                                _isValidatedByOcr = false;
                                _isStrictVerified = false;
                                _matchedSnippets = {};
                                _ocrRawText = '';
                                _ocrErrorMessage = null;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Readings cleared and receipt capture reset.')),
                              );
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
                              backgroundColor: canSave ? StationColors.successGreen : Colors.grey.shade400,
                              elevation: canSave ? 1 : 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(StationDimensions.buttonRadius),
                              ),
                            ),
                            onPressed: canSave
                                ? () {
                                    // Validation gate 2: Meter readings must have changed from previous/baseline readings
                                    final double prevN1 = selectedPump.nozzles.isNotEmpty
                                        ? (selectedPump.nozzles[0].currentTotaliserMl / 1000.0)
                                        : 0.0;
                                    final double prevN2 = selectedPump.nozzles.length > 1
                                        ? (selectedPump.nozzles[1].currentTotaliserMl / 1000.0)
                                        : 0.0;

                                    final bool n1Changed = (n1Litres - prevN1).abs() > 0.0001;
                                    final bool n2Changed = (n2Litres - prevN2).abs() > 0.0001;

                                    if (!n1Changed && !n2Changed) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('No changes detected in readings. Enter new readings from the captured receipt.'),
                                          backgroundColor: StationColors.errorRed,
                                        ),
                                      );
                                      return;
                                    }

                                    if (n1Litres < prevN1 || n2Litres < prevN2) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('New readings cannot be lower than the previous baseline reading.'),
                                          backgroundColor: StationColors.errorRed,
                                        ),
                                      );
                                      return;
                                    }

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
                                      imagePath: _uploadedImagePath!,
                                      validationStatus: ReceiptValidationStatus.valid,
                                      statusMessage: 'Verified dynamic reading committed via OCR capture.',
                                      capturedBy: '${state.currentUser.name} (live capture)',
                                      capturedAt: DateTime.now(),
                                    );

                                    state.saveReceiptScan(scan);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Totaliser reading saved! ${selectedPump.name} nozzles updated successfully.'),
                                        backgroundColor: StationColors.successGreen,
                                      ),
                                    );

                                    if (widget.onNavigate != null) {
                                      widget.onNavigate!(0); // Back to My Shift
                                    }
                                  }
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!canSave) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        !state.settings.allowStaffTotaliserCameraScan
                            ? 'Scanning restricted by owner in settings'
                            : (!_isCustomImageUploaded || !_isValidatedByOcr)
                                ? '🔒 Capture photo and validate using OCR to enable save'
                                : 'Processing OCR verification...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _captureOrUploadReceiptPhoto(BuildContext context) async {
    final picker = ImagePicker();
    final XFile? photo = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: StationColors.primary),
              title: const Text('Open Camera (Take Photo)'),
              onTap: () async {
                final f = await picker.pickImage(source: ImageSource.camera);
                Navigator.pop(ctx, f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: StationColors.primary),
              title: const Text('Select from Gallery / Storage'),
              onTap: () async {
                final f = await picker.pickImage(source: ImageSource.gallery);
                Navigator.pop(ctx, f);
              },
            ),
          ],
        ),
      ),
    );

    if (photo != null) {
      setState(() {
        _isProcessingOcr = true;
      });

      try {
        String effectivePath = photo.path;
        if (kIsWeb) {
          try {
            final bytes = await photo.readAsBytes();
            if (bytes.isNotEmpty) {
              final base64Data = base64Encode(bytes);
              final mime = photo.mimeType ?? 'image/png';
              effectivePath = 'data:$mime;base64,$base64Data';
            }
          } catch (e) {
            debugPrint('Could not read image bytes on web: $e');
          }
        }

        final extraction = await OcrService.processReceiptImage(
          effectivePath,
          targetPumpId: _selectedPumpId,
        );

        if (!mounted) return;

        final displayFileName = photo.name.isNotEmpty ? photo.name : photo.path;

        if (!extraction.success) {
          setState(() {
            _isProcessingOcr = false;
            _isCustomImageUploaded = true;
            _uploadedImagePath = displayFileName;
            _isValidatedByOcr = false;
            _isStrictVerified = false;
            _ocrErrorMessage = extraction.errorMessage ?? 'Could not read meter readings from receipt.';
            _ocrRawText = extraction.rawText;
            _dateController.clear();
            _timeController.clear();
            _nozzle1Controller.clear();
            _nozzle2Controller.clear();
            _matchedSnippets = {};
          });

          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: StationColors.accentOrange, size: 28),
                  SizedBox(width: 8),
                  Text('OCR Scan Incomplete', style: TextStyle(fontWeight: FontWeight.bold, color: StationColors.textDark)),
                ],
              ),
              content: Text(
                '${extraction.errorMessage ?? "Could not clearly identify nozzle CumVolume lines."}\n\nPlease verify that the receipt photo is flat, well-lit, and not blurred. You can retake the photo or enter values manually.',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: StationColors.primary),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          return;
        }

        final state = context.read<StationStateProvider>();
        final selectedPump = state.pumps.firstWhere(
          (p) => p.id == _selectedPumpId,
          orElse: () => state.pumps.first,
        );

        // Strict Wrong Pump validation gate
        final receiptPumpSNo = extraction.pumpSerialNumber.trim();
        final receiptFpId = extraction.fpId.trim();
        final expectedSNo = selectedPump.serialNumber.trim();
        final expectedFpId = selectedPump.id.replaceAll('pump_', '').trim();

        final bool matchesSNo = receiptPumpSNo.isNotEmpty && receiptPumpSNo == expectedSNo;
        final bool matchesFp = receiptFpId.isNotEmpty && receiptFpId == expectedFpId;

        if (!matchesSNo && !matchesFp) {
          setState(() {
            _isProcessingOcr = false;
            _isCustomImageUploaded = false;
            _uploadedImagePath = null;
            _isValidatedByOcr = false;
            _isStrictVerified = false;
            _dateController.clear();
            _timeController.clear();
            _nozzle1Controller.clear();
            _nozzle2Controller.clear();
            _matchedSnippets = {};
            _ocrRawText = '';
            _ocrErrorMessage = null;
          });

          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.cancel_outlined, color: StationColors.errorRed, size: 28),
                  SizedBox(width: 8),
                  Text('Wrong pump', style: TextStyle(fontWeight: FontWeight.bold, color: StationColors.errorRed)),
                ],
              ),
              content: Text(
                'Wrong pump! The uploaded receipt has Pump SNo "$receiptPumpSNo" (FP ID: $receiptFpId), but ${selectedPump.name} (SNo: $expectedSNo) is currently selected.\n\nPlease upload the receipt corresponding to ${selectedPump.name}.',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: StationColors.errorRed),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          return;
        }

        setState(() {
          _isCustomImageUploaded = true;
          _uploadedImagePath = displayFileName;
          _isProcessingOcr = false;
          _isValidatedByOcr = true;
          _isStrictVerified = extraction.isStrictMatch;
          _ocrConfidence = extraction.confidence;
          _matchedSnippets = extraction.nozzleMatchedSnippet;
          _ocrRawText = extraction.rawText;
          _ocrErrorMessage = null;

          if (extraction.date.isNotEmpty) {
            _dateController.text = extraction.date;
          }
          if (extraction.time.isNotEmpty) {
            _timeController.text = extraction.time;
          }

          if (extraction.nozzleLitres.containsKey(1)) {
            _nozzle1Controller.text = (extraction.nozzleLitres[1]!).toStringAsFixed(3);
          }
          if (extraction.nozzleLitres.containsKey(2)) {
            _nozzle2Controller.text = (extraction.nozzleLitres[2]!).toStringAsFixed(3);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Receipt validated for ${selectedPump.name}! Extracted Date: ${_dateController.text}, Time: ${_timeController.text}, CumVolume readings.',
            ),
            backgroundColor: StationColors.successGreen,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isProcessingOcr = false;
          _isCustomImageUploaded = true;
          _uploadedImagePath = photo.path;
          _isValidatedByOcr = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt image captured. (OCR note: $e)'),
            backgroundColor: StationColors.accentOrange,
          ),
        );
      }
    }
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
