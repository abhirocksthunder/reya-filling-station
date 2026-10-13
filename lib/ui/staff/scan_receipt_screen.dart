import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../l10n/app_strings.dart';
import '../../models/pump.dart';
import '../../models/receipt_scan.dart';
import '../../services/station_state_provider.dart';
import '../../services/ocr_service.dart';
import '../../services/remote_logging_service.dart';
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
  String? _uploadedImageDataUri;
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
  late final TextEditingController _nozzle1RateController;
  late final TextEditingController _nozzle2RateController;

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
    _nozzle1RateController = TextEditingController(text: '105.71');
    _nozzle2RateController = TextEditingController(text: '98.50');
    RemoteLoggingService().logScreenView('ScanReceiptScreen');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<StationStateProvider>().refreshCurrentUserLocation(silent: true);
      }
    });
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
    _uploadedImageDataUri = null;
    _isValidatedByOcr = false;
    _isStrictVerified = false;
    _matchedSnippets = {};
    _ocrRawText = '';
    _ocrErrorMessage = null;
    _nozzle1Controller.clear();
    _nozzle2Controller.clear();
    if (pump.nozzles.isNotEmpty) {
      _nozzle1RateController.text = (pump.nozzles[0].ratePaisePerLitre / 100.0).toStringAsFixed(2);
    } else {
      _nozzle1RateController.text = '105.71';
    }
    if (pump.nozzles.length > 1) {
      _nozzle2RateController.text = (pump.nozzles[1].ratePaisePerLitre / 100.0).toStringAsFixed(2);
    } else {
      _nozzle2RateController.text = '98.50';
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _nozzle1Controller.dispose();
    _nozzle2Controller.dispose();
    _nozzle1RateController.dispose();
    _nozzle2RateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final pumps = state.pumps;
    final double? curLat = state.currentUser.lastLatitude;
    final double? curLon = state.currentUser.lastLongitude;
    final double curDist = state.currentUser.lastDistanceMeters ?? 0.0;
    final double? curAcc = state.currentUser.lastAccuracyMeters;
    final bool isInsidePerimeter = state.currentUser.isAtStation ?? true;

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
          const SizedBox(height: 14),

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
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.local_gas_station, color: StationColors.primary),
                  ),
                  items: pumps.map((p) {
                    return DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        '${p.name} (SNo: ${p.serialNumber})',
                        overflow: TextOverflow.ellipsis,
                      ),
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
                    if (state.settings.canUserSeeOcrDebug(state.currentUser)) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'OCR Diagnostics & Debugger',
                        icon: const Icon(Icons.bug_report_outlined, color: StationColors.accentOrange),
                        style: IconButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.all(12),
                        ),
                        onPressed: () => _showOcrDiagnosticsDialog(context),
                      ),
                    ],
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
                        InkWell(
                          onTap: () => _showOcrDiagnosticsDialog(context),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              'Debug Info',
                              style: TextStyle(
                                fontSize: 11,
                                color: StationColors.primary,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
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

          // Reading Input Fields (Real Dynamic Totaliser Meter Confirmation)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
              border: Border.all(color: StationColors.divider),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isWide = constraints.maxWidth >= 600;
                final String n1Fuel = selectedPump.nozzles.isNotEmpty
                    ? selectedPump.nozzles[0].fuelType
                    : 'Petrol';
                final String n2Fuel = selectedPump.nozzles.length > 1
                    ? selectedPump.nozzles[1].fuelType
                    : 'Diesel';
                final String? n1Prev = selectedPump.nozzles.isNotEmpty
                    ? selectedPump.nozzles[0].formattedPreviousReading
                    : null;
                final String? n2Prev = selectedPump.nozzles.length > 1
                    ? selectedPump.nozzles[1].formattedPreviousReading
                    : null;

                Widget buildNozzleSection({
                  required int nozzleNum,
                  required String fuelType,
                  required String? prevReading,
                  required TextEditingController readingController,
                  required TextEditingController rateController,
                }) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: StationColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Nozzle $nozzleNum ($fuelType)',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: StationColors.primary,
                              ),
                            ),
                            if (prevReading != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  'Prev: $prevReading',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: StationColors.textMedium,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: readingController,
                          maxLength: 15,
                          inputFormatters: [LengthLimitingTextInputFormatter(15)],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Nozzle $nozzleNum ($fuelType) Litres',
                            filled: true,
                            fillColor: Colors.white,
                            counterText: '',
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: rateController,
                          maxLength: 10,
                          inputFormatters: [LengthLimitingTextInputFormatter(10)],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Nozzle $nozzleNum ($fuelType) Rate (₹/L)',
                            helperText: 'Update if price changed',
                            helperMaxLines: 2,
                            prefixText: '₹ ',
                            filled: true,
                            fillColor: Colors.white,
                            counterText: '',
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
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
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: buildNozzleSection(
                              nozzleNum: 1,
                              fuelType: n1Fuel,
                              prevReading: n1Prev,
                              readingController: _nozzle1Controller,
                              rateController: _nozzle1RateController,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: buildNozzleSection(
                              nozzleNum: 2,
                              fuelType: n2Fuel,
                              prevReading: n2Prev,
                              readingController: _nozzle2Controller,
                              rateController: _nozzle2RateController,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      buildNozzleSection(
                        nozzleNum: 1,
                        fuelType: n1Fuel,
                        prevReading: n1Prev,
                        readingController: _nozzle1Controller,
                        rateController: _nozzle1RateController,
                      ),
                      const SizedBox(height: 12),
                      buildNozzleSection(
                        nozzleNum: 2,
                        fuelType: n2Fuel,
                        prevReading: n2Prev,
                        readingController: _nozzle2Controller,
                        rateController: _nozzle2RateController,
                      ),
                    ],
                  ],
                );
              },
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
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
                      child: Builder(
                        builder: (context) {
                          final double delta1 = n1Litres - prevN1;
                          final bool isLow1 = n1Litres < prevN1;
                          final bool isExcessive1 = prevN1 > 0 && delta1 > 25000.0;
                          final bool isError1 = isLow1 || isExcessive1;
                          final String deltaLabel1 = isLow1
                              ? '${delta1.toStringAsFixed(3)} L (LOWER THAN BASELINE)'
                              : isExcessive1
                                  ? '+${delta1.toStringAsFixed(3)} L (GAP TOO LARGE - SCAN TOTALISER AGAIN)'
                                  : '+${delta1.toStringAsFixed(3)} L';
                          return Text(
                            'Baseline: ${selectedPump.nozzles[0].formattedPreviousReading} • Delta: $deltaLabel1',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isError1 ? FontWeight.bold : FontWeight.normal,
                              color: isError1 ? StationColors.errorRed : StationColors.textLight,
                            ),
                          );
                        },
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
                      child: Builder(
                        builder: (context) {
                          final double delta2 = n2Litres - prevN2;
                          final bool isLow2 = n2Litres < prevN2;
                          final bool isExcessive2 = prevN2 > 0 && delta2 > 25000.0;
                          final bool isError2 = isLow2 || isExcessive2;
                          final String deltaLabel2 = isLow2
                              ? '${delta2.toStringAsFixed(3)} L (LOWER THAN BASELINE)'
                              : isExcessive2
                                  ? '+${delta2.toStringAsFixed(3)} L (GAP TOO LARGE - SCAN TOTALISER AGAIN)'
                                  : '+${delta2.toStringAsFixed(3)} L';
                          return Text(
                            'Baseline: ${selectedPump.nozzles[1].formattedPreviousReading} • Delta: $deltaLabel2',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isError2 ? FontWeight.bold : FontWeight.normal,
                              color: isError2 ? StationColors.errorRed : StationColors.textLight,
                            ),
                          );
                        },
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
              final bool hasBothNozzleReadings = _nozzle1Controller.text.trim().isNotEmpty &&
                  (selectedPump.nozzles.length < 2 || _nozzle2Controller.text.trim().isNotEmpty);
              final bool canSave = state.settings.allowStaffTotaliserCameraScan &&
                  _isCustomImageUploaded &&
                  _uploadedImagePath != null &&
                  !_isProcessingOcr &&
                  hasBothNozzleReadings;

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: StationDimensions.primaryButtonHeight,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.refresh, color: StationColors.primary, size: 18),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Reset Readings',
                                maxLines: 1,
                                style: TextStyle(
                                  color: StationColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
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
                                _uploadedImageDataUri = null;
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
                            icon: const Icon(Icons.check, color: Colors.white, size: 18),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                AppStrings.get('saveReading', lang),
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
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

                                    if (_nozzle1Controller.text.trim().isEmpty ||
                                        (selectedPump.nozzles.length >= 2 && _nozzle2Controller.text.trim().isEmpty)) {
                                      _showScanTotaliserAgainDialog(
                                        context,
                                        title: 'Scan Totaliser Again',
                                        message:
                                            'Both Nozzle 1 and Nozzle 2 readings are required for ${selectedPump.name}. Please scan the totaliser receipt again.',
                                      );
                                      return;
                                    }

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
                                      _showScanTotaliserAgainDialog(
                                        context,
                                        title: 'Scan Totaliser Again',
                                        message:
                                            'New readings cannot be lower than the previous baseline reading (Nozzle 1 Prev: ${prevN1.toStringAsFixed(3)} L, Nozzle 2 Prev: ${prevN2.toStringAsFixed(3)} L). Please scan the totaliser receipt again.',
                                      );
                                      return;
                                    }

                                    final bool excessiveN1 = prevN1 > 0 && (n1Litres - prevN1) > 25000.0;
                                    final bool excessiveN2 = prevN2 > 0 && (n2Litres - prevN2) > 25000.0;
                                    if (excessiveN1 || excessiveN2) {
                                      _showScanTotaliserAgainDialog(
                                        context,
                                        title: 'Scan Totaliser Again',
                                        message:
                                            'Abnormal reading gap detected (${excessiveN1 ? "Nozzle 1 gap: +${(n1Litres - prevN1).toStringAsFixed(3)} L" : "Nozzle 2 gap: +${(n2Litres - prevN2).toStringAsFixed(3)} L"}).\n\nDaily nozzle differences are typically 1,000 – 10,000 L and never in lakhs. Please scan the totaliser receipt again so the CumVolume below the CumVolume line is captured accurately.',
                                      );
                                      return;
                                    }

                                    final n1Ml = (n1Litres * 1000).round();
                                    final n2Ml = (n2Litres * 1000).round();

                                    final n1RateRupees = double.tryParse(_nozzle1RateController.text);
                                    final n2RateRupees = double.tryParse(_nozzle2RateController.text);
                                    final n1RatePaise = n1RateRupees != null && n1RateRupees > 0
                                        ? (n1RateRupees * 100).round()
                                        : (selectedPump.nozzles.isNotEmpty ? selectedPump.nozzles[0].ratePaisePerLitre : 10571);
                                    final n2RatePaise = n2RateRupees != null && n2RateRupees > 0
                                        ? (n2RateRupees * 100).round()
                                        : (selectedPump.nozzles.length > 1 ? selectedPump.nozzles[1].ratePaisePerLitre : 9850);

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
                                      nozzleRatesPaisePerLitre: {
                                        1: n1RatePaise,
                                        2: n2RatePaise,
                                      },
                                      imagePath: _uploadedImageDataUri ?? _uploadedImagePath ?? 'assets/images/media_1791634198035.png',
                                      validationStatus: ReceiptValidationStatus.valid,
                                      statusMessage: _isValidatedByOcr
                                          ? 'Verified dynamic reading committed via OCR capture.'
                                          : 'Receipt photo attached with manual totaliser confirmation.',
                                      capturedBy: '${state.currentUser.name} (live capture)',
                                      capturedAt: DateTime.now(),
                                      locationVerified: isInsidePerimeter,
                                      distanceMeters: curDist,
                                      scanLatitude: curLat,
                                      scanLongitude: curLon,
                                      scanAccuracyMeters: curAcc,
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
                            : !_isCustomImageUploaded
                                ? '🔒 Capture photo and validate using OCR to enable save'
                                : _isProcessingOcr
                                    ? 'Processing OCR verification...'
                                    : 'Both Nozzle 1 & Nozzle 2 readings must be captured to save',
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

  void _showScanTotaliserAgainDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: StationColors.accentOrange, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, color: StationColors.textDark, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.bug_report_outlined, size: 18),
            label: const Text('Diagnostics'),
            onPressed: () {
              Navigator.pop(ctx);
              _showOcrDiagnosticsDialog(context);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
            style: ElevatedButton.styleFrom(backgroundColor: StationColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              _captureOrUploadReceiptPhoto(context);
            },
            label: const Text(
              'Scan Totaliser Again',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
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
                final f = await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 2200,
                  maxHeight: 2200,
                  imageQuality: 90,
                );
                Navigator.pop(ctx, f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: StationColors.primary),
              title: const Text('Select from Gallery / Storage (JPG, PNG, HEIC)'),
              onTap: () async {
                final f = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 2200,
                  maxHeight: 2200,
                  imageQuality: 90,
                );
                Navigator.pop(ctx, f);
              },
            ),
          ],
        ),
      ),
    );

    if (photo != null) {
      if (mounted) {
        context.read<StationStateProvider>().refreshCurrentUserLocation(silent: true);
      }
      setState(() {
        _isProcessingOcr = true;
      });

      try {
        String dataUri = '';
        try {
          final bytes = await photo.readAsBytes();
          if (bytes.isNotEmpty) {
            final lowerName = '${photo.name} ${photo.path} ${photo.mimeType ?? ''}'.toLowerCase();
            final bool isHeic = lowerName.contains('.heic') ||
                lowerName.contains('.heif') ||
                lowerName.contains('image/heic') ||
                lowerName.contains('image/heif') ||
                (bytes.length >= 12 &&
                    bytes[4] == 0x66 &&
                    bytes[5] == 0x74 &&
                    bytes[6] == 0x79 &&
                    bytes[7] == 0x70);

            if (!kIsWeb && (isHeic || bytes.length > 450000)) {
              try {
                final codec = await ui.instantiateImageCodec(bytes, targetWidth: 960);
                final frame = await codec.getNextFrame();
                final pngData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
                if (pngData != null) {
                  dataUri = 'data:image/png;base64,${base64Encode(pngData.buffer.asUint8List())}';
                }
              } catch (convErr) {
                debugPrint('Preview normalization fallback: $convErr');
              }
            }

            if (dataUri.isEmpty) {
              final mime = isHeic ? 'image/heic' : (photo.mimeType ?? 'image/jpeg');
              final base64Data = base64Encode(bytes);
              dataUri = 'data:$mime;base64,$base64Data';
            }
          }
        } catch (e) {
          debugPrint('Could not read image bytes: $e');
        }

        // CRITICAL: On Android/iOS (!kIsWeb), pass the local file path (photo.path) to ML Kit
        // rather than a base64 data: URI string. On Web, pass the dataUri or blob path.
        final String effectivePath = kIsWeb
            ? (dataUri.isNotEmpty ? dataUri : photo.path)
            : (photo.path.isNotEmpty ? photo.path : dataUri);

        final stateBeforeOcr = context.read<StationStateProvider>();
        final pumpBeforeOcr = stateBeforeOcr.pumps.firstWhere(
          (p) => p.id == _selectedPumpId,
          orElse: () => stateBeforeOcr.pumps.first,
        );
        final double baselineN1 = pumpBeforeOcr.nozzles.isNotEmpty
            ? (pumpBeforeOcr.nozzles[0].currentTotaliserMl / 1000.0)
            : 0.0;
        final double baselineN2 = pumpBeforeOcr.nozzles.length > 1
            ? (pumpBeforeOcr.nozzles[1].currentTotaliserMl / 1000.0)
            : 0.0;

        final extraction = await OcrService.processReceiptImage(
          effectivePath,
          targetPumpId: _selectedPumpId,
          expectedBaselineLitres: {
            if (baselineN1 > 0) 1: baselineN1,
            if (baselineN2 > 0) 2: baselineN2,
          },
        );

        if (!mounted) return;

        final displayFileName = photo.name.isNotEmpty ? photo.name : photo.path;

        if (!extraction.success) {
          final now = DateTime.now();
          final fallbackDate = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
          final fallbackTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
          setState(() {
            _isProcessingOcr = false;
            _isCustomImageUploaded = true;
            _uploadedImagePath = displayFileName;
            _uploadedImageDataUri = dataUri.isNotEmpty ? dataUri : photo.path;
            _isValidatedByOcr = false;
            _isStrictVerified = false;
            _ocrErrorMessage = extraction.errorMessage ?? 'Could not read meter readings from receipt.';
            _ocrRawText = extraction.rawText;
            if (_dateController.text.trim().isEmpty) {
              _dateController.text = fallbackDate;
            }
            if (_timeController.text.trim().isEmpty) {
              _timeController.text = fallbackTime;
            }
            _nozzle1Controller.clear();
            _nozzle2Controller.clear();
            _matchedSnippets = {};
          });

          _showScanTotaliserAgainDialog(
            context,
            title: 'Scan Totaliser Again',
            message:
                '${extraction.errorMessage ?? "Could not clearly identify nozzle CumVolume lines."}\n\nPlease scan the totaliser receipt again, ensuring both Nozzle 1 and Nozzle 2 CumVolume lines are flat, well-lit, and not blurred.',
          );
          return;
        }

        final state = context.read<StationStateProvider>();
        final selectedPump = state.pumps.firstWhere(
          (p) => p.id == _selectedPumpId,
          orElse: () => state.pumps.first,
        );

        // Strict Wrong Pump validation gate (supports optical normalization & Pump 2 FP ID 3)
        final receiptPumpSNo = extraction.pumpSerialNumber.trim();
        final receiptFpId = extraction.fpId.trim();
        final expectedSNo = selectedPump.serialNumber.trim();
        final expectedFpId = selectedPump.id.replaceAll('pump_', '').trim();

        final bool matchesSNo = receiptPumpSNo.isNotEmpty &&
            (receiptPumpSNo == expectedSNo ||
                (receiptPumpSNo.length >= 4 &&
                    expectedSNo.length >= 4 &&
                    receiptPumpSNo.substring(receiptPumpSNo.length - 4) ==
                        expectedSNo.substring(expectedSNo.length - 4)));
        final bool matchesFp = receiptFpId.isNotEmpty &&
            (receiptFpId == expectedFpId ||
                (expectedFpId == '2' && receiptFpId == '3' && expectedSNo.endsWith('1346')));

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
                TextButton.icon(
                  icon: const Icon(Icons.bug_report_outlined, size: 18),
                  label: const Text('View Diagnostics'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showOcrDiagnosticsDialog(context);
                  },
                ),
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

        final bool hasNozzle1 = extraction.nozzleLitres.containsKey(1);
        final bool hasNozzle2 = selectedPump.nozzles.length < 2 || extraction.nozzleLitres.containsKey(2);
        final bool bothNozzlesCaptured = hasNozzle1 && hasNozzle2;

        setState(() {
          _isCustomImageUploaded = true;
          _uploadedImagePath = displayFileName;
          _uploadedImageDataUri = dataUri.isNotEmpty ? dataUri : photo.path;
          _isProcessingOcr = false;
          _isValidatedByOcr = bothNozzlesCaptured;
          _isStrictVerified = bothNozzlesCaptured && extraction.isStrictMatch;
          _ocrConfidence = extraction.confidence;
          _matchedSnippets = extraction.nozzleMatchedSnippet;
          _ocrRawText = extraction.rawText;
          _ocrErrorMessage = bothNozzlesCaptured
              ? null
              : (!hasNozzle1
                  ? 'Nozzle 1 reading was not captured for ${selectedPump.name}. Please scan the totaliser again.'
                  : 'Nozzle 2 CumVolume below the line was not captured clearly. Please scan the totaliser again.');

          if (extraction.date.isNotEmpty) {
            _dateController.text = extraction.date;
          }
          if (extraction.time.isNotEmpty) {
            _timeController.text = extraction.time;
          }

          if (extraction.nozzleLitres.containsKey(1)) {
            _nozzle1Controller.text = (extraction.nozzleLitres[1]!).toStringAsFixed(3);
          } else {
            _nozzle1Controller.clear();
          }
          if (extraction.nozzleLitres.containsKey(2)) {
            _nozzle2Controller.text = (extraction.nozzleLitres[2]!).toStringAsFixed(3);
          } else {
            _nozzle2Controller.clear();
          }
        });

        // Alert immediately if Nozzle 1 or Nozzle 2 reading was missed or rejected!
        if (!bothNozzlesCaptured) {
          final String missingDetail = !hasNozzle1 && !hasNozzle2
              ? 'Neither Nozzle 1 nor Nozzle 2 CumVolume readings could be captured clearly for ${selectedPump.name}.'
              : !hasNozzle1
                  ? 'Nozzle 1 reading was not captured for ${selectedPump.name} (only Nozzle 2 was detected).'
                  : 'Nozzle 2 CumVolume reading below the CumVolume line was not captured clearly for ${selectedPump.name} (or had an invalid gap).';
          _showScanTotaliserAgainDialog(
            context,
            title: 'Scan Totaliser Again',
            message:
                '$missingDetail\n\nPlease scan the totaliser receipt again, ensuring the full printout (both Nozzle 1 and Nozzle 2 CumVolume lines) is flat, well-lit, and clearly visible.',
          );
          return;
        }

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
          _uploadedImageDataUri = photo.path;
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

  void _showOcrDiagnosticsDialog(BuildContext context) {
    final state = context.read<StationStateProvider>();
    final selectedPump = state.pumps.firstWhere(
      (p) => p.id == _selectedPumpId,
      orElse: () => state.pumps.first,
    );
    final extraction = OcrService.lastExtraction;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (sheetCtx, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  // Title Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: StationColors.accentOrange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bug_report, color: StationColors.accentOrange, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OCR Diagnostics & Raw Slip',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StationColors.textDark),
                            ),
                            Text(
                              'Forecourt image recognition & parser telemetry',
                              style: TextStyle(fontSize: 12, color: StationColors.textMedium),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Engine & System Status Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Active OCR Engine:', style: TextStyle(fontSize: 13, color: StationColors.textMedium)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (kIsWeb ? Colors.blue.shade50 : Colors.teal.shade50),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: (kIsWeb ? Colors.blue.shade200 : Colors.teal.shade200)),
                              ),
                              child: Text(
                                extraction?.engineUsed ?? (kIsWeb ? 'Tesseract.js (In-Browser Web)' : 'Google ML Kit (Android)'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: (kIsWeb ? Colors.blue.shade800 : Colors.teal.shade800),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Recognition Latency:', style: TextStyle(fontSize: 13, color: StationColors.textMedium)),
                            Text('${extraction?.durationMs ?? 0} ms', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Validation Status:', style: TextStyle(fontSize: 13, color: StationColors.textMedium)),
                            Text(
                              extraction == null
                                  ? 'No scan attempted yet'
                                  : extraction.success
                                      ? '✅ Parsed Successfully'
                                      : '❌ Incomplete / Failed',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: extraction == null
                                    ? Colors.grey
                                    : extraction.success
                                        ? StationColors.successGreen
                                        : StationColors.errorRed,
                              ),
                            ),
                          ],
                        ),
                        if (extraction?.underlyingEngineError != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Engine Exception: ${extraction!.underlyingEngineError}',
                                    style: TextStyle(fontSize: 12, color: Colors.red.shade900),
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

                  // Field Matching Breakdown
                  const Text('Field-by-Field Match Telemetry:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: StationColors.textDark)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        _buildDiagnosticFieldRow('Pump Serial No', extraction?.pumpSerialNumber ?? '-', selectedPump.serialNumber),
                        const Divider(height: 14),
                        _buildDiagnosticFieldRow('FP ID', extraction?.fpId ?? '-', selectedPump.id.replaceAll('pump_', '')),
                        const Divider(height: 14),
                        _buildDiagnosticFieldRow('Slip Date', extraction?.date ?? '-', 'Must be recent'),
                        const Divider(height: 14),
                        _buildDiagnosticFieldRow('Slip Time', extraction?.time ?? '-', 'HH:mm:ss format'),
                        const Divider(height: 14),
                        _buildDiagnosticFieldRow(
                          'Nozzle 1 CumVolume',
                          extraction?.nozzleLitres[1] != null ? '${extraction!.nozzleLitres[1]} L' : 'Not isolated',
                          'CumVolume: XXXXXX.XXX',
                        ),
                        const Divider(height: 14),
                        _buildDiagnosticFieldRow(
                          'Nozzle 2 CumVolume',
                          extraction?.nozzleLitres[2] != null ? '${extraction!.nozzleLitres[2]} L' : 'Not isolated',
                          'CumVolume: XXXXXX.XXX',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Raw OCR Text Stream Viewer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Raw Extracted OCR Stream:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: StationColors.textDark)),
                      if (extraction != null && extraction.rawText.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.copy, size: 14, color: StationColors.primary),
                          label: const Text('Copy Raw Text', style: TextStyle(fontSize: 12, color: StationColors.primary)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: extraction.rawText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Raw OCR text copied to clipboard!')),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        (extraction != null && extraction.rawText.isNotEmpty)
                            ? extraction.rawText
                            : (extraction?.errorMessage ?? 'No OCR text extracted yet. Take a receipt photo using "Capture Photo" above to run diagnostics.'),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFFE2E8F0),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Troubleshooting Guide
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.help_outline, color: Colors.amber.shade900, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Mobile OCR Troubleshooting Steps',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildTroubleshootStep('1', 'Camera Permissions', 'Ensure Camera and Storage permissions are granted in Android Settings -> Apps -> Reya Filling Station -> Permissions.'),
                        _buildTroubleshootStep('2', 'Google Play Services Model', 'On first Android launch, Google Play Services downloads the Latin OCR model in the background. If installed offline, connect to Wi-Fi/Mobile Data for 1 minute.'),
                        _buildTroubleshootStep('3', 'Orientation & Glare', 'Hold the camera directly flat above the receipt (vertical orientation). Avoid reflections from sun or station canopy lights on thermal ink.'),
                        _buildTroubleshootStep('4', 'Dispatched Pump Serial', 'Ensure the receipt slip corresponds to the dispenser selected in the dropdown (e.g. SNo: ${selectedPump.serialNumber}).'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDiagnosticFieldRow(String label, String extracted, String target) {
    final bool isMatch = extracted != '-' && (target == 'Must be recent' || target == 'HH:mm:ss format' || target.startsWith('CumVolume') || extracted == target);
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(label, style: const TextStyle(fontSize: 12, color: StationColors.textMedium)),
        ),
        Expanded(
          flex: 4,
          child: Text(
            extracted,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: isMatch ? StationColors.textDark : StationColors.errorRed,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            target,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildTroubleshootStep(String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: Colors.amber.shade800,
            child: Text(num, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.3),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
